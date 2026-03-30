# frozen_string_literal: true

class Captain::ApprovalRequest < ApplicationRecord
  self.table_name = 'captain_approval_requests'

  belongs_to :account
  belongs_to :conversation
  belongs_to :assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true

  enum status: { pending: 0, resolved: 1, expired: 2 }

  ASSIGNEE_TYPES = %w[user team].freeze
  MESSENGER_TYPES = %w[telegram vk max].freeze

  validates :title, presence: true
  validates :options, presence: true
  validates :assignee_type, inclusion: { in: ASSIGNEE_TYPES }, allow_nil: true
  validates :messenger_type, inclusion: { in: MESSENGER_TYPES }, allow_nil: true

  scope :pending_unexpired, -> { pending.where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def target_users
    case assignee_type
    when 'user'  then target_user_members
    when 'team'  then target_team_members
    else []
    end
  end

  def resolve!(index:, by_user_id:, custom_text: nil)
    with_lock do
      next false unless pending?

      update!(
        status: :resolved,
        selected_option_index: index,
        custom_response: custom_text,
        resolved_by_id: by_user_id
      )
      ApprovalBot::ActionExecutorService.new(self).execute
      true
    end
  end

  private

  def target_user_members
    User.where(id: assignee_id).select { |u| u.telegram_chat_id.present? }
  end

  def target_team_members
    team = Team.find_by(id: assignee_id)
    return [] unless team

    team.members.where.not(telegram_chat_id: [nil, '']).to_a
  end

  def selected_option
    return nil if selected_option_index.nil?

    options[selected_option_index]&.with_indifferent_access
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
