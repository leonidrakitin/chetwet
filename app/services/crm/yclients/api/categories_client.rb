# frozen_string_literal: true

class Crm::Yclients::Api::CategoriesClient < Crm::Yclients::Api::BaseClient
  # https://developers.yclients.com/ru/#tag/Kategorii-uslug

  def initialize(partner_token, user_token, company_id)
    super(partner_token, user_token)
    @company_id = company_id
  end

  def list
    result = get("service_categories/#{@company_id}")
    Array.wrap(result)
  end
end
