class Captain::AssistantTemplates::TemplateAdapterService
  Loader = Captain::AssistantTemplates::Loader

  def initialize(template:, business_context:, clarifications: {}, locale: 'en')
    @template = template
    @business_context = business_context || {}
    @clarifications = clarifications
    @locale = Loader.resolve_locale(locale)
  end

  def perform
    {
      'assistant' => adapt_assistant,
      'scenarios' => adapt_scenarios,
      'faq_seed' => adapt_faqs
    }
  end

  private

  attr_reader :template, :business_context, :clarifications, :locale

  def adapt_assistant
    attrs = template['assistant'] || {}
    {
      'name' => Loader.localized(attrs['name_i18n'], locale),
      'description' => adapt_description(attrs),
      'response_guidelines' => adapt_guidelines(attrs['response_guidelines'] || []),
      'guardrails' => attrs['guardrails'] || [],
      'config' => build_config(attrs)
    }
  end

  def adapt_description(attrs)
    base_description = Loader.localized(attrs['description_i18n'], locale)
    return base_description unless business_context['description'].present?

    product_name = business_context['description']
    base_description.gsub(/\[.*?\]/, product_name)
  end

  def adapt_guidelines(guidelines)
    return guidelines unless business_context['description'].present?

    guidelines.map do |guideline|
      guideline.gsub(/\[.*?\]/, business_context['description'])
    end
  end

  def build_config(attrs)
    {
      'product_name' => business_context['description'] || attrs['product_name_placeholder'],
      'tone' => attrs['tone'],
      'emojify' => attrs['emojify'],
      'knowledge_mode' => attrs['knowledge_mode'],
      'knowledge_answer_threshold' => attrs['knowledge_answer_threshold'],
      'feature_faq' => attrs['feature_faq']
    }.compact
  end

  def adapt_scenarios
    scenarios = template['scenarios'] || []
    clarifications_data = clarifications['scenarios'] || {}

    scenarios.map do |scenario|
      key = scenario['key']
      {
        'title' => Loader.localized(scenario['title_i18n'], locale),
        'description' => Loader.localized(scenario['description_i18n'], locale),
        'instruction' => adapt_scenario_instruction(scenario['instruction'], clarifications_data[key]),
        'enabled' => true
      }
    end
  end

  def adapt_scenario_instruction(instruction, scenario_clarifications = nil)
    return instruction unless scenario_clarifications || business_context['description'].present?

    adapted = instruction
    adapted = adapted.gsub(/\[Salon name\]|\[business name\]/i, business_context['description']) if business_context['description'].present?
    adapted
  end

  def adapt_faqs
    faqs = template['faq_seed'] || []
    clarifications['faqs'] || {}

    faqs.map do |faq|
      question = Loader.localized(faq['q_i18n'], locale)
      answer = Loader.localized(faq['a_i18n'], locale)

      {
        'question' => adapt_faq_content(question),
        'answer' => adapt_faq_content(answer)
      }
    end
  end

  def adapt_faq_content(content)
    return content unless business_context['description'].present?

    content.gsub(/\[.*?\]/, business_context['description'])
  end
end
