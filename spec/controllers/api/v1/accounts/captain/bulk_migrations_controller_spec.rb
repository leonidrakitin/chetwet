# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Accounts::Captain::BulkMigrationsController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def auth_headers(user)
    user.create_new_auth_token
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/bulk_migrations' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/bulk_migrations", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'returns empty array when no migrations' do
        get "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
            headers: auth_headers(admin),
            as: :json
        expect(response).to have_http_status(:success)
        expect(json_response).to eq([])
      end

      it 'returns list of migrations' do
        migration = create(:bulk_migration, account: account, captain_assistant: assistant, inbox: inbox)
        get "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
            headers: auth_headers(admin),
            as: :json
        expect(response).to have_http_status(:success)
        expect(json_response.size).to eq(1)
        expect(json_response.first[:id]).to eq(migration.id)
        expect(json_response.first[:source]).to eq('telegram')
        expect(json_response.first[:status]).to be_present
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/bulk_migrations/:id' do
    let(:migration) { create(:bulk_migration, account: account, captain_assistant: assistant, inbox: inbox) }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/captain/bulk_migrations/#{migration.id}", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'returns the migration' do
        get "/api/v1/accounts/#{account.id}/captain/bulk_migrations/#{migration.id}",
            headers: auth_headers(admin),
            as: :json
        expect(response).to have_http_status(:success)
        expect(json_response[:id]).to eq(migration.id)
        expect(json_response[:source]).to eq(migration.source)
        expect(json_response[:progress_percent]).to be >= 0
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/bulk_migrations' do
    let(:json_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/bulk_migration_sample.json'),
        'application/json'
      )
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
             params: {
               bulk_migration: {
                 source: 'telegram',
                 captain_assistant_id: assistant.id,
                 inbox_id: inbox.id,
                 file: json_file
               }
             },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      it 'creates a migration and returns 201' do
        expect do
          post "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
               headers: auth_headers(admin),
               params: {
                 bulk_migration: {
                   source: 'telegram',
                   captain_assistant_id: assistant.id,
                   inbox_id: inbox.id,
                   file: json_file,
                   dry_run: '0'
                 }
               }
        end.to change(BulkMigration, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:id]).to be_present
        expect(json_response[:source]).to eq('telegram')
        expect(json_response[:dry_run]).to be false
      end

      it 'creates a migration with dry_run true' do
        post "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
             headers: auth_headers(admin),
             params: {
               bulk_migration: {
                 source: 'whatsapp',
                 captain_assistant_id: assistant.id,
                 inbox_id: inbox.id,
                 file: json_file,
                 dry_run: '1'
               }
             }
        expect(response).to have_http_status(:created)
        expect(json_response[:dry_run]).to be true
      end

      it 'returns 422 when file is missing' do
        post "/api/v1/accounts/#{account.id}/captain/bulk_migrations",
             headers: auth_headers(admin),
             params: {
               bulk_migration: {
                 source: 'telegram',
                 captain_assistant_id: assistant.id,
                 inbox_id: inbox.id
               }
             }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to be_present
      end
    end
  end
end
