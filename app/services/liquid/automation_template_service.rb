# Renders automation message content with Liquid variables (contact, conversation, agent, inbox, account).
# Used when sending messages from automation rules so {{ contact.name }}, {{ conversation.display_id }}, etc. work.
class Liquid::AutomationTemplateService
  pattr_initialize [:conversation!]

  def call(message)
    return message if message.blank?

    process_liquid_in_content(message_drops, message)
  end

  private

  def message_drops
    {
      'contact' => ContactDrop.new(conversation.contact),
      'conversation' => ConversationDrop.new(conversation),
      'agent' => UserDrop.new(conversation.assignee),
      'inbox' => InboxDrop.new(conversation.inbox),
      'account' => AccountDrop.new(conversation.account)
    }
  end

  def process_liquid_in_content(drops, message)
    message = message.gsub(/`(.*?)`/m, '{% raw %}`\1`{% endraw %}')
    template = Liquid::Template.parse(message)
    template.render(drops)
  rescue Liquid::Error
    message
  end
end
