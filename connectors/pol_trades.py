"""Download the latest congress-trading-monitor snapshot from GitHub and load it
into raw.<schema>.filers and raw.<schema>.trades. Everything stays in memory; nothing
is written to disk.

Ported from data_profiling/snowflake_upload/download_and_load_test.py. Same flow;
differences: the caller passes an open Snowflake connection and the target schema,
and progress goes to logging instead of print.

Flow:

[a] GET LATEST SHA + BUILD URL
	a1. GET the latest commit on main from the GitHub API
	a2. read the sha, check it is 40 hex chars
	a3. build the archive download URL for that sha
	a4. log sha + commit message

[b] DOWNLOAD ARCHIVE INTO MEMORY
	b1. GET the archive URL with a timeout
	b2. on network error / 5xx: retry a few times with a short wait
	b3. on any other non-200 (e.g. 404): fail immediately
	b4. keep the response body as bytes
	b5. log size (expect ~11 MB)

[c] OPEN ARCHIVE + SELECT FILER FILES
	c1. open the .tar.gz from memory
	c2. keep only regular .json files directly inside public/data/filer/
	c3. fail if none were found

[d] PARSE FILER FILES IN MEMORY
	d1. read + json-parse each selected file; record parse errors, keep going
	d2. result: list of (filename, data) pairs

[e] VALIDATE
	e1. file count > 0; warn if far from ~446
	e2. per file: dict with `filer` and `trades` keys, `trades` is a list;
	    warn if filer id != filename
	e3. fail once with a summary of ALL problems (from d1 + e2)
	e4. log number of filers and trades

[f] LOAD INTO SNOWFLAKE
	f1. build filers DataFrame (all values as strings)
	f2. build trades DataFrame (all values as strings)
	f3. write_pandas with overwrite into raw.<schema>.filers (truncate, then load)
	f4. write_pandas with overwrite into raw.<schema>.trades (truncate, then load)
	f5. log row counts from Snowflake

The tables must already exist (bootstrap-snowflake/raw_tables.sql). The truncate is
not rolled back if the load fails, so a failed load leaves the table empty.

Requires: requests, pandas, pyarrow, snowflake-connector-python.
"""

import io
import json
import logging
import re
import tarfile
import time
from pathlib import Path

import pandas as pd
import requests
from snowflake.connector.pandas_tools import write_pandas

log = logging.getLogger(__name__)

REPO = "kadoa-org/congress-trading-monitor"
BRANCH = "main"
FILER_PATH_PART = "/public/data/filer/"
EXPECTED_FILERS = 446

TIMEOUT_SECONDS = 60
MAX_ATTEMPTS = 3
RETRY_WAIT_SECONDS = 5

DATABASE = "raw"

FILER_COLUMNS = [
	"id",
	"full_name",
	"branch",
	"chamber",
	"party",
	"state",
	"agency",
	"level",
	"office",
	"photo_url",
]

TRADE_COLUMNS = [
	"id",
	"filing_id",
	"filer_id",
	"source_id",
	"transaction_date",
	"notification_date",
	"filing_date",
	"owner",
	"ticker",
	"asset_name",
	"asset_type",
	"transaction_type",
	"amount_range_low",
	"amount_range_high",
	"amount_range_label",
	"comment",
	"is_late",
	"days_to_file",
	"ingested_at",
	"row_index",
	"notification_received_over_30d",
	"doc_url",
	"filing_type",
	"ret_since",
	"excess_since",
	"ret_30d",
	"ret_1y",
]


# [a] GET LATEST SHA + BUILD URL
def get_latest_sha_and_url():
	# a1. ask the GitHub API for the latest commit on main
	api_url = f"https://api.github.com/repos/{REPO}/commits/{BRANCH}"
	resp = requests.get(api_url, timeout=TIMEOUT_SECONDS)
	if resp.status_code != 200:
		raise RuntimeError(f"GitHub API returned {resp.status_code} for {api_url} (403 may mean rate limit)")
	commit = resp.json()

	# a2. read the sha and check it looks like a full commit hash
	sha = commit["sha"]
	if not re.fullmatch(r"[0-9a-f]{40}", sha):
		raise RuntimeError(f"Unexpected sha format: {sha!r}")

	# a3. build the archive download URL for exactly this commit
	archive_url = f"https://codeload.github.com/{REPO}/tar.gz/{sha}"

	# a4. log which commit we are loading
	message = commit["commit"]["message"].splitlines()[0]
	log.info(f"[a] latest commit: {sha} ({message})")
	return sha, archive_url


# [b] DOWNLOAD ARCHIVE INTO MEMORY
def download_archive(archive_url):
	for attempt in range(1, MAX_ATTEMPTS + 1):
		# b1. GET the archive with a timeout
		try:
			resp = requests.get(archive_url, timeout=TIMEOUT_SECONDS)
		except requests.RequestException as e:
			# b2. network error: retry after a short wait
			log.warning(f"[b] attempt {attempt} failed: {e}")
			time.sleep(RETRY_WAIT_SECONDS)
			continue

		# b2. server error (5xx): retry after a short wait
		if resp.status_code >= 500:
			log.warning(f"[b] attempt {attempt} got {resp.status_code}, retrying")
			time.sleep(RETRY_WAIT_SECONDS)
			continue

		# b3. any other non-200 (e.g. 404 bad sha): fail immediately
		if resp.status_code != 200:
			raise RuntimeError(f"Archive download returned {resp.status_code} for {archive_url}")

		# b4. keep the whole body in memory
		archive_bytes = resp.content

		# b5. log the size
		log.info(f"[b] downloaded {len(archive_bytes) / 1_000_000:.1f} MB")
		return archive_bytes

	raise RuntimeError(f"Archive download failed after {MAX_ATTEMPTS} attempts")


