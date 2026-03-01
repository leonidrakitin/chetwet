# frozen_string_literal: true

class ConversationDeduplicator
  SIMILARITY_THRESHOLD = 0.22   # если cosine distance < 0.22 → считаем дубликат (очень похожие)

  def initialize(account)
    @account = account
    @embedding_service = Captain::Llm::EmbeddingService.new(account_id: account.id)
    @seen_embeddings = []   # [ [embedding_vector, dialog_index] ]
  end

  def deduplicate(dialogs)
    return [] if dialogs.empty?

    unique = []
    dialogs.each_with_index do |dialog, index|
      text_for_embedding = dialog_text(dialog)
      next if text_for_embedding.blank?

      begin
        embedding = @embedding_service.get_embedding(text_for_embedding)
      rescue Captain::Llm::EmbeddingService::EmbeddingsError => e
        Rails.logger.warn "[ConversationDeduplicator] Embedding failed for dialog #{index}, including without deduplication: #{e.message}"
        unique << dialog
        next
      end

      if duplicate?(embedding)
        next # пропускаем дубликат
      end

      @seen_embeddings << [embedding, index]
      unique << dialog
    end

    unique
  end

  private

  def dialog_text(dialog)
    # Берём весь диалог, но обрезаем до разумного размера (экономим токены и время)
    dialog[:messages]
      .map { |m| "#{m[:sender_type]}: #{m[:content]}" }
      .join("\n")
      .truncate(8000) # ~2000 токенов max
  end

  def duplicate?(new_embedding)
    return false if new_embedding.blank?

    @seen_embeddings.any? do |seen_embedding, _|
      distance = cosine_distance(new_embedding, seen_embedding)
      distance < SIMILARITY_THRESHOLD
    end
  end

  # Cosine distance = 1 - cosine similarity
  def cosine_distance(vec_a, vec_b)
    dot = vec_a.zip(vec_b).sum { |x, y| x * y }
    norm_a = Math.sqrt(vec_a.sum { |x| x * x })
    norm_b = Math.sqrt(vec_b.sum { |x| x * x })
    return 1.0 if norm_a.zero? || norm_b.zero?

    1.0 - (dot / (norm_a * norm_b))
  end
end
