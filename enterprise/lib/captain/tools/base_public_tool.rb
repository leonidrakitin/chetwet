require 'agents'

class Captain::Tools::BasePublicTool < Agents::Tool
  # risk_level indicates the side-effect scope of a tool:
  # - :read     — pure lookup, no state change (default)
  # - :write    — changes business state but is reversible / low-impact
  # - :critical — irreversible or high-impact (refund, cancel, pay), requires customer confirmation
  def self.risk_level(level = nil)
    if level.nil?
      @risk_level || :read
    else
      @risk_level = level.to_sym
    end
  end

  def self.inherited(subclass)
    super
    subclass.instance_variable_set(:@risk_level, @risk_level) if defined?(@risk_level)
  end

  def initialize(assistant)
    @assistant = assistant
    super()
  end

  def active?
    # Public tools are always active
    true
  end

  def permissions
    # Override in subclasses to specify required permissions
    # Returns empty array for public tools (no permissions required)
    []
  end

  def risk_level
    self.class.risk_level
  end

  private

  # Fail-safe for write/critical tools: ensure the LLM has called at least one
  # of the given lookup tools before invoking this one. Prevents tools from
  # being called with hallucinated IDs.
  #
  # Returns nil if grounding is satisfied, or an error hash that the caller
  # should return from #perform when it is not.
  # rubocop:disable Metrics/CyclomaticComplexity
  def ensure_prior_tool(tool_context, *tool_names)
    needed = Array(tool_names).flatten.map { |n| normalize_tool_name(n) }.uniq
    return nil if needed.empty?

    history = Array(tool_context&.state&.dig(:orchestration, :tool_history)).map { |n| normalize_tool_name(n) }
    return nil if needed.any? { |name| history.include?(name) }

    {
      status: 'error',
      policy: 'param_not_grounded',
      error: "Before calling this tool, call one of: #{needed.join(', ')} to confirm parameters."
    }
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def normalize_tool_name(name)
    name.to_s.delete_prefix('captain--tools--').sub(/\Acaptain::tools::/i, '').downcase
  end

  def account_scoped(model_class)
    model_class.where(account_id: @assistant.account_id)
  end

  def find_conversation(state)
    conversation_id = state&.dig(:conversation, :id)
    return nil unless conversation_id

    account_scoped(::Conversation).find_by(id: conversation_id)
  end

  def find_contact(state)
    contact_id = state&.dig(:contact, :id)
    return nil unless contact_id

    account_scoped(::Contact).find_by(id: contact_id)
  end

  def log_tool_usage(action, details = {})
    Rails.logger.info do
      "#{self.class.name}: #{action} for assistant #{@assistant&.id} - #{details.inspect}"
    end
  end
end
