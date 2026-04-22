class Captain::AssistantTemplates::Instantiator
  Loader = Captain::AssistantTemplates::Loader

  def initialize(account:, template_id:, product_name:, locale: nil, name_override: nil, adapted_data: nil)
    @account = account
    @template = Loader.find(template_id)
    @product_name = product_name.to_s.presence || @template.dig('assistant', 'product_name_placeholder').to_s
    @locale = Loader.resolve_locale(locale || @template['locale_default'])
    @name_override = name_override
    @adapted_data = adapted_data
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

  attr_reader :account, :template, :product_name, :locale, :name_override, :adapted_data

  def build_assistant
    if adapted_data.present? && adapted_data['assistant'].present?
      build_assistant_from_adapted
    else
      build_assistant_from_template
    end
  end

  def build_assistant_from_adapted
    attrs = adapted_data['assistant']
    name = name_override.presence || attrs['name'] || 'Assistant'
    description = attrs['description'].presence || "AI assistant for #{product_name}"

    account.captain_assistants.create!(
      name: name,
      description: description,
      response_guidelines: attrs['response_guidelines'] || [],
      guardrails: attrs['guardrails'] || [],
      config: attrs['config'] || assistant_config(template['assistant'] || {})
    )
  end

  def build_assistant_from_template
    attrs = template['assistant'] || {}
    name = name_override.presence || Loader.localized(attrs['name_i18n'], locale) || 'Assistant'
    description = Loader.localized(attrs['description_i18n'], locale) || "AI assistant for #{product_name}"

    account.captain_assistants.create!(
      name: name,
      description: description,
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
    scenarios_data = if adapted_data.present? && adapted_data['scenarios'].present?
                       adapted_data['scenarios']
                     else
                       template['scenarios'] || []
                     end

    scenarios_data.each do |s|
      instruction = s['instruction'].to_s.strip
      instruction = strip_invalid_tool_references(instruction)

      if adapted_data.present? && adapted_data['scenarios'].present?
        assistant.scenarios.create!(
          account: account,
          title: s['title'],
          description: s['description'],
          instruction: instruction,
          enabled: s['enabled'] != false
        )
      else
        assistant.scenarios.create!(
          account: account,
          title: Loader.localized(s['title_i18n'], locale),
          description: Loader.localized(s['description_i18n'], locale),
          instruction: instruction,
          enabled: true
        )
      end
    end
  end

  def strip_invalid_tool_references(instruction)
    tool_reference_regex = %r{\[([^\]]+)\]\(tool://([^)]+)\)}
    instruction.gsub(tool_reference_regex) do |_match|
      tool_name = Regexp.last_match(2)
      "<!-- tool: #{tool_name} -->"
    end
  end

  def build_faq_responses(assistant)
    faq_data = if adapted_data.present? && adapted_data['faq_seed'].present?
                 adapted_data['faq_seed']
               else
                 template['faq_seed'] || []
               end

    faq_data.each do |faq|
      if adapted_data.present? && adapted_data['faq_seed'].present?
        question = faq['question']
        answer = faq['answer']
      else
        question = Loader.localized(faq['q_i18n'], locale)
        answer = Loader.localized(faq['a_i18n'], locale)
      end
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
