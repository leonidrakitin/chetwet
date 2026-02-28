# frozen_string_literal: true

FactoryBot.define do
  factory :bulk_migration do
    account
    association :captain_assistant, factory: :captain_assistant
    inbox
    source { 'telegram' }
    dry_run { false }

    after(:build) do |migration|
      next if migration.file.attached?

      migration.file.attach(
        io: Rails.root.join('spec/fixtures/files/bulk_migration_sample.json').open,
        filename: 'bulk_migration_sample.json',
        content_type: 'application/json'
      )
    end
  end
end
