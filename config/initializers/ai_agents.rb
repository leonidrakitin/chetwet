# frozen_string_literal: true

require 'agents'

Rails.application.config.after_initialize do
  # Source of truth: Llm::Config.apply_to_globals! reads CAPTAIN_PROVIDERS and configures
  # both Agents.config and (transitively) RubyLLM.config for the primary provider.
  # Note: ai-agents' Runner builds `RubyLLM::Chat.new(model: ...)` without a per-call
  # context, so the global config must reflect the user's Super Admin selection. We
  # re-apply this on every Super Admin save (see SuperAdmin::AppConfigsController) and
  # before each Captain V2 run (see AgentRunnerService).
  #
  # Scope: this only writes transport-level config (api_key/api_base). The model is
  # owned by the runtime path (Llm::Config.resolve_runtime_model + per-agent `model:`),
  # so we never set Agents.config.default_model from CAPTAIN_OPEN_AI_MODEL here.
  Llm::Config.apply_to_globals!
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end
