class Api::V1::Accounts::Captain::AssistantTemplatesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  def index
    render json: Captain::AssistantTemplates::Loader.preview_list(locale: params[:locale])
  end

  def show
    template = Captain::AssistantTemplates::Loader.find(params[:id])
    render json: Captain::AssistantTemplates::Loader.preview(template, locale: params[:locale])
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    render json: { error: e.message }, status: :not_found
  end

  def create_assistant
    @assistant = Captain::AssistantTemplates::Instantiator.new(
      account: Current.account,
      template_id: instantiate_params[:template_id],
      product_name: instantiate_params[:product_name],
      locale: instantiate_params[:locale],
      name_override: instantiate_params[:name],
      adapted_data: instantiate_params[:adapted_data]
    ).perform!

    render partial: 'api/v1/models/captain/assistant', formats: [:json], locals: { resource: @assistant }
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    render json: { error: e.message }, status: :not_found
  end

  def adapt
    template = Captain::AssistantTemplates::Loader.find(adapt_params[:template_id])
    business_context = Current.account.settings['business_context']

    adapted = Captain::AssistantTemplates::TemplateAdapterService.new(
      template: template,
      business_context: business_context,
      clarifications: adapt_params[:clarifications] || {},
      locale: adapt_params[:locale]
    ).perform

    render json: adapted
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    render json: { error: e.message }, status: :not_found
  end

  def clarifying_questions
    template = Captain::AssistantTemplates::Loader.find(params[:template_id])
    locale = params[:locale] || Current.account.locale || 'en'

    questions = template['clarifying_questions'] || []

    formatted_questions = questions.map do |q|
      {
        purpose: q['purpose'],
        question: Captain::AssistantTemplates::Loader.localized(q['question_i18n'], locale)
      }
    end

    render json: {
      template_id: params[:template_id],
      template_name: Captain::AssistantTemplates::Loader.localized(template['assistant']['name_i18n'], locale),
      questions: formatted_questions
    }
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def instantiate_params
    params.require(:template).permit(:template_id, :product_name, :locale, :name, adapted_data: {})
  end

  def adapt_params
    params.permit(:template_id, :locale, clarifications: {})
  end
end