# [c] OPEN ARCHIVE + SELECT FILER FILES
def select_filer_members(tar):
	# c2. keep only regular .json files directly inside public/data/filer/
	members = []
	for member in tar.getmembers():
		if not member.isfile():
			continue
		if FILER_PATH_PART not in member.name:
			continue
		if not member.name.endswith(".json"):
			continue
		name_inside_filer = member.name.split(FILER_PATH_PART, 1)[1]
		if "/" in name_inside_filer:
			continue
		members.append(member)

	# c3. nothing found means the repo layout probably changed
	if not members:
		raise RuntimeError(f"No files found under {FILER_PATH_PART} in the archive (layout changed?)")

	log.info(f"[c] found {len(members)} filer files in archive")
	return members


# [d] PARSE FILER FILES IN MEMORY
def parse_filer_files(tar, members, problems):
	# d1. read + parse each file; record errors instead of stopping
	parsed = []
	for member in members:
		filename = Path(member.name).name
		try:
			raw = tar.extractfile(member).read()
			data = json.loads(raw)
		except (json.JSONDecodeError, UnicodeDecodeError) as e:
			problems.append(f"{filename}: could not parse JSON ({e})")
			continue
		parsed.append((filename, data))

	# d2. list of (filename, data) pairs
	return parsed


# [e] VALIDATE
def validate(parsed, problems):
	# e1. check the file count
	if not parsed:
		problems.append("no filer files could be parsed")
	elif abs(len(parsed) - EXPECTED_FILERS) > EXPECTED_FILERS * 0.2:
		log.warning(f"[e] {len(parsed)} filer files, expected about {EXPECTED_FILERS}")

	# e2. check the structure of each file
	for filename, data in parsed:
		if not isinstance(data, dict) or "filer" not in data or "trades" not in data:
			problems.append(f"{filename}: missing top-level `filer` or `trades` key")
			continue
		if not isinstance(data["trades"], list):
			problems.append(f"{filename}: `trades` is not a list")
			continue
		if data["filer"].get("id") != Path(filename).stem:
			log.warning(f"[e] {filename}: filer id is {data['filer'].get('id')!r}")

	# e3. fail once, listing every problem found in [d] and [e]
	if problems:
		summary = "\n".join(f"  - {p}" for p in problems)
		raise RuntimeError(f"Snapshot failed validation ({len(problems)} problem(s)):\n{summary}")

	# e4. log what we are about to load
	n_trades = sum(len(data["trades"]) for _, data in parsed)
	log.info(f"[e] valid: {len(parsed)} filers, {n_trades} trades")


def to_varchar_df(records, columns):
	"""Build a DataFrame of strings (None stays None) so pandas never turns
	nullable ints into floats (e.g. 1001 -> 1001.0) before they reach Snowflake."""
	rows = [
		{c: None if r.get(c) is None else str(r.get(c)) for c in columns}
		for r in records
	]
	return pd.DataFrame(rows, columns=columns, dtype=object)


def upload(conn, schema, table, df):
	cur = conn.cursor()
	success, _, _, _ = write_pandas(
		conn,
		df,
		table_name=table,
		database=DATABASE,
		schema=schema,
		quote_identifiers=False,
		overwrite=True,
		auto_create_table=False,
	)
	if not success:
		raise RuntimeError(f"write_pandas failed for {table}")
	cur.execute(f"select count(*) from {DATABASE}.{schema}.{table}")
	log.info(f"[f] {DATABASE}.{schema}.{table} now has {cur.fetchone()[0]} rows")


# [f] LOAD INTO SNOWFLAKE
def load_into_snowflake(conn, schema, parsed):
	# f1. one filer row per file
	filers_df = to_varchar_df([data["filer"] for _, data in parsed], FILER_COLUMNS)

	# f2. one trade row per item in every file's trades list
	trades_df = to_varchar_df([t for _, data in parsed for t in data["trades"]], TRADE_COLUMNS)

	# f3. empty and fill the filers table
	upload(conn, schema, "filers", filers_df)

	# f4. empty and fill the trades table
	upload(conn, schema, "trades", trades_df)


def run(conn, schema):
	"""Run [a]-[f] against an open Snowflake connection. The caller owns the
	connection (opens and closes it). Returns a small summary for logging/XCom."""
	run_start_time = time.time()

	# [a] which commit to load
	sha, archive_url = get_latest_sha_and_url()

	# [b] download it
	archive_bytes = download_archive(archive_url)

	# [c] open the archive from memory and pick the filer files
	# c1. open the .tar.gz straight from the bytes
	with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as tar:
		members = select_filer_members(tar)

		# [d] parse them (problems are collected, not raised yet)
		problems = []
		parsed = parse_filer_files(tar, members, problems)

	# [e] validate everything, fail once if anything is wrong
	validate(parsed, problems)

	# [f] load into Snowflake
	load_into_snowflake(conn, schema, parsed)

	n_trades = sum(len(data["trades"]) for _, data in parsed)
	log.info(f"done: loaded snapshot {sha} into {DATABASE}.{schema} in {round(time.time() - run_start_time)}s")
	return {"sha": sha, "filers": len(parsed), "trades": n_trades}
