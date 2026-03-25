require 'rails_helper'

RSpec.describe Captain::ClassificationSchema do
  describe 'schema properties' do
    it 'has department property with valid enums' do
      expect(described_class.properties).to have_key('department')
      schema = described_class.properties['department']
      expect(schema[:enum]).to include('sales', 'support', 'billing', 'technical', 'general')
    end

    it 'has priority property with valid enums' do
      expect(described_class.properties).to have_key('priority')
      schema = described_class.properties['priority']
      expect(schema[:enum]).to include('low', 'medium', 'high', 'urgent')
    end

    it 'has sentiment property with valid enums' do
      expect(described_class.properties).to have_key('sentiment')
      schema = described_class.properties['sentiment']
      expect(schema[:enum]).to include('negative', 'neutral', 'positive')
    end

    it 'has tags property as array' do
      expect(described_class.properties).to have_key('tags')
      schema = described_class.properties['tags']
      expect(schema[:type]).to eq('array')
    end

    it 'has language property' do
      expect(described_class.properties).to have_key('language')
    end

    it 'has requires_immediate_response as boolean' do
      expect(described_class.properties).to have_key('requires_immediate_response')
      expect(described_class.properties['requires_immediate_response'][:type]).to eq('boolean')
    end

    it 'has suggested_response_template' do
      expect(described_class.properties).to have_key('suggested_response_template')
    end
  end
end
