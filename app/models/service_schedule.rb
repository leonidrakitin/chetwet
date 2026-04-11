# frozen_string_literal: true

# == Schema Information
#
# Table name: service_schedules
#
#  id                    :bigint           not null, primary key
#  breaks                :jsonb
#  holidays              :jsonb
#  slot_interval_minutes :integer          default(30), not null
#  timezone              :string           default("UTC"), not null
#  working_hours         :jsonb
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#
# Indexes
#
#  index_service_schedules_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ServiceSchedule < ApplicationRecord
  belongs_to :account

  validates :timezone, presence: true
  validates :slot_interval_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 480 }

  DAYS_OF_WEEK = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  before_validation :set_default_working_hours, on: :create

  def working_hours_for(day)
    working_hours[day.to_s.downcase] || { 'enabled' => false, 'slots' => [] }
  end

  def enabled_days
    DAYS_OF_WEEK.select { |day| working_hours_for(day)['enabled'] }
  end

  def holiday?(date)
    holidays.any? { |h| h['date'] == date.to_s }
  end

  def tz
    @tz ||= ActiveSupport::TimeZone.new(timezone)
  end

  private

  def set_default_working_hours
    return if working_hours.present?

    self.working_hours = {
      'monday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'tuesday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'wednesday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'thursday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'friday' => { 'enabled' => true, 'slots' => [{ 'start' => '09:00', 'end' => '18:00' }] },
      'saturday' => { 'enabled' => false, 'slots' => [] },
      'sunday' => { 'enabled' => false, 'slots' => [] }
    }
  end
end
