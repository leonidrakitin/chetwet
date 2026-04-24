# frozen_string_literal: true

# == Schema Information
#
# Table name: service_bookings
#
#  id                     :bigint           not null, primary key
#  cancellation_reason    :string
#  cancelled_at           :datetime
#  customer_notes         :text
#  internal_notes         :text
#  metadata               :jsonb
#  preferences            :jsonb
#  scheduled_at           :datetime         not null
#  status                 :integer          default("pending"), not null
#  total_duration_minutes :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  contact_id             :bigint           not null
#  service_provider_id    :bigint           not null
#
# Indexes
#
#  index_service_bookings_on_account_id                            (account_id)
#  index_service_bookings_on_account_id_and_scheduled_at           (account_id,scheduled_at)
#  index_service_bookings_on_contact_id                            (contact_id)
#  index_service_bookings_on_service_provider_id                   (service_provider_id)
#  index_service_bookings_on_service_provider_id_and_scheduled_at  (service_provider_id,scheduled_at)
#  index_service_bookings_on_status                                (status)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (service_provider_id => service_providers.id)
#
class ServiceBooking < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :service_provider
  has_many :service_booking_items, -> { order(:position) }, dependent: :destroy, inverse_of: :service_booking
  has_many :services, through: :service_booking_items

  enum status: { pending: 0, confirmed: 1, completed: 2, cancelled: 3, arrived: 4, no_show: 5 }

  validates :scheduled_at, presence: true
  validates :total_duration_minutes, numericality: { only_integer: true, greater_than: 0 },
                                     allow_nil: true
  validate :scheduled_at_not_in_past, on: :create
  validate :cannot_cancel_without_reason, on: :update

  accepts_nested_attributes_for :service_booking_items, allow_destroy: true

  scope :upcoming, -> { where('scheduled_at > ?', Time.current).order(:scheduled_at) }
  scope :past, -> { where('scheduled_at <= ?', Time.current).order(scheduled_at: :desc) }
  scope :for_provider, ->(provider_id) { where(service_provider_id: provider_id) }
  scope :for_contact, ->(contact_id) { where(contact_id: contact_id) }
  scope :on_date, ->(date) { where(scheduled_at: date.all_day) }
  scope :active_bookings, -> { where.not(status: :cancelled) }

  delegate :name, to: :service_provider, prefix: true
  delegate :name, to: :contact, prefix: true

  def end_time
    return scheduled_at if total_duration_minutes.blank?

    scheduled_at + total_duration_minutes.minutes
  end

  def time_range
    scheduled_at..end_time
  end

  def cancel!(reason: nil)
    update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancellation_reason: reason
    )
  end

  def confirm!
    update!(status: :confirmed)
  end

  def complete!
    update!(status: :completed)
  end

  def calculate_total_duration
    update(total_duration_minutes: service_booking_items.sum(:duration_minutes))
  end

  private

  def scheduled_at_not_in_past
    return unless scheduled_at.present? && scheduled_at < Time.current

    errors.add(:base, I18n.t('services.bookings.past_time'))
  end

  def cannot_cancel_without_reason
    return unless status_changed?(to: 'cancelled') && cancellation_reason.blank?

    errors.add(:cancellation_reason, 'is required when cancelling')
  end
end
