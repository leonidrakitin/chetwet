# == Schema Information
#
# Table name: notification_template_deliveries
#
#  id                       :bigint           not null, primary key
#  metadata                 :jsonb            not null
#  responded_at             :datetime
#  sent_at                  :datetime         not null
#  status                   :string           default("sent"), not null
#  trigger_type             :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  contact_id               :bigint
#  conversation_id          :bigint
#  notification_template_id :bigint           not null
#
class NotificationTemplateDelivery < ApplicationRecord
  STATUSES = %w[sent failed skipped replied].freeze

  belongs_to :notification_template, inverse_of: :deliveries
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :sent_at, presence: true
end
