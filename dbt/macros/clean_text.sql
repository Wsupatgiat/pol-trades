{#
	Clean a free-text column:
	- newlines, tabs and runs of any whitespace become a single space
	- leading/trailing whitespace trimmed
	- lowercased
	Usage: {{ clean_text('asset_name') }} as asset_name
#}
{# 'SAP  SE ADS' --> 'sap se ads' #}
{# regex turns any whitespace run (spaces, tabs, newlines) into one space, then trim and lowercase #}
{% macro clean_text(column) -%}
	lower(trim(regexp_replace({{ column }}, '\\s+', ' ')))
{%- endmacro %}
