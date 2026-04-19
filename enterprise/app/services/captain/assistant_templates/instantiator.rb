class Captain::AssistantTemplates::Instantiator
  def initialize(account:, template_id:, product_name:, locale: nil, name_override: nil)
    @account = account
    @template = Loader.find(template_id)
    @product_name = product_name.to_s.presence || @template.dig('assistant', 'product_name_placeholder').to_s
    @locale = Loader.resolve_locale(locale || @template['locale_default'])
    @name_override = name_override
  end

  def perform!
    ActiveRecord::Base.transaction do
      assistant = build_assistant
      build_scenarios(assistant)
      build_faq_responses(assistant)
      assistant
    end
  end

  private

  attr_reader :account, :template, :product_name, :locale, :name_override

  def build_assistant
    attrs = template['assistant'] || {}
    account.captain_assistants.create!(
      name: name_override.presence || Loader.localized(attrs['name_i18n'], locale),
      description: Loader.localized(attrs['description_i18n'], locale),
      response_guidelines: attrs['response_guidelines'] || [],
      guardrails: attrs['guardrails'] || [],
      config: assistant_config(attrs)
    )
  end

  def assistant_config(attrs)
    {
      'product_name' => product_name,
      'tone' => attrs['tone'],
      'emojify' => attrs['emojify'],
      'knowledge_mode' => attrs['knowledge_mode'],
      'knowledge_answer_threshold' => attrs['knowledge_answer_threshold'],
      'feature_faq' => attrs['feature_faq']
    }.compact
  end

  def build_scenarios(assistant)
    (template['scenarios'] || []).each do |s|
      assistant.scenarios.create!(
        account: account,
        title: Loader.localized(s['title_i18n'], locale),
        description: Loader.localized(s['description_i18n'], locale),
        instruction: s['instruction'].to_s.strip,
        enabled: true
      )
    end
  end

  def build_faq_responses(assistant)
    (template['faq_seed'] || []).each do |faq|
      question = Loader.localized(faq['q_i18n'], locale)
      answer = Loader.localized(faq['a_i18n'], locale)
      next if question.blank? || answer.blank?

      assistant.responses.create!(
        account: account,
        question: question,
        answer: answer,
        status: :approved
      )
    end
  end
end
