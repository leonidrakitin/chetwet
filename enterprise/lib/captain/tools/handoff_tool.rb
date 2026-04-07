class Captain::Tools::HandoffTool < Captain::Tools::BasePublicTool
  description 'Use ONLY as a last resort to escalate the conversation to human support. Trigger strictly ' \
              'if the user explicitly demands a human agent or the issue is completely unsolvable here. Do NOT use ' \
              'for approval or quick clarification — use `captain--tools--ask_human` instead.'
  param :reason, type: 'string', desc: 'The reason why human escalation is needed (optional)', required: false
  param :post_reason_as_note, type: 'boolean',
                              desc: 'If false, do not create a private note with the reason ' \
                                    '(use when you already added a note via Add Private Note)',
                              required: false

  def name
    'escalate_to_human'
  end

  def perform(tool_context, reason: nil, post_reason_as_note: true)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    log_tool_usage('tool_human_escalation', {
                     conversation_id: conversation.id,
                     reason: reason || 'Agent requested human escalation'
                   })

    trigger_handoff(conversation, reason, post_reason_as_note)

    "Conversation escalated to human support team#{" (Reason: #{reason})" if reason}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    'Failed to escalate conversation to human support'
  end

  private

  def trigger_handoff(conversation, reason, post_reason_as_note)
    if post_reason_as_note && reason.present?
      conversation.messages.create!(
        message_type: :outgoing,
        private: true,
        sender: @assistant,
        account: conversation.account,
        inbox: conversation.inbox,
        content: reason
      )
    end

    # Trigger the bot handoff (sets status to open + dispatches events)
    conversation.bot_handoff!

    # Send out of office message if applicable (since template messages were suppressed while Captain was handling)
    send_out_of_office_message_if_applicable(conversation)
  end

  def send_out_of_office_message_if_applicable(conversation)
    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  # TODO: Future enhancement - Add team assignment capability
  # This tool could be enhanced to:
  # 1. Accept team_id parameter for routing to specific teams
  # 2. Set conversation priority based on handoff reason
  # 3. Add metadata for intelligent agent assignment
  # 4. Support escalation levels (L1 -> L2 -> L3)
  #
  # Example future signature:
  # param :team_id, type: 'string', desc: 'ID of team to assign conversation to', required: false
  # param :priority, type: 'string', desc: 'Priority level (low/medium/high/urgent)', required: false
  # param :escalation_level, type: 'string', desc: 'Support level (L1/L2/L3)', required: false
end
