# frozen_string_literal: true

class Captain::Knowledge::UnifiedSearchService
  DEFAULT_VECTOR_LIMIT = 20
  DEFAULT_RESULT_LIMIT = 5

  def initialize(assistant:)
    @assistant = assistant
    @embedding_service = Captain::Llm::EmbeddingService.new(account_id: assistant.account_id)
  end

  def search(query, limit: DEFAULT_RESULT_LIMIT)
    return [] if query.blank?

    embedding = @embedding_service.get_embedding(query)
    return [] if embedding.blank?

    faq_results = search_faqs(embedding)
    chunk_results = search_chunks(embedding)

    (faq_results + chunk_results)
      .sort_by { |r| -r.confidence }
      .first(limit)
  end

  private

  def search_faqs(embedding)
    @assistant.responses.approved
              .nearest_neighbors(:embedding, embedding, distance: 'cosine')
              .limit(DEFAULT_VECTOR_LIMIT)
              .map do |response|
      Captain::Knowledge::SearchResult.new(
        source: 'faq',
        record: response,
        distance: response.neighbor_distance
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[UnifiedSearchService] FAQ search failed: #{e.message}")
    []
  end

  def search_chunks(embedding)
    Captain::DocumentChunk
      .where(account_id: @assistant.account_id, assistant_id: @assistant.id)
      .joins(:document)
      .merge(Captain::Document.chunking_status_ready)
      .nearest_neighbors(:embedding, embedding, distance: 'cosine')
      .limit(DEFAULT_VECTOR_LIMIT)
      .map do |chunk|
        Captain::Knowledge::SearchResult.new(
          source: 'chunk',
          record: chunk,
          distance: chunk.neighbor_distance
        )
      end
  rescue StandardError => e
    Rails.logger.warn("[UnifiedSearchService] Chunk search failed: #{e.message}")
    []
  end
end
