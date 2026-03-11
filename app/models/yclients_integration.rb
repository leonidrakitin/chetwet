# frozen_string_literal: true

# == Schema Information
#
# Table name: yclients_integrations
#
#  id            :bigint           not null, primary key
#  account_id    :bigint           not null
#  salon_id      :integer          not null
#  bearer_token  :string
#  connected_at  :datetime
#  status        :integer          default("active"), not null
#  webhook_secret: string
#  system_user_id: string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_yclients_integrations_on_account_id_and_salon_id  (account_id,salon_id) UNIQUE
#  index_yclients_integrations_on_salon_id                 (salon_id)
#
class YclientsIntegration < ApplicationRecord
  belongs_to :account

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  encrypts :bearer_token if Chatwoot.encryption_configured?

  enum status: { active: 0, revoked: 1, disabled: 2 }

  validates :account_id, presence: true
  validates :salon_id, presence: true, numericality: { only_integer: true }
  validates :salon_id, uniqueness: { scope: :account_id }
end
