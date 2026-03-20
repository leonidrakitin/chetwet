# frozen_string_literal: true

class TelegramLiveFetcherService
  attr_reader :stats

  MESSAGES_PER_PAGE = 100
  CONSECUTIVE_EMPTY_LIMIT = 20

  def initialize(telegram_session, options = {})
    @session = telegram_session
    @options = options.with_indifferent_access
    @my_user_id = telegram_session.telegram_user_id.to_i
    @rpc = Telegram::RpcBridge.new(telegram_session)
    @date_cutoff = compute_date_cutoff(@options[:date_limit_months])
    @stats = { total_chats: 0, processed_chats: 0, skipped_chats: 0,
               total_messages: 0, skipped_by_date: 0 }
  end

  def fetch(&block)
    chat_ids = load_and_collect_chats
    @stats[:total_chats] = chat_ids.size
    dialogs = []

    consecutive_empty = 0
    chat_ids.each_with_index do |chat_id, idx|
      dialog = fetch_chat_dialog(chat_id.to_i)
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
      block&.call(idx + 1, chat_ids.size)
    end
    dialogs
  end

  private

  def load_and_collect_chats
    max = @options[:max_chats] || 500
    (max / 100.0).ceil.times do
      @rpc.load_chats(limit: 100)
    rescue Telegram::TdlibError
      break
    end

    chat_ids = []
    deadline = Time.now + 15.seconds
    while Time.now < deadline
      chat_ids = $alfred.with { |c| c.smembers("telegram_rpc:chats:#{@session.id}") }
      break if chat_ids.any?

      sleep 1
    end
    chat_ids.first(max)
  end

  def fetch_chat_dialog(chat_id)
    chat = @rpc.get_chat(chat_id)
    return nil unless allowed_chat_type?(chat)

    messages = paginate_messages(chat_id)
    return nil if messages.empty?

    build_dialog(chat, messages)
  end

  def allowed_chat_type?(chat)
    type = chat.dig('type', '@type')
    return true if type == 'chatTypePrivate'

    @options[:include_groups] && %w[chatTypeBasicGroup chatTypeSupergroup].include?(type)
  end

  def paginate_messages(chat_id)
    all_messages = []
    from_id = 0
    max = @options[:max_messages_per_chat] || 1000

    loop do
      batch = @rpc.get_chat_history(chat_id, from_message_id: from_id, limit: MESSAGES_PER_PAGE)
      msgs = Array(batch['messages'])
      break if msgs.empty?

      if @date_cutoff
        msgs_in_range = msgs.take_while { |m| Time.zone.at(m['date'].to_i) >= @date_cutoff }
        all_messages.concat(msgs_in_range)
        break if msgs_in_range.size < msgs.size
      else
        all_messages.concat(msgs)
      end

      break if all_messages.size >= max

      from_id = msgs.last['id']
    end

    all_messages.first(max).reverse
  end

  def build_dialog(chat, messages)
    {
      external_id: "tg_live_#{chat['id']}",
      source: 'telegram_personal',
      contact_external_id: chat['id'].to_s,
      contact_name: chat['title'] || 'Unknown',
      contact_avatar_url: nil,
      title: chat['title'],
      messages: messages.filter_map { |m| convert_message(m) }
    }
  end

  def convert_message(msg)
    content = extract_text_content(msg)
    return nil if content.blank?

    {
      external_id: msg['id'].to_s,
      created_at: Time.zone.at(msg['date'].to_i),
      sender_type: resolve_sender_type(msg),
      content: content,
      content_type: 'text'
    }
  end

  def resolve_sender_type(msg)
    sender = msg['sender_id'] || {}
    case sender['@type']
    when 'messageSenderUser'
      sender['user_id'].to_i == @my_user_id ? 'agent' : 'user'
    when 'messageSenderChat'
      'system'
    else
      'user'
    end
  end

  def extract_text_content(msg)
    msg.dig('content', 'text', 'text') ||
      msg.dig('content', 'caption', 'text') ||
      ''
  end

  def compute_date_cutoff(months)
    return nil unless months.to_i.positive?

    months.to_i.months.ago
  end
end
