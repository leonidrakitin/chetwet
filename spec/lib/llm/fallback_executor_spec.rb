require 'rails_helper'

RSpec.describe Llm::FallbackExecutor do
  describe '.execute' do
    let(:provider_chain) { [:openai, :deepseek] }

    context 'when first provider succeeds' do
      it 'returns the result without trying fallback' do
        result = described_class.execute(provider_chain: provider_chain) do |_ctx, provider|
          "success from #{provider}"
        end

        expect(result).to eq('success from openai')
      end
    end

    context 'when first provider fails' do
      it 'tries the next provider' do
        call_count = 0
        result = described_class.execute(provider_chain: provider_chain) do |_ctx, provider|
          call_count += 1
          raise RubyLLM::Error, 'API error' if provider == :openai

          "success from #{provider}"
        end

        expect(result).to eq('success from deepseek')
        expect(call_count).to eq(2)
      end
    end

    context 'when all providers fail' do
      it 'raises AllProvidersFailedError' do
        expect do
          described_class.execute(provider_chain: provider_chain) do
            raise RubyLLM::Error, 'API error'
          end
        end.to raise_error(Llm::FallbackExecutor::AllProvidersFailedError, /All providers failed/)
      end
    end

    context 'with default provider chain' do
      before do
        allow(Llm::Config).to receive(:provider_chain).and_return([:openai])
      end

      it 'uses Llm::Config.provider_chain' do
        result = described_class.execute do |_ctx, provider|
          "default chain #{provider}"
        end

        expect(result).to eq('default chain openai')
      end
    end
  end
end
