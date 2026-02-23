class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  def perform(_tool_context, query:)
    log_tool_usage('searching', { query: query })

    responses = @assistant.responses.approved.search(query).to_a

    if responses.empty?
      log_tool_usage('no_results', { query: query })
      return { answer: nil, confidence: 0.0, policy: 'no_match' }
    end

    confidence, policy = assess_confidence(responses.first)
    log_tool_usage('found_results', { query: query, count: responses.size, confidence: confidence, policy: policy })

    return { answer: nil, confidence: confidence, policy: policy } if policy == 'no_match'

    { answer: format_responses(responses.first(3)), confidence: confidence, policy: policy }
  end

  private

  def assess_confidence(best_response)
    confidence = neighbor_confidence(best_response)
    auto_threshold = @assistant.faq_auto_answer_threshold.to_f.nonzero? || 0.82
    suggest_threshold = @assistant.faq_suggest_threshold.to_f.nonzero? || 0.65

    policy = if confidence >= auto_threshold
               'auto_answer'
             elsif confidence >= suggest_threshold
               'suggest'
             else
               'no_match'
             end
    [confidence, policy]
  end

  def neighbor_confidence(response)
    return 0.0 unless response.respond_to?(:neighbor_distance) && response.neighbor_distance

    (1.0 - response.neighbor_distance).round(4)
  end

  def format_responses(responses)
    responses.map { |response| format_response(response) }.join
  end

  def format_response(response)
    formatted_response = "
        Question: #{response.question}
        Answer: #{response.answer}
        "
    if should_show_source?(response)
      formatted_response += "
          Source: #{response.documentable.external_link}
          "
    end

    formatted_response
  end

  def should_show_source?(response)
    return false if response.documentable.blank?
    return false unless response.documentable.try(:external_link)

    # Don't show source if it's a PDF placeholder
    external_link = response.documentable.external_link
    !external_link.start_with?('PDF:')
  end
end
