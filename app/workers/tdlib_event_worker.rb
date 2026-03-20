class TdlibEventWorker < ApplicationJob
  queue_as :default

  LOCK_TTL = 45.seconds
  UPDATE_TYPES = %w[
    updateNewMessage
    updateMessageContent
    updateDeleteMessages
    updateMessageSendSucceeded
    updateConnectionState
    updateChatTitle
    updateChatPhoto
    updateUser
  ].freeze

  def perform(telegram_session_id)
    @telegram_session = TelegramSession.find(telegram_session_id)
    return unless @telegram_session.active?
    return unless acquire_lock!

    @client = Telegram::Client.new(@telegram_session)
    register_handlers!

    # Русский комментарий: Sidekiq job держим живым как event loop для одного inbox.
    loop do
      @telegram_session.reload
      break unless @telegram_session.active?

      process_rpc_requests!
      refresh_lock!
      sleep 1
    end
  rescue Telegram::TdlibError, StandardError => e
    @telegram_session&.update!(status: :disconnected, last_error: e.message)
    @telegram_session&.inbox&.channel&.update!(status: 'disconnected', last_error: e.message)
    retry_job wait: 10.seconds if @telegram_session.present?
  ensure
    @client&.close
    release_lock!
  end

  private

  def register_handlers!
    @client.on('updateAuthorizationState') do |update|
      state = Telegram::Client::AUTH_STATES[update.dig('authorization_state', '@type')] || :unknown
      status = if state == :ready
                 :active
               elsif %i[wait_tdlib_parameters wait_phone_number wait_code
                        wait_password].include?(state)
                 :authenticating
               else
                 :disconnected
               end
      @telegram_session.update!(
        auth_state: state.to_s,
        status: status,
        last_error: nil
      )
      @telegram_session.inbox.channel.update!(status: status.to_s, last_error: nil)
      @telegram_session.persist_session_snapshot!
    end

    @client.on('updateNewChat') do |update|
      chat = update['chat']
      next unless chat

      $alfred.with do |c|
        c.sadd(rpc_chats_key, chat['id'].to_s)
        c.expire(rpc_chats_key, 1.hour.to_i)
      end
    end

    UPDATE_TYPES.each do |update_type|
      next if update_type == 'updateAuthorizationState'

      @client.on(update_type) do |update|
        Telegram::EventHandlerService.new(
          telegram_session: @telegram_session,
          update: update,
          client: @client
        ).perform
      end
    end
  end

  def acquire_lock!
    @lock_token = SecureRandom.hex(8)
    Rails.cache.write(lock_key, @lock_token, unless_exist: true, expires_in: LOCK_TTL)
  end

  def refresh_lock!
    return unless Rails.cache.read(lock_key) == @lock_token

    Rails.cache.write(lock_key, @lock_token, expires_in: LOCK_TTL)
  end

  def release_lock!
    return unless @lock_token.present?
    return unless Rails.cache.read(lock_key) == @lock_token

    Rails.cache.delete(lock_key)
  end

  def process_rpc_requests!
    rpc_key = "telegram_rpc:requests:#{@telegram_session.id}"

    while (raw = $alfred.with { |c| c.lpop(rpc_key) })
      req = JSON.parse(raw)
      response = begin
        result = @client.public_send(req['method'].underscore, **req['params'].symbolize_keys)
        { data: result }
      rescue StandardError => e
        { error: e.message }
      end

      response_key = "telegram_rpc:response:#{req['id']}"
      $alfred.with do |c|
        c.rpush(response_key, response.to_json)
        c.expire(response_key, 60)
      end
    end
  end

  def rpc_chats_key
    "telegram_rpc:chats:#{@telegram_session.id}"
  end

  def lock_key
    "telegram_personal:tdlib_worker:#{@telegram_session.id}"
  end
end
