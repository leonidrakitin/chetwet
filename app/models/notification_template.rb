# == Schema Information
#
# Table name: notification_templates
#
#  id                      :bigint           not null, primary key
#  audience                :jsonb            not null
#  conditions              :jsonb            not null
#  description             :text
#  enabled                 :boolean          default(TRUE), not null
#  event_type              :string
#  last_sent_at            :datetime
#  limits                  :jsonb            not null
#  messages                :jsonb            not null
#  metadata                :jsonb            not null
#  name                    :string           not null
#  next_send_at            :datetime
#  position                :integer          default(0), not null
#  schedule                :jsonb            not null
#  template_type           :string           default("event"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  inbox_id                :bigint
#  yclients_integration_id :bigint
#
class NotificationTemplate < ApplicationRecord
  TEMPLATE_TYPES = %w[event time interval lost_clients client_consent].freeze
  EVENT_TEMPLATE_TYPES = %w[event client_consent].freeze
  INTERVAL_TEMPLATE_TYPES = %w[interval lost_clients].freeze

  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :yclients_integration, optional: true

  has_many :deliveries, class_name: 'NotificationTemplateDelivery', dependent: :destroy_async, inverse_of: :notification_template

  scope :active, -> { where(enabled: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :due, -> { active.where('next_send_at IS NOT NULL AND next_send_at <= ?', Time.current) }

  before_validation :normalize_json_fields
  before_validation :normalize_messages
  before_validation :sync_inbox_from_yclients
  before_validation :set_next_send_at, if: :schedule_changed?

  validates :name, presence: true
  validates :template_type, presence: true, inclusion: { in: TEMPLATE_TYPES }
  validates :messages, presence: true
  validate :messages_must_be_an_array
  validate :inbox_belongs_to_account
  validate :yclients_integration_belongs_to_account

  def type
    template_type
  end

  def type=(value)
    self.template_type = value
  end

  def order
    position
  end

  def order=(value)
    self.position = value
  end

  def trigger_event
    event_type
  end

  def trigger_event=(value)
    self.event_type = value
  end

  def event_template?
    template_type.in?(EVENT_TEMPLATE_TYPES)
  end

  def time_template?
    template_type == 'time'
  end

  def interval_template?
    template_type.in?(INTERVAL_TEMPLATE_TYPES)
  end

  def yclients_enabled?
    yclients_integration_id.present?
  end

  def effective_inbox_id
    inbox_id || yclients_integration&.inbox_id
  end

  def timezone
    schedule['timezone'].presence || inbox&.timezone.presence || yclients_integration&.inbox&.timezone.presence || 'UTC'
  end

  def schedule_changed?
    will_save_change_to_schedule? || will_save_change_to_template_type? || will_save_change_to_enabled?
  end

  private

  def normalize_json_fields
    self.schedule = schedule.presence || {}
    self.conditions = conditions.presence || {}
    self.audience = audience.presence || {}
    self.limits = limits.presence || {}
    self.metadata = metadata.presence || {}
  end

  def normalize_messages
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

  def set_next_send_at
    self.next_send_at = NotificationTemplates::ScheduleCalculator.new(template: self).next_time
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
