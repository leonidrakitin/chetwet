class Captain::Tools::Copilot::ConfigureAssistantService < Captain::Tools::BaseTool
  Loader = Captain::AssistantTemplates::Loader

  def self.name
    'configure_assistant_from_template'
  end

  description 'Help configure a new AI assistant from a template. Lists available templates, asks clarifying questions about the business, and adapts the template to the specific use case. Use this when the agent wants to create or customize an assistant.'

  param :action, type: :string, desc: 'Action to perform: "list_templates", "get_questions", "preview", or "create"', required: true
  param :template_id, type: :string, desc: 'Template ID for get_questions, preview, or create actions', required: false
  param :clarifications, type: :object, desc: 'Answers to clarifying questions (key-value pairs)', required: false
  param :assistant_name, type: :string, desc: 'Custom name for the assistant (optional)', required: false

  def execute(action:, template_id: nil, clarifications: {}, assistant_name: nil)
    case action
    when 'list_templates'
      list_templates
    when 'get_questions'
      get_questions(template_id)
    when 'preview'
      preview_assistant(template_id, clarifications)
    when 'create'
      create_assistant(template_id, clarifications, assistant_name)
    else
      "Unknown action: #{action}. Available actions: list_templates, get_questions, preview, create"
    end
  end

  def active?
    user_has_permission('administrator')
  end

  private

  def list_templates
    locale = @assistant.account.locale || 'en'
    templates = Loader.preview_list(locale: locale)

    return 'No templates available' if templates.empty?

    formatted = templates.map do |t|
      {
        id: t[:id],
        name: t[:name],
        description: t[:description],
        industry: t[:industry],
        scenarios_count: t[:scenarios].length,
        faq_count: t[:faq_count]
      }
    end

    {
      templates: formatted,
      message: "Found #{formatted.length} templates. Use 'get_questions' with a template_id to see clarifying questions for customization."
    }.to_json
  end

  def get_questions(template_id)
    return 'template_id is required for get_questions action' if template_id.blank?

    template = Loader.find(template_id)
    questions = template['clarifying_questions'] || default_questions

    {
      template_id: template_id,
      template_name: Loader.localized(template['assistant']['name_i18n'], @assistant.account.locale),
      questions: questions.map do |q|
        {
          purpose: q['purpose'],
          question: Loader.localized(q['question_i18n'], @assistant.account.locale)
        }
      end
    }.to_json
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    { error: e.message }.to_json
  end

  def preview_assistant(template_id, clarifications)
    return 'template_id is required for preview action' if template_id.blank?

    template = Loader.find(template_id)
    business_context = @assistant.account.settings['business_context'] || {}

    adapted = Captain::AssistantTemplates::TemplateAdapterService.new(
      template: template,
      business_context: business_context,
      clarifications: clarifications,
      locale: @assistant.account.locale
    ).perform

    {
      preview: {
        name: adapted['assistant']['name'],
        description: adapted['assistant']['description'],
        scenarios: adapted['scenarios'].map { |s| { title: s['title'], description: s['description'] } },
        faq_count: adapted['faq_seed'].length
      },
      message: "Preview ready. Use 'create' action to create the assistant."
    }.to_json
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    { error: e.message }.to_json
  end

  def create_assistant(template_id, clarifications, assistant_name)
    return 'template_id is required for create action' if template_id.blank?
    return 'Only administrators can create assistants' unless active?

    template = Loader.find(template_id)
    business_context = @assistant.account.settings['business_context'] || {}

    adapted_data = Captain::AssistantTemplates::TemplateAdapterService.new(
      template: template,
      business_context: business_context,
      clarifications: clarifications,
      locale: @assistant.account.locale
    ).perform

    assistant = Captain::AssistantTemplates::Instantiator.new(
      account: @assistant.account,
      template_id: template_id,
      product_name: business_context['description'] || template.dig('assistant', 'product_name_placeholder'),
      locale: @assistant.account.locale,
      name_override: assistant_name,
      adapted_data: adapted_data
    ).perform!

    {
      success: true,
      assistant: {
        id: assistant.id,
        name: assistant.name,
        description: assistant.description
      },
      message: "Assistant '#{assistant.name}' created successfully with #{assistant.scenarios.count} scenarios and #{assistant.responses.count} FAQs."
    }.to_json
  rescue StandardError => e
    { error: "Failed to create assistant: #{e.message}" }.to_json
  end

  def default_questions
    [
      {
        'purpose' => 'product_info',
        'question_i18n' => {
          'en' => 'What products or services do you offer?',
          'ru' => 'Какие продукты или услуги вы предлагаете?'
        }
      },
      {
        'purpose' => 'faq_hints',
        'question_i18n' => {
          'en' => 'What are the most common customer questions?',
          'ru' => 'Какие вопросы клиенты задают чаще всего?'
        }
      },
      {
        'purpose' => 'policies',
        'question_i18n' => {
          'en' => 'Do you have any special policies (returns, SLA, etc.)?',
          'ru' => 'Есть ли особые политики (возвраты, SLA и т.д.)?'
        }
      }
    ]
  end
end
