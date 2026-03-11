FactoryBot.define do
  factory :api_token do
    association :user
    token { SecureRandom.hex(32) }
    name { "Test Token" }
  end
end
