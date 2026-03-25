class Captain::ClassificationSchema < RubyLLM::Schema
  # Structured output schema for automatic conversation classification
  # Used with GLM-5 model for JSON response with predefined fields

  property :department,
           type: 'string',
           enum: %w[sales support billing technical general],
           description: 'Suggested department for routing'

  property :priority,
           type: 'string',
           enum: %w[low medium high urgent],
           description: 'Urgency level of the conversation'

  property :sentiment,
           type: 'string',
           enum: %w[negative neutral positive],
           description: 'Overall customer sentiment'

  property :language,
           type: 'string',
           description: 'Detected language code (e.g., en, es, fr)'

  property :tags,
           type: 'array',
           items: { type: 'string' },
           description: 'Suggested tags for categorization'

  property :requires_immediate_response,
           type: 'boolean',
           description: 'Whether this conversation needs immediate attention'

  property :suggested_response_template,
           type: 'string',
           description: 'Suggested FAQ or template ID to respond with'
end
