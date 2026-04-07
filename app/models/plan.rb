# == Schema Information
#
# Table name: plans
#
#  id             :bigint           not null, primary key
#  active         :boolean          default(TRUE), not null
#  annual_price   :decimal(10, 2)   default(0.0)
#  captain_models :jsonb
#  description    :text
#  display_name   :string
#  feature_list   :jsonb
#  name           :string           not null
#  price          :decimal(10, 2)   default(0.0)
#  trial_days     :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_plans_on_name  (name) UNIQUE
#
class Plan < ApplicationRecord
  has_many :accounts, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :annual_price, numericality: { greater_than_or_equal_to: 0 }
  validates :trial_days, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  AVAILABLE_FEATURES = Featurable::FEATURE_LIST.pluck('name').freeze

  def selected_features=(list)
    self.feature_list = Array(list).map(&:to_s).select { |f| AVAILABLE_FEATURES.include?(f) }
  end
end
