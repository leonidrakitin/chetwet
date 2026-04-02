class Captain::Tools::Copilot::CreateSegmentService < Captain::Tools::BaseTool
  def self.name
    'create_segment'
  end

  description 'Create a contact segment (saved filter) from a natural language description. ' \
              'Translates the description into filter conditions and saves as a CustomFilter.'

  param :name,        type: :string, desc: 'Name for the segment',                                                    required: true
  param :description, type: :string, desc: 'Natural language description of the segment, e.g. "clients inactive for 30+ days"', required: true

  def execute(name:, description:)
    return 'Access denied: only administrators can create segments' unless user_is_administrator?

    query = generate_filter_query(description)
    return 'Could not generate filter conditions from the description. Please try a more specific description.' if query.blank?

    segment = CustomFilter.new(
      name: name,
      filter_type: :contact,
      query: query,
      account_id: @assistant.account_id,
      user_id: @user&.id
    )

    if segment.save
      "Segment created successfully. ID: #{segment.id}, Name: #{segment.name}. " \
        "Filter conditions: #{segment.query.to_json}"
    else
      "Failed to create segment: #{segment.errors.full_messages.join(', ')}"
    end
  end

  def active?
    user_is_administrator?
  end

  private

  def generate_filter_query(description)
    prompt = <<~PROMPT
      Convert this natural language segment description into a Chatwoot contact filter query JSON array.

      Description: #{description}

      Available filter attributes and operators:
      - name: equal_to, not_equal_to, contains, does_not_contain, is_present, is_not_present
      - email: equal_to, not_equal_to, contains, does_not_contain, is_present, is_not_present
      - phone_number: equal_to, not_equal_to, contains, does_not_contain, is_present, is_not_present
      - identifier: equal_to, not_equal_to, contains, does_not_contain
      - country_code: equal_to, not_equal_to
      - city: equal_to, not_equal_to, contains, does_not_contain
      - labels: equal_to, not_equal_to, is_present, is_not_present
      - created_at: is_greater_than, is_less_than, days_before
      - last_activity_at: is_greater_than, is_less_than, days_before
      - blocked: equal_to, not_equal_to
      - company: equal_to, not_equal_to, contains, does_not_contain

      For "days_before" operator, value is number of days.

      Return ONLY a valid JSON array, no other text. Example:
      [{"attribute_key":"last_activity_at","filter_operator":"days_before","values":["30"],"query_operator":null}]
    PROMPT

    response = llm_request(prompt)
    parsed = extract_json_array(response)
    parsed if parsed.is_a?(Array) && parsed.any?
  end

  def llm_request(prompt)
    llm_service = Captain::Llm::AssistantChatService.new(assistant: @assistant)
    llm_service.generate_response(additional_message: prompt)
  end

  def extract_json_array(text)
    return nil if text.blank?

    match = text.match(/\[[\s\S]*\]/)
    return nil unless match

    JSON.parse(match[0])
  rescue JSON::ParserError
    nil
  end

  def user_is_administrator?
    return false if @user.blank?

    account_user = AccountUser.find_by(account_id: @assistant.account_id, user_id: @user.id)
    return false if account_user.blank?

    account_user.administrator?
  end
end
