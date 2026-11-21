select
	filer_id,
	full_name,
	branch,
	chamber,
	party,
	state,
	agency,
	level,
	office,
	office_title,
	photo_url
from {{ ref('stg_filers') }}
