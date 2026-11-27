{# 'SAP  SE ADS' --> 'sap se ads' #}
{# regex turns any whitespace run (spaces, tabs, newlines) into one space, then trim and lowercase #}
{% macro clean_text(column) -%}
	lower(trim(regexp_replace({{ column }}, '\\s+', ' ')))
{%- endmacro %}
