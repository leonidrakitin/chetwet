class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  def perform(tool_context, query:)
    log_tool_usage('searching', { query: query })

    search_service = Captain::Knowledge::UnifiedSearchService.new(assistant: @assistant)
    results = search_service.search(query)

    decision = Captain::Knowledge::PolicyDecision.new(
      assistant: @assistant,
      search_results: results
    ).decide

    decision[:query] = query
    write_state(tool_context, decision)

    Rails.logger.info(
      "[Captain] FaqLookupTool query=#{query.inspect} " \
      "policy=#{decision[:policy]} confidence=#{decision[:confidence]} " \
      "mode=#{@assistant.knowledge_mode || 'balanced'}"
    )

    decision
  rescue StandardError => e
    Rails.logger.error("[Captain] FaqLookupTool error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))

    error_result = {
      status: 'error',
      policy: 'no_match',
      query: query,
      answer_draft: nil,
      sources: [],
      requires_operator: false,
      confidence: 0.0
    }
    write_state(tool_context, error_result)
    error_result
  end

  private

  def write_state(tool_context, result)
    tool_context.state[:orchestration] ||= {}
    tool_context.state[:orchestration][:last_faq_lookup] = result
  end
end
