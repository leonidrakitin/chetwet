class Captain::Llm::DetectLanguageService
  MIN_TEXT_LENGTH = 3

  pattr_initialize [:account!, :message_text!]

  def call
    return fallback_locale unless valid_text?

    detector = CLD3::NNetLanguageIdentifier.new(0, 1000)
    result = detector.find_language(@message_text)

    result.reliable? ? result.language.to_s : fallback_locale
  rescue StandardError => e
    Rails.logger.warn "[Captain::Llm::DetectLanguageService] CLD3 failed: #{e.message}, falling back to account locale"
    fallback_locale
  end

  private

  def valid_text?
    @message_text.present? && @message_text.to_s.strip.length >= MIN_TEXT_LENGTH
  end

  def fallback_locale
    @account.locale&.split('_')&.first || 'en'
  end
end
