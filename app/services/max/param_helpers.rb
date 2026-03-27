# frozen_string_literal: true

module Max::ParamHelpers
  def update_type
    params[:update_type]
  end

  def message_created?
    update_type == 'message_created'
  end

  def message_callback?
    update_type == 'message_callback'
  end

  def bot_started?
    update_type == 'bot_started'
  end

  def max_params_from_id
    if message_callback?
      params.dig(:callback, :user, :user_id)
    elsif bot_started?
      params.dig(:user, :user_id)
    else
      params.dig(:message, :sender, :user_id)
    end
  end

  def max_params_sender_name
    first_name, last_name = if message_callback?
                              [params.dig(:callback, :user, :first_name), params.dig(:callback, :user, :last_name)]
                            elsif bot_started?
                              [params.dig(:user, :first_name), params.dig(:user, :last_name)]
                            else
                              [params.dig(:message, :sender, :first_name), params.dig(:message, :sender, :last_name)]
                            end
    [first_name, last_name].compact.join(' ').presence
  end

  def max_params_sender_username
    if message_callback?
      params.dig(:callback, :user, :username)
    elsif bot_started?
      params.dig(:user, :username)
    else
      params.dig(:message, :sender, :username)
    end
  end

  def max_params_message_id
    if message_callback?
      params.dig(:callback, :callback_id)
    else
      params.dig(:message, :body, :mid)
    end
  end

  def max_params_message_content
    if message_callback?
      params.dig(:callback, :payload)
    elsif bot_started?
      nil
    else
      params.dig(:message, :body, :text)
    end
  end

  def max_params_chat_id
    return params[:chat_id] if bot_started?

    params.dig(:message, :recipient, :chat_id) || max_params_from_id
  end

  def max_params_attachments
    return [] unless message_created?

    params.dig(:message, :body, :attachments) || []
  end
end
