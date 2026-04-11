# frozen_string_literal: true

require 'ruby_llm'

class Captain::Tools::BaseTool < RubyLLM::Tool
  include Captain::ToolInstrumentation

  attr_reader :account, :conversation, :contact

  def initialize(account:, conversation: nil, contact: nil)
    @account = account
    @conversation = conversation
    @contact = contact || conversation&.contact
    super()
  end

  def active?
    @account.present?
  end

  private

  def format_result(message, data: nil)
    data ? { message: message, data: data }.to_json : message
  end

  def error_result(message)
    { error: message }.to_json
  end
end
