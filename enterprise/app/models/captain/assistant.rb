# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :string
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
class Captain::Assistant < ApplicationRecord
  include Avatarable
  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :documents, class_name: 'Captain::Document', dependent: :destroy_async
  has_many :document_chunks, class_name: 'Captain::DocumentChunk', dependent: :destroy_async
  has_many :responses, class_name: 'Captain::AssistantResponse', dependent: :destroy_async
  has_many :captain_inboxes,
           class_name: 'CaptainInbox',
           foreign_key: :captain_assistant_id,
           dependent: :destroy_async
  has_many :inboxes,
           through: :captain_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :bulk_migrations, dependent: :destroy_async
  has_many :copilot_threads, dependent: :destroy_async
  has_many :scenarios, class_name: 'Captain::Scenario', dependent: :destroy_async

  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_document_faq_generation,
                 :feature_contact_attributes, :product_name,
                 :autonomy_max_retries, :faq_auto_answer_threshold, :faq_suggest_threshold,
                 :autonomy_self_check_enabled, :autonomy_return_to_scenario,
                 :disabled_built_in_tools,
                 :knowledge_mode, :knowledge_answer_threshold

  validates :name, presence: true
  validates :description, presence: true
  validates :account_id, presence: true
  validates :knowledge_mode, inclusion: { in: %w[balanced strict ultra_strict], allow_nil: true }

  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def available_name
    name
  end

  def available_agent_tools
    disabled_ids = disabled_built_in_tools || []
    tools = self.class.built_in_agent_tools.reject { |t| disabled_ids.include?(t[:id]) }

    custom_tools = account.captain_custom_tools.enabled.map(&:to_tool_metadata)
    tools.concat(custom_tools)

    tools
  end

  def built_in_tools_with_status
    disabled_ids = disabled_built_in_tools || []
    self.class.built_in_agent_tools.map do |tool|
      tool.merge(enabled: disabled_ids.exclude?(tool[:id]))
    end
  end

  def available_tool_ids
    available_agent_tools.pluck(:id)
  end

  def push_event_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  private

  def agent_name
    name.parameterize(separator: '_')
  end

  def agent_tools
    orchestration_subagent_tools + [
      self.class.resolve_tool_class('faq_lookup').new(self),
      self.class.resolve_tool_class('handoff').new(self)
    ]
  end

  def prompt_context
    enabled = scenarios.enabled.to_a
    scenario_entries = enabled.map do |scenario|
      key = "#{scenario.title} Agent".parameterize(separator: '_')
      "- #{scenario.title}: #{scenario.description}, use handoff_to_#{key} tool"
    end

    {
      name: name,
      description: description,
      product_name: config['product_name'] || 'this product',
      knowledge_mode: knowledge_mode,
      scenarios: enabled.map do |scenario|
        { title: scenario.title, key: scenario.handoff_key, description: scenario.description }
      end,
      scenarios_list: scenario_entries.join("\n"),
      system_tools_list: build_system_tools_list(enabled),
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def build_system_tools_list(enabled_scenarios)
    scenario_tool_ids = enabled_scenarios.flat_map { |s| s.tools || [] }.uniq
    all_built_in = self.class.built_in_agent_tools

    scenario_tool_ids.filter_map do |tool_id|
      meta = all_built_in.find { |t| t[:id] == tool_id }
      next unless meta

      "- #{tool_id}: #{meta[:description]}"
    end.join("\n")
  end

  def default_avatar_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/assets/images/dashboard/captain/logo.svg"
  end
end
