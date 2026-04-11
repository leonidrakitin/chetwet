FactoryBot.define do
  factory :campaign do
    account { nil }
    inbox { nil }
    yclients_integration { nil }
    name { 'MyString' }
    description { 'MyText' }
    enabled { false }
    schedule { '' }
    audience { '' }
    messages { '' }
    metadata { '' }
  end
end
