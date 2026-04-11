FactoryBot.define do
  factory :campaign_delivery do
    campaign { nil }
    account { nil }
    contact { nil }
    conversation { nil }
    status { 'MyString' }
    trigger_type { 'MyString' }
    sent_at { '2026-04-11 09:41:47' }
    metadata { '' }
  end
end
