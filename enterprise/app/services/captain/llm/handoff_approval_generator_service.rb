# frozen_string_literal: true

# Generates a customer-facing message and a list of operator reply options for
# Captain handoff/approval flows in a single LLM call. The instruction template
# is taken from assistant.config['handoff_approval_instructions'] (editable in
# the Business Context UI) and falls back to a multilingual default.
class Captain::Llm::HandoffApprovalGeneratorService < Llm::BaseAiService
  DEFAULT_INSTRUCTIONS = <<~PROMPT
    When a conversation is being escalated to a human operator, produce:
    - customer_message: a short, polite message to the customer IN THE LANGUAGE OF THE CONVERSATION.
      Examples:
        EN: "Let me check this with our team — I'll get back to you shortly."
        RU: "Уточняю это с оператором, скоро вернусь с ответом."
        ES: "Déjame consultarlo con nuestro equipo, te contesto enseguida."
    - options: 2–4 short ready-made replies the operator can pick from. Base them on the FAQ context when available.
      Each option must be a single short sentence the operator could send to the customer as-is.
      If there is no relevant FAQ context, return an empty array.

    Return STRICT JSON with no markdown:
    {"customer_message": "...", "options": ["...", "..."]}
  PROMPT

  RECENT_MESSAGE_LIMIT = 8
  FAQ_SNIPPET_LIMIT = 4

  def initialize(assistant:, conversation:, reason: nil, faq_snippets: [])
    super()
    @assistant = assistant
    @conversation = conversation
    @reason = reason
    @faq_snippets = Array(faq_snippets).compact_blank
  end

  # @return [Hash] { customer_message: String, options: Array<String> } — both may be blank on failure.
  def generate
    response = chat
               .with_params(response_format: { type: 'json_object' })
               .with_instructions(system_prompt)
               .ask(user_prompt)
    parse(response&.content)
  rescue RubyLLM::Error => e
    Rails.logger.warn("[HandoffApprovalGenerator] LLM error: #{e.message}")
    blank_result
  rescue StandardError => e
    Rails.logger.warn("[HandoffApprovalGenerator] unexpected error: #{e.message}")
    blank_result
  end

  private

  def system_prompt
    instructions = @assistant.config['handoff_approval_instructions'].presence || DEFAULT_INSTRUCTIONS
    <<~PROMPT
      You are an assistant that produces structured JSON for a human-handoff approval UI.
      Reply with a single JSON object only. No markdown, no commentary.

      #{instructions}
    PROMPT
  end

  def user_prompt
    parts = []
    parts << "Account language hint: #{@conversation.account.locale_english_name}"
    parts << "Reason for escalation: #{@reason}" if @reason.present?
    parts << "FAQ context (use to ground the options, do not invent):\n#{@faq_snippets.join("\n---\n")}" if @faq_snippets.any?
    parts << "Recent conversation:\n#{recent_conversation_text}"
    parts.join("\n\n")
  end

  def recent_conversation_text
    @conversation
      .messages
      .where(private: false)
      .order(:created_at)
      .last(RECENT_MESSAGE_LIMIT)
      .filter_map { |m| format_message(m) }
      .join("\n")
  end

  def format_message(message)
    role = message.incoming? ? 'customer' : 'agent'
    content = message.content.to_s.strip
    return nil if content.blank?

    "#{role}: #{content.truncate(400)}"
  end

  def parse(content)
    return blank_result if content.blank?

    json = JSON.parse(sanitize_json_response(content))
    {
      customer_message: json['customer_message'].to_s.strip,
      options: Array(json['options']).filter_map { |o| o.to_s.strip.presence }.first(FAQ_SNIPPET_LIMIT)
    }
  rescue JSON::ParserError => e
    Rails.logger.warn("[HandoffApprovalGenerator] failed to parse LLM response: #{e.message}")
    blank_result
  end

  def blank_result
    { customer_message: '', options: [] }
  end
end
