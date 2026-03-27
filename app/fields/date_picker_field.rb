require 'administrate/field/base'

class DatePickerField < Administrate::Field::Base
  def formatted_date
    return nil if data.blank?

    Date.parse(data.to_s).strftime('%d %b %Y')
  rescue ArgumentError
    data.to_s
  end

  def date_value
    return nil if data.blank?

    Date.parse(data.to_s).strftime('%Y-%m-%d')
  rescue ArgumentError
    nil
  end
end
