require 'rails_helper'

RSpec.describe Captain::Assistant, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }

  describe 'tool availability' do
    it 'filters booking tools when booking manager is not enabled' do
      tool_ids = assistant.built_in_tools_with_status.map { |tool| tool[:id] }

      expect(tool_ids).not_to include('booking_get_services')
    end

    it 'includes booking tools when booking manager is enabled' do
      create(:integrations_hook, account: account, app_id: 'booking_manager')

      tool_ids = assistant.built_in_tools_with_status.map { |tool| tool[:id] }

      expect(tool_ids).to include('booking_get_services')
    end

    it 'filters VK Market tools when VK Market is not enabled' do
      expect(assistant.available_tool_ids).not_to include('vk_market_get_products')
    end

    it 'includes VK Market tools when VK Market is enabled' do
      create(:integrations_hook, account: account, app_id: 'vk_market')

      expect(assistant.available_tool_ids).to include('vk_market_get_products')
    end
  end
end
