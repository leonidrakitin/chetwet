require 'rails_helper'

RSpec.describe Llm::Config do
  def upsert_installation_config(name, value)
    record = InstallationConfig.find_or_initialize_by(name: name)
    record.value = value
    record.locked = false
    record.save!
    record
  end

  after { described_class.reset! }

  describe '.captain_openai_api_base' do
    it 'does not double-append /v1 for OpenRouter full API path' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://openrouter.ai/api/v1')

      expect(described_class.captain_openai_api_base).to eq('https://openrouter.ai/api/v1')
    end

    it 'maps bare OpenRouter origin to /api/v1' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://openrouter.ai')

      expect(described_class.captain_openai_api_base).to eq('https://openrouter.ai/api/v1')
    end

    it 'defaults to OpenAI /v1 when endpoint unset' do
      InstallationConfig.where(name: 'CAPTAIN_OPEN_AI_ENDPOINT').delete_all

      expect(described_class.captain_openai_api_base).to eq('https://api.openai.com/v1')
    end

    it 'preserves explicit OpenAI /v1 base' do
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://api.openai.com/v1')

      expect(described_class.captain_openai_api_base).to eq('https://api.openai.com/v1')
    end
  end

  describe '.embedding_openai_credentials' do
    it 'uses main key and normalizes global endpoint when embedding endpoint unset' do
      upsert_installation_config('CAPTAIN_OPEN_AI_API_KEY', 'main-key')
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://api.example.com')
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_OPEN_AI_API_KEY').delete_all
      InstallationConfig.where(name: 'CAPTAIN_EMBEDDING_OPEN_AI_ENDPOINT').delete_all

      key, base = described_class.embedding_openai_credentials

      expect(key).to eq('main-key')
      expect(base).to eq('https://api.example.com/v1')
    end

    it 'prefers dedicated embedding key and endpoint when set' do
      upsert_installation_config('CAPTAIN_OPEN_AI_API_KEY', 'main-key')
      upsert_installation_config('CAPTAIN_OPEN_AI_ENDPOINT', 'https://openrouter.ai/api/v1')
      upsert_installation_config('CAPTAIN_EMBEDDING_OPEN_AI_API_KEY', 'emb-key')
      upsert_installation_config('CAPTAIN_EMBEDDING_OPEN_AI_ENDPOINT', 'https://api.openai.com/')

      key, base = described_class.embedding_openai_credentials

      expect(key).to eq('emb-key')
      expect(base).to eq('https://api.openai.com/v1')
    end
  end
end
