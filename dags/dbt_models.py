"""Manually triggered DAG: run the dbt project in dbt/ with Cosmos. Cosmos turns each
dbt model into an Airflow task (run + test). The dbt profile is built from the
snowflake_default Airflow connection, so there is no profiles.yml."""

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig
from cosmos.profiles import SnowflakePrivateKeyPemProfileMapping
from pendulum import datetime

SNOWFLAKE_CONN_ID = "snowflake_default"

# paths inside the Astro containers (see Dockerfile and docker-compose.override.yml)
DBT_PROJECT_PATH = "/usr/local/airflow/dbt"
DBT_EXECUTABLE_PATH = "/usr/local/airflow/dbt_venv/bin/dbt"

profile_config = ProfileConfig(
	profile_name="pol-trades",
	target_name="testing",
	profile_mapping=SnowflakePrivateKeyPemProfileMapping(
		conn_id=SNOWFLAKE_CONN_ID,
		# the connection has database=raw and no schema; override both for dbt
		profile_args={"database": "staging", "schema": "testing"},
	),
)

dbt_models = DbtDag(
	dag_id="dbt_models",
	project_config=ProjectConfig(DBT_PROJECT_PATH),
	profile_config=profile_config,
	execution_config=ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE_PATH),
	start_date=datetime(2026, 10, 1),
	schedule=None,
	catchup=False,
	tags=["pol_trades", "dbt"],
	default_args={"retries": 2},
)
