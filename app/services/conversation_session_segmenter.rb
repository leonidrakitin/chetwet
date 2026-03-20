# frozen_string_literal: true

class ConversationSessionSegmenter
  DEFAULT_GAP_MINUTES = 120

  def initialize(gap_minutes: DEFAULT_GAP_MINUTES)
    @gap = gap_minutes.minutes
  end

  def segment(dialogs)
    dialogs.flat_map { |dialog| split_into_sessions(dialog) }
  end

  private

  def split_into_sessions(dialog)
    messages = dialog[:messages].sort_by { |m| m[:created_at] }
    return [dialog] if messages.size < 2

    sessions = []
    current = [messages.first]

    messages.each_cons(2) do |prev, curr|
      if (curr[:created_at] - prev[:created_at]) > @gap
        sessions << session_dialog(dialog, current, sessions.size)
        current = [curr]
      else
        current << curr
      end
    end
    sessions << session_dialog(dialog, current, sessions.size)
  end

  def session_dialog(original, msgs, index)
    original.merge(
      external_id: "#{original[:external_id]}_s#{index}",
      messages: msgs,
      session_metadata: {
        session_index: index,
        duration_seconds: (msgs.last[:created_at] - msgs.first[:created_at]).to_i,
        message_count: msgs.size
      }
    )
  end
end
