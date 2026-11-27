select
	-- filer columns, in source order
	df.filer_id,
	df.full_name,
	df.branch,
	df.party,
	df.state,
	-- trade columns, in source order
	ft.trade_id,
	ft.filing_id,
	ft.transaction_date,
	ft.notification_date,
	ft.owner,
	ft.ticker,
	ft.asset_name,
	ft.transaction_type,
	ft.amount_range_label,
	ft.comment,
	ft.is_late,
	ft.days_to_file,
	ft.doc_url,
	-- added by fct_trades, not in source
	ft.loaded_at as trades_loaded_at
from {{ ref('dim_filers') }} df
inner join {{ ref('fct_trades') }} ft
	on df.filer_id = ft.filer_id
-- TODO: timezone. Both sides use the session timezone for now
where to_date(ft.loaded_at) = current_date()
