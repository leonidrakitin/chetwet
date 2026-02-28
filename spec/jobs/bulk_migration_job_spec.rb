# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkMigrationJob, type: :job do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:migration) do
    create(:bulk_migration, account: account, captain_assistant: assistant, inbox: inbox, dry_run: true)
  end

  before do
    allow(Parsers::TelegramParser).to receive(:new).and_return(instance_double(Parsers::TelegramParser, parse: [], stats: {}))
  end

  describe '#perform' do
    it 'updates migration status to processing then completed' do
      allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess).and_return([])

      described_class.perform_now(migration.id, { dry_run: true })

      migration.reload
      expect(migration.status).to eq('completed')
      expect(migration.report['summary']).to include('DRY-RUN')
      expect(migration.report['dry_run']).to be true
    end

    it 'does not import when dry_run is true' do
      allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess).and_return([{ messages: [] }])

      expect_any_instance_of(ConversationImporterService).not_to receive(:import!)

      described_class.perform_now(migration.id, { dry_run: true })
    end

    context 'when migration already completed' do
      before { migration.update!(status: 'completed') }

      it 'returns without running' do
        expect_any_instance_of(ConversationPreprocessorService).not_to receive(:preprocess)

        described_class.perform_now(migration.id)
      end
    end
  end
end
