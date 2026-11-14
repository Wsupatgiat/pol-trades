with source as (
	select * from {{ source('pol_trades', 'trades') }}
),

typed as (
	select
		id,
		filer_id,
		filing_id,
		source_id,
		filing_type,
		doc_url,
		try_to_date(transaction_date) as transaction_date,
		try_to_date(notification_date) as notification_date,
		try_to_date(filing_date) as filing_date,
		try_to_timestamp_ntz(ingested_at) as ingested_at,
		owner,
		ticker,
		asset_name,
		asset_type,
		transaction_type,
		-- raw bound first; when null, parse from the label ('Over $x', or '$a - $b' with the '-' optional
		-- because some oge labels drop it, e.g. '$50,001 $100,000')
		coalesce(
			try_to_number(amount_range_low),
			try_to_number(replace(regexp_substr(amount_range_label, 'over \\$([0-9,]+)', 1, 1, 'ie', 1), ',', '')),
			try_to_number(replace(regexp_substr(amount_range_label, '^\\$([0-9,]+) *-? *\\$([0-9,]+)$', 1, 1, 'e', 1), ',', ''))
		) as amount_range_low,
		coalesce(
			try_to_number(amount_range_high),
			try_to_number(replace(regexp_substr(amount_range_label, '^\\$([0-9,]+) *-? *\\$([0-9,]+)$', 1, 1, 'e', 2), ',', ''))
		) as amount_range_high,
		amount_range_label,
		comment,
		try_to_boolean(is_late) as is_late,
		try_to_number(days_to_file) as days_to_file,
		try_to_boolean(notification_received_over_30d) as notification_received_over_30d,
		try_to_double(ret_since) as ret_since,
		try_to_double(excess_since) as excess_since,
		try_to_double(ret_30d) as ret_30d,
		try_to_double(ret_1y) as ret_1y
	from source
)

select
	id as trade_id,
	filer_id,
	filing_id,
	source_id,
	filing_type,
	doc_url,
	transaction_date,
	notification_date,
	filing_date,
	ingested_at,
	case owner
		when 'SP' then 'spouse'
		when 'Spouse' then 'spouse'
		when 'JT' then 'joint'
		when 'Joint' then 'joint'
		when 'DC' then 'dependent child'
		when 'Child' then 'dependent child'
		when 'DJ' then 'dependent joint'
		when 'Self' then 'self'
		when 'SA' then null
		else lower(owner)
	end as owner,
	-- Ticker Derived Columns
	ticker,
	case
		when ticker = 'US-TBILL' then null
		else regexp_substr(ticker, '^[A-Z0-9]+')
	end as ticker_root,
	case
		when regexp_like(ticker, '^[A-Z0-9]+[.-][A-Z]$') then right(ticker, 1)
	end as share_class,
	case
		when regexp_like(ticker, '^[A-Z0-9]+-P[A-Z]$') then right(ticker, 1)
	end as preferred_series,
	case
		when regexp_like(ticker, '^[A-Z0-9]+\\.[A-Z]{2}$') then split_part(ticker, '.', 2)
	end as exchange_suffix,
	-- Ticker Derived Columns
	coalesce(ticker = 'US-TBILL', false) as is_treasury_placeholder,
	{{ clean_text('asset_name') }} as asset_name,
	lower(asset_type) as asset_type,
	lower(transaction_type) as transaction_type,
	-- round the low bound down to 2 significant digits (1,001 -> 1,000; 5,000,001 -> 5,000,000).
	-- also absorbs label typos like '$5,001,001' -> 5,000,000
	case
		when amount_range_low > 0
			then (amount_range_low - mod(amount_range_low, power(10, floor(log(10, amount_range_low)) - 1)))::number
	end as amount_range_low,
	-- 'Over' labels have no upper bound (raw data stores 100,000,000 for some)
	case
		when amount_range_label ilike '%over $%' then null
		else amount_range_high
	end as amount_range_high,
	amount_range_label,
	{{ clean_text('comment') }} as comment,
	case
		when days_to_file >= 0 then days_to_file
	end as days_to_file,
	is_late,
	notification_received_over_30d,
	ret_since,
	excess_since,
	ret_30d,
	ret_1y
from typed
