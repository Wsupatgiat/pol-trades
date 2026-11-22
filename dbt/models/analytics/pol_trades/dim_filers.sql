{{
	config(
		materialized='incremental',
		unique_key='filer_id',
		incremental_strategy='merge'
	)
}}

-- incremental: merge every stg_filers row on filer_id (update existing, insert new)
-- filers missing from the source are kept as-is (merge never deletes)
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
	photo_url,
	current_timestamp() as last_updated_at
from {{ ref('stg_filers') }}
