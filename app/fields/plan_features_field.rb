require 'administrate/field/base'

class PlanFeaturesField < Administrate::Field::Base
  def self.available_features
    SuperAdmin::AccountFeaturesHelper.account_features
  end

  def to_s
    Array(data).join(', ')
  end
end
