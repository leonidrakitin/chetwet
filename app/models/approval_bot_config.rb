# frozen_string_literal: true

class ApprovalBotConfig < ApplicationRecord
  encrypts :bot_token if Chatwoot.encryption_configured?

  CHANNEL_TYPES = %w[telegram vk max].freeze

  belongs_to :account

  validates :channel_type, presence: true, inclusion: { in: CHANNEL_TYPES }
  validates :channel_type, uniqueness: { scope: :account_id }
  validates :bot_token, presence: true, if: :enabled?

  scope :enabled, -> { where(enabled: true) }
end
