require 'administrate/base_dashboard'

class PlanDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    display_name: Field::String,
    price: Field::Number.with_options(decimals: 2),
    annual_price: Field::Number.with_options(decimals: 2),
    trial_days: Field::Number,
    description: Field::Text,
    active: Field::Boolean,
    feature_list: PlanFeaturesField,
    accounts: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[id name price annual_price trial_days active accounts].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id name display_name price annual_price trial_days description active feature_list accounts created_at updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    name display_name price annual_price trial_days description active feature_list
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(plan)
    plan.display_name.presence || plan.name
  end

  def permitted_attributes(_action)
    super + [feature_list: []]
  end
end
