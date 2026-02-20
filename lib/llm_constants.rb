# frozen_string_literal: true

module LlmConstants
  DEFAULT_MODEL = 'deepseek-chat'
  DEFAULT_EMBEDDING_MODEL = 'aroxima/gte-qwen2-1.5b-instruct:q4_k_m'
  PDF_PROCESSING_MODEL = 'deepseek-chat'

  OPENAI_API_ENDPOINT = 'https://api.deepseek.com'

  PROVIDER_PREFIXES = {
    'openai' => %w[gpt- o1 o3 o4 text-embedding- whisper- tts-],
    'anthropic' => %w[claude-],
    'google' => %w[gemini-],
    'mistral' => %w[mistral- codestral-],
    'deepseek' => %w[deepseek-],
    # 'qwen' => %w[qwen-],
    'ollama' => %w[aroxima/ nomic-embed mxbai-embed bge- qwen3-]
  }.freeze
end
