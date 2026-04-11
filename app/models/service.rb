# frozen_string_literal: true

# == Schema Information
#
# Table name: services
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  currency         :string           default("RUB")
#  description      :text
#  duration_minutes :integer          default(30), not null
#  metadata         :jsonb
#  name             :string           not null
#  price            :decimal(10, 2)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_services_on_account_id             (account_id)
#  index_services_on_account_id_and_active  (account_id,active)
#  index_services_on_name                   (name)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Service < ApplicationRecord
  belongs_to :account
  has_many :service_booking_items, dependent: :restrict_with_error
  has_many :service_bookings, through: :service_booking_items

  validates :name, presence: true, length: { maximum: 255 }
  validates :duration_minutes, presence: true,
                               numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1440 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def formatted_duration
    hours = duration_minutes / 60
    minutes = duration_minutes % 60
    return "#{hours}h" if minutes.zero?
    return "#{minutes}min" if hours.zero?

    "#{hours}h #{minutes}min"
  end
end
