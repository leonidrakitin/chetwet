class Api::V1::Accounts::TelegramSessionsController < Api::V1::Accounts::BaseController
  before_action :fetch_telegram_session, only: %i[show submit_code submit_password reconnect]

  def show
    render json: session_payload(@telegram_session, @telegram_session.inbox)
  end

  def create
    unless GlobalConfig.get_value('ENABLE_TELEGRAM_PERSONAL_CHANNEL')
      render json: { error: 'Telegram Personal is disabled' }, status: :forbidden
      return
    end

    api_id = GlobalConfig.get_value('TELEGRAM_PERSONAL_API_ID')
    api_hash = GlobalConfig.get_value('TELEGRAM_PERSONAL_API_HASH')

    if api_id.blank? || api_hash.blank?
      render json: { error: 'Telegram Personal API credentials are not configured' }, status: :unprocessable_entity
      return
    end

    result = Inbox::TelegramPersonalService.new(
      account: Current.account,
      user: Current.user,
      params: telegram_session_create_params
    ).perform

    render json: session_payload(result[:telegram_session], result[:inbox]), status: :created
  rescue Telegram::TdlibError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def submit_code
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).submit_code!(params[:code])
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def submit_password
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).submit_password!(params[:password])
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reconnect
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).start_authentication!
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_telegram_session
    @telegram_session = TelegramSession.joins(:inbox).where(id: params[:id], inboxes: { account_id: Current.account.id }).first!
  end

  def telegram_session_create_params
    params.permit(:name, :phone_number)
  end

  def session_payload(telegram_session, inbox)
    {
      id: telegram_session.id,
      inbox_id: inbox.id,
      inbox_name: inbox.name,
      channel_type: inbox.channel_type,
      phone_number: telegram_session.phone_number,
      status: telegram_session.status,
      auth_state: telegram_session.auth_state,
      last_error: telegram_session.last_error,
      telegram_user_id: telegram_session.telegram_user_id,
      telegram_username: telegram_session.telegram_username
    }
  end
end
