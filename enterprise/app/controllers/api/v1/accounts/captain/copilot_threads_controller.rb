class Api::V1::Accounts::Captain::CopilotThreadsController < Api::V1::Accounts::BaseController
  before_action :ensure_message, only: :create

  def index
    scope = Current.account.copilot_threads
                   .where(user_id: Current.user.id)
                   .includes(:user, :assistant)
                   .order(created_at: :desc)
    scope = scope.for_source(permitted_params[:source]) if permitted_params[:source].present?
    @copilot_threads = scope.page(permitted_params[:page] || 1).per(5)
  end

  def create
    source = copilot_thread_params[:source].presence || 'default'
    existing = Current.account.copilot_threads
                      .where(user_id: Current.user.id, assistant_id: assistant.id)
                      .for_source(source)
                      .order(created_at: :desc)
                      .first

    if existing
      @copilot_thread = existing
      copilot_message = @copilot_thread.copilot_messages.create!(
        message_type: :user,
        message: { content: copilot_thread_params[:message] }
      )
      build_copilot_response(copilot_message)
      render
      return
    end

    ActiveRecord::Base.transaction do
      @copilot_thread = Current.account.copilot_threads.create!(
        title: copilot_thread_params[:message],
        user: Current.user,
        assistant: assistant,
        source: source
      )

      copilot_message = @copilot_thread.copilot_messages.create!(
        message_type: :user,
        message: { content: copilot_thread_params[:message] }
      )

      build_copilot_response(copilot_message)
    end
  end

  private

  def build_copilot_response(copilot_message)
    if Current.account.usage_limits[:captain][:responses][:current_available].positive?
      copilot_message.enqueue_response_job(copilot_thread_params[:conversation_id], Current.user.id)
    else
      copilot_message.copilot_thread.copilot_messages.create!(
        message_type: :assistant,
        message: { content: I18n.t('captain.copilot_limit') }
      )
    end
  end

  def ensure_message
    return render_could_not_create_error(I18n.t('captain.copilot_message_required')) if copilot_thread_params[:message].blank?
  end

  def assistant
    Current.account.captain_assistants.find(copilot_thread_params[:assistant_id])
  end

  def copilot_thread_params
    params.permit(:message, :assistant_id, :conversation_id, :source)
  end

  def permitted_params
    params.permit(:page, :source)
  end
end
