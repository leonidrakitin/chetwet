class Captain::Tools::SearchDocumentationService < Captain::Tools::BaseTool
  def self.name
    'search_documentation'
  end
  description 'Search and retrieve documentation from knowledge base'

  param :query, desc: 'Search Query', required: true

  def execute(query:)
    Rails.logger.info { "#{self.class.name}: #{query}" }

    translated_query = Captain::Llm::TranslateQueryService
                       .new(account: assistant.account)
                       .translate(query, target_language: assistant.account.locale_english_name)

    responses = assistant.responses.approved.search(translated_query)

    return 'No FAQs found for the given query' if responses.empty?

    responses.map { |response| format_response(response) }.join
  rescue Captain::Llm::EmbeddingService::EmbeddingsError => e
    Rails.logger.error "#{self.class.name}: Embedding search failed: #{e.message}"
    'Documentation search is temporarily unavailable. Please try to help the user based on available context.'
  end

  private

  def format_response(response)
    formatted_response = "
        Question: #{response.question}
        Answer: #{response.answer}
        "
    if response.documentable.present? && response.documentable.try(:external_link)
      formatted_response += "
          Source: #{response.documentable.external_link}
          "
    end

    formatted_response
  end
end
