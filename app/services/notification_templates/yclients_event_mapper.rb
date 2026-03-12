class NotificationTemplates::YclientsEventMapper
  pattr_initialize [:record_data!]

  def call
    status = normalized_status
    events = []

    events << 'booking_cancelled' if cancelled?(status)
    events << 'booking_created' if events.blank?
    events << 'confirmed' if truthy?(record_data['confirmed'] || record_data[:confirmed])
    events << 'paid' if paid?
    events << 'arrived' if arrived?(status)
    events
  end

  private

  def normalized_status
    value = record_data['status'] || record_data[:status] || record_data['attendance'] || record_data[:attendance]
    value.to_s.downcase
  end

  def cancelled?(status)
    %w[cancelled canceled deleted -1].include?(status)
  end

  def arrived?(status)
    %w[arrived 1 visited].include?(status)
  end

  def paid?
    truthy?(record_data['paid_full'] || record_data[:paid_full]) ||
      (record_data['paid_amount'] || record_data[:paid_amount]).to_f.positive?
  end

  def truthy?(value)
    value == true || value.to_s == 'true' || value.to_s == '1'
  end
end
