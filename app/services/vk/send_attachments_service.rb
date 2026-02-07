# frozen_string_literal: true

class Vk::SendAttachmentsService
  pattr_initialize [:message!]

  def perform
    return nil unless channel.peer_id(message).present?

    attachment_ids = []
    message.attachments.each do |attachment|
      id = send_attachment(attachment)
      attachment_ids << id if id.present?
    end

    return attachment_ids.last if attachment_ids.one?
    return attachment_ids.last if attachment_ids.many?

    nil
  end

  private

  def send_attachment(attachment)
    return nil unless attachment.with_attached_file?

    case attachment.file_type
    when 'image'
      upload_and_send_photo(attachment)
    when 'file', 'video', 'audio'
      upload_and_send_doc(attachment)
    else
      upload_and_send_doc(attachment)
    end
  rescue StandardError => e
    Rails.logger.warn "[VK] Send attachment failed: #{e.message}"
    nil
  end

  def upload_and_send_photo(attachment)
    upload_url = get_photo_upload_server
    return unless upload_url

    upload_result = upload_file(upload_url, attachment, 'photo')
    return unless upload_result

    photo_data = save_messages_photo(upload_result)
    return unless photo_data

    send_message_with_attachment("photo#{photo_data['owner_id']}_#{photo_data['id']}")
  end

  def upload_and_send_doc(attachment)
    upload_url = get_doc_upload_server
    unless upload_url
      Rails.logger.warn '[VK] Failed to get doc upload server'
      return
    end

    upload_result = upload_file(upload_url, attachment, 'file')
    unless upload_result
      Rails.logger.warn "[VK] Failed to upload doc for attachment #{attachment.id}"
      return
    end

    unless upload_result['file'].present?
      Rails.logger.warn "[VK] Upload response missing file field: #{upload_result.keys}"
      return
    end

    doc_data = save_messages_doc(upload_result)
    return unless doc_data

    doc = doc_data.dig('response', 'doc') || doc_data.dig('response', 0) || doc_data['doc']
    return unless doc

    send_message_with_attachment("doc#{doc['owner_id']}_#{doc['id']}")
  end

  def get_photo_upload_server
    response = HTTParty.get(
      "#{channel.vk_api_url}/photos.getMessagesUploadServer",
      query: {
        peer_id: channel.peer_id(message),
        access_token: channel.access_token,
        v: '5.199'
      }
    )
    return nil unless response.success?

    response.parsed_response.dig('response', 'upload_url')
  end

  def get_doc_upload_server
    response = HTTParty.get(
      "#{channel.vk_api_url}/docs.getMessagesUploadServer",
      query: {
        type: 'doc',
        peer_id: channel.peer_id(message),
        access_token: channel.access_token,
        v: '5.199'
      }
    )
    return nil unless response.success?

    response.parsed_response.dig('response', 'upload_url')
  end

  def upload_file(upload_url, attachment, field_name)
    temp_path = save_attachment_to_tempfile(attachment)
    return nil unless temp_path

    begin
      File.open(temp_path, 'rb') do |file|
        response = HTTParty.post(
          upload_url,
          body: { field_name => file },
          multipart: true
        )
        return nil unless response.success?

        response.parsed_response
      end
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end

  def save_attachment_to_tempfile(attachment)
    return nil unless attachment.file.attached?

    filename = attachment.file.filename.to_s.presence || attachment_filename_for_type(attachment)
    temp_dir = Rails.root.join('tmp/uploads', "vk-#{attachment.message_id}")
    FileUtils.mkdir_p(temp_dir)
    temp_path = File.join(temp_dir, filename)

    File.open(temp_path, 'wb') do |file|
      attachment.file.blob.open { |blob_file| IO.copy_stream(blob_file, file) }
    end

    temp_path
  end

  def attachment_filename_for_type(attachment)
    ext = case attachment.file_type
          when 'audio' then 'mp3'
          when 'image' then 'jpg'
          when 'video' then 'mp4'
          else 'bin'
          end
    "attachment.#{ext}"
  end

  def save_messages_photo(upload_result)
    response = HTTParty.post(
      "#{channel.vk_api_url}/photos.saveMessagesPhoto",
      body: {
        photo: upload_result['photo'],
        server: upload_result['server'],
        hash: upload_result['hash'],
        access_token: channel.access_token,
        v: '5.199'
      }
    )
    return nil unless response.success?

    response.parsed_response.dig('response')&.first
  end

  def save_messages_doc(upload_result)
    response = HTTParty.post(
      "#{channel.vk_api_url}/docs.save",
      body: {
        file: upload_result['file'],
        access_token: channel.access_token,
        v: '5.199'
      }
    )
    unless response.success?
      Rails.logger.warn "[VK] docs.save failed: #{response.parsed_response}"
      return nil
    end

    response.parsed_response
  end

  def send_message_with_attachment(attachment_str)
    body = {
      peer_id: channel.peer_id(message),
      attachment: attachment_str,
      random_id: SecureRandom.random_number(2**31),
      access_token: channel.access_token,
      v: '5.199'
    }
    body[:message] = message.outgoing_content if message.outgoing_content.present?
    body[:reply_to] = channel.reply_to_message_id(message) if channel.reply_to_message_id(message)

    response = HTTParty.post("#{channel.vk_api_url}/messages.send", body: body)

    channel.process_error(message, response)
    response.parsed_response['response'] if response.success?
  end

  def channel
    @channel ||= message.inbox.channel
  end
end
