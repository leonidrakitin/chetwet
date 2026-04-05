# frozen_string_literal: true

module LlmConstants
  DEFAULT_MODEL = 'gpt-4.1'
  DEFAULT_EMBEDDING_MODEL = 'text-embedding-3-small'
  # OpenRouter often returns "No successful provider responses" for text-embedding-3-small; ada-002 is reliably routed (1536-dim).
  OPENROUTER_DEFAULT_EMBEDDING_MODEL = 'text-embedding-ada-002'
  PDF_PROCESSING_MODEL = 'gpt-4.1-mini'

  OPENAI_API_ENDPOINT = 'https://api.openai.com'

  PROVIDER_PREFIXES = {
    'openai' => %w[gpt- o1 o3 o4 text-embedding- whisper- tts-],
    'cohere' => %w[rerank- command- embed-],
    'anthropic' => %w[claude-],
    'google' => %w[gemini-],
    'mistral' => %w[mistral- codestral-],
    'deepseek' => %w[deepseek-]
  }.freeze
end
