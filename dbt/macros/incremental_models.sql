{% macro select_new(src, keys, hash_col='row_hash') %}
	left join {{ this }} this
		on
		{%- for key in keys %}
		{% if not loop.first %}and {% endif %}{{ src }}.{{ key }} = this.{{ key }}
		{%- endfor %}
	where
		this.{{ keys[0] }} is null
		or {{ src }}.{{ hash_col }} <> this.{{ hash_col }}
{% endmacro %}
