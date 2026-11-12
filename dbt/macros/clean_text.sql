{#
	Clean a free-text column:
	- newlines, tabs and runs of any whitespace become a single space
	- leading/trailing whitespace trimmed
	- lowercased
	Usage: {{ clean_text('asset_name') }} as asset_name
#}
{% macro clean_text(column) -%}
	lower(trim(regexp_replace({{ column }}, '\\s+', ' ')))
{%- endmacro %}
