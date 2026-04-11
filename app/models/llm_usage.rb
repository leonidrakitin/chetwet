class LlmUsage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  FEATURES = %w[assistant copilot editor label_suggestion audio_transcription help_center_search].freeze

  validates :feature, presence: true, inclusion: { in: FEATURES }
  validates :model, presence: true
  validates :provider, presence: true
  validates :prompt_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :completion_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_tokens, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :for_feature, ->(feature) { where(feature: feature) }
  scope :since_date, ->(time) { where(created_at: time..) }
  scope :until_date, ->(time) { where(created_at: ..time) }

  class << self
    def total_cost_for_account(account_id, since_date: nil, until_date: nil)
      scope = for_account(account_id)
      scope = scope.since_date(since_date) if since_date
      scope = scope.until_date(until_date) if until_date
      scope.sum(:cost_usd)
    end

    def total_tokens_for_account(account_id, since_date: nil, until_date: nil)
      scope = for_account(account_id)
      scope = scope.since_date(since_date) if since_date
      scope = scope.until_date(until_date) if until_date
      {
        prompt: scope.sum(:prompt_tokens),
        completion: scope.sum(:completion_tokens),
        total: scope.sum(:total_tokens)
      }
    end

    def summary_for_account(account_id, since_date: nil, until_date: nil)
      scope = for_account(account_id)
      scope = scope.since_date(since_date) if since_date
      scope = scope.until_date(until_date) if until_date

      {
        total_cost_usd: scope.sum(:cost_usd),
        total_prompt_tokens: scope.sum(:prompt_tokens),
        total_completion_tokens: scope.sum(:completion_tokens),
        total_tokens: scope.sum(:total_tokens),
        total_requests: scope.count,
        by_feature: summary_by_feature(scope),
        by_model: summary_by_model(scope)
      }
    end

    def summary_for_conversation(conversation_id)
      scope = for_conversation(conversation_id)

      {
        total_cost_usd: scope.sum(:cost_usd),
        total_prompt_tokens: scope.sum(:prompt_tokens),
        total_completion_tokens: scope.sum(:completion_tokens),
        total_tokens: scope.sum(:total_tokens),
        total_requests: scope.count,
        by_feature: summary_by_feature(scope)
      }
    end

    private

    def summary_by_feature(scope)
      scope.group(:feature).select(
        'feature,
         SUM(cost_usd) as total_cost_usd,
         SUM(prompt_tokens) as total_prompt_tokens,
         SUM(completion_tokens) as total_completion_tokens,
         SUM(total_tokens) as total_tokens,
         COUNT(*) as total_requests'
      ).each_with_object({}) do |row, hash|
        hash[row.feature] = {
          total_cost_usd: row.total_cost_usd,
          total_prompt_tokens: row.total_prompt_tokens,
          total_completion_tokens: row.total_completion_tokens,
          total_tokens: row.total_tokens,
          total_requests: row.total_requests
        }
      end
    end

    def summary_by_model(scope)
      scope.group(:model).select(
        'model,
         SUM(cost_usd) as total_cost_usd,
         SUM(prompt_tokens) as total_prompt_tokens,
         SUM(completion_tokens) as total_completion_tokens,
         SUM(total_tokens) as total_tokens,
         COUNT(*) as total_requests'
      ).each_with_object({}) do |row, hash|
        hash[row.model] = {
          total_cost_usd: row.total_cost_usd,
          total_prompt_tokens: row.total_prompt_tokens,
          total_completion_tokens: row.total_completion_tokens,
          total_tokens: row.total_tokens,
          total_requests: row.total_requests
        }
      end
    end
  end
end
