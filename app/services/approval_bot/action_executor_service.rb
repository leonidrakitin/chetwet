# frozen_string_literal: true

class ApprovalBot::ActionExecutorService
  def initialize(approval_request)
    @request = approval_request
  end

  def execute
    option = resolved_option
    return unless option

    dispatch_action(option)
    schedule_follow_up
  end

  private

  def resolved_option
    option = @request.selected_option
    return option if option

    # free_text variant: last option with type free_text
    free_text_option = @request.options.map(&:with_indifferent_access).find { |o| o[:action_type] == 'free_text' }
    free_text_option&.merge(label: @request.custom_response)
  end

  def dispatch_action(option)
    case option[:action_type]
    when 'reply_to_customer'
      send_reply(option.dig(:action_payload, :content) || @request.custom_response)
    when 'free_text'
      send_reply(@request.custom_response)
    when 'external_api_call'
      call_external_api(option[:action_payload])
    when 'resume_captain'
      resume_captain(option[:action_payload])
    end
  rescue StandardError => e
    Rails.logger.error("[ApprovalBot] ActionExecutor failed for request #{@request.id}: #{e.message}")
  end

  def send_reply(content)
    return if content.blank?

    conversation.messages.create!(
      content: content,
      message_type: :outgoing,
      account_id: @request.account_id,
      inbox_id: conversation.inbox_id,
      sender: @request.resolved_by
    )
  end

  def call_external_api(payload)
    return if payload.blank?

    url = payload['url'] || payload[:url]
    return if url.blank?

    Webhooks::Trigger.execute(url, webhook_payload, :approval_bot)
  end

  def resume_captain(payload)
    instruction = payload&.dig('instruction') || payload&.dig(:instruction)
    return if instruction.blank?

    conversation.messages.create!(
      content: "[Operator instruction: #{instruction}]",
      message_type: :activity,
      account_id: @request.account_id,
      inbox_id: conversation.inbox_id
    )
  rescue StandardError => e
    Rails.logger.warn("[ApprovalBot] Failed to resume captain for request #{@request.id}: #{e.message}")
  end

  def schedule_follow_up
    ApprovalBot::FollowUpNotifyJob.set(wait: 1.minute).perform_later(@request)
  end

  def webhook_payload
    {
      approval_request_id: @request.id,
      conversation_id: @request.conversation_id,
      account_id: @request.account_id,
      selected_option: @request.selected_option,
      custom_response: @request.custom_response,
      resolved_by: @request.resolved_by&.email
    }
  end

  def conversation
    @conversation ||= @request.conversation
  end
end
