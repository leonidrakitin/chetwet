# frozen_string_literal: true

class Yclients::LabelsSyncJob < ApplicationJob
  queue_as :low_priority

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(account_id, hook_id = nil)
    account = Account.find(account_id)
    hook = if hook_id
             Integrations::Hook.find(hook_id)
           else
             account.hooks.find_by!(app_id: 'yclients', status: :enabled)
           end

    synced = Crm::Yclients::LabelsSyncService.new(account, hook).sync

    Rails.logger.info "YClients LabelsSyncJob: synced #{synced} categories as labels for account_id=#{account_id}"
  end
end
