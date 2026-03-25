require 'rails_helper'

RSpec.describe Captain::PerformanceAnalyticsService do
  let(:account_id) { create(:account).id }
  let(:time_range) { 24.hours.ago..Time.current }
  let(:service) { described_class.new(account_id: account_id, time_range: time_range) }

  describe '#analytics' do
    it 'returns analytics hash with expected keys' do
      result = service.analytics

      expect(result).to have_key(:total_requests)
      expect(result).to have_key(:average_latency_ms)
      expect(result).to have_key(:tokens_used)
      expect(result).to have_key(:model_distribution)
      expect(result).to have_key(:reasoning_usage)
      expect(result).to have_key(:error_rate)
      expect(result).to have_key(:average_cost)
    end

    it 'returns tokens summary with expected structure' do
      result = service.analytics
      tokens = result[:tokens_used]

      expect(tokens).to have_key(:input)
      expect(tokens).to have_key(:output)
      expect(tokens).to have_key(:cache_read)
      expect(tokens).to have_key(:cache_creation)
      expect(tokens).to have_key(:reasoning)
    end

    it 'returns model distribution' do
      result = service.analytics
      distribution = result[:model_distribution]

      expect(distribution).to have_key('glm-5')
      expect(distribution).to have_key('glm-4.6')
      expect(distribution).to have_key('glm-4.6v')
    end
  end

  describe '#cost_breakdown' do
    it 'returns cost by model' do
      result = service.cost_breakdown

      expect(result).to have_key(:glm_5)
      expect(result).to have_key(:glm_4_6)
      expect(result).to have_key(:glm_ocr)
      expect(result).to have_key(:glm_asr)
    end
  end

  describe '#top_models' do
    it 'returns array of top models' do
      result = service.top_models(limit: 5)
      expect(result).to be_a(Array)
    end
  end
end
