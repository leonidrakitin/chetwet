# frozen_string_literal: true

class ApprovalBot::DraftResponseService < Captain::BaseTaskService
  def initialize(approval_request, option_index)
    @request = approval_request
    @option_index = option_index
    super(account: approval_request.account, conversation_display_id: approval_request.conversation.display_id)
  end

  def generate
    option = @request.options[@option_index]&.with_indifferent_access
    return nil unless option

    result = perform_with_option(option)
    result&.dig(:message).presence
  end

  private

  def perform_with_option(option)
    make_api_call(
      model: GPT_MODEL,
      messages: [
        { role: 'system', content: system_prompt(option) },
        { role: 'user', content: formatted_conversation }
      ]
    )
  end

  def system_prompt(option)
    <<~PROMPT
      You are helping a customer support agent draft their next reply.
      The agent will send this message directly to the customer.

      The customer's conversation was escalated to a human operator.
      The operator reviewed the situation and chose the following action:
      "#{option[:label]}"

      #{escalation_context}

      Write a clear, helpful reply to the customer based on the operator's decision.
      - Address the customer directly
      - Be concise and friendly
      - Do not mention internal processes, escalation, or operator decisions
      - Reply in the customer's language (match the language used in the conversation)
      - Output only the reply text, nothing else
    PROMPT
  end

  def escalation_context
    return '' if @request.context.blank?

    "Context of the escalation:\n#{@request.context.truncate(1000)}"
  end

  def formatted_conversation
    LlmFormatter::ConversationLlmFormatter.new(conversation).format(token_limit: TOKEN_LIMIT)
  end

  def event_name
    'approval_draft'
  end
end
