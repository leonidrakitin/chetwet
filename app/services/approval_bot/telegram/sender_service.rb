# frozen_string_literal: true

class ApprovalBot::Telegram::SenderService < ApprovalBot::BaseSenderService
  FREE_TEXT_INDEX = 'free_text'
  SUMMARY_CALLBACK = 'summary'

  def initialize(config:)
    super()
    @config = config
  end

  def agent_reachable?(user)
    user.telegram_chat_id.present?
  end

  def send_approval_request(user:, request:)
    keyboard = build_keyboard(request)
    text = format_request_message(request)
    response = post_message(chat_id: user.telegram_chat_id, text: text, reply_markup: keyboard)
    return unless response.success?

    message_id = response.parsed_response.dig('result', 'message_id')&.to_s
    request.update_columns(messenger_message_id: message_id, messenger_type: 'telegram')
  end

  def send_message(chat_id:, text:, reply_markup: nil)
    post_message(chat_id: chat_id, text: text, reply_markup: reply_markup&.to_json)
  end

  def edit_message(chat_id:, message_id:, text:, reply_markup: nil)
    body = { chat_id: chat_id, message_id: message_id, text: text, parse_mode: 'HTML' }
    body[:reply_markup] = reply_markup.to_json if reply_markup
    HTTParty.post("#{api_url}/editMessageText", body: body)
  end

  def mark_resolved(request:, resolved_label:)
    return if request.messenger_message_id.blank?

    text = "#{format_request_message(request)}\n\n<b>✓ #{resolved_label}</b>"
    request.target_users.each do |user|
      edit_message(
        chat_id: user.telegram_chat_id,
        message_id: request.messenger_message_id,
        text: text
      )
    end
  end

  def answer_callback(callback_query_id, text: nil)
    HTTParty.post(
      "#{api_url}/answerCallbackQuery",
      body: { callback_query_id: callback_query_id, text: text }.compact
    )
  end

  private

  def build_keyboard(request)
    buttons = request.options.each_with_index.map do |option, index|
      option = option.with_indifferent_access
      callback_data = option[:action_type] == 'free_text' ? "appr::#{request.id}::#{FREE_TEXT_INDEX}" : "appr::#{request.id}::#{index}"
      [{ text: option[:label], callback_data: callback_data }]
    end
    { inline_keyboard: buttons }.to_json
  end

  def format_request_message(request)
    parts = ['📋 <b>Запрос согласования</b>']

    if request.context.present?
      parts << "\n🗣️ <b>Контекст:</b>"
      parts << request.context.truncate(300)
    end

    parts << "\n❓ #{request.title}"
    parts.join("\n")
  end

  def post_message(chat_id:, text:, reply_markup: nil)
    body = { chat_id: chat_id, text: text, parse_mode: 'HTML' }
    body[:reply_markup] = reply_markup if reply_markup
    HTTParty.post("#{api_url}/sendMessage", body: body)
  end

  def api_url
    "https://api.telegram.org/bot#{@config.bot_token}"
  end
end
