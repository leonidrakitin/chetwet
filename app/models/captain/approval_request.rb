# frozen_string_literal: true

# == Schema Information
#
# Table name: captain_approval_requests
#
#  id                    :bigint           not null, primary key
#  assignee_type         :string
#  context               :text
#  custom_response       :text
#  expires_at            :datetime
#  messenger_type        :string
#  options               :jsonb            not null
#  selected_option_index :integer
#  status                :integer          default("pending"), not null
#  title                 :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  assignee_id           :bigint
#  assistant_id          :bigint
#  conversation_id       :bigint           not null
#  messenger_message_id  :string
#  resolved_by_id        :bigint
#
# Indexes
#
#  idx_on_assignee_type_assignee_id_status_eee2bf9c60             (assignee_type,assignee_id,status)
#  index_captain_approval_requests_on_account_id                  (account_id)
#  index_captain_approval_requests_on_assistant_id                (assistant_id)
#  index_captain_approval_requests_on_conversation_id             (conversation_id)
#  index_captain_approval_requests_on_conversation_id_and_status  (conversation_id,status)
#  index_captain_approval_requests_on_resolved_by_id              (resolved_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assistant_id => captain_assistants.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (resolved_by_id => users.id)
#
class Captain::ApprovalRequest < ApplicationRecord
  self.table_name = 'captain_approval_requests'

  belongs_to :account
  belongs_to :conversation, class_name: '::Conversation'
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
      update_associated_message
      true
    end
  end

  def selected_option
    return nil if selected_option_index.nil?

    options[selected_option_index]&.with_indifferent_access
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

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def update_associated_message
    # The approval_request_id is carried on the private outgoing message used to render
    # the dashboard input_select bubble; the customer-facing text never carries it.
    message = conversation.messages
                          .where(private: true)
                          .where("content_attributes->>'approval_request_id' = ?", id.to_s)
                          .order(created_at: :desc)
                          .first
    return unless message

    label = selected_option&.dig(:label) || custom_response
    return if label.blank?

    message.update!(
      content_attributes: message.content_attributes.merge(
        submittedValues: [{ title: label, value: label }]
      )
    )
  end
end
