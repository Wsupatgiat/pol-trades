-- Raw landing tables for the pol_trades source (filer + trades JSON from
-- kadoa-org/congress-trading-monitor). All columns are varchar and nullable;
-- casting, cleaning and null checks happen in dbt staging.
--
-- Run after bootstrap-snowflake/bootstrap.sql. Safe to rerun.

-- ===================== raw.pol_trades =====================
create table if not exists raw.pol_trades.filers (
	id varchar,
	full_name varchar,
	branch varchar,
	chamber varchar,
	party varchar,
	state varchar,
	agency varchar,
	level varchar,
	office varchar,
	photo_url varchar
);

create table if not exists raw.pol_trades.trades (
	id varchar,
	filing_id varchar,
	filer_id varchar,
	source_id varchar,
	transaction_date varchar,
	notification_date varchar,
	filing_date varchar,
	owner varchar,
	ticker varchar,
	asset_name varchar,
	asset_type varchar,
	transaction_type varchar,
	amount_range_low varchar,
	amount_range_high varchar,
	amount_range_label varchar,
	comment varchar,
	is_late varchar,
	days_to_file varchar,
	ingested_at varchar,
	row_index varchar,
	notification_received_over_30d varchar,
	doc_url varchar,
	filing_type varchar,
	ret_since varchar,
	excess_since varchar,
	ret_30d varchar,
	ret_1y varchar
);

-- ===================== raw.testing =====================
create table if not exists raw.testing.filers (
	id varchar,
	full_name varchar,
	branch varchar,
	chamber varchar,
	party varchar,
	state varchar,
	agency varchar,
	level varchar,
	office varchar,
	photo_url varchar
);

create table if not exists raw.testing.trades (
	id varchar,
	filing_id varchar,
	filer_id varchar,
	source_id varchar,
	transaction_date varchar,
	notification_date varchar,
	filing_date varchar,
	owner varchar,
	ticker varchar,
	asset_name varchar,
	asset_type varchar,
	transaction_type varchar,
	amount_range_low varchar,
	amount_range_high varchar,
	amount_range_label varchar,
	comment varchar,
	is_late varchar,
	days_to_file varchar,
	ingested_at varchar,
	row_index varchar,
	notification_received_over_30d varchar,
	doc_url varchar,
	filing_type varchar,
	ret_since varchar,
	excess_since varchar,
	ret_30d varchar,
	ret_1y varchar
);
