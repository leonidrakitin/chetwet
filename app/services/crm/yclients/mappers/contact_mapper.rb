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
    base[:yclients_attributes] = extra if extra.any?
    base
  end

  def comment_for_yclients
    note_contents = contact.notes.latest.limit(10).pluck(:content).compact_blank
    if note_contents.any?
      note_contents.join("\n\n")
    else
      "Imported from Chatwoot ##{contact.id}"
    end
  end

  private

  attr_reader :contact
end
