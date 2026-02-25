class BotMessageBufferJob < ApplicationJob
  queue_as :high

  def perform(conversation_id, bot_type, bot_id, token)
    buffer = BotMessageBufferService.new(conversation_id, bot_type, bot_id)
    return unless buffer.valid_token?(token)

    messages = buffer.flush_messages
    return if messages.empty?

    dispatch(conversation_id, bot_type, bot_id, messages)
  end

  private

  def dispatch(conversation_id, bot_type, bot_id, messages)
    case bot_type
    when 'agent_bot'
      dispatch_to_agent_bot(bot_id, messages)
    when 'dialogflow'
      dispatch_to_dialogflow(bot_id, messages)
    when 'captain'
      dispatch_to_captain(conversation_id)
    end
  end

  def dispatch_to_agent_bot(bot_id, messages)
    agent_bot = AgentBot.find_by(id: bot_id)
    return if agent_bot.nil? || agent_bot.outgoing_url.blank?

    last_message = messages.last
    payload = last_message.webhook_data.merge(
      event: 'message_created',
      messages: messages.map { |m| { id: m.id, content: m.content, created_at: m.created_at } }
    )
    AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload)
  end

  def dispatch_to_dialogflow(hook_id, messages)
    hook = Integrations::Hook.find_by(id: hook_id)
    return if hook.nil?

    HookJob.perform_later(hook, 'message.created', message: messages.last)
  end

  def dispatch_to_captain(_conversation_id)
    # Overridden in Enterprise module
  end
end

BotMessageBufferJob.prepend_mod_with('BotMessageBufferJob')
