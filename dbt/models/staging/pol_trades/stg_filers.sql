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
	{{ clean_text('office') }} as office,
	-- 'U.S. Representative · VA-07' --> 'u.s. representative'
	-- congress: after clean_text, keep the text before the middle dot (chr(183)); split_part, no regex
	-- 'Governor 3' --> 'governor'
	-- executive: after clean_text, regex strips a trailing space and number
	case
		when branch = 'congress' then trim(split_part({{ clean_text('office') }}, chr(183), 1))
		else regexp_replace({{ clean_text('office') }}, ' [0-9]+$', '')
	end as office_title,
	photo_url
from source
