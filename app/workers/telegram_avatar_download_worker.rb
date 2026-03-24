class TelegramAvatarDownloadWorker < ApplicationJob
  queue_as :purgable

  def perform(telegram_session_id, contact_id, file_id)
    telegram_session = TelegramSession.find(telegram_session_id)
    contact = Contact.find(contact_id)
    return if contact.avatar.attached?

    client = Telegram::Client.new(telegram_session)
    downloaded = client.download_file(file_id, synchronous: true)
    local_path = downloaded.dig('local', 'path') || downloaded.dig('file', 'local', 'path')
    return if local_path.blank? || !File.exist?(local_path)

    File.open(local_path, 'rb') do |file|
      contact.avatar.attach(
        io: file,
        filename: File.basename(local_path),
        content_type: Marcel::MimeType.for(Pathname.new(local_path))
      )
    end
  rescue Telegram::TdlibError => e
    Rails.logger.error "TelegramAvatarDownloadWorker: failed to download avatar for contact #{contact_id}: #{e.message}"
  ensure
    client&.close
  end
end
