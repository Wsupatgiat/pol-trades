# Raw landing tables for the pol_trades source. All columns varchar and nullable;

locals {
	filers_columns = [
		"id", "full_name", "branch", "chamber", "party",
		"state", "agency", "level", "office", "photo_url",
	]
	trades_columns = [
		"id", "filing_id", "filer_id", "source_id", "transaction_date",
		"notification_date", "filing_date", "owner", "ticker", "asset_name",
		"asset_type", "transaction_type", "amount_range_low", "amount_range_high", "amount_range_label",
		"comment", "is_late", "days_to_file", "ingested_at", "row_index",
		"notification_received_over_30d", "doc_url", "filing_type", "ret_since", "excess_since",
		"ret_30d", "ret_1y",
	]
}

# ===================== raw.pol_trades =====================
resource "snowflake_table" "raw_pol_trades_filers" {
	database = snowflake_schema.raw_pol_trades.database
	schema   = snowflake_schema.raw_pol_trades.name
	name     = "FILERS"

	dynamic "column" {
		for_each = local.filers_columns
		content {
			# Uppercase so unquoted references (e.g. in the connector) resolve
			name = upper(column.value)
			type = "VARCHAR"
		}
	}
}

resource "snowflake_table" "raw_pol_trades_trades" {
	database = snowflake_schema.raw_pol_trades.database
	schema   = snowflake_schema.raw_pol_trades.name
	name     = "TRADES"

	dynamic "column" {
		for_each = local.trades_columns
		content {
			name = upper(column.value)
			type = "VARCHAR"
		}
	}
}

# ===================== raw.testing =====================
resource "snowflake_table" "raw_testing_filers" {
	database = snowflake_schema.raw_testing.database
	schema   = snowflake_schema.raw_testing.name
	name     = "FILERS"

	dynamic "column" {
		for_each = local.filers_columns
		content {
			name = upper(column.value)
			type = "VARCHAR"
		}
	}
}

resource "snowflake_table" "raw_testing_trades" {
	database = snowflake_schema.raw_testing.database
	schema   = snowflake_schema.raw_testing.name
	name     = "TRADES"

	dynamic "column" {
		for_each = local.trades_columns
		content {
			name = upper(column.value)
			type = "VARCHAR"
		}
	}
}
