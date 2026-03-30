# frozen_string_literal: true

class ApprovalBot::Telegram::AccountLinkerService
  include Redis::RedisKeys

  LINK_TTL = 1800 # 30 minutes

  def initialize(config:, sender:)
    @config = config
    @sender = sender
  end

  def handle_start(chat_id, token)
    key = format(APPROVAL_BOT_LINK_TOKEN, token: token)
    data = Redis::Alfred.get(key)

    if data.blank?
      @sender.send_message(chat_id: chat_id, text: 'Link expired. Please generate a new one.')
      return
    end

    Redis::Alfred.set(awaiting_key(chat_id), "link::#{token}", ex: LINK_TTL)
    @sender.send_message(chat_id: chat_id, text: 'Please share your phone number to connect your account.', reply_markup: phone_keyboard)
  end

  def handle_contact(chat_id)
    stored = Redis::Alfred.get(awaiting_key(chat_id))
    return false unless stored.to_s.start_with?('link::')

    token = stored.sub('link::', '')
    key = format(APPROVAL_BOT_LINK_TOKEN, token: token)
    data = Redis::Alfred.get(key)

    if data.blank?
      @sender.send_message(chat_id: chat_id, text: 'Link expired. Please generate a new one.')
      return true
    end

    user = find_user(data)
    unless user
      @sender.send_message(chat_id: chat_id, text: 'User not found.')
      return true
    end

    user.update!(telegram_chat_id: chat_id)
    Redis::Alfred.delete(awaiting_key(chat_id))
    Redis::Alfred.delete(key)

    @sender.send_message(chat_id: chat_id, text: "Connected as #{user.name}!", reply_markup: remove_keyboard)
    true
  end

  private

  def find_user(data)
    parsed = JSON.parse(data)
    User.joins(:account_users)
        .where(account_users: { account_id: parsed['account_id'] })
        .find_by(id: parsed['user_id'])
  end

  def awaiting_key(chat_id)
    "APPROVAL_BOT::LINK_AWAIT::#{chat_id}"
  end

  def phone_keyboard
    {
      keyboard: [[{ text: "\xF0\x9F\x93\x9E Share phone number", request_contact: true }]],
      one_time_keyboard: true,
      resize_keyboard: true
    }.to_json
  end

  def remove_keyboard
    { remove_keyboard: true }.to_json
  end
end
