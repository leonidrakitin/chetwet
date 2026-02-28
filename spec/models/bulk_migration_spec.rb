# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkMigration, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:captain_assistant).class_name('Captain::Assistant') }
    it { is_expected.to belong_to(:inbox) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_inclusion_of(:source).in_array(%w[telegram whatsapp vk]) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed') }
  end

  describe '#progress_percent' do
    it 'returns 0 when total_dialogs is 0' do
      migration = build(:bulk_migration, total_dialogs: 0, processed: 0)
      expect(migration.progress_percent).to eq(0)
    end

    it 'returns rounded percentage when total_dialogs and processed are set' do
      migration = build(:bulk_migration, total_dialogs: 100, processed: 50)
      expect(migration.progress_percent).to eq(50.0)
    end
  end

  describe 'file validation' do
    it 'requires file to be attached' do
      account = create(:account)
      assistant = create(:captain_assistant, account: account)
      inbox = create(:inbox, account: account)
      migration = described_class.new(
        account: account,
        captain_assistant: assistant,
        inbox: inbox,
        source: 'telegram'
      )
      migration.validate
      expect(migration.errors[:file]).to be_present
    end
  end
end
