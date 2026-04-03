# frozen_string_literal: true

# == Schema Information
#
# Table name: approval_bot_configs
#
#  id           :bigint           not null, primary key
#  bot_name     :string
#  bot_token    :text
#  channel_type :string           not null
#  enabled      :boolean          default(FALSE), not null
#  settings     :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_approval_bot_configs_on_account_id                   (account_id)
#  index_approval_bot_configs_on_account_id_and_channel_type  (account_id,channel_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ApprovalBotConfig < ApplicationRecord
  encrypts :bot_token if Chatwoot.encryption_configured?

  CHANNEL_TYPES = %w[telegram vk max].freeze

  belongs_to :account

  validates :channel_type, presence: true, inclusion: { in: CHANNEL_TYPES }
  validates :channel_type, uniqueness: { scope: :account_id }
  validates :bot_token, presence: true, if: :enabled?

  scope :enabled, -> { where(enabled: true) }
end
