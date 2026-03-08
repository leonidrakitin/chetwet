FactoryBot.define do
  factory :yclients_integration do
    account
    sequence(:salon_id) { |n| 1000 + n }
    bearer_token { 'bearer-token' }
    connected_at { Time.current }
    status { :active }
    system_user_id { 'system-user-id' }
  end
end
