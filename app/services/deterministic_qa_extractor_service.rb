# frozen_string_literal: true

# DeterministicQaExtractorService
# Извлекает Q-A пары из диалога по правилу:
# последовательность user+... → agent+... = одна пара.
class DeterministicQaExtractorService
  def extract(dialog)
    messages = dialog[:messages]
    pairs = []
    i = 0

    while i < messages.size
      user_msgs = collect_block(messages, i, 'user')
      i += user_msgs.size
      next if user_msgs.empty?

      agent_msgs = collect_block(messages, i, 'agent')
      i += agent_msgs.size
      next if agent_msgs.empty?

      pairs << build_pair(user_msgs, agent_msgs)
    end
    pairs
  end

  private

  def collect_block(messages, start_idx, sender_type)
    block = []
    idx = start_idx
    while idx < messages.size && messages[idx][:sender_type] == sender_type
      block << messages[idx]
      idx += 1
    end
    block
  end

  def build_pair(user_msgs, agent_msgs)
    {
      question: user_msgs.map { |m| m[:content] }.join("\n"),
      answer: agent_msgs.map { |m| m[:content] }.join("\n"),
      resolved: true,
      user_messages_count: user_msgs.size,
      agent_messages_count: agent_msgs.size,
      first_question_at: user_msgs.first[:created_at],
      response_time_seconds: response_time(user_msgs, agent_msgs)
    }
  end

  def response_time(user_msgs, agent_msgs)
    return 0 unless user_msgs.last[:created_at] && agent_msgs.first[:created_at]

    (agent_msgs.first[:created_at] - user_msgs.last[:created_at]).to_i
  end
end
