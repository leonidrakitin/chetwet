# frozen_string_literal: true

# Shared tone + emoji instructions for Captain V1 (system prompt) and V2 (merged response guidelines).
module Captain::AssistantPromptExtras
  VALID_TONES = %w[formal neutral friendly].freeze
  MAX_ALLOWED_EMOJIS = 10

  module_function

  def normalize_allowed_emojis(raw)
    return [] if raw.blank?

    items = Array(raw).flat_map do |entry|
      next [] if entry.nil?

      entry.to_s.grapheme_clusters
    end

    items.select { |grapheme| emoji_grapheme?(grapheme) }.uniq.take(MAX_ALLOWED_EMOJIS)
  end

  def emoji_grapheme?(grapheme)
    return false if grapheme.blank?

    grapheme.match?(/\p{Extended_Pictographic}/)
  end

  def sanitize_config_hash(config)
    return {} if config.blank?

    h = config.stringify_keys
    if h.key?('tone')
      t = h['tone'].to_s
      h['tone'] = VALID_TONES.include?(t) ? t : 'neutral'
    end
    h['emojify'] = ActiveModel::Type::Boolean.new.cast(h['emojify']) if h.key?('emojify')
    h['allowed_emojis'] = normalize_allowed_emojis(h['allowed_emojis']) if h.key?('allowed_emojis')
    h
  end

  # English lines appended to the V1 system prompt (after core response guidelines).
  def prompt_suffix_for_config(config)
    cfg = config.is_a?(Hash) ? config.stringify_keys : {}
    tone = (cfg['tone'].presence || 'neutral')
    lines = [tone_line_v1(tone)]
    lines.concat(emoji_lines_v1(cfg))

    "#{lines.join("\n")}\n"
  end

  def tone_line_v1(tone)
    case tone.to_s
    when 'formal'
      '- Response tone: Use a formal, professional register. Avoid slang and overly casual phrasing.'
    when 'friendly'
      '- Response tone: Use a warm, friendly, conversational style while staying helpful and on-topic.'
    else
      '- Response tone: Use a balanced, neutral tone—clear and polite without being stiff or overly casual.'
    end
  end

  def emoji_lines_v1(cfg)
    emojify = ActiveModel::Type::Boolean.new.cast(cfg['emojify'])
    allowed = normalize_allowed_emojis(cfg['allowed_emojis'])

    return ['- Emojis: Do not use emoji characters in your responses.'] unless emojify

    return ['- Emojis: You may use emoji characters sparingly and naturally when it fits the message.'] if allowed.empty?

    list = allowed.join(' ')
    ["- Emojis: Only these emoji characters are allowed in your responses (do not use any other emoji): #{list}"]
  end

  # Plain strings merged into Liquid `response_guidelines` (same semantics as V1).
  def response_guideline_extras_for_config(config)
    cfg = config.is_a?(Hash) ? config.stringify_keys : {}
    tone = (cfg['tone'].presence || 'neutral')
    out = [tone_line_v1(tone).sub(/\A-\s*/, '')]
    out.concat(emoji_lines_v1(cfg).map { |l| l.sub(/\A-\s*/, '') })
    out
  end
end
