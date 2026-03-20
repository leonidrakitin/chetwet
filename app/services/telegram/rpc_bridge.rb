# frozen_string_literal: true

# Telegram::RpcBridge
# Sends RPC requests to the TdlibEventWorker via Redis and waits for responses.
# This avoids creating a second TDLib client (which would conflict with the worker's lock).
class Telegram::RpcBridge
  TIMEOUT = 45
  REQUEST_TTL = 60
  MAX_RETRIES = 2

  def initialize(telegram_session)
    @session = telegram_session
  end

  def get_chat_history(chat_id, from_message_id: 0, limit: 50)
    request('getChatHistory', chat_id: chat_id, from_message_id: from_message_id, limit: limit)
  end

  def load_chats(limit: 100)
    request('loadChats', limit: limit)
  end

  def get_chat(chat_id)
    request('getChat', chat_id: chat_id)
  end

  private

  def request(method, params = {})
    request_id = SecureRandom.uuid
    payload = { id: request_id, method: method, params: params }.to_json

    redis { |c| c.rpush(request_key, payload) }
    redis { |c| c.expire(request_key, REQUEST_TTL) }

    retries = 0
    loop do
      response_raw = redis { |c| c.blpop(response_key(request_id), timeout: TIMEOUT) }
      response_json = response_raw&.last

      unless response_json
        retries += 1
        raise Telegram::TdlibError, "RPC timeout for #{method}" if retries > MAX_RETRIES

        redis { |c| c.rpush(request_key, payload) }
        next
      end

      result = JSON.parse(response_json)
      raise Telegram::TdlibError, result['error'] if result['error']

      return result['data']
    end
  end

  def redis(&)
    $alfred.with(&)
  end

  def request_key
    "telegram_rpc:requests:#{@session.id}"
  end

  def response_key(request_id)
    "telegram_rpc:response:#{request_id}"
  end
end
