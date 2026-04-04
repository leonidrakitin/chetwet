class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  # rubocop:disable Metrics/MethodLength -- TEMP DEBUG TMP logging (revert commit)
  def perform(_tool_context, query:)
    log_tool_usage('searching', { query: query })

    faq_results, chunk_results = search_knowledge(query)
    total_results = faq_results.size + chunk_results.size

    if total_results.zero?
      log_tool_usage('no_results', { query: query })
      out = "No relevant FAQs found for: #{query}"
      Rails.logger.info(
        '[Captain DEBUG TMP] FaqLookupTool#perform no_results ' \
        "assistant_id=#{@assistant.id} query=#{query.inspect} return=#{out.inspect}"
      )
      out
    else
      log_tool_usage('found_results', { query: query, count: total_results })
      body = "#{format_chunk_results(chunk_results)}#{format_responses(faq_results)}"
      needs_operator = body.include?('REQUIRES_OPERATOR_CLARIFICATION')
      Rails.logger.info(
        '[Captain DEBUG TMP] FaqLookupTool#perform hit ' \
        "assistant_id=#{@assistant.id} query=#{query.inspect} chunks=#{chunk_results.size} faqs=#{faq_results.size} " \
        "requires_operator_hint=#{needs_operator} return_len=#{body.bytesize}"
      )
      body
    end
  end
  # rubocop:enable Metrics/MethodLength

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
      hint = '[REQUIRES_OPERATOR_CLARIFICATION: Call `captain--tools--ask_human` tool with title to get ' \
             'operator approval first. DO NOT answer to the customer explicitly yet.]'
      formatted_response += "\n          #{hint}\n          "
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

  def should_show_document_source?(document)
    return false if document.blank?
    return false if document.external_link.blank?

    !document.external_link.start_with?('PDF:')
  end
end
