# frozen_string_literal: true

# == Schema Information
#
# Table name: service_providers
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  metadata    :jsonb
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_service_providers_on_account_id             (account_id)
#  index_service_providers_on_account_id_and_active  (account_id,active)
#  index_service_providers_on_name                   (name)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ServiceProvider < ApplicationRecord
  belongs_to :account
  has_many :service_bookings, dependent: :restrict_with_error
  has_one :provider_schedule, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def available_services
    account.services.active.ordered
  end

  def effective_schedule
    return account.service_schedule unless provider_schedule

    provider_schedule.effective_schedule
  end

  def working_hours_for(day)
    effective_schedule&.working_hours_for(day) || { 'enabled' => false, 'slots' => [] }
  end

  def holiday?(date)
    effective_schedule&.holiday?(date) || false
  end
end
