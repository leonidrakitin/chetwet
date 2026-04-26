# frozen_string_literal: true

# == Schema Information
#
# Table name: captain_trace_events
#
#  id                :bigint           not null, primary key
#  event_type        :string           not null
#  payload           :jsonb            not null
#  sequence          :integer          not null
#  created_at        :datetime         not null
#  account_id        :bigint           not null
#  assistant_id      :bigint
#  conversation_id   :bigint           not null
#  session_id        :string           not null
#  source_message_id :bigint
#
# Indexes
#
#  index_captain_trace_events_on_account_id                      (account_id)
#  index_captain_trace_events_on_assistant_id                    (assistant_id)
#  index_captain_trace_events_on_conversation_id                 (conversation_id)
#  index_captain_trace_events_on_conversation_id_and_created_at  (conversation_id,created_at)
#  index_captain_trace_events_on_session_id_and_sequence         (session_id,sequence)
#  index_captain_trace_events_on_source_message_id               (source_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#
class Captain::TraceEvent < ApplicationRecord
  self.table_name = 'captain_trace_events'

  EVENT_TYPES = %w[
    run_started
    llm_request
    llm_response
    prompt_snapshot
    tool_start
    tool_complete
    agent_handoff
    policy_check
    citation_check
    knowledge_hit
    decision_evaluated
    decision_selected
    decision_rejected
    decision_deferred
    escalation
    escalation_decision
    handoff
    outgoing_message
    error
    run_completed
  ].freeze

  DECISION_EVENT_TYPES = %w[
    decision_evaluated
    decision_selected
    decision_rejected
    decision_deferred
    escalation_decision
  ].freeze

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation', inverse_of: :captain_trace_events
  belongs_to :assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :source_message, class_name: '::Message', optional: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :session_id, presence: true
  validates :sequence, presence: true

  scope :for_message, ->(message_id) { where(source_message_id: message_id) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :ordered, -> { order(:session_id, :sequence, :id) }
  scope :decisions, -> { where(event_type: DECISION_EVENT_TYPES) }
  scope :by_event_types, ->(types) { where(event_type: Array(types).map(&:to_s).reject(&:blank?)) }
end
