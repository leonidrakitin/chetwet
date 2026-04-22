# frozen_string_literal: true

class Captain::Knowledge::SearchResult
  attr_reader :source, :record, :distance

  def initialize(source:, record:, distance:)
    @source = source
    @record = record
    @distance = distance || 1.0
  end

  def confidence
    value = 1.0 - distance
    value.negative? ? 0.0 : value.round(4)
  end

  def content
    case source
    when 'faq'
      format_faq_content
    when 'chunk'
      format_chunk_content
    end
  end

  def source_link
    case source
    when 'faq'
      faq_source_link
    when 'chunk'
      chunk_source_link
    end
  end

  def title
    case source
    when 'faq'
      record.question.to_s.truncate(120)
    when 'chunk'
      document = record.document
      document&.name.presence || document&.external_link.presence || 'Document'
    end
  end

  def requires_operator?
    source == 'faq' && record.requires_clarification?
  end

  private

  def format_faq_content
    text = "\nQuestion: #{record.question}\nAnswer: #{record.answer}\n"
    return text unless record.requires_clarification?

    text + "\n[REQUIRES_OPERATOR_CLARIFICATION: This topic requires operator review. " \
           'You MUST call `escalate_to_human` to transfer the conversation to a human agent. ' \
           "The operator will be notified via Telegram. DO NOT answer the customer directly.]\n"
  end

  def format_chunk_content
    document = record.document
    title = document&.name.presence || document&.external_link || 'Document'
    text = "\nArticle: #{title}\n"

    text += "Context: #{record.context}\n" if record.context.present?

    text += "Content: #{record.content}\n"

    text += "Source: #{document.external_link}\n" if should_show_chunk_source?(document)

    text
  end

  def faq_source_link
    return nil if record.documentable.blank?
    return nil unless record.documentable.try(:external_link)
    return nil if record.documentable.external_link.start_with?('PDF:')

    record.documentable.external_link
  end

  def chunk_source_link
    document = record.document
    return nil if document.blank?
    return nil if document.external_link.blank?
    return nil if document.external_link.start_with?('PDF:')

    document.external_link
  end

  def should_show_chunk_source?(document)
    document.present? &&
      document.external_link.present? &&
      !document.external_link.start_with?('PDF:')
  end
end
