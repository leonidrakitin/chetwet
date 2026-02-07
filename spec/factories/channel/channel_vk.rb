FactoryBot.define do
  factory :channel_vk, class: 'Channel::Vk' do
    group_id { '123456789' }
    access_token { 'vk_access_token' }
    secret { 'vk_secret' }
    account

    before(:create) do |channel_vk|
      channel_vk.define_singleton_method(:ensure_valid_credentials) { nil }
    end

    after(:create) do |channel_vk|
      create(:inbox, channel: channel_vk, account: channel_vk.account)
    end
  end
end
