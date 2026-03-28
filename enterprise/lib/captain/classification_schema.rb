class Captain::ClassificationSchema < RubyLLM::Schema
  # Structured output schema for automatic conversation classification
  # Used with GLM-5 model for JSON response with predefined fields

  string :department,
         enum: %w[sales support billing technical general],
         description: 'Suggested department for routing'

  string :priority,
         enum: %w[low medium high urgent],
         description: 'Urgency level of the conversation'

  string :sentiment,
         enum: %w[negative neutral positive],
         description: 'Overall customer sentiment'

  string :language,
         description: 'Detected language code (e.g., en, es, fr)'

  array :tags,
        of: :string,
        description: 'Suggested tags for categorization'

  boolean :requires_immediate_response,
          description: 'Whether this conversation needs immediate attention'

  string :suggested_response_template,
         description: 'Suggested FAQ or template ID to respond with'
end
