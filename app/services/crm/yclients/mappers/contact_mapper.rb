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
      'comment' => "Imported from Chatwoot ##{contact.id}"
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
      'balance' => client['balance']
    }.compact
    base[:yclients_attributes] = extra if extra.any?
    base
  end

  private

  attr_reader :contact
end
