with source as (
	select * from {{ source('pol_trades', 'filers') }}
)

select
	id as filer_id,
	lower(full_name) as full_name,
	branch,
	chamber,
	party,
	state,
	lower(agency) as agency,
	case level
		when 'Level I' then 1
		when 'Level II' then 2
	end::integer as level,
	office,
	-- congress: 'U.S. Representative · NJ-07' -> 'U.S. Representative' (separator is chr(183))
	-- executive: strip numeric suffixes like 'Governor 2'
	case
		when branch = 'congress' then trim(split_part(office, chr(183), 1))
		else regexp_replace(office, ' [0-9]+$', '')
	end as office_title,
	photo_url
from source
