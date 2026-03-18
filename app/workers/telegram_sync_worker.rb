class TelegramSyncWorker < ApplicationJob
  queue_as :default

  def perform(telegram_session_id = nil)
    sessions = telegram_session_id.present? ? TelegramSession.where(id: telegram_session_id) : TelegramSession.active

    sessions.find_each do |session|
      TdlibEventWorker.perform_later(session.id)
      sync_recent_history(session)
    end
  end

  private

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
