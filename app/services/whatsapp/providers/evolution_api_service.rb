class Whatsapp::Providers::EvolutionApiService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, _template_info, message)
    # Evolution API (Baileys) does not support Meta-style templates.
    # Send as plain text instead.
    send_text_message(phone_number, message)
  end

  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    response = HTTParty.get(
      "#{api_base_path}/instance/connectionState/#{instance_name}",
      headers: api_headers
    )
    response.success?
  rescue StandardError
    false
  end

  def api_headers
    { 'apikey' => whatsapp_channel.provider_config['api_key'], 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    media_id
  end

  private

  def api_base_path
    whatsapp_channel.provider_config['api_url']
  end

  def instance_name
    whatsapp_channel.provider_config['instance_name']
  end

  def message_endpoint(path)
    "#{api_base_path}/message/#{path}/#{instance_name}"
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      message_endpoint('sendText'),
      headers: api_headers,
      body: {
        number: phone_number,
        text: message.outgoing_content
      }.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    media_type = attachment_media_type(attachment.file_type)

    response = HTTParty.post(
      message_endpoint('sendMedia'),
      headers: api_headers,
      body: {
        number: phone_number,
        mediatype: media_type,
        media: attachment.download_url,
        caption: message.outgoing_content,
        fileName: attachment.file.filename.to_s
      }.to_json
    )

    process_response(response, message)
  end

  def send_interactive_text_message(phone_number, message)
    # Evolution API does not support interactive messages via Baileys.
    # Fall back to plain text with numbered options.
    items = message.content_attributes['items']
    options_text = items.each_with_index.map { |item, i| "#{i + 1}. #{item['title']}" }.join("\n")
    content = "#{message.outgoing_content}\n\n#{options_text}"

    response = HTTParty.post(
      message_endpoint('sendText'),
      headers: api_headers,
      body: {
        number: phone_number,
        text: content
      }.to_json
    )

    process_response(response, message)
  end

  def attachment_media_type(file_type)
    case file_type
    when 'image' then 'image'
    when 'audio' then 'audio'
    when 'video' then 'video'
    else 'document'
    end
  end

  def process_response(response, message)
    parsed = response.parsed_response
    if response.success?
      parsed.dig('key', 'id')
    else
      handle_error(response, message)
      nil
    end
  end

  def error_message(response)
    parsed = response.parsed_response
    parsed&.dig('message') || parsed&.dig('error')
  end
end
