module Captain::Assistant::CitationValidator
  module_function

  CLARIFYING_QUESTION_MAX_LENGTH = 120
  STRICT_MODES = %w[strict ultra_strict].freeze

  # Returns :ok, :missing, or :invalid_label.
  # :ok          — answer is not subject to citation rules, or citations are valid
  # :missing     — strict mode requires citations and none are present
  # :invalid_label — response cites a [n] that is not present in sources
  def check(assistant:, result:, response_text:)
    return :ok unless strict_for_citations?(assistant)
    return :ok if response_text.blank?
    return :ok if response_text == 'conversation_handoff'
    return :ok if clarifying_question?(response_text)

    last_lookup = extract_last_faq_lookup(result)
    return :ok if last_lookup.blank?
    return :ok if last_lookup[:policy].to_s != 'answer'

    valid_labels = extract_valid_labels(last_lookup[:sources])
    return :ok if valid_labels.empty?

    citations = response_text.scan(/\[(\d+)\]/).flatten
    return :missing if citations.empty?
    return :invalid_label if citations.any? { |c| valid_labels.exclude?(c) }

    :ok
  end

  def strict_for_citations?(assistant)
    STRICT_MODES.include?(assistant&.knowledge_mode.to_s)
  end

  def extract_last_faq_lookup(result)
    return nil unless result.respond_to?(:context)

    state = result.context&.dig(:state)
    lookup = state&.dig(:orchestration, :last_faq_lookup)
    return nil unless lookup.is_a?(Hash)

    lookup.with_indifferent_access
  end

  def extract_valid_labels(sources)
    return [] if sources.blank?

    sources.filter_map do |src|
      next unless src.is_a?(Hash)

      (src[:label] || src['label']).to_s.presence
    end
  end

  def clarifying_question?(text)
    stripped = text.to_s.strip
    stripped.length < CLARIFYING_QUESTION_MAX_LENGTH && stripped.end_with?('?')
  end
end
