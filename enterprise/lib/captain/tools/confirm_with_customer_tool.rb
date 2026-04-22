# frozen_string_literal: true

# Dry-run confirmation tool. Must be called before any :critical write
# (booking, cancellation, refund...). Stores the intended tool + args in
# runtime state and instructs the assistant to present a short summary to
# the customer. On the NEXT customer turn, the assistant reads
# `pending_customer_confirm` from orchestration state and either invokes
# the stored tool (on "yes") or aborts (on "no").
class Captain::Tools::ConfirmWithCustomerTool < Captain::Tools::BasePublicTool
  risk_level :read

  description 'Ask the customer for yes/no confirmation before executing a write/critical action. ' \
              'Stores the intended tool+args in runtime state; the agent invokes the stored tool ' \
              'on the next turn only when the customer explicitly confirms.'

  param :summary, type: 'string',
                  desc: 'Short human-readable summary to show the customer (e.g. "Book with Ivanova on Apr 25 16:00, total 3500₽?")',
                  required: true
  param :on_confirm_tool, type: 'string',
                          desc: 'Tool name to invoke when the user confirms (e.g. "booking_book_appointment")',
                          required: true
  param :on_confirm_args, type: 'object',
                          desc: 'Hash of arguments to pass to on_confirm_tool on confirmation',
                          required: true

  def perform(tool_context, summary:, on_confirm_tool:, on_confirm_args:)
    conversation = find_conversation(tool_context.state)
    return { status: 'error', error: 'Conversation not found' } unless conversation

    pending = {
      'summary' => summary.to_s,
      'on_confirm_tool' => on_confirm_tool.to_s,
      'on_confirm_args' => on_confirm_args.is_a?(Hash) ? on_confirm_args : {},
      'created_at' => Time.current.iso8601,
      'expires_at' => 1.hour.from_now.iso8601
    }

    Captain::RuntimeStateService.new(conversation).update_state('pending_customer_confirm' => pending)
    orchestration = (tool_context.state[:orchestration] ||= {})
    orchestration['pending_customer_confirm'] = pending

    log_tool_usage('confirm_with_customer', { conversation_id: conversation.id, tool: on_confirm_tool })

    {
      status: 'pending_confirmation',
      summary: summary,
      instruction: "Respond to the customer with exactly this summary and ask for yes/no: \"#{summary}\". " \
                   'Do NOT call the target tool now — wait for their reply on the next turn.'
    }
  end
end
