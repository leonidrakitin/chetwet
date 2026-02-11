class ContactSegmentMembership < ApplicationRecord
  belongs_to :contact
  belongs_to :contact_segment

  validates :contact_id, uniqueness: { scope: :contact_segment_id }
end
