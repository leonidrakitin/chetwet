# frozen_string_literal: true

class ApprovalBot::BaseSenderService
  def send_approval_request(user:, request:)
    raise NotImplementedError
  end

  def send_message(chat_id:, text:, reply_markup: nil)
    raise NotImplementedError
  end

  def edit_message(chat_id:, message_id:, text:, reply_markup: nil)
    raise NotImplementedError
  end

  def mark_resolved(request:, resolved_label:)
    raise NotImplementedError
  end

  def agent_reachable?(user)
    raise NotImplementedError
  end
end
