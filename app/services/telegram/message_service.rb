class Telegram::MessageService < Base::SendOnChannelService
  def channel_class
    Channel::TelegramPersonal
  end

  private

  def perform_reply
    response = if message.attachments.present?
                 send_attachments
               elsif message.outgoing_content.present?
                 send_text_message
               end

    message_id = extract_message_id(response)
    message.update!(source_id: message_id.to_s) if message_id.present?
  rescue Telegram::RateLimitError, Telegram::TdlibError => e
    message.update!(status: :failed, external_error: e.message)
    raise e
  end

  def send_text_message
    with_client do |client|
      client.send_text_message(
        chat_id: telegram_chat_id,
        formatted_text: formatted_text,
        reply_to_message_id: reply_to_message_id
      )
    end
  end

  def send_attachments
    result = nil

    message.attachments.each do |attachment|
      Telegram::MediaService.new(
        telegram_session: telegram_session,
        attachment: attachment,
        caption: formatted_text,
        chat_id: telegram_chat_id,
        reply_to_message_id: reply_to_message_id
      ).send_attachment!.tap do |response|
        result ||= response
      end
    end

    result
  end

  def telegram_session
    @telegram_session ||= inbox.telegram_session
  end

  def telegram_chat_id
    conversation.additional_attributes['chat_id'].to_i
  end

  def reply_to_message_id
    message.content_attributes['in_reply_to_external_id']&.to_i
  end

  def extract_message_id(response)
    return if response.blank?

    response.dig('message', 'id') || response['id']
  end

  def with_client
    client = Telegram::Client.new(telegram_session)
    yield client
  ensure
    client&.close
  end

  def formatted_text
    @formatted_text ||= Telegram::MessageService::FormattedTextBuilder.new(message.outgoing_content.to_s).perform
  end

  class FormattedTextBuilder
    ENTITY_TYPES = {
      'b' => 'textEntityTypeBold',
      'strong' => 'textEntityTypeBold',
      'i' => 'textEntityTypeItalic',
      'em' => 'textEntityTypeItalic',
      'code' => 'textEntityTypeCode',
      'pre' => 'textEntityTypePre'
    }.freeze

    def initialize(content)
      @content = content
      @text = +''
      @entities = []
    end

    def perform
      fragment = Nokogiri::HTML::DocumentFragment.parse(@content)
      fragment.children.each { |node| append_node(node) }

      { '@type' => 'formattedText', text: @text, entities: @entities }
    end

    private

    def append_node(node, inherited_types = [])
      if node.text?
        append_text(node.text, inherited_types)
        return
      end

      types = inherited_types.dup
      types << entity_for_node(node) if entity_for_node(node).present?

      if node.name == 'a' && node['href'].present?
        start = @text.length
        node.children.each { |child| append_node(child, types.compact) }
        append_entity('textEntityTypeTextUrl', start, @text.length - start, url: node['href'])
        return
      end

      node.children.each { |child| append_node(child, types.compact) }
      @text << "\n" if node.name == 'br'
    end

    def append_text(text, entity_types)
      return if text.blank?

      start = @text.length
      @text << CGI.unescapeHTML(text)
      length = @text.length - start
      entity_types.each { |entity_type| append_entity(entity_type, start, length) }
    end

    def append_entity(type, offset, length, extra = {})
      return if length <= 0

      @entities << {
        '@type' => 'textEntity',
        offset: offset,
        length: length,
        type: { '@type' => type }.merge(extra)
      }
    end

    def entity_for_node(node)
      ENTITY_TYPES[node.name]
    end
  end
end
