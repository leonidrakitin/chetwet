class Telegram::MediaService
  pattr_initialize [:telegram_session!, :message, :file_payload, :attachment, :caption, :chat_id, :reply_to_message_id]

  def download_to_attachment!
    with_client do |client|
      downloaded = client.download_file(file_id, synchronous: true)
      local_path = downloaded.dig('local', 'path') || downloaded.dig('file', 'local', 'path')
      raise Telegram::TdlibError, "TDLib file path is blank for file_id=#{file_id}" if local_path.blank?

      File.open(local_path, 'rb') do |file|
        message.attachments.create!(
          account_id: message.account_id,
          file_type: incoming_file_type,
          file: {
            io: file,
            filename: File.basename(local_path),
            content_type: Marcel::MimeType.for(Pathname.new(local_path))
          },
          fallback_title: fallback_title,
          meta: incoming_meta
        )
      end
    end
  end

  def send_attachment!
    with_client do |client|
      with_local_file do |local_path|
        case attachment.file_type
        when 'image'
          client.send_photo(
            chat_id: chat_id.to_i,
            file_path: local_path,
            caption: caption_payload,
            reply_to_message_id: reply_to_message_id
          )
        when 'audio'
          client.send_voice_note(
            chat_id: chat_id.to_i,
            file_path: local_path,
            caption: caption_payload,
            reply_to_message_id: reply_to_message_id
          )
        else
          client.send_document(
            chat_id: chat_id.to_i,
            file_path: local_path,
            caption: caption_payload,
            reply_to_message_id: reply_to_message_id
          )
        end
      end
    end
  end

  private

  def with_client
    client = Telegram::Client.new(telegram_session)
    yield client
  ensure
    client&.close
  end

  def file_id
    file_payload['id'] || file_payload.dig('file', 'id')
  end

  def incoming_file_type
    case file_payload['kind']
    when 'photo'
      :image
    when 'voice_note', 'audio'
      :audio
    when 'video'
      :video
    else
      :file
    end
  end

  def incoming_meta
    {
      telegram_file_id: file_id,
      telegram_kind: file_payload['kind']
    }.compact
  end

  def fallback_title
    file_payload['file_name'] || file_payload['kind']
  end

  def caption_payload
    caption.presence || { '@type' => 'formattedText', text: '', entities: [] }
  end

  def with_local_file
    temp_path = Rails.root.join('tmp', 'telegram_personal_uploads', SecureRandom.hex(8), attachment.file.filename.to_s)
    FileUtils.mkdir_p(File.dirname(temp_path))

    attachment.file.blob.open do |blob|
      File.open(temp_path, 'wb') { |file| IO.copy_stream(blob, file) }
    end

    yield temp_path.to_s
  ensure
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
  end
end
