# == Schema Information
#
# Table name: campaigns
#
#  id                      :bigint           not null, primary key
#  audience                :jsonb
#  description             :text
#  enabled                 :boolean          default(TRUE)
#  last_sent_at            :datetime
#  messages                :jsonb
#  metadata                :jsonb
#  name                    :string           not null
#  schedule                :jsonb
#  scheduled_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  inbox_id                :bigint
#  yclients_integration_id :bigint
#
# Indexes
#
#  index_campaigns_on_account_id                   (account_id)
#  index_campaigns_on_account_id_and_enabled       (account_id,enabled)
#  index_campaigns_on_account_id_and_scheduled_at  (account_id,scheduled_at)
#  index_campaigns_on_inbox_id                     (inbox_id)
#  index_campaigns_on_scheduled_at                 (scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (yclients_integration_id => yclients_integrations.id) ON DELETE => nullify
#
class Campaign < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :yclients_integration, optional: true

  has_many :deliveries, class_name: 'CampaignDelivery', dependent: :destroy_async, inverse_of: :campaign

  scope :active, -> { where(enabled: true) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :due, -> { active.where('scheduled_at IS NOT NULL AND scheduled_at <= ?', Time.current) }

  before_validation :normalize_json_fields
  before_validation :sync_inbox_from_yclients

  validates :name, presence: true
  validates :messages, presence: true
  validate :messages_must_be_an_array
  validate :inbox_belongs_to_account
  validate :yclients_integration_belongs_to_account

  def effective_inbox_id
    inbox_id || yclients_integration&.inbox_id
  end

  def timezone
    schedule['timezone'].presence || inbox&.timezone.presence || yclients_integration&.inbox&.timezone.presence || 'UTC'
  end

  private

  def normalize_json_fields
    self.schedule = schedule.presence || {}
    self.audience = audience.presence || {}
    self.metadata = metadata.presence || {}
    self.messages = Array.wrap(messages).map do |message|
      normalized = message.is_a?(Hash) ? message : { text: message.to_s }
      {
        'text' => normalized[:text] || normalized['text'] || '',
        'attachments' => Array.wrap(normalized[:attachments] || normalized['attachments']),
        'buttons' => Array.wrap(normalized[:buttons] || normalized['buttons'])
      }
    end
  end

  def sync_inbox_from_yclients
    self.inbox_id ||= yclients_integration&.inbox_id
  end

  def messages_must_be_an_array
    errors.add(:messages, 'must contain at least one message block') if messages.blank?
  end

  def inbox_belongs_to_account
    return if inbox.blank? || inbox.account_id == account_id

    errors.add(:inbox_id, 'must belong to the same account')
  end

  def yclients_integration_belongs_to_account
    return if yclients_integration.blank? || yclients_integration.account_id == account_id

    errors.add(:yclients_integration_id, 'must belong to the same account')
  end
end
