class Telegram::AuthenticationService
  AUTH_FLOW_STATES = %i[wait_tdlib_parameters wait_phone_number wait_code wait_password ready].freeze

  pattr_initialize [:telegram_session!]

  delegate :inbox, to: :telegram_session

  def start_authentication!
    with_client do |client|
      state = client.wait_for_state(*AUTH_FLOW_STATES)
      client.set_phone_number(telegram_session.phone_number) if state == :wait_phone_number
      update_session_state!(client.wait_for_state(:wait_code, :wait_password, :ready))
      sync_profile!(client) if telegram_session.active?
    end

    telegram_session
  rescue Telegram::RateLimitError, Telegram::TdlibError => e
    handle_auth_error!(e)
  end

  def submit_code!(code)
    with_client do |client|
      client.wait_for_state(:wait_code, :wait_password, :ready)
      client.check_code(code)
      update_session_state!(client.wait_for_state(:wait_password, :ready))
      sync_profile!(client) if telegram_session.active?
    end

    telegram_session
  rescue Telegram::RateLimitError, Telegram::TdlibError => e
    handle_auth_error!(e)
  end

  def submit_password!(password)
    with_client do |client|
      client.wait_for_state(:wait_password, :ready)
      client.check_password(password)
      update_session_state!(client.wait_for_state(:ready))
      sync_profile!(client)
    end

    telegram_session
  rescue Telegram::RateLimitError, Telegram::TdlibError => e
    handle_auth_error!(e)
  end

  def status_payload
    {
      id: telegram_session.id,
      inbox_id: telegram_session.inbox_id,
      phone_number: telegram_session.phone_number,
      status: telegram_session.status,
      auth_state: telegram_session.auth_state,
      last_error: telegram_session.last_error,
      telegram_user_id: telegram_session.telegram_user_id,
      telegram_username: telegram_session.telegram_username
    }
  end

  private

  def with_client
    client = Telegram::Client.new(telegram_session)
    yield client
  ensure
    client&.close
  end

  def sync_profile!(client)
    me = client.get_me
    username = me['usernames'].to_a.first&.dig('username') || me['username']

    telegram_session.update!(
      status: :active,
      auth_state: 'ready',
      last_error: nil,
      metadata: (telegram_session.metadata || {}).merge(
        'telegram_user_id' => me['id'].to_s,
        'telegram_username' => username
      )
    )

    inbox.channel.update!(
      telegram_user_id: me['id'].to_s,
      telegram_username: username,
      status: 'active',
      last_error: nil
    )

    telegram_session.persist_session_snapshot!(
      'me' => {
        'id' => me['id'],
        'first_name' => me['first_name'],
        'last_name' => me['last_name'],
        'username' => username
      }
    )
  end

  def update_session_state!(state)
    mapped_status =
      case state
      when :ready
        :active
      when :wait_phone_number, :wait_code, :wait_password, :wait_tdlib_parameters
        :authenticating
      else
        :disconnected
      end

    telegram_session.update!(
      status: mapped_status,
      auth_state: state.to_s,
      last_error: nil
    )

    inbox.channel.update!(
      status: mapped_status.to_s,
      last_error: nil
    )
  end

  def handle_auth_error!(error)
    # Русский комментарий: TDLib часто возвращает общую ошибку, поэтому фиксируем ее и оставляем wizard на текущем шаге.
    telegram_session.update!(status: :disconnected, last_error: error.message)
    inbox.channel.update!(status: 'disconnected', last_error: error.message)
    raise error
  end
end
