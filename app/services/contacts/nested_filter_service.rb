class Contacts::NestedFilterService < FilterService
  ATTRIBUTE_MODEL = 'contact_attribute'.freeze

  def initialize(account, query)
    @account = account
    @query = query.is_a?(Hash) ? query.with_indifferent_access : {}
    file = File.read('./lib/filters/filter_keys.yml')
    @filters = YAML.safe_load(file)
    @filter_values = {}
    @index_counter = 0
  end

  def perform
    sql_string = build_nested_query(@query)
    contacts = base_relation.where(sql_string, @filter_values.with_indifferent_access)
    {
      contacts: contacts,
      count: contacts.count
    }
  end

  def filter_values(query_hash)
    current_val = query_hash['values'][0]
    if query_hash['attribute_key'] == 'phone_number'
      "+#{current_val&.delete('+')}"
    elsif query_hash['attribute_key'] == 'country_code'
      current_val.downcase
    else
      current_val.is_a?(String) ? current_val.downcase : current_val
    end
  end

  def base_relation
    @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
  end

  def filter_config
    {
      entity: 'Contact',
      table_name: 'contacts'
    }
  end

  private

  def build_nested_query(node)
    case node[:type]
    when 'group'
      build_group_query(node)
    when 'condition'
      build_condition_query_for_node(node)
    else
      ''
    end
  end

  def build_group_query(node)
    sql_operator = node[:operator]&.upcase == 'OR' ? ' OR ' : ' AND '

    parts = node[:children].filter_map do |child|
      child = child.with_indifferent_access if child.is_a?(Hash)
      result = build_nested_query(child)
      result.presence
    end

    return '' if parts.empty?

    "(#{parts.join(sql_operator)})"
  end

  def build_condition_query_for_node(node)
    @index_counter += 1
    current_index = @index_counter

    query_hash = {
      'attribute_key' => node[:attribute_key],
      'filter_operator' => node[:filter_operator],
      'values' => node[:values],
      'query_operator' => nil,
      'custom_attribute_type' => node[:attribute_model] == 'custom_attribute' ? 'contact_attribute' : nil
    }.with_indifferent_access

    model_filters = @filters['contacts']
    current_filter = model_filters[query_hash['attribute_key']]

    build_single_condition(current_filter, query_hash, current_index)
  end

  def build_single_condition(current_filter, query_hash, current_index)
    filter_operator_value = filter_operation(query_hash, current_index)

    if current_filter.nil?
      attribute_type = 'contact_attribute'
      return custom_attribute_query(query_hash, attribute_type, current_index).to_s.gsub(/\s*(AND|OR)\s*$/, '').strip
    end

    case current_filter['attribute_type']
    when 'additional_attributes'
      build_additional_attr_condition(query_hash, filter_operator_value, current_filter['data_type'])
    else
      build_standard_condition(current_filter, query_hash, current_index, filter_operator_value)
    end
  end

  def build_additional_attr_condition(query_hash, filter_operator_value, data_type)
    if data_type == 'text_case_insensitive'
      "LOWER(contacts.additional_attributes ->> '#{query_hash[:attribute_key]}') #{filter_operator_value}"
    else
      "contacts.additional_attributes ->> '#{query_hash[:attribute_key]}' #{filter_operator_value}"
    end
  end

  def build_standard_condition(current_filter, query_hash, current_index, filter_operator_value)
    case current_filter['data_type']
    when 'date'
      "(contacts.#{query_hash[:attribute_key]})::date #{filter_operator_value}::date"
    when 'labels'
      build_tag_condition(query_hash, current_index)
    when 'text_case_insensitive'
      "LOWER(contacts.#{query_hash[:attribute_key]}) #{filter_operator_value}"
    else
      "contacts.#{query_hash[:attribute_key]} #{filter_operator_value}"
    end
  end

  def build_tag_condition(query_hash, current_index)
    @filter_values["value_#{current_index}"] = filter_values(query_hash)

    tag_model_relation_query =
      "SELECT * FROM taggings WHERE taggings.taggable_id = contacts.id AND taggings.taggable_type = 'Contact'"
    tag_query =
      "AND taggings.tag_id IN (SELECT tags.id FROM tags WHERE tags.name IN (:value_#{current_index}))"

    case query_hash[:filter_operator]
    when 'equal_to'
      "EXISTS (#{tag_model_relation_query} #{tag_query})"
    when 'not_equal_to'
      "NOT EXISTS (#{tag_model_relation_query} #{tag_query})"
    when 'is_present'
      "EXISTS (#{tag_model_relation_query})"
    when 'is_not_present'
      "NOT EXISTS (#{tag_model_relation_query})"
    end
  end

  def equals_to_filter_string(filter_operator, current_index)
    return "= :value_#{current_index}" if filter_operator == 'equal_to'

    "!= :value_#{current_index}"
  end
end
