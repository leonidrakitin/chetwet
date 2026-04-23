class Captain::Copilot::ResponseJob < ApplicationJob
  queue_as :default

  def perform(assistant:, conversation_id:, user_id:, copilot_thread_id:, message:)
    Rails.logger.info("#{self.class.name} Copilot response job for assistant_id=#{assistant.id} user_id=#{user_id}")
    generate_chat_response(
      assistant: assistant,
      conversation_id: conversation_id,
      user_id: user_id,
      copilot_thread_id: copilot_thread_id,
      message: message
    )
  end

  private

  def generate_chat_response(assistant:, conversation_id:, user_id:, copilot_thread_id:, message:)
    conversation = @account.conversations.find_by(display_id: conversation_id)

    copilot_thread = if copilot_thread_id.present?
                       @account.copilot_threads.find(copilot_thread_id)
                     elsif conversation.present?
                       conversation.copilot_thread || conversation.create_copilot_thread(
                         title: "Copilot: #{conversation.display_id}",
                         user_id: user_id,
                         assistant: assistant,
                         source: 'conversation'
                       )
                     else
                       @account.copilot_threads.create!(
                         title: "Copilot: #{Time.current.to_i}",
                         user_id: user_id,
                         assistant: assistant,
                         source: 'default'
                       )
                     end

    service = Captain::Copilot::ChatService.new(
      assistant,
      user_id: user_id,
      copilot_thread_id: copilot_thread.id,
      conversation_id: conversation_id
    )
    service.generate_response(message)
  end
end
