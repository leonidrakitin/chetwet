class TelegramMediaDownloadWorker < ApplicationJob
  queue_as :default

  def perform(telegram_session_id, message_id, file_payload)
    telegram_session = TelegramSession.find(telegram_session_id)
    message = Message.find(message_id)

    Telegram::MediaService.new(
      telegram_session: telegram_session,
      message: message,
      file_payload: file_payload
    ).download_to_attachment!
  rescue Telegram::TdlibError => e
    message&.update!(content_attributes: (message.content_attributes || {}).merge('media_error' => e.message))
    raise e
  end
end
