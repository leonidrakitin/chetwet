# frozen_string_literal: true

class Crm::Yclients::Api::BookingClient < Crm::Yclients::Api::BaseClient
  def initialize(partner_token, user_token, company_id)
    super(partner_token, user_token)
    @company_id = company_id
  end

  def get_staff(params = {})
    result = get("book_staff/#{@company_id}", params)
    Array.wrap(result)
  end

  def get_services(params = {})
    result = get("book_services/#{@company_id}", params)
    Array.wrap(result)
  end

  def get_dates(params = {})
    result = get("book_dates/#{@company_id}", params)
    Array.wrap(result)
  end

  def get_times(staff_id, date)
    result = get("book_times/#{@company_id}/#{staff_id}/#{date}")
    Array.wrap(result)
  end

  def check_booking(data)
    post("book_check/#{@company_id}", data)
  end

  def create_booking(data)
    post("book_record/#{@company_id}", data)
  end
end
