# frozen_string_literal: true

class Captain::Knowledge::PolicyDecision
  MODES = %w[balanced strict ultra_strict].freeze

  DEFAULT_THRESHOLDS = {
    'balanced' => { answer: 0.55 },
    'strict' => { answer: 0.70 },
    'ultra_strict' => { answer: 0.85 }
  }.freeze

  def initialize(assistant:, search_results:)
    @assistant = assistant
    @results = search_results
    @mode = normalize_mode(@assistant.knowledge_mode)
    @thresholds = load_thresholds
  end

  def decide
    return no_match if @results.empty?

    best = @results.first
    confidence = best.confidence

    if best.requires_operator?
      escalate(best)
    elsif confidence >= @thresholds[:answer]
      answer(best)
    else
      no_match
    end
  end

  private

  def normalize_mode(mode)
    MODES.include?(mode) ? mode : 'balanced'
  end

  def load_thresholds
    defaults = DEFAULT_THRESHOLDS[@mode]

    {
      answer: @assistant.knowledge_answer_threshold.to_f.positive? ? @assistant.knowledge_answer_threshold.to_f : defaults[:answer]
    }
  end

  def answer(best)
    labelled = labelled_sources
    {
      status: 'ok',
      policy: 'answer',
      confidence: best.confidence,
      answer_draft: build_draft(labelled),
      sources: labelled,
      requires_operator: false,
      query: nil
    }
  end

  def escalate(best)
    labelled = labelled_sources
    {
      status: 'ok',
      policy: 'escalate',
      confidence: best.confidence,
      answer_draft: build_draft(labelled),
      sources: labelled,
      requires_operator: true,
      query: nil
    }
  end

  def no_match
    {
      status: 'no_match',
      policy: 'no_match',
      confidence: 0.0,
      answer_draft: nil,
      sources: [],
      requires_operator: false,
      query: nil
    }
  end

  def build_draft(labelled)
    labelled.map { |src| "[#{src[:label]}] #{src[:content]}" }.join("\n\n")
  end

  def labelled_sources
    @results.first(3).each_with_index.map do |result, index|
      {
        label: index + 1,
        title: result.title,
        link: result.source_link,
        content: result.content
      }
    end
  end
end
