class Crm::Yclients::Mappers::RecordMapper
  def self.map_to_metadata(record)
    services = Array.wrap(record['services']).pluck('title').join(', ')
    staff = record.dig('staff', 'name')
    amount = record['cost'].to_f

    {
      'record_id' => record['id'],
      'company_id' => record['company_id']&.to_s,
      'record_date' => record['date'],
      'service' => services.presence,
      'staff' => staff.presence,
      'amount' => amount,
      'status' => record['attendance']
    }.compact
  end

  def self.extract_transactions(records)
    Array.wrap(records).flat_map do |record|
      transactions = Array.wrap(record['goods_transactions'])
      transactions.map do |t|
        {
          'record_id' => record['id'],
          'date' => record['date'],
          'title' => t['good_title'],
          'amount' => t['cost'].to_f,
          'discount' => t['discount'].to_f,
          'total' => t['cost'].to_f - t['discount'].to_f
        }
      end
    end
  end
end
