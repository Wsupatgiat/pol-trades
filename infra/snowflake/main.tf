terraform {
	required_providers {
		snowflake = {
			source  = "snowflakedb/snowflake"
			version = "~> 2.22"
		}
	}
}

locals {
	sf_conn    = jsondecode(regex("AIRFLOW_CONN_SNOWFLAKE_DEFAULT='?(\\{.*\\})'?", file("${path.module}/../../.env"))[0])
	# Assumes extra.account is in "orgname-accountname" format
	sf_account = split("-", local.sf_conn.extra.account)
}

provider "snowflake" {
	organization_name        = local.sf_account[0]
	account_name             = local.sf_account[1]
	user                     = local.sf_conn.login
	authenticator            = "SNOWFLAKE_JWT"
	# Airflow Snowflake provider 6.3.0+ stores the key base64 encoded; the Terraform provider needs PEM
	private_key              = base64decode(local.sf_conn.extra.private_key_content)
	# Airflow stores a key passphrase in the connection password; null if the key is unencrypted
	private_key_passphrase   = try(local.sf_conn.password, null)
	role                     = "ACCOUNTADMIN"
	preview_features_enabled = ["snowflake_table_resource"]
}

resource "snowflake_warehouse" "data_wh" {
	name           = "DATA_WH"
	warehouse_size = "X-SMALL"
}

# ===================== databases =====================
resource "snowflake_database" "raw" {
	name = "RAW"
}

resource "snowflake_database" "staging" {
	name = "STAGING"
}

resource "snowflake_database" "analytics" {
	name = "ANALYTICS"
}

# ===================== raw schemas =====================
resource "snowflake_schema" "raw_pol_trades" {
	name     = "POL_TRADES"
	database = snowflake_database.raw.name
}

resource "snowflake_schema" "raw_testing" {
	name     = "TESTING"
	database = snowflake_database.raw.name
}

# ===================== staging schemas =====================
resource "snowflake_schema" "staging_pol_trades" {
	name     = "POL_TRADES"
	database = snowflake_database.staging.name
}

resource "snowflake_schema" "staging_testing" {
	name     = "TESTING"
	database = snowflake_database.staging.name
}

# ===================== analytics schemas =====================
resource "snowflake_schema" "analytics_pol_trades" {
	name     = "POL_TRADES"
	database = snowflake_database.analytics.name
}

resource "snowflake_schema" "analytics_testing" {
	name     = "TESTING"
	database = snowflake_database.analytics.name
}
