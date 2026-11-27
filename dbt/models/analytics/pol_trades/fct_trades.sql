{{
	config(
		materialized='incremental',
		unique_key='trade_id',
		incremental_strategy='merge',
		merge_exclude_columns=['loaded_at']
	)
}}

with stg as (
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
		{{
			dbt_utils.generate_surrogate_key([
				'filer_id',
				'filing_id',
				'source_id',
				'filing_type',
				'doc_url',
				'transaction_date',
				'notification_date',
				'filing_date',
				'ingested_at',
				'owner',
				'ticker',
				'ticker_root',
				'share_class',
				'preferred_series',
				'exchange_suffix',
				'is_treasury_placeholder',
				'asset_name',
				'asset_type',
				'transaction_type',
				'amount_range_low',
				'amount_range_high',
				'amount_range_label',
				'comment',
				'days_to_file',
				'is_late',
				'notification_received_over_30d'
			])
		}} as row_hash
	from {{ ref('stg_trades') }}
)
select
	stg.*,
	current_timestamp() as loaded_at,
	current_timestamp() as updated_at
from stg
{% if is_incremental() %}
{{ select_new('stg', ['trade_id']) }}
{% endif %}


