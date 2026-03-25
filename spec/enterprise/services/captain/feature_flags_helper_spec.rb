require 'rails_helper'

RSpec.describe Captain::FeatureFlagsHelper do
  describe '.zai_provider_enabled?' do
    it 'returns false when no config' do
      expect(described_class.zai_provider_enabled?(1)).to be(false)
    end

    it 'returns true when configured' do
      InstallationConfig.create(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED', value: 'true')
      expect(described_class.zai_provider_enabled?(1)).to be(true)
    end

    it 'returns false for nil account_id' do
      expect(described_class.zai_provider_enabled?(nil)).to be(false)
    end
  end

  describe '.use_zai_for_account?' do
    let(:account) { create(:account) }

    context 'when Z.AI not enabled' do
      it 'returns false' do
        expect(described_class.use_zai_for_account?(account)).to be(false)
      end
    end

    context 'when Z.AI enabled and account in rollout' do
      before do
        InstallationConfig.create(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED', value: 'true')
        InstallationConfig.create(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE', value: '100')
      end

      it 'returns true' do
        expect(described_class.use_zai_for_account?(account)).to be(true)
      end
    end
  end

  describe '.zai_rollout_percentage' do
    it 'returns 0 by default' do
      expect(described_class.zai_rollout_percentage).to eq(0)
    end

    it 'returns configured percentage' do
      InstallationConfig.create(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE', value: '50')
      expect(described_class.zai_rollout_percentage).to eq(50)
    end
  end

  describe '.account_in_rollout?' do
    it 'always returns true at 100%' do
      InstallationConfig.create(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE', value: '100')
      expect(described_class.account_in_rollout?(1)).to be(true)
    end

    it 'uses consistent bucketing' do
      InstallationConfig.create(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE', value: '50')

      result1 = described_class.account_in_rollout?(1)
      result2 = described_class.account_in_rollout?(1)

      expect(result1).to eq(result2)
    end
  end

  describe '.enable_zai_provider!' do
    it 'creates or updates config' do
      described_class.enable_zai_provider!

      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_PROVIDER_ENABLED')
      expect(config.value).to eq('true')
    end
  end

  describe '.set_rollout_percentage' do
    it 'validates percentage' do
      expect do
        described_class.set_rollout_percentage(101)
      end.to raise_error(ArgumentError)
    end

    it 'sets valid percentage' do
      described_class.set_rollout_percentage(25)

      config = InstallationConfig.find_by(name: 'CAPTAIN_ZAI_ROLLOUT_PERCENTAGE')
      expect(config.value.to_i).to eq(25)
    end
  end

  describe '.rollout_stages' do
    it 'returns predefined stages' do
      stages = described_class.rollout_stages

      expect(stages).to have_key(:testing)
      expect(stages).to have_key(:beta)
      expect(stages).to have_key(:general)
      expect(stages[:general]).to eq(100)
    end
  end
end
