class Crm::Yclients::Api::RecordsClient < Crm::Yclients::Api::BaseClient
  # https://yclients.docs.apiary.io/#reference/0/0

  def initialize(partner_token, user_token, company_id)
    super(partner_token, user_token)
    @company_id = company_id
  end

  def get_by_client(client_id)
    result = get("records/#{@company_id}", { client_id: client_id })
    Array.wrap(result)
  end

  def find(record_id)
    get("record/#{@company_id}/#{record_id}")
  end

  def create(data)
    post("records/#{@company_id}", data)
  end

  def update(record_id, data)
    put("record/#{@company_id}/#{record_id}", data)
  end
end
