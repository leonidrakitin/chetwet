class Api::V1::Accounts::TelegramSessionsController < Api::V1::Accounts::BaseController
  before_action :fetch_telegram_session, only: %i[show submit_code submit_password reconnect]

  def index
    sessions = TelegramSession.joins(:inbox).where(inboxes: { account_id: Current.account.id }).order(:id)
    render json: sessions.map { |s| session_payload(s, s.inbox) }
  end

  def show
    render json: session_payload(@telegram_session, @telegram_session.inbox)
  end

  def create
    return if render_telegram_personal_guards

    result = Inbox::TelegramPersonalService.new(
      account: Current.account,
      user: Current.user,
      params: telegram_session_create_params
    ).perform

    render json: session_payload(result[:telegram_session], result[:inbox]), status: :created
  rescue Telegram::TdlibError, ActiveRecord::RecordInvalid => e
    render json: { error: humanize_telegram_error(e.message) }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: 'Could not connect to Telegram. Please check your phone number and try again.' }, status: :unprocessable_entity
  end

  def submit_code
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).submit_code!(params[:code])
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: humanize_telegram_error(e.message) }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: 'Could not verify the code. Please try again.' }, status: :unprocessable_entity
  end

  def submit_password
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).submit_password!(params[:password])
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: humanize_telegram_error(e.message) }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: 'Could not verify the password. Please try again.' }, status: :unprocessable_entity
  end

  def reconnect
    Telegram::AuthenticationService.new(telegram_session: @telegram_session).start_authentication!
    render json: session_payload(@telegram_session.reload, @telegram_session.inbox)
  rescue Telegram::TdlibError => e
    render json: { error: humanize_telegram_error(e.message) }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: 'Could not reconnect to Telegram. Please try again.' }, status: :unprocessable_entity
  end

  private

  def render_telegram_personal_guards
    unless GlobalConfig.get_value('ENABLE_TELEGRAM_PERSONAL_CHANNEL')
      render json: { error: 'Telegram Personal is disabled' }, status: :forbidden
      return true
    end

    api_id = GlobalConfig.get_value('TELEGRAM_PERSONAL_API_ID')
    api_hash = GlobalConfig.get_value('TELEGRAM_PERSONAL_API_HASH')

    if api_id.blank? || api_hash.blank?
      render json: { error: 'Telegram Personal API credentials are not configured' }, status: :unprocessable_entity
      return true
    end

    false
  end

  TDLIB_ERROR_MESSAGES = {
    'PHONE_NUMBER_OCCUPIED' => 'This phone number is linked to another Telegram account. Use a different number or remove the existing inbox.',
    'PHONE_NUMBER_INVALID' => 'The phone number is invalid. Please check the format (include country code) and try again.',
    'PHONE_NUMBER_BANNED' => 'This phone number has been banned by Telegram.',
    'PHONE_CODE_INVALID' => 'The verification code is incorrect. Please check the code and try again.',
    'PHONE_CODE_EXPIRED' => 'The verification code has expired. Click Reconnect to request a new one.',
    'PASSWORD_HASH_INVALID' => 'Incorrect 2FA password. Please check your cloud password and try again.',
    'FLOOD_WAIT' => 'Too many attempts. Please wait a few minutes before trying again.',
    'TDLib state timeout' => 'Connection to Telegram timed out. Please try again.',
    'RPC timeout' => 'Telegram is taking too long to respond. Please try again in a moment.'
  }.freeze

  def humanize_telegram_error(message)
    TDLIB_ERROR_MESSAGES.each do |code, friendly|
      return friendly if message.include?(code)
    end
    message
  end

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
