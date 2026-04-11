# == Schema Information
#
# Table name: campaign_deliveries
#
#  id              :bigint           not null, primary key
#  metadata        :jsonb
#  sent_at         :datetime
#  status          :string           not null
#  trigger_type    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  campaign_id     :bigint           not null
#  contact_id      :bigint
#  conversation_id :bigint
#
# Indexes
#
#  index_campaign_deliveries_on_account_id                  (account_id)
#  index_campaign_deliveries_on_campaign_id                 (campaign_id)
#  index_campaign_deliveries_on_campaign_id_and_status      (campaign_id,status)
#  index_campaign_deliveries_on_contact_id                  (contact_id)
#  index_campaign_deliveries_on_contact_id_and_campaign_id  (contact_id,campaign_id)
#  index_campaign_deliveries_on_conversation_id             (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#
class CampaignDelivery < ApplicationRecord
  belongs_to :campaign
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true

  STATUSES = %w[sent failed skipped replied].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
end
