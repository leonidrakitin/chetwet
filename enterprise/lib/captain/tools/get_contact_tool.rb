class Captain::Tools::GetContactTool < Captain::Tools::BasePublicTool
  description 'Get full contact profile including name, email, phone, custom attributes, and conversation history summary'
  param :contact_id, type: 'integer', desc: 'Contact ID (optional, defaults to current conversation contact)', required: false

  def perform(tool_context, contact_id: nil)
    contact = if contact_id.present?
                account_scoped(::Contact).find_by(id: contact_id)
              else
                find_contact(tool_context.state)
              end

    return 'Contact not found' unless contact

    log_tool_usage('get_contact', { contact_id: contact.id })

    format_contact(contact)
  end

  private

  def format_contact(contact)
    parts = []
    parts << "Name: #{contact.name}" if contact.name.present?
    parts << "Email: #{contact.email}" if contact.email.present?
    parts << "Phone: #{contact.phone_number}" if contact.phone_number.present?
    parts << "Type: #{contact.contact_type}" if contact.contact_type.present?
    parts << "Created: #{contact.created_at.strftime('%Y-%m-%d')}"

    conversations = contact.conversations.order(last_activity_at: :desc).limit(5)
    if conversations.any?
      parts << "Recent conversations (#{contact.conversations.count} total):"
      conversations.each do |c|
        parts << "  ##{c.display_id}: #{c.status} (#{c.last_activity_at&.strftime('%Y-%m-%d')})"
      end
    end

    custom_attrs = contact.custom_attributes
    parts << "Custom attributes: #{custom_attrs.map { |k, v| "#{k}=#{v}" }.join(', ')}" if custom_attrs.present?

    parts.join("\n")
  end
end
