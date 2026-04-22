# Lightweight LLM-based self-check that verifies every factual claim in the draft
# answer is supported by the sources returned by faq_lookup.
#
# Runs on a cheap model (default gpt-4o-mini) and intentionally does NOT count
# toward Captain usage limits — the returned hash excludes `:message` so the
# parent `Enterprise::Captain::BaseTaskService#perform` does not increment usage.
class Captain::Llm::AnswerVerificationService < Captain::BaseTaskService
  RESPONSE_SCHEMA = Captain::AnswerVerificationSchema
  DEFAULT_VERIFIER_MODEL = 'gpt-4o-mini'.freeze
  MAX_DRAFT_CHARS = 2_000
  MAX_SOURCE_CHARS = 1_500

  pattr_initialize [:account!, :draft!, :sources!]

  def perform
    return default_supported('empty draft') if draft.to_s.strip.blank?
    return default_supported('no sources') if sources.blank?

    response = make_api_call(
      model: verifier_model,
      messages: [
        { role: 'system', content: prompt_from_file('answer_verification') },
        { role: 'user', content: user_payload }
      ],
      schema: RESPONSE_SCHEMA
    )

    return default_supported("verifier_error: #{response[:error]}") if response[:error].present?

    parse_response(response[:message])
  end

  private

  def verifier_model
    InstallationConfig.find_by(name: 'CAPTAIN_VERIFIER_MODEL')&.value.presence || DEFAULT_VERIFIER_MODEL
  end

  def prompt_from_file(file_name)
    Rails.root.join('enterprise/lib/captain/prompts', "#{file_name}.liquid").read
  end

  def user_payload
    <<~PAYLOAD
      SOURCES:
      #{format_sources}

      DRAFT:
      #{draft.to_s.truncate(MAX_DRAFT_CHARS)}
    PAYLOAD
  end

  def format_sources
    sources.filter_map { |src| format_source(src) }.join("\n---\n")
  end

  def format_source(src)
    return nil unless src.is_a?(Hash)

    indifferent = src.with_indifferent_access
    label = indifferent[:label]
    title = indifferent[:title].to_s.presence
    content = indifferent[:content].to_s.truncate(MAX_SOURCE_CHARS)
    return nil if content.blank?

    header = "[#{label}]"
    header = "#{header} #{title}" if title.present?
    "#{header}\n#{content}"
  end

  def parse_response(message)
    return default_supported('invalid response') unless message.is_a?(Hash)

    body = message.with_indifferent_access
    {
      supported: body['supported'] == true,
      unsupported: Array(body['unsupported_claims']).map(&:to_s)
    }
  end

  def default_supported(reason)
    # On any verifier failure, fail OPEN (treat as supported) — the Ruby citation
    # check already runs before the verifier, so we do not want to escalate every
    # conversation when the verifier is flaky or mis-configured.
    { supported: true, unsupported: [], reason: reason }
  end

  # Prefer the system API key over the account OpenAI hook — internal
  # evaluation should not consume the customer's OpenAI credits.
  def api_key
    @api_key ||= system_api_key.presence || openai_hook&.settings&.dig('api_key')
  end

  def event_name
    'captain.answer_verification'
  end

  def build_follow_up_context?
    false
  end
end
