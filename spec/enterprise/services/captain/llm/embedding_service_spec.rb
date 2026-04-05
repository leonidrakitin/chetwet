# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Llm::EmbeddingService, type: :model do
  def upsert_installation_config(name, value)
    record = InstallationConfig.find_or_initialize_by(name: name)
    record.value = value
    record.locked = false
    record.save!
  end

  after { Llm::Config.reset! }

  describe '.resolved_embedding_model' do
    it 'uses explicit CAPTAIN_EMBEDDING_MODEL when set' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://openrouter.ai/api/v1')
      upsert_installation_config('CAPTAIN_EMBEDDING_MODEL', 'custom-embedding-model')

      expect(described_class.resolved_embedding_model).to eq('custom-embedding-model')
    end

    it 'uses OpenRouter-safe default when endpoint is OpenRouter and model unset' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://openrouter.ai/api/v1')
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_MODEL').delete_all

      expect(described_class.resolved_embedding_model).to eq(LlmConstants::OPENROUTER_DEFAULT_EMBEDDING_MODEL)
    end

    it 'uses text-embedding-3-small when not OpenRouter' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://api.openai.com/v1')
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_MODEL').delete_all

      expect(described_class.resolved_embedding_model).to eq(LlmConstants::DEFAULT_EMBEDDING_MODEL)
    end
  end
end
