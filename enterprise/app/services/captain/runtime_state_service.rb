class Captain::RuntimeStateService
  STATE_KEY = 'assistant_runtime'.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def state
    @conversation.additional_attributes.fetch(STATE_KEY, {})
  end

  def update_state(patch)
    current = state
    @conversation.update!(
      additional_attributes: @conversation.additional_attributes.merge(STATE_KEY => current.merge(patch.stringify_keys))
    )
  end

  def reset_state
    @conversation.update!(
      additional_attributes: @conversation.additional_attributes.except(STATE_KEY)
    )
  end
end
