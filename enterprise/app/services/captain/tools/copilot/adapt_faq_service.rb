class Captain::Tools::Copilot::AdaptFaqService < Captain::Tools::BaseTool
  description 'Adapt an existing FAQ to better fit the business context. Takes an FAQ ID and customizes the question and/or answer based on the business type and description.'

  param :faq_id, type: :number, desc: 'The ID of the FAQ to adapt', required: true
  param :adaptation_hints, type: :object, desc: 'Optional hints for adaptation (e.g., tone, specific details to include)', required: false

  def execute(faq_id:, adaptation_hints: {})
    business_context = @assistant.account.settings['business_context']

    return { error: 'No business context set. Please configure business context in Account Settings first.' }.to_json if business_context.blank?

    faq = Captain::AssistantResponse.find_by(id: faq_id, account_id: @assistant.account_id)

    return { error: "FAQ with ID #{faq_id} not found" }.to_json if faq.nil?

    adapted = adapt_faq(faq, business_context, adaptation_hints)

    {
      original: {
        id: faq.id,
        question: faq.question,
        answer: faq.answer
      },
      adapted: adapted,
      message: 'FAQ adapted. To apply changes, update the FAQ in the Captain Assistant settings.'
    }.to_json
  end

  def active?
    user_has_permission('administrator')
  end

  private

  def adapt_faq(faq, business_context, hints)
    business_context['business_type']
    description = business_context['description']

    adapted_question = faq.question.dup
    adapted_answer = faq.answer.dup

    if description.present?
      adapted_question = adapt_for_business(adapted_question, description)
      adapted_answer = adapt_for_business(adapted_answer, description)
    end

    adapted_answer = adjust_tone(adapted_answer, hints['tone']) if hints['tone'].present?

    adapted_answer = "#{adapted_answer} #{hints['details']}" if hints['details'].present?

    {
      question: adapted_question,
      answer: adapted_answer
    }
  end

  def adapt_for_business(text, business_description)
    text.gsub(/\[.*?\]/, business_description)
        .gsub(/\b(salon|restaurant|company|business)\b/i, business_description)
  end

  def adjust_tone(text, tone)
    case tone.downcase
    when 'formal'
      text.gsub(/we're/i, 'we are')
          .gsub(/can't/i, 'cannot')
          .gsub(/won't/i, 'will not')
    when 'casual'
      text.gsub(/We are/i, "We're")
          .gsub(/You can/i, 'You can')
    else
      text
    end
  end
end
