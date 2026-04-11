# frozen_string_literal: true

# == Schema Information
#
# Table name: service_booking_items
#
#  id                 :bigint           not null, primary key
#  duration_minutes   :integer
#  position           :integer          default(0), not null
#  price              :decimal(10, 2)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  service_booking_id :bigint           not null
#  service_id         :bigint           not null
#
# Indexes
#
#  index_service_booking_items_on_service_booking_id               (service_booking_id)
#  index_service_booking_items_on_service_booking_id_and_position  (service_booking_id,position)
#  index_service_booking_items_on_service_id                       (service_id)
#
# Foreign Keys
#
#  fk_rails_...  (service_booking_id => service_bookings.id)
#  fk_rails_...  (service_id => services.id)
#
class ServiceBookingItem < ApplicationRecord
  belongs_to :service_booking
  belongs_to :service

  validates :position, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 },
                               allow_nil: true

  before_validation :set_defaults, on: :create

  delegate :name, to: :service, prefix: true

  private

  def set_defaults
    self.duration_minutes ||= service&.duration_minutes
    self.price ||= service&.price
  end
end
