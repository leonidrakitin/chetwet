class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  def perform(tool_context, query:)
    log_tool_usage('searching', { query: query })

    faq_results, chunk_results = search_knowledge(query)
    total_results = faq_results.size + chunk_results.size

    if total_results.zero?
      log_tool_usage('no_results', { query: query })
      result = {
        status: 'no_match',
        policy: 'no_match',
        query: query,
        answer_draft: nil,
        sources: [],
        requires_operator: false
      }
      write_state(tool_context, result)
      Rails.logger.info(
        '[Captain DEBUG TMP] FaqLookupTool#perform no_results ' \
        "assistant_id=#{@assistant.id} query=#{query.inspect} return=#{result.inspect}"
      )
      result
    else
      log_tool_usage('found_results', { query: query, count: total_results })
      answer_draft = "#{format_chunk_results(chunk_results)}#{format_responses(faq_results)}"
      needs_operator = faq_results.any?(&:requires_clarification?)
      result = {
        status: 'ok',
        policy: needs_operator ? 'escalate' : 'answer',
        query: query,
        answer_draft: answer_draft,
        sources: collect_sources(faq_results, chunk_results),
        requires_operator: needs_operator,
        confidence: total_results
      }
      write_state(tool_context, result)
      Rails.logger.info(
        '[Captain DEBUG TMP] FaqLookupTool#perform hit ' \
        "assistant_id=#{@assistant.id} query=#{query.inspect} chunks=#{chunk_results.size} faqs=#{faq_results.size} " \
        "requires_operator_hint=#{needs_operator} return_len=#{answer_draft.bytesize}"
      )
      result
    end
  end

  private

  def search_knowledge(query)
    if chunk_retrieval_mode?
      [
        search_non_document_faqs(query),
        Captain::Documents::HybridChunkSearchService.new(assistant: @assistant).search(query)
      ]
    else
      [@assistant.responses.approved.search(query).to_a, []]
    end
  end

  def search_non_document_faqs(query)
    @assistant.responses
              .approved
              .where.not(documentable_type: 'Captain::Document')
              .search(query)
              .to_a
  end

  def chunk_retrieval_mode?
    return false unless chunk_builder_enabled?

    value = @assistant.config&.fetch('feature_document_faq_generation', true)
    !ActiveModel::Type::Boolean.new.cast(value)
  end

  def chunk_builder_enabled?
    value = InstallationConfig.find_by(name: 'CAPTAIN_DOCUMENT_CHUNKING_ENABLED')&.value
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def format_chunk_results(chunks)
    chunks.map { |chunk| format_chunk(chunk) }.join
  end

  def format_chunk(chunk)
    document = chunk.document
    source_link = document.external_link if should_show_document_source?(document)
    title = document.name.presence || document.external_link

    formatted = "
        Article: #{title}
        Context: #{chunk.context}
        Content: #{chunk.content}
        "
    if source_link.present?
      formatted += "
        Source: #{source_link}
        "
    end
    formatted
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
    if response.requires_clarification?
      hint = '[REQUIRES_OPERATOR_CLARIFICATION: This topic requires operator review. ' \
             'You MUST call `captain--tools--escalate_to_human` to transfer the conversation to a human agent. ' \
             'The operator will be notified via Telegram. DO NOT answer the customer directly.]'
      formatted_response += "\n          #{hint}\n          "
    end

    formatted_response
  end

  def collect_sources(faq_results, chunk_results)
    faq_sources = faq_results.filter_map do |response|
      response.documentable&.try(:external_link) if should_show_source?(response)
    end
    chunk_sources = chunk_results.filter_map do |chunk|
      document = chunk.document
      document&.external_link if should_show_document_source?(document)
    end
    (faq_sources + chunk_sources).compact.uniq
  end

  def write_state(tool_context, result)
    tool_context.state[:orchestration] ||= {}
    tool_context.state[:orchestration][:last_faq_lookup] = result
  end

  def should_show_source?(response)
    return false if response.documentable.blank?
    return false unless response.documentable.try(:external_link)

    # Don't show source if it's a PDF placeholder
    external_link = response.documentable.external_link
    !external_link.start_with?('PDF:')
  end

  def should_show_document_source?(document)
    return false if document.blank?
    return false if document.external_link.blank?

    !document.external_link.start_with?('PDF:')
  end
end
