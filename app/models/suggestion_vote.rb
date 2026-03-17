class SuggestionVote < ApplicationRecord
  belongs_to :suggestion
  belongs_to :user

  validates :vote_type, inclusion: { in: %w[upvote downvote] }
  validates :user_id, uniqueness: { scope: :suggestion_id }
end
