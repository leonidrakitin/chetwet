class Crm::Yclients::Mappers::ContactMapper
  def self.map(contact)
    new(contact).map
  end

  def initialize(contact)
    @contact = contact
  end

  def map
    {
      'name' => contact.name.presence,
      'phone' => contact.phone_number.presence,
      'email' => contact.email.presence,
      'comment' => comment_for_yclients
    }.compact
  end

  def self.map_from_yclients(client)
    {
      name: client['name'],
      phone_number: client['phone'],
      email: client['email']
    }.compact
  end

  def self.map_from_yclients_full(client)
    base = map_from_yclients(client)
    extra = {
      'birth_date' => client['birth_date'],
      'discount' => client['discount'],
      'categories' => client['categories'],
      'visits' => client['visits'],
      'balance' => client['balance'],
      'comment' => client['comment']
    }.compact
    extra.merge!(consent_attributes(client))
    base[:yclients_attributes] = extra if extra.any?
    base
  end

  # YCLIENTS consent fields:
  #   sms_check: 0 = no consent, 1/2 = has consent for personal data processing
  #   sms_not:   0 = agrees to mailings, 1 = does NOT agree (inverted!)
  def self.consent_attributes(client)
    attrs = {}
    attrs['consent_pd'] = client['sms_check'].to_i.positive? if client.key?('sms_check')
    attrs['consent_mailing'] = client['sms_not'].to_i.zero? if client.key?('sms_not')
    attrs.compact
  end

  def comment_for_yclients
    "Imported from Chatwoot ##{contact.id}"
  end

  private

  attr_reader :contact
end
