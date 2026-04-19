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
      name_override: instantiate_params[:name]
    ).perform!

    render partial: 'api/v1/models/captain/assistant', formats: [:json], locals: { resource: @assistant }
  rescue Captain::AssistantTemplates::TemplateNotFoundError => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def instantiate_params
    params.require(:template).permit(:template_id, :product_name, :locale, :name)
  end
end
