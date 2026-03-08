# frozen_string_literal: true

class Captain::Tools::YclientsGetTransactionsTool < Captain::Tools::YclientsBaseTool
  description 'Get financial transaction history for the current contact in YClients'
  param :company_id, type: 'string', desc: 'Salon/company ID when multiple YClients hooks are connected'

  def perform(tool_context, company_id: nil, **)
    hook = yclients_hook(state: tool_context.state, company_id: company_id)
    return missing_hook_message if hook.blank?

    yclients_id = find_yclients_client_id(tool_context.state, hook: hook)
    return 'Contact is not linked to a YClients client' unless yclients_id

    records = records_client_for(hook).get_by_client(yclients_id)
    return 'No records found for this client' if records.blank?

    transactions = Crm::Yclients::Mappers::RecordMapper.extract_transactions(records)
    return 'No transactions found' if transactions.blank?

    format_transactions(transactions, Crm::Yclients::HookResolver.company_id_for(hook))
  rescue Crm::Yclients::Api::BaseClient::ApiError => e
    "YClients API error: #{e.message}"
  end

  private

  def format_transactions(transactions, company_id)
    lines = transactions.first(20).map do |t|
      "- #{t['date']}: #{t['title'] || 'Payment'} — #{t['amount']} rub (#{t['type'] || 'record'})"
    end

    "Transactions for company #{company_id} (#{transactions.size}):\n#{lines.join("\n")}"
  end
end
