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

  private

  attr_reader :contact
end
