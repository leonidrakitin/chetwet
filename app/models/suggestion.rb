# == Schema Information
#
# Table name: suggestions
#
#  id                :bigint           not null, primary key
#  description       :text
#  description_plain :text
#  downvotes_count   :integer          default(0), not null
#  status            :string           default("pending"), not null
#  tags              :string           default([]), is an Array
#  title             :string           not null
#  upvotes_count     :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_suggestions_on_account_id  (account_id)
#  index_suggestions_on_status      (status)
#  index_suggestions_on_tags        (tags) USING gin
#  index_suggestions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Suggestion < ApplicationRecord
  MAX_IMAGES = 10
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp image/heic image/heif].freeze

  belongs_to :account
  belongs_to :user
  has_many :suggestion_votes, dependent: :destroy
  has_many_attached :images

  DESCRIPTION_HTML_TAGS = %w[p br strong b i em u ul ol li a h1 h2 h3 h4 blockquote code pre].freeze
  DESCRIPTION_HTML_ATTRIBUTES = %w[href rel target].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: %w[pending approved rejected] }
  validate :validate_images

  before_validation :sanitize_description_html
  before_validation :sync_description_plain

  scope :ordered_by_votes, -> { order(upvotes_count: :desc, created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :for_user, ->(user_id) { user_id.present? ? where(user_id: user_id) : all }
  scope :search_by, lambda { |query|
    if query.blank?
      all
    else
      escaped = ActiveRecord::Base.sanitize_sql_like(query)
      q = "%#{escaped}%"
      where(
        'title ILIKE :q OR COALESCE(description_plain, \'\') ILIKE :q',
        q: q
      )
    end
  }

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

  def validate_images
    return unless images.attached?

    if images.attachments.size > MAX_IMAGES
      errors.add(:images, :too_many, count: MAX_IMAGES)
      return
    end

    invalid_type = images.attachments.any? do |att|
      ct = att.blob&.content_type
      ct.blank? || ALLOWED_IMAGE_TYPES.exclude?(ct)
    end

    errors.add(:images, :invalid_type) if invalid_type
  end

  def sanitize_description_html
    return if description.blank?

    self.description = Rails::HTML5::SafeListSanitizer.new.sanitize(
      description,
      tags: DESCRIPTION_HTML_TAGS,
      attributes: DESCRIPTION_HTML_ATTRIBUTES
    )
  end

  def sync_description_plain
    self.description_plain =
      description.present? ? ActionController::Base.helpers.strip_tags(description).squish.presence : nil
  end

  def recalculate_votes!
    update_columns(
      upvotes_count: suggestion_votes.where(vote_type: 'upvote').count,
      downvotes_count: suggestion_votes.where(vote_type: 'downvote').count
    )
  end
end
