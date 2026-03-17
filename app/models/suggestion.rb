class Suggestion < ApplicationRecord
  belongs_to :account
  belongs_to :user
  has_many :suggestion_votes, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[pending approved rejected] }

  scope :ordered_by_votes, -> { order(upvotes_count: :desc, created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :search_by, ->(query) { where('title ILIKE :q OR description ILIKE :q', q: "%#{query}%") if query.present? }

  def vote_by(user, vote_type)
    existing_vote = suggestion_votes.find_by(user: user)

    if existing_vote
      if existing_vote.vote_type == vote_type
        existing_vote.destroy!
        recalculate_votes!
        return nil
      else
        existing_vote.update!(vote_type: vote_type)
      end
    else
      suggestion_votes.create!(user: user, vote_type: vote_type)
    end

    recalculate_votes!
    suggestion_votes.find_by(user: user)
  end

  def add_tag(tag)
    self.tags = (tags || []).push(tag).uniq
    save!
  end

  def remove_tag(tag)
    self.tags = (tags || []).reject { |t| t == tag }
    save!
  end

  private

  def recalculate_votes!
    update_columns(
      upvotes_count: suggestion_votes.where(vote_type: 'upvote').count,
      downvotes_count: suggestion_votes.where(vote_type: 'downvote').count
    )
  end
end
