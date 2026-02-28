# frozen_string_literal: true

require 'rails_helper'

# Eager load parser (eager_load is false in test)
require Rails.root.join('app/services/parsers/conversation_parser').to_s
require Rails.root.join('app/services/parsers/telegram_parser').to_s

RSpec.describe TelegramParser do
  let(:parser) { described_class.new }
  let(:fixture_path) { Rails.root.join('spec/fixtures/files/telegram_export_sample.json') }

  describe '#parse' do
    it 'returns array of unified dialogs' do
      dialogs = parser.parse(fixture_path.to_s, {})
      expect(dialogs).to be_an(Array)
      expect(dialogs.size).to be >= 0
      dialogs.each do |d|
        expect(d).to include(:external_id, :source, :contact_external_id, :contact_name, :messages)
        expect(d[:source]).to eq('telegram')
        expect(d[:messages]).to be_an(Array)
        d[:messages].each do |m|
          expect(m).to include(:external_id, :created_at, :sender_type, :content, :content_type)
        end
      end
    end

    it 'fills stats' do
      parser.parse(fixture_path.to_s, {})
      expect(parser.stats).to include(:total_chats, :processed_chats, :skipped_chats, :total_messages)
    end
  end
end
