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
	-- office is cleaned first (clean_text: whitespace collapsed, trimmed, lowercased)
	-- congress: 'U.S. Representative · NJ-07' -> 'u.s. representative' (separator is chr(183))
	-- executive: strip numeric suffixes like 'Governor 2' -> 'governor'
	case
		when branch = 'congress' then trim(split_part({{ clean_text('office') }}, chr(183), 1))
		else regexp_replace({{ clean_text('office') }}, ' [0-9]+$', '')
	end as office_title,
	photo_url
from source
