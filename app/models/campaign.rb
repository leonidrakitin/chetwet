# == Schema Information
#
# Table name: campaigns
#
#  id                      :bigint           not null, primary key
#  audience                :jsonb
#  audience_count          :integer          default(0), not null
#  description             :text
#  enabled                 :boolean          default(TRUE)
#  failed_count            :integer          default(0), not null
#  last_sent_at            :datetime
#  messages                :jsonb
#  metadata                :jsonb
#  name                    :string           not null
#  schedule                :jsonb
#  scheduled_at            :datetime
#  sent_count              :integer          default(0), not null
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
  before_save :calculate_audience_count, if: -> { audience_changed? || inbox_id_changed? }

  validates :name, presence: true
  validates :messages, presence: true
  validate :messages_must_be_an_array
  validate :inbox_belongs_to_account
  validate :yclients_integration_belongs_to_account

  DELIVERY_STATUSES = %w[scheduled in_progress completed].freeze

  def effective_inbox_id
    inbox_id || yclients_integration&.inbox_id
  end

  def timezone
    schedule['timezone'].presence || inbox&.timezone.presence || yclients_integration&.inbox&.timezone.presence || 'UTC'
  end

  def delivery_status
    return 'scheduled' if scheduled_at.present? && sent_count.zero?
    return 'completed' if !enabled || last_sent_at.present?

    'in_progress'
  end

  def delivery_progress_percent
    return 0 if audience_count.zero?

    [(sent_count.to_f / audience_count * 100).round, 100].min
  end

  def reset_delivery_counters!
    update!(sent_count: 0, failed_count: 0)
  end

  private

  def calculate_audience_count
    self.audience_count = Campaigns::AudienceScope.new(campaign: self).call.size
  rescue StandardError
    self.audience_count = 0
  end

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
