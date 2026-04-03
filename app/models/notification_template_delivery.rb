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
# Indexes
#
#  index_notification_template_deliveries_on_account_id       (account_id)
#  index_notification_template_deliveries_on_contact_id       (contact_id)
#  index_notification_template_deliveries_on_conversation_id  (conversation_id)
#  index_nt_deliveries_on_account_contact_sent_at             (account_id,contact_id,sent_at)
#  index_nt_deliveries_on_conversation_sent_at                (conversation_id,sent_at)
#  index_nt_deliveries_on_template_contact_sent_at            (notification_template_id,contact_id,sent_at)
#  index_nt_deliveries_on_template_id                         (notification_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (notification_template_id => notification_templates.id)
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
