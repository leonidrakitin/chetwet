class Captain::Tools::Copilot::SuggestFaqsService < Captain::Tools::BaseTool
  description 'Suggest new FAQs based on the business context. Analyzes the account business type and description to generate relevant FAQ suggestions.'

  param :count, type: :number, desc: 'Number of FAQ suggestions to generate (default: 5)', required: false

  def execute(count: 5)
    business_context = @assistant.account.settings['business_context']

    return { error: 'No business context set. Please configure business context in Account Settings first.' }.to_json if business_context.blank?

    existing_questions = @assistant.account.captain_assistants
                                   .flat_map(&:responses)
                                   .pluck(:question)
                                   .map(&:downcase)

    suggestions = generate_faq_suggestions(business_context, existing_questions, count)

    {
      business_context: business_context,
      suggestions: suggestions,
      message: "Generated #{suggestions.length} FAQ suggestions based on your business context. Use 'adapt_faq' to adapt existing FAQs."
    }.to_json
  end

  def active?
    user_has_permission('administrator')
  end

  private

  def generate_faq_suggestions(business_context, existing_questions, count)
    business_type = business_context['business_type']
    description = business_context['description']

    suggestions_by_type = {
      'support' => [
        { q: 'How do I reset my password?',
          a: 'You can reset your password by clicking "Forgot Password" on the login page and following the instructions sent to your email.' },
        { q: 'What are your support hours?', a: 'Our support team is available [hours]. You can reach us via [channels].' },
        { q: 'How long does it take to get a response?',
          a: 'We typically respond within [response time]. Priority support customers receive faster responses.' },
        { q: 'Can I escalate my ticket?', a: 'Yes, you can request escalation by replying to your ticket or contacting our support team directly.' },
        { q: 'Where can I find documentation?', a: 'Our documentation is available at [docs URL]. You can also search within the help center.' }
      ],
      'sales' => [
        { q: 'What are your pricing plans?', a: 'We offer several pricing tiers: [plans]. Each plan includes different features and usage limits.' },
        { q: 'Do you offer a free trial?', a: 'Yes, we offer a [duration] free trial. No credit card required to start.' },
        { q: 'Can I get a demo?', a: 'Absolutely! You can schedule a demo at [scheduling link] or contact our sales team directly.' },
        { q: 'Do you offer discounts for annual billing?', a: 'Yes, annual billing includes a [discount]% discount compared to monthly billing.' },
        { q: 'What payment methods do you accept?', a: 'We accept major credit cards, PayPal, and bank transfers for enterprise customers.' }
      ],
      'ecommerce' => [
        { q: 'What are your shipping options?',
          a: 'We offer standard, express, and overnight shipping. Free shipping is available for orders over [amount].' },
        { q: 'What is your return policy?',
          a: 'You can return items within [days] days of delivery. Items must be unused and in original packaging.' },
        { q: 'How can I track my order?',
          a: 'Once your order ships, you will receive a tracking number via email. You can also check status in your account.' },
        { q: 'Do you ship internationally?', a: 'Yes, we ship to [countries/regions]. International shipping rates and times vary by location.' },
        { q: 'Can I change or cancel my order?',
          a: 'You can modify or cancel your order within [hours] of placing it. Contact support for assistance.' }
      ]
    }

    suggestions = suggestions_by_type[business_type] || suggestions_by_type['support']

    suggestions
      .reject { |s| existing_questions.any? { |eq| eq.include?(s[:q].downcase) } }
      .take(count)
      .map do |s|
        s[:a] = s[:a].gsub(/\[.*?\]/, description || 'our business')
        s
      end
  end
end
