class SegmentChangeLog < ApplicationRecord
  belongs_to :contact
  belongs_to :contact_segment

  enum action: { enter: 'enter', exit: 'exit' }
  enum trigger_source: {
    inbound_message: 'inbound_message',
    outbound_campaign: 'outbound_campaign',
    reminder_message: 'reminder_message',
    manual_edit: 'manual_edit',
    cron_recalc: 'cron_recalc'
  }

  validates :action, presence: true
  validates :trigger_source, presence: true
  validates :detected_at, presence: true

  scope :recent, -> { order(detected_at: :desc) }
end
