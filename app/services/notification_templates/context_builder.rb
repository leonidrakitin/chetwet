class NotificationTemplates::ContextBuilder
  DEFAULT_VALUES = {
    'client_name' => nil,
    'service_name' => nil,
    'branch_name' => nil,
    'master_name' => nil,
    'price' => nil,
    'date' => nil,
    'time' => nil
  }.freeze

  pattr_initialize [:conversation!]

  def call
    yclients = conversation.additional_attributes['yclients'] || {}
    {
      'client_name' => conversation.contact.name.presence || conversation.contact.phone_number,
      'service_name' => yclients['service'].presence,
      'branch_name' => yclients['branch_name'].presence,
      'master_name' => yclients['staff'].presence,
      'price' => format_amount(yclients['amount']),
      'date' => formatted_date(yclients['record_date']),
      'time' => formatted_time(yclients['record_date'])
    }.reverse_merge(DEFAULT_VALUES)
  end

  private

  def format_amount(amount)
    return if amount.blank?

    format('%.2f', amount.to_f)
  end

  def formatted_date(value)
    parsed = parse_time(value)
    parsed&.strftime('%Y-%m-%d')
  end

  def formatted_time(value)
    parsed = parse_time(value)
    parsed&.strftime('%H:%M')
  end

  def parse_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue StandardError
    nil
  end
end
