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
