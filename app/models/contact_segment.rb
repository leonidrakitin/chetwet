class ContactSegment < ApplicationRecord
  belongs_to :account
  belongs_to :creator, class_name: 'User', foreign_key: 'created_by_id', optional: true

  has_many :memberships, class_name: 'ContactSegmentMembership', dependent: :destroy
  has_many :members, through: :memberships, source: :contact
  has_many :change_logs, class_name: 'SegmentChangeLog', dependent: :destroy
  has_many :campaigns, foreign_key: :segment_id, dependent: :nullify, inverse_of: :segment

  validates :name, presence: true
  validates :query, presence: true
  validate :validate_query_structure

  scope :active, -> { where(active: true) }

  def membership_ids
    memberships.pluck(:contact_id)
  end

  private

  def validate_query_structure
    return if query.blank?

    validator = SegmentQueryValidator.new(query)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:query, error) }
  end
end
