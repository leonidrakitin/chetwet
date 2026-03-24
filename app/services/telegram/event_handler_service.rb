class Telegram::EventHandlerService
  pattr_initialize [:telegram_session!, :update!, :client]

  def perform
    case update_type
    when 'updateNewMessage'
      process_new_message
    when 'updateMessageContent'
      process_message_edit
    when 'updateDeleteMessages'
      process_message_delete
    when 'updateMessageSendSucceeded'
      process_delivery_update
    when 'updateConnectionState'
      process_connection_update
    when 'updateChatTitle', 'updateChatPhoto', 'updateUser'
      process_chat_update
    end
  rescue StandardError => e
    telegram_session.update!(last_error: e.message, status: :disconnected)
    telegram_session.inbox.channel.update!(last_error: e.message, status: 'disconnected')
    raise e
  end

  private

  def process_new_message
    message_payload = update['message'] || {}
    return if Chatwoot::Api.find_message(inbox: inbox, source_id: message_payload['id']).present?

    peer = peer_profile(message_payload)

    contact_inbox = Chatwoot::Api.find_or_create_contact_inbox(
      inbox: inbox,
      source_id: peer['id'].to_s,
      contact_attributes: contact_attributes(peer)
    )

    enqueue_avatar_download(contact_inbox.contact, peer)

    conversation = Chatwoot::Api.find_or_create_conversation(
      inbox: inbox,
      contact_inbox: contact_inbox,
      additional_attributes: { chat_id: message_payload['chat_id'], peer_user_id: peer['id'].to_s }
    )

    message = Chatwoot::Api.create_message(
      conversation: conversation,
      attributes: message_attributes(message_payload, contact_inbox.contact)
    )

    enqueue_media_downloads(message_payload, message)
  end

  def process_message_edit
    existing_message = Chatwoot::Api.find_message(inbox: inbox, source_id: update['message_id'])
    return unless existing_message

    message = Chatwoot::Api.update_message(
      inbox: inbox,
      source_id: update['message_id'],
      attributes: {
        content: extract_content(update['new_content']),
        content_attributes: (existing_message.content_attributes || {}).merge('edited' => true)
      }
    )

    enqueue_media_downloads({ 'content' => update['new_content'] }, message) if message.present?
  end

  def process_message_delete
    Array(update['message_ids']).each do |message_id|
      message = Chatwoot::Api.find_message(inbox: inbox, source_id: message_id)
      Chatwoot::Api.mark_message_deleted!(message) if message
    end
  end

  def process_delivery_update
    message = Chatwoot::Api.find_message(inbox: inbox, source_id: update['old_message_id'])
    return unless message

    message.update!(source_id: update.dig('message', 'id').to_s, status: :delivered)
  end

  def process_connection_update
    state = update.dig('state', '@type').to_s
    status = state.match?(/ready/i) ? :active : :disconnected

    telegram_session.update!(status: status, last_error: nil)
    inbox.channel.update!(status: status.to_s, last_error: nil)
  end

  def process_chat_update
    telegram_session.update!(
      metadata: (telegram_session.metadata || {}).merge('last_synced_at' => Time.current.iso8601)
    )
  end

  def enqueue_media_downloads(message_payload, message)
    return if message.blank?

    media_files(message_payload).each do |payload|
      TelegramMediaDownloadWorker.perform_later(telegram_session.id, message.id, payload)
    end
  end

  def message_attributes(message_payload, contact)
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      content: extract_content(message_payload['content']),
      message_type: message_payload['is_outgoing'] ? :outgoing : :incoming,
      sender: message_payload['is_outgoing'] ? nil : contact,
      status: message_payload['is_outgoing'] ? :delivered : :sent,
      content_attributes: content_attributes(message_payload),
      source_id: message_payload['id'].to_s
    }
  end

  def content_attributes(message_payload)
    attrs = {}
    reply_to_id = message_payload.dig('reply_to', 'message_id')
    attrs[:in_reply_to_external_id] = reply_to_id.to_s if reply_to_id.present?
    attrs[:external_echo] = true if message_payload['is_outgoing']
    attrs
  end

  def contact_attributes(peer)
    {
      name: contact_name(peer),
      additional_attributes: {
        username: peer['username'],
        phone_number: peer['phone_number'],
        social_telegram_user_id: peer['id'].to_s,
        social_telegram_user_name: peer['username']
      }.compact
    }
  end

  def contact_name(peer)
    full_name = [peer['first_name'], peer['last_name']].compact.join(' ').strip
    full_name.presence || peer['username'].presence || peer['title'].presence || telegram_session.phone_number
  end

  def peer_profile(message_payload)
    chat = tdlib_client.get_chat(message_payload['chat_id'])
    type = chat.dig('type', '@type')

    if type == 'chatTypePrivate'
      user = tdlib_client.get_user(chat.dig('type', 'user_id'))
      return user.merge('title' => chat['title'], 'avatar_file_id' => profile_photo_file_id(user))
    end

    { 'id' => message_payload['chat_id'], 'title' => chat['title'] }
  rescue Telegram::TdlibError
    { 'id' => message_payload['chat_id'] }
  end

  def profile_photo_file_id(user)
    user.dig('profile_photo', 'small', 'id')
  end

  def enqueue_avatar_download(contact, peer)
    return if contact.avatar.attached?

    file_id = peer['avatar_file_id']
    return if file_id.blank?

    TelegramAvatarDownloadWorker.perform_later(telegram_session.id, contact.id, file_id)
  end

  def extract_content(content_payload)
    return '' if content_payload.blank?

    case content_payload['@type']
    when 'messageText'
      content_payload.dig('text', 'text').to_s
    when 'messagePhoto', 'messageDocument', 'messageVoiceNote', 'messageAudio', 'messageVideo'
      content_payload.dig('caption', 'text').to_s
    else
      ''
    end
  end

  def media_files(message_payload)
    content = message_payload['content'] || {}

    case content['@type']
    when 'messagePhoto'
      [build_media_payload(content.dig('photo', 'sizes')&.last&.dig('photo'), 'photo', content)]
    when 'messageDocument'
      [build_media_payload(content['document']['document'], 'document', content).merge('file_name' => content.dig('document', 'file_name'))]
    when 'messageVoiceNote'
      [build_media_payload(content['voice_note']['voice'], 'voice_note', content)]
    when 'messageAudio'
      [build_media_payload(content['audio']['audio'], 'audio', content).merge('file_name' => content.dig('audio', 'file_name'))]
    when 'messageVideo'
      [build_media_payload(content['video']['video'], 'video', content).merge('file_name' => content.dig('video', 'file_name'))]
    else
      []
    end.compact
  end

  def build_media_payload(file_payload, kind, content)
    return if file_payload.blank?

    {
      'id' => file_payload['id'],
      'kind' => kind,
      'caption' => content.dig('caption', 'text')
    }
  end

  def tdlib_client
    @tdlib_client ||= client || Telegram::Client.new(telegram_session)
  end

  def inbox
    telegram_session.inbox
  end

  def update_type
    update['@type']
  end
end
