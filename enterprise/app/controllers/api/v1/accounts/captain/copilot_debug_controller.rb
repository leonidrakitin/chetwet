class Api::V1::Accounts::Captain::CopilotDebugController < Api::V1::Accounts::BaseController
  before_action :ensure_admin
  before_action :find_copilot_thread

  def show
    render json: CopilotDebugEnricher.new(@copilot_thread).to_h
  end

  private

  def ensure_admin
    render json: { error: 'Unauthorized' }, status: :unauthorized unless Current.user.administrator?
  end

  def find_copilot_thread
    @copilot_thread = Current.account.copilot_threads.find_by(id: params[:id])
    render json: { error: 'Copilot thread not found' }, status: :not_found unless @copilot_thread
  end
end
