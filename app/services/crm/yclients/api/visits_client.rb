class Crm::Yclients::Api::VisitsClient < Crm::Yclients::Api::BaseClient
  # https://developers.yclients.com — PUT /api/v1/visits/{visit_id}/{record_id}
  def update_status(visit_id, record_id, data)
    put("visits/#{visit_id}/#{record_id}", data)
  end
end
