# frozen_string_literal: true

# == Schema Information
#
# Table name: provider_schedules
#
#  id                       :bigint           not null, primary key
#  breaks                   :jsonb
#  holidays                 :jsonb
#  inherit_account_schedule :boolean          default(TRUE), not null
#  timezone                 :string           default("UTC"), not null
#  working_hours            :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  service_provider_id      :bigint           not null
#
# Indexes
#
#  index_provider_schedules_on_service_provider_id  (service_provider_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (service_provider_id => service_providers.id)
#
class ProviderSchedule < ApplicationRecord
  include NormalizesScheduleWorkingHours

  belongs_to :service_provider

  validates :timezone, presence: true

  DAYS_OF_WEEK = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  before_validation :set_default_working_hours, on: :create

  def working_hours_for(day)
    normalize_day_config((working_hours || {})[day.to_s.downcase])
  end

  def enabled_days
    DAYS_OF_WEEK.select { |day| working_hours_for(day)['enabled'] }
  end

  def holiday?(date)
    (holidays || []).any? { |h| h['date'] == date.to_s }
  end

  def breaks
    self[:breaks] || []
  end

  def slot_interval_minutes
    service_provider.account.service_schedule&.slot_interval_minutes || 30
  end

  def tz
    @tz ||= ActiveSupport::TimeZone.new(timezone)
  end

  def effective_schedule
    return service_provider.account.service_schedule if inherit_account_schedule?

    self
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
