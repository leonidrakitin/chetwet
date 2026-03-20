# frozen_string_literal: true

class VkLiveFetcherService
  attr_reader :stats

  VK_API_BASE = 'https://api.vk.com/method'
  VK_API_VERSION = '5.199'
  CONVERSATIONS_PER_PAGE = 200
  MESSAGES_PER_PAGE = 200
  CONSECUTIVE_EMPTY_LIMIT = 20

  def initialize(access_token, options = {})
    @token = access_token
    @options = options.with_indifferent_access
    @my_user_id = nil
    @date_cutoff = compute_date_cutoff(@options[:date_limit_months])
    @user_cache = {}
    @stats = { total_chats: 0, processed_chats: 0, skipped_chats: 0,
               total_messages: 0, skipped_by_date: 0 }
  end

  def fetch(&block)
    @my_user_id = fetch_my_user_id
    conversations = load_conversations
    @stats[:total_chats] = conversations.size
    dialogs = []
    consecutive_empty = 0

    conversations.each_with_index do |conv_item, idx|
      dialog = fetch_conversation_dialog(conv_item)
      if dialog && dialog[:messages].present?
        dialogs << dialog
        @stats[:processed_chats] += 1
        @stats[:total_messages] += dialog[:messages].size
        consecutive_empty = 0
      else
        @stats[:skipped_chats] += 1
        @stats[:skipped_by_date] += 1 if @date_cutoff
        consecutive_empty += 1
        break if @date_cutoff && consecutive_empty >= CONSECUTIVE_EMPTY_LIMIT
      end
      block&.call(idx + 1, conversations.size)
    end
    dialogs
  end

  private

  def fetch_my_user_id
    resp = vk_get('users.get', {})
    resp&.first&.dig('id')
  end

  def load_conversations
    max = @options[:max_chats] || 500
    all_conversations = []
    offset = 0

    loop do
      resp = vk_get('messages.getConversations', { count: CONVERSATIONS_PER_PAGE, offset: offset, extended: 1 })
      break unless resp

      items = resp['items'] || []
      break if items.empty?

      cache_profiles(resp)

      items.each do |item|
        conv = item['conversation'] || item
        peer = conv.dig('peer') || {}
        next if peer['type'] == 'chat' && !@options[:include_groups]

        all_conversations << item
      end

      offset += items.size
      break if offset >= (resp['count'] || 0)
      break if all_conversations.size >= max
    end

    all_conversations.first(max)
  end

  def fetch_conversation_dialog(conv_item)
    conversation = conv_item['conversation'] || conv_item
    peer = conversation.dig('peer') || {}
    peer_id = peer['id']
    return nil unless peer_id

    messages = paginate_messages(peer_id)
    return nil if messages.empty?

    contact_name = resolve_contact_name(conversation)
    build_dialog(peer_id, contact_name, messages)
  end

  def paginate_messages(peer_id)
    all_messages = []
    offset = 0
    max = @options[:max_messages_per_chat] || 1000

    loop do
      resp = vk_get('messages.getHistory', { peer_id: peer_id, count: MESSAGES_PER_PAGE, offset: offset, rev: 0 })
      items = resp&.dig('items') || []
      break if items.empty?

      if @date_cutoff
        msgs_in_range = items.take_while { |m| Time.zone.at(m['date'].to_i) >= @date_cutoff }
        all_messages.concat(msgs_in_range)
        break if msgs_in_range.size < items.size
      else
        all_messages.concat(items)
      end

      break if all_messages.size >= max

      offset += items.size
    end

    all_messages.first(max).reverse
  end

  def resolve_contact_name(conversation)
    peer = conversation.dig('peer') || {}
    case peer['type']
    when 'user'
      user = @user_cache[peer['id']]
      return [user['first_name'], user['last_name']].compact.join(' ').presence if user

      user = resolve_user(peer['id'])
      [user['first_name'], user['last_name']].compact.join(' ').presence || "User #{peer['id']}"
    when 'chat'
      conversation.dig('chat_settings', 'title') || "Chat #{peer['local_id']}"
    when 'group'
      "Group #{peer['id']}"
    else
      "VK #{peer['id']}"
    end
  end

  def resolve_user(user_id)
    return @user_cache[user_id] if @user_cache.key?(user_id)

    resp = vk_get('users.get', { user_ids: user_id, fields: 'photo_100' })
    user = resp&.first || {}
    @user_cache[user_id] = user
    user
  end

  def cache_profiles(resp)
    Array(resp['profiles']).each do |profile|
      @user_cache[profile['id']] = profile
    end
  end

  def build_dialog(peer_id, contact_name, messages)
    {
      external_id: "vk_live_#{peer_id}",
      source: 'vk_personal',
      contact_external_id: peer_id.to_s,
      contact_name: contact_name,
      contact_avatar_url: nil,
      title: contact_name,
      messages: messages.filter_map { |m| convert_message(m) }
    }
  end

  def convert_message(msg)
    content = msg['text'].to_s.presence
    content ||= attachment_summary(msg['attachments']) if msg['attachments'].present?
    return nil if content.blank?
    return nil if msg['action'].present?

    {
      external_id: msg['id'].to_s,
      created_at: Time.zone.at(msg['date'].to_i),
      sender_type: msg['from_id'].to_i == @my_user_id ? 'agent' : 'user',
      content: content,
      content_type: 'text'
    }
  end

  def attachment_summary(attachments)
    return nil if attachments.blank?

    attachments.map { |a| "[#{a['type']}]" }.join(' ')
  end

  def compute_date_cutoff(months)
    return nil unless months.to_i.positive?

    months.to_i.months.ago
  end

  def vk_get(method, params)
    response = HTTParty.get(
      "#{VK_API_BASE}/#{method}",
      query: params.merge(access_token: @token, v: VK_API_VERSION)
    )
    return nil unless response.success?

    parsed = response.parsed_response
    if (error = parsed['error'])
      Rails.logger.error "[VkLiveFetcherService] API error in #{method}: #{error['error_msg']} (#{error['error_code']})"
      return nil
    end
    parsed['response']
  end
end
