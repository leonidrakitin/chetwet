# == Schema Information
#
# Table name: suggestion_votes
#
#  id            :bigint           not null, primary key
#  vote_type     :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  suggestion_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_suggestion_votes_on_suggestion_id              (suggestion_id)
#  index_suggestion_votes_on_suggestion_id_and_user_id  (suggestion_id,user_id) UNIQUE
#  index_suggestion_votes_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (suggestion_id => suggestions.id)
#  fk_rails_...  (user_id => users.id)
#
class SuggestionVote < ApplicationRecord
  belongs_to :suggestion
  belongs_to :user

  validates :vote_type, inclusion: { in: %w[upvote downvote] }
  validates :user_id, uniqueness: { scope: :suggestion_id }
end
