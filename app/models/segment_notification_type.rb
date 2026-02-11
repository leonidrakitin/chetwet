class SegmentNotificationType < ApplicationRecord
  belongs_to :account

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc) }
end
