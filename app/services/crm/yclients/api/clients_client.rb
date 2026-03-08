class Crm::Yclients::Api::ClientsClient < Crm::Yclients::Api::BaseClient
  # https://yclients.docs.apiary.io/#reference/0/0

  def initialize(partner_token, user_token, company_id)
    super(partner_token, user_token)
    @company_id = company_id
  end

  def search(phone: nil, email: nil)
    raise ArgumentError, 'phone or email required' if phone.blank? && email.blank?

    params = {}
    params[:phone] = phone if phone.present?
    params[:email] = email if email.present?

    result = get("clients/#{@company_id}", params)
    Array.wrap(result)
  end

  def create(data)
    post("clients/#{@company_id}", data)
  end

  def update(client_id, data)
    put("client/#{@company_id}/#{client_id}", data)
  end

  def find_by_phone(phone)
    search(phone: phone).first
  end

  def find_by_email(email)
    search(email: email).first
  end

  def list(page: 1, count: 100)
    result = get("clients/#{@company_id}", { page: page, count: count })
    Array.wrap(result)
  end
end
