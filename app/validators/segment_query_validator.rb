class SegmentQueryValidator
  MAX_NODES = 20
  MAX_DEPTH = 3
  VALID_OPERATORS = %w[AND OR].freeze
  VALID_NODE_TYPES = %w[group condition].freeze
  CONDITION_FIELDS = %w[attribute_key filter_operator values].freeze

  attr_reader :errors

  def initialize(query)
    @query = query.is_a?(Hash) ? query.with_indifferent_access : {}
    @errors = []
    @node_count = 0
  end

  def valid?
    validate_root
    @errors.empty?
  end

  private

  def validate_root
    if @query[:type] != 'group'
      @errors << 'root node must be a group'
      return
    end

    validate_node(@query, depth: 1)
    @errors << "too many nodes (max #{MAX_NODES})" if @node_count > MAX_NODES
  end

  def validate_node(node, depth:)
    @node_count += 1

    unless VALID_NODE_TYPES.include?(node[:type])
      @errors << "invalid node type: #{node[:type]}"
      return
    end

    case node[:type]
    when 'group'
      validate_group(node, depth)
    when 'condition'
      validate_condition(node)
    end
  end

  def validate_group(node, depth)
    unless VALID_OPERATORS.include?(node[:operator]&.upcase)
      @errors << "invalid operator: #{node[:operator]}"
    end

    unless node[:children].is_a?(Array) && node[:children].any?
      @errors << 'group must have at least one child'
      return
    end

    node[:children].each do |child|
      child = child.with_indifferent_access if child.is_a?(Hash)
      if child[:type] == 'group' && depth >= MAX_DEPTH
        @errors << "maximum nesting depth exceeded (max #{MAX_DEPTH})"
        next
      end
      validate_node(child, depth: child[:type] == 'group' ? depth + 1 : depth)
    end
  end

  def validate_condition(node)
    CONDITION_FIELDS.each do |field|
      @errors << "condition missing #{field}" if node[field].blank?
    end
  end
end
