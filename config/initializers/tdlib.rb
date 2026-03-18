require 'digest'
require 'fileutils'
require 'json'
require 'securerandom'
require 'tdlib-ruby'

TD.configure do |config|
  config.lib_path = ENV.fetch('TDLIB_LIB_PATH', Rails.root.join('vendor/tdlib').to_s)
  config.encryption_key = ENV.fetch('TDLIB_ENCRYPTION_KEY', Rails.application.secret_key_base)
  config.client.use_test_dc = ActiveModel::Type::Boolean.new.cast(ENV.fetch('TDLIB_USE_TEST_DC', false))
  config.client.use_file_database = true
  config.client.use_chat_info_database = true
  config.client.use_message_database = true
  config.client.use_secret_chats = false
  config.client.enable_storage_optimizer = true
  config.client.system_language_code = 'en'
  config.client.device_model = 'Chatwoot TDLib'
  config.client.system_version = RUBY_PLATFORM
  config.client.application_version = ENV.fetch('CHATWOOT_VERSION', 'development')
end

TD::Api.set_log_verbosity_level(1) if defined?(TD::Api)

module Telegram
  class TdlibError < StandardError; end
  class RateLimitError < TdlibError; end

  module TdlibConfig
    module_function

    def base_directory
      Rails.root.join('tmp', 'tdlib')
    end

    def database_directory(session)
      base_directory.join(session.directory_key, 'db')
    end

    def files_directory(session)
      base_directory.join(session.directory_key, 'files')
    end

    def ensure_directories!(session)
      [database_directory(session), files_directory(session)].each do |path|
        FileUtils.mkdir_p(path)
      end
    end

    def client_options(session)
      ensure_directories!(session)

      {
        api_id: session.api_id.to_i,
        api_hash: session.api_hash.to_s,
        database_directory: database_directory(session).to_s,
        files_directory: files_directory(session).to_s,
        encryption_key: tdlib_database_key(session)
      }
    end

    def encryptor
      secret = ENV.fetch('TDLIB_SESSION_ENCRYPTION_KEY', Rails.application.secret_key_base)
      salt = ENV.fetch('TDLIB_SESSION_ENCRYPTION_SALT', 'telegram-session-data')
      key = ActiveSupport::KeyGenerator.new(secret).generate_key(salt, ActiveSupport::MessageEncryptor.key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm', serializer: JSON)
    end

    def tdlib_database_key(session)
      Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:telegram:#{session.directory_key}")
    end
  end

  class Client
    AUTH_STATES = {
      'authorizationStateWaitTdlibParameters' => :wait_tdlib_parameters,
      'authorizationStateWaitPhoneNumber' => :wait_phone_number,
      'authorizationStateWaitCode' => :wait_code,
      'authorizationStateWaitPassword' => :wait_password,
      'authorizationStateReady' => :ready,
      'authorizationStateClosing' => :closing,
      'authorizationStateClosed' => :closed,
      'authorizationStateLoggingOut' => :logging_out
    }.freeze

    def initialize(session)
      @session = session
      @client = TD::Client.new(**TdlibConfig.client_options(session))
      @client.connect if @client.respond_to?(:connect)
    rescue StandardError => e
      raise map_error(e)
    end

    def on(update_type, &block)
      client.on(update_type) do |payload|
        block.call(normalize(payload))
      end
    end

    def authorization_state
      request('getAuthorizationState')
    end

    def normalized_authorization_state(payload = authorization_state)
      AUTH_STATES[dig_type(payload, 'authorization_state')] || :unknown
    end

    def set_phone_number(phone_number)
      request('setAuthenticationPhoneNumber', phone_number: phone_number, settings: nil)
    end

    def check_code(code)
      request('checkAuthenticationCode', code: code)
    end

    def check_password(password)
      request('checkAuthenticationPassword', password: password)
    end

    def get_me
      request('getMe')
    end

    def get_chat(chat_id)
      request('getChat', chat_id: chat_id)
    end

    def get_user(user_id)
      request('getUser', user_id: user_id)
    end

    def get_chat_history(chat_id, from_message_id: 0, limit: 50)
      request('getChatHistory', chat_id: chat_id, from_message_id: from_message_id, offset: 0, limit: limit, only_local: false)
    end

    def load_chats(limit: 50)
      request('loadChats', chat_list: { '@type' => 'chatListMain' }, limit: limit)
    end

    def delete_messages(chat_id, message_ids)
      request('deleteMessages', chat_id: chat_id, message_ids: Array(message_ids), revoke: false)
    end

    def edit_message_text(chat_id, message_id, formatted_text)
      request(
        'editMessageText',
        chat_id: chat_id,
        message_id: message_id,
        input_message_content: {
          '@type' => 'inputMessageText',
          text: formatted_text,
          link_preview_options: { '@type' => 'linkPreviewOptions', is_disabled: false },
          clear_draft: false
        }
      )
    end

    def download_file(file_id, priority: 32, synchronous: true)
      request('downloadFile', file_id: file_id, priority: priority, offset: 0, limit: 0, synchronous: synchronous)
    end

    def send_text_message(chat_id:, formatted_text:, reply_to_message_id: nil)
      request(
        'sendMessage',
        chat_id: chat_id,
        reply_to: reply_to_payload(reply_to_message_id),
        options: { '@type' => 'messageSendOptions', disable_notification: false, from_background: true },
        input_message_content: {
          '@type' => 'inputMessageText',
          text: formatted_text,
          link_preview_options: { '@type' => 'linkPreviewOptions', is_disabled: false },
          clear_draft: false
        }
      )
    end

    def send_document(chat_id:, file_path:, caption:, reply_to_message_id: nil)
      request(
        'sendMessage',
        chat_id: chat_id,
        reply_to: reply_to_payload(reply_to_message_id),
        options: { '@type' => 'messageSendOptions', disable_notification: false, from_background: true },
        input_message_content: {
          '@type' => 'inputMessageDocument',
          document: { '@type' => 'inputFileLocal', path: file_path },
          caption: caption
        }
      )
    end

    def send_photo(chat_id:, file_path:, caption:, reply_to_message_id: nil)
      request(
        'sendMessage',
        chat_id: chat_id,
        reply_to: reply_to_payload(reply_to_message_id),
        options: { '@type' => 'messageSendOptions', disable_notification: false, from_background: true },
        input_message_content: {
          '@type' => 'inputMessagePhoto',
          photo: { '@type' => 'inputFileLocal', path: file_path },
          caption: caption
        }
      )
    end

    def send_voice_note(chat_id:, file_path:, caption:, reply_to_message_id: nil)
      request(
        'sendMessage',
        chat_id: chat_id,
        reply_to: reply_to_payload(reply_to_message_id),
        options: { '@type' => 'messageSendOptions', disable_notification: false, from_background: true },
        input_message_content: {
          '@type' => 'inputMessageVoiceNote',
          voice_note: { '@type' => 'inputFileLocal', path: file_path },
          caption: caption
        }
      )
    end

    def close
      client.close if client.respond_to?(:close)
    rescue StandardError
      client.dispose if client.respond_to?(:dispose)
    ensure
      client.dispose if client.respond_to?(:dispose)
    end

    def wait_for_state(*states, timeout: 25)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      loop do
        current_state = normalized_authorization_state
        return current_state if states.include?(current_state)

        raise TdlibError, "TDLib state timeout: #{current_state}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.2
      end
    end

    private

    attr_reader :client

    def request(type, payload = {})
      normalize(client.broadcast_and_receive(payload.merge('@type' => type)))
    rescue StandardError => e
      raise map_error(e)
    end

    def normalize(payload)
      return payload.deep_stringify_keys if payload.is_a?(Hash)
      return payload.to_h.deep_stringify_keys if payload.respond_to?(:to_h)
      return JSON.parse(payload.to_json) if payload.respond_to?(:to_json)

      {}
    rescue JSON::ParserError
      {}
    end

    def map_error(error)
      return error if error.is_a?(TdlibError)

      message = error.respond_to?(:message) ? error.message : error.to_s
      return RateLimitError.new(message) if message.match?(/too many requests/i)

      TdlibError.new(message)
    end

    def dig_type(payload, *path)
      value = payload.dig(*path)
      return value['@type'] if value.is_a?(Hash)

      value.to_s
    end

    def reply_to_payload(reply_to_message_id)
      return nil if reply_to_message_id.blank?

      {
        '@type' => 'inputMessageReplyToMessage',
        message_id: reply_to_message_id.to_i
      }
    end
  end
end
