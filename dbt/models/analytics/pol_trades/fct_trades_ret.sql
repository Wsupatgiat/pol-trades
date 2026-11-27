select
	trade_id,
	ret_since,
	excess_since,
	ret_30d,
	ret_1y
from {{ ref('stg_trades') }}
