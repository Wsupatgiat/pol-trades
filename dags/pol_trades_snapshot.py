"""Manually triggered DAG: load the latest congress-trading-monitor snapshot into
raw.<schema>.filers / trades. All logic lives in connectors/pol_trades.py; this file
only wires it into Airflow."""

from airflow.sdk import Param, dag, task
from pendulum import datetime

SNOWFLAKE_CONN_ID = "snowflake_default"


@dag(
	start_date=datetime(2026, 10, 1),
	schedule=None,
	catchup=False,
	tags=["pol_trades", "raw"],
	default_args={"retries": 2},
	params={"schema": Param("testing", enum=["testing", "pol_trades"])},
)
def pol_trades_snapshot():
	@task
	def download_validate_load(**context):
		# imported here so the DAG file parses without the Snowflake packages
		from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

		from connectors.pol_trades import run

		conn = SnowflakeHook(snowflake_conn_id=SNOWFLAKE_CONN_ID).get_conn()
		try:
			return run(conn, schema=context["params"]["schema"])
		finally:
			conn.close()

	download_validate_load()


pol_trades_snapshot()
