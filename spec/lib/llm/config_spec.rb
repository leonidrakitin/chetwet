require 'rails_helper'

RSpec.describe Llm::Config do
  def upsert_installation_config(name, value)
    record = InstallationConfig.find_or_initialize_by(name: name)
    record.value = value
    record.locked = false
    record.save!
    record
  end

  def reset_config_cache
    described_class.send(:reset_cache)
  end

  before { reset_config_cache }

  describe '.provider_config' do
    context 'when CAPTAIN_PROVIDERS is set' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('CAPTAIN_PROVIDERS').and_return({
                                                                                          'primary_provider' => 'openai',
                                                                                          'providers' => {
                                                                                            'openai' => { 'enabled' => true, 'api_key' => 'sk-test' }
                                                                                          }
                                                                                        })
        reset_config_cache
      end

      it 'returns the stored config' do
        config = described_class.provider_config
        expect(config['primary_provider']).to eq('openai')
      end
    end

    context 'when CAPTAIN_PROVIDERS is not set' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('CAPTAIN_PROVIDERS').and_return(nil)
        allow(InstallationConfig).to receive(:find_by).and_call_original
        reset_config_cache
      end

      it 'migrates from legacy config' do
        config = described_class.provider_config
        expect(config).to be_a(Hash)
        expect(config['providers']).to be_a(Hash)
      end
    end
  end

  describe '.primary_provider' do
    before do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'primary_provider' => 'deepseek'
                                                                     })
      reset_config_cache
    end

    it 'returns the mapped provider symbol (deepseek maps to openai)' do
      expect(described_class.primary_provider).to eq(:openai)
    end
  end

  describe '.provider_chain' do
    context 'with enabled providers' do
      before do
        allow(described_class).to receive(:provider_config).and_return({
                                                                         'primary_provider' => 'openai',
                                                                         'fallback_order' => %w[deepseek qwen],
                                                                         'providers' => {
                                                                           'openai' => { 'enabled' => true, 'api_key' => 'sk-test' },
                                                                           'deepseek' => { 'enabled' => true, 'api_key' => 'sk-deep' },
                                                                           'qwen' => { 'enabled' => false, 'api_key' => '' }
                                                                         }
                                                                       })
        reset_config_cache
      end

      it 'returns enabled providers as chatwoot-name symbols (so with_provider can resolve the right config)' do
        chain = described_class.provider_chain
        expect(chain).to eq([:openai, :deepseek])
      end
    end

    context 'with a non-openai primary (zai) and openai fallback' do
      before do
        allow(described_class).to receive(:provider_config).and_return({
                                                                         'primary_provider' => 'zai',
                                                                         'fallback_order' => %w[openai],
                                                                         'providers' => {
                                                                           'zai' => { 'enabled' => true, 'api_key' => 'zai-key',
                                                                                      'api_base' => 'https://open.bigmodel.cn' },
                                                                           'openai' => { 'enabled' => true, 'api_key' => 'sk-test' }
                                                                         }
                                                                       })
        reset_config_cache
      end

      it 'preserves the chatwoot provider name so with_provider reads zai config (not openai)' do
        expect(described_class.provider_chain).to eq([:zai, :openai])

        captured = []
        described_class.with_provider(:zai) do |_ctx, chatwoot_sym, ruby_llm_sym|
          captured << [chatwoot_sym, ruby_llm_sym]
        end
        expect(captured).to eq([[:zai, :openai]])
      end
    end

    context 'with no enabled providers' do
      before do
        allow(described_class).to receive(:provider_config).and_return(nil)
        reset_config_cache
      end

      it 'returns default :openai' do
        expect(described_class.provider_chain).to eq([:openai])
      end
    end
  end

  describe '.with_provider' do
    before do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'providers' => {
                                                                         'openai' => { 'api_key' => 'sk-test', 'api_base' => 'https://api.openai.com' }
                                                                       }
                                                                     })
      reset_config_cache
    end

    it 'yields a RubyLLM context' do
      expect { |b| described_class.with_provider(:openai, &b) }.to yield_control
    end
  end

  describe '.apply_to_globals!' do
    context 'when primary is an OpenAI-compatible provider (zai)' do
      before do
        allow(described_class).to receive(:provider_config).and_return({
                                                                         'primary_provider' => 'zai',
                                                                         'providers' => {
                                                                           'zai' => { 'enabled' => true, 'api_key' => 'zai-key',
                                                                                      'api_base' => 'https://open.bigmodel.cn' }
                                                                         }
                                                                       })
        reset_config_cache
      end

      it 'writes the primary key into Agents.configuration.openai_api_key' do
        # OpenAI-compatible providers (zai/qwen/deepseek) all share the openai_* slots
        # in RubyLLM/Agents — that's why a missing key surfaces as
        # "Missing configuration for OpenAI: openai_api_key" even when zai is selected.
        described_class.apply_to_globals!

        expect(Agents.configuration.openai_api_key).to eq('zai-key')
        expect(Agents.configuration.openai_api_base).to eq('https://open.bigmodel.cn/v1')
      end
    end
  end

  describe '.ruby_llm_provider' do
    it 'maps openai to :openai' do
      expect(described_class.ruby_llm_provider('openai')).to eq(:openai)
    end

    it 'maps openrouter to :openrouter' do
      expect(described_class.ruby_llm_provider('openrouter')).to eq(:openrouter)
    end

    it 'maps deepseek to :openai (OpenAI-compatible)' do
      expect(described_class.ruby_llm_provider('deepseek')).to eq(:openai)
    end
  end

  describe '.captain_openai_api_base' do
    it 'normalizes the api base with /v1 suffix' do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'primary_provider' => 'openai',
                                                                       'providers' => {
                                                                         'openai' => { 'api_base' => 'https://custom.api.com' }
                                                                       }
                                                                     })
      reset_config_cache

      expect(described_class.captain_openai_api_base).to eq('https://custom.api.com/v1')
    end

    it 'does not double-append /v1 for OpenRouter full API path' do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'primary_provider' => 'openrouter',
                                                                       'providers' => {
                                                                         'openrouter' => { 'api_base' => 'https://openrouter.ai/api/v1' }
                                                                       }
                                                                     })
      reset_config_cache

      expect(described_class.captain_openai_api_base).to eq('https://openrouter.ai/api/v1')
    end

    it 'maps bare OpenRouter origin to /api/v1' do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'primary_provider' => 'openrouter',
                                                                       'providers' => {
                                                                         'openrouter' => { 'api_base' => 'https://openrouter.ai' }
                                                                       }
                                                                     })
      reset_config_cache

      expect(described_class.captain_openai_api_base).to eq('https://openrouter.ai/api/v1')
    end
  end

  describe '.embedding_openai_credentials' do
    it 'returns embedding credentials from config' do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'embedding' => {
                                                                         'api_key' => 'emb-key',
                                                                         'api_base' => 'https://embed.api.com'
                                                                       }
                                                                     })
      reset_config_cache

      key, base = described_class.embedding_openai_credentials
      expect(key).to eq('emb-key')
      expect(base).to eq('https://embed.api.com/v1')
    end

    it 'falls back to provider key when embedding key not set' do
      allow(described_class).to receive(:provider_config).and_return({
                                                                       'embedding' => {},
                                                                       'providers' => {
                                                                         'openai' => { 'api_key' => 'main-key', 'api_base' => 'https://api.openai.com' }
                                                                       }
                                                                     })
      reset_config_cache

      key, = described_class.embedding_openai_credentials
      expect(key).to eq('main-key')
    end
  end
end
