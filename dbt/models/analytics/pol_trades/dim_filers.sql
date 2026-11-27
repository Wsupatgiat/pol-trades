{{
	config(
		materialized='incremental',
		unique_key='filer_id',
		incremental_strategy='merge',
		merge_exclude_columns=['loaded_at']
	)
}}

with stg as (
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
	{{
		dbt_utils.generate_surrogate_key([
			'full_name',
			'branch',
			'chamber',
			'party',
			'state',
			'agency',
			'level',
			'office',
			'office_title',
			'photo_url'
		])
	}} as row_hash
	from {{ ref('stg_filers') }}
)
select
	stg.*,
	current_timestamp() as updated_at,
	current_timestamp() as loaded_at
from stg
{% if is_incremental() %}
{{ select_new('stg', ['filer_id']) }}
{% endif %}
