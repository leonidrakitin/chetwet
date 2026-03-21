class TelegramSyncWorker < ApplicationJob
  queue_as :default

  PERMANENT_ERRORS = /USER_DEACTIVATED|AUTH_KEY_UNREGISTERED|SESSION_REVOKED|SESSION_EXPIRED|re-authentication/i

  def perform(telegram_session_id = nil)
    if telegram_session_id.present?
      sessions = TelegramSession.where(id: telegram_session_id)
    else
      sessions = TelegramSession.active
      reconnect_disconnected_sessions
    end

    sessions.find_each do |session|
      TdlibEventWorker.perform_later(session.id)
      sync_recent_history(session)
    end
  end

  private

  def reconnect_disconnected_sessions
    TelegramSession.disconnected.find_each do |session|
      next if session.last_error&.match?(PERMANENT_ERRORS)
      next unless Telegram::TdlibConfig.database_directory(session).exist?
      next if worker_lock_held?(session)

      Telegram::AuthenticationService.new(telegram_session: session).reconnect!
    rescue StandardError => e
      Rails.logger.warn("[TelegramReconnect] session=#{session.id} error=#{e.message}")
    end
  end

  def worker_lock_held?(session)
    Rails.cache.exist?("telegram_personal:tdlib_worker:#{session.id}")
  end

  def sync_recent_history(session)
    client = Telegram::Client.new(session)

    known_chat_ids(session).each do |chat_id|
      history = client.get_chat_history(chat_id, limit: 25)
      Array(history['messages']).reverse_each do |message|
        Telegram::EventHandlerService.new(
          telegram_session: session,
          update: { '@type' => 'updateNewMessage', 'message' => message },
          client: client
        ).perform
      end
    end

    session.update!(metadata: (session.metadata || {}).merge('last_synced_at' => Time.current.iso8601))
    session.persist_session_snapshot!
  ensure
    client&.close
  end

  def known_chat_ids(session)
    session.inbox.conversations.pluck(Arel.sql("additional_attributes->>'chat_id'")).compact.map(&:to_i).uniq
  end
end
