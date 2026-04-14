# frozen_string_literal: true

class Captain::Tools::BookingBaseTool < Captain::Tools::BasePublicTool
  def active?
    assistant_account.hooks.exists?(app_id: 'booking_manager', status: :enabled)
  end

  private

  def assistant_account
    @assistant_account ||= Account.find(@assistant.account_id)
  end

  def account
    assistant_account
  end

  def conversation_for(tool_context)
    find_conversation(tool_context.state)
  end

  def contact_for(tool_context)
    find_contact(tool_context.state) || conversation_for(tool_context)&.contact
  end

  def format_result(message, data: nil)
    data ? { message: message, data: data }.to_json : message
  end

  def error_result(message)
    { error: message }.to_json
  end
end
