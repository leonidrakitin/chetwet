class Crm::Yclients::Api::CommentsClient < Crm::Yclients::Api::BaseClient
  def initialize(partner_token, user_token, company_id)
    super(partner_token, user_token)
    @company_id = company_id
  end

  def list(client_id)
    result = get("comments/#{@company_id}/#{client_id}")
    Array.wrap(result)
  end

  def create(client_id, text)
    post("comments/#{@company_id}/#{client_id}", { 'text' => text })
  end
end
