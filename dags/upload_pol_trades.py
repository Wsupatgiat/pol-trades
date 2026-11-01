"""Manually triggered DAG: upload the latest congress-trading-monitor snapshot to S3 as
two gzipped CSVs, then COPY them into raw.<schema>.filers / trades (truncate, then load).

extract_raw is ported as-is from data_profiling/upload_raw/upload_s3.py (no validation).
Snowflake reads the files straight from S3 using the aws_default connection's keys,
passed inline in COPY INTO (no stage / storage integration yet). The rendered SQL shows
the access key id in the UI and task logs; the secret key is masked by Airflow."""

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.sdk import Param, dag, task
from pendulum import datetime

AWS_CONN_ID = "aws_default"
SNOWFLAKE_CONN_ID = "snowflake_default"
REGION = "us-east-1"
BUCKET_PARAMETER = "/pol-trades/raw_data_bucket"

REPO = "kadoa-org/congress-trading-monitor"

FILER_COLUMNS = ["id", "full_name", "branch", "chamber", "party", "state", "agency", "level", "office", "photo_url"]
TRADE_COLUMNS = ["id", "filer_id", "filing_id", "source_id", "filing_type", "transaction_date", "notification_date",
	"filing_date", "owner", "ticker", "asset_name", "asset_type", "transaction_type", "amount_range_low",
	"amount_range_high", "amount_range_label", "comment", "is_late", "days_to_file", "ingested_at",
	"notification_received_over_30d", "doc_url", "ret_since", "excess_since", "ret_30d", "ret_1y", "row_index"]
NULL = "\\N"

# Truncate raw.<schema>.<table>, then COPY s3://bucket/prefix/<table>.csv.gz into it.
# The CSV column order differs from the table, so columns are matched by header name.
# FORCE = TRUE so re-running the same sha reloads instead of skipping already-loaded files.
# The last statement's result (row count) is pushed to XCom.
TARGET = "raw.{{ params.schema }}.{{ params.table }}"
LOAD_SQL = [
	f"truncate table {TARGET}",
	f"""
	copy into {TARGET}
	from 's3://{{{{ ti.xcom_pull(task_ids='extract_raw')['bucket'] }}}}/{{{{ ti.xcom_pull(task_ids='extract_raw')['prefix'] }}}}{{{{ params.table }}}}.csv.gz'
	credentials = (aws_key_id = '{{{{ conn.{AWS_CONN_ID}.login }}}}' aws_secret_key = '{{{{ conn.{AWS_CONN_ID}.password }}}}')
	file_format = (
		type = csv
		parse_header = true
		field_optionally_enclosed_by = '"'
		compression = gzip
		null_if = ('\\\\N')
	)
	match_by_column_name = case_insensitive
	force = true
	""",
	f"select count(*) from {TARGET}",
]


def to_csv_gz(rows, columns):
	import csv
	import gzip
	import io

	buf = io.StringIO()
	# fieldnames fixed so column order is stable; a key not in columns raises ValueError
	writer = csv.DictWriter(buf, fieldnames=columns)
	writer.writeheader()
	for row in rows:
		writer.writerow({**{k: NULL for k in columns}, **{k: v for k, v in row.items() if v is not None}})
	return gzip.compress(buf.getvalue().encode("utf-8"))


@dag(
	start_date=datetime(2026, 10, 1),
	schedule=None,
	catchup=False,
	tags=["pol_trades", "raw"],
	default_args={"retries": 2},
	params={"schema": Param("testing", enum=["testing", "pol_trades"])},
)
def upload_pol_trades():
	@task
	def extract_raw():
		import io
		import json
		import tarfile
		from datetime import datetime, timezone
		from pathlib import PurePosixPath

		import requests
		from airflow.providers.amazon.aws.hooks.s3 import S3Hook

		hook = S3Hook(aws_conn_id=AWS_CONN_ID, region_name=REGION)
		s3 = hook.get_conn()
		bucket = hook.get_session().client("ssm").get_parameter(Name=BUCKET_PARAMETER)["Parameter"]["Value"]

		sha = requests.get(f"https://api.github.com/repos/{REPO}/commits/main", timeout=60).json()["sha"]
		archive = requests.get(f"https://codeload.github.com/{REPO}/tar.gz/{sha}", timeout=60).content

		snapshot_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
		prefix = f"pol_trades/snapshot_date={snapshot_date}/sha={sha}/"

		filers, trades = [], []
		with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
			for member in tar:
				path = PurePosixPath(member.name)
				if member.isfile() and path.suffix == ".json" and path.parent.as_posix().endswith("public/data/filer"):
					data = json.load(tar.extractfile(member))
					filers.append(data["filer"])
					trades.extend(data["trades"])

		for name, rows, columns in [("filers", filers, FILER_COLUMNS), ("trades", trades, TRADE_COLUMNS)]:
			s3.put_object(Bucket=bucket, Key=f"{prefix}{name}.csv.gz", Body=to_csv_gz(rows, columns),
				ContentType="text/csv", ContentEncoding="gzip")

		print(f"uploaded {len(filers)} filers and {len(trades)} trades to s3://{bucket}/{prefix}")
		return {"bucket": bucket, "prefix": prefix}

	# load_filers and load_trades run in parallel after extract_raw
	load_filers = SQLExecuteQueryOperator(
		task_id="load_filers",
		conn_id=SNOWFLAKE_CONN_ID,
		sql=LOAD_SQL,
		params={"table": "filers"},
	)
	load_trades = SQLExecuteQueryOperator(
		task_id="load_trades",
		conn_id=SNOWFLAKE_CONN_ID,
		sql=LOAD_SQL,
		params={"table": "trades"},
	)

	extract_raw() >> [load_filers, load_trades]


upload_pol_trades()
