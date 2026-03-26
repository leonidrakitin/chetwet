# frozen_string_literal: true

class Avito::SendAttachmentsService
  pattr_initialize [:message!]

  def perform
    return nil unless channel.chat_id(message).present?

    last_id = nil
    message.attachments.each do |attachment|
      id = send_attachment(attachment)
      last_id = id if id.present?
    end
    last_id
  end

  private

  def send_attachment(attachment)
    return nil unless attachment.file.attached?

    case attachment.file_type
    when 'image'
      upload_and_send_image(attachment)
    else
      # Avito messenger only supports images for outgoing messages.
      # For other file types, send a text note with the file URL if available.
      send_file_as_text(attachment)
    end
  rescue StandardError => e
    Rails.logger.warn "[Avito] SendAttachmentsService failed for attachment #{attachment.id}: #{e.message}"
    nil
  end

  def upload_and_send_image(attachment)
    temp_path = save_attachment_to_tempfile(attachment)
    return nil unless temp_path

    begin
      image_id = channel.upload_image(temp_path)
      return nil unless image_id

      channel.send_image_message(channel.chat_id(message), image_id)
    ensure
      FileUtils.rm_f(temp_path) if temp_path
    end
  end

  def send_file_as_text(attachment)
    # Avito doesn't support sending arbitrary files — send a placeholder text
    file_name = attachment.file.filename.to_s
    text_content = "[Файл: #{file_name}]"

    # Build a temporary message-like object to reuse the send method
    response = HTTParty.post(
      "#{channel.avito_api_url}/messenger/v1/accounts/#{channel.avito_user_id}/chats/#{channel.chat_id(message)}/messages",
      headers: channel.auth_headers.merge('Content-Type' => 'application/json'),
      body: {
        type: 'text',
        message: {
          text: text_content
        }
      }.to_json
    )

    return nil unless response.success?

    response.parsed_response['id']
  rescue StandardError => e
    Rails.logger.warn "[Avito] send_file_as_text error: #{e.message}"
    nil
  end

  def save_attachment_to_tempfile(attachment)
    return nil unless attachment.file.attached?

    filename = attachment.file.filename.to_s.presence || 'attachment.jpg'
    temp_dir = Rails.root.join('tmp/uploads', "avito-#{attachment.message_id}")
    FileUtils.mkdir_p(temp_dir)
    temp_path = File.join(temp_dir, filename)

    File.open(temp_path, 'wb') do |file|
      attachment.file.blob.open { |blob_file| IO.copy_stream(blob_file, file) }
    end

    temp_path
  rescue StandardError => e
    Rails.logger.warn "[Avito] save_attachment_to_tempfile error: #{e.message}"
    nil
  end

  def channel
    @channel ||= message.inbox.channel
  end
end
