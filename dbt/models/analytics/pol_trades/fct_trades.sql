select
	trade_id,
	filer_id,
	filing_id,
	source_id,
	filing_type,
	doc_url,
	-- format: YYYY-MM-DD
	transaction_date,
	-- format: YYYY-MM-DD
	notification_date,
	-- format: YYYY-MM-DD
	filing_date,
	-- format: YYYY-MM-DD HH:MI:SS
	ingested_at,
	owner,
	ticker,
	ticker_root,
	share_class,
	preferred_series,
	exchange_suffix,
	is_treasury_placeholder,
	asset_name,
	asset_type,
	transaction_type,
	amount_range_low,
	amount_range_high,
	amount_range_label,
	comment,
	days_to_file,
	is_late,
	notification_received_over_30d,
	ret_since,
	excess_since,
	ret_30d,
	ret_1y
from {{ ref('stg_trades') }}
