# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkMigrationJob, type: :job do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:migration) do
    create(:bulk_migration, account: account, captain_assistant: assistant, inbox: inbox, dry_run: true)
  end

  let(:fake_parser) { instance_double(Parsers::TelegramParser, parse: [], stats: { total_chats: 0 }) }

  before do
    allow(Parsers::TelegramParser).to receive(:new).and_return(fake_parser)
    allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess).and_return([])
    allow_any_instance_of(BulkMigrationReportService).to receive(:deliver!)
  end

  describe '#perform' do
    it 'updates migration status to processing then completed' do
      described_class.perform_now(migration.id, { dry_run: true })

      migration.reload
      expect(migration.status).to eq('completed')
      expect(migration.report['summary']).to include('DRY-RUN')
      expect(migration.report['dry_run']).to be true
    end

    it 'sets status to :processing and records started_at before running' do
      statuses = []
      started_ats = []

      allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess) do
        migration.reload
        statuses << migration.status
        started_ats << migration.started_at
        []
      end

      described_class.perform_now(migration.id, { dry_run: true })

      expect(statuses).to include('processing')
      expect(started_ats.first).to be_present
    end

    it 'does not import when dry_run is true' do
      allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess).and_return([{ messages: [] }])

      expect_any_instance_of(ConversationImporterService).not_to receive(:import!)

      described_class.perform_now(migration.id, { dry_run: true })
    end

    it 'sets status to :failed and saves error message to report on StandardError' do
      allow_any_instance_of(ConversationPreprocessorService).to receive(:preprocess).and_raise(StandardError, 'Boom!')

      expect { described_class.perform_now(migration.id, { dry_run: true }) }.to raise_error(StandardError, 'Boom!')

      migration.reload
      expect(migration.status).to eq('failed')
      expect(migration.report['error']).to eq('Boom!')
    end

    context 'when migration is already completed' do
      before { migration.update!(status: 'completed') }

      it 'returns without running' do
        expect_any_instance_of(ConversationPreprocessorService).not_to receive(:preprocess)

        described_class.perform_now(migration.id)
      end
    end

    context 'with build_final_report' do
      it 'report contains parser_stats, preprocess_stats, import_stats and total_faqs_generated' do
        described_class.perform_now(migration.id, { dry_run: true })

        migration.reload
        report = migration.report
        expect(report).to include('parser_stats', 'preprocess_stats', 'import_stats', 'total_faqs_generated')
      end
    end
  end

  describe '#parser_for' do
    let(:job) { described_class.new }

    it 'returns Parsers::TelegramParser for telegram' do
      expect(job.send(:parser_for, 'telegram')).to eq(Parsers::TelegramParser)
    end

    it 'returns Parsers::WhatsAppParser for whatsapp' do
      expect(job.send(:parser_for, 'whatsapp')).to eq(Parsers::WhatsAppParser)
    end

    it 'returns Parsers::VkParser for vk or vkontakte' do
      expect(job.send(:parser_for, 'vk')).to eq(Parsers::VkParser)
      expect(job.send(:parser_for, 'vkontakte')).to eq(Parsers::VkParser)
    end

    it 'raises ArgumentError for unknown source' do
      expect { job.send(:parser_for, 'unknown_source') }.to raise_error(ArgumentError)
    end
  end

  describe '#process_batch_import' do
    let(:job) { described_class.new }
    let(:dialog) { { external_id: 'ext-1', messages: [] } }

    before { migration.update!(status: 'processing', total_dialogs: 3) }

    it 'broadcasts progress via ActionCable after each batch' do
      importer = instance_double(ConversationImporterService, import!: { success: true, faqs_generated: 0 })
      allow(ConversationImporterService).to receive(:new).and_return(importer)

      expect(ActionCable.server).to receive(:broadcast).at_least(:once)

      job.send(:process_batch_import, [dialog, dialog, dialog], inbox, migration)
    end

    it 'correctly counts imported vs skipped' do
      success_importer = instance_double(ConversationImporterService, import!: { success: true, faqs_generated: 0 })
      failure_importer = instance_double(ConversationImporterService, import!: { success: false, faqs_generated: 0 })

      call_count = 0
      allow(ConversationImporterService).to receive(:new) do
        call_count += 1
        call_count == 1 ? success_importer : failure_importer
      end

      result = job.send(:process_batch_import, [dialog, dialog, dialog], inbox, migration)
      expect(result[:imported]).to eq(1)
      expect(result[:skipped]).to eq(2)
    end

    it 'sums faqs_generated correctly across dialogs' do
      importer = instance_double(ConversationImporterService, import!: { success: true, faqs_generated: 3 })
      allow(ConversationImporterService).to receive(:new).and_return(importer)

      result = job.send(:process_batch_import, [dialog, dialog], inbox, migration)
      expect(result[:faqs_generated]).to eq(6)
    end
  end
end
