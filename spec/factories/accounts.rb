FactoryBot.define do
  factory :account do
    association :household
    name { Faker::Bank.name }
    account_type { "budget" }
    starting_balance { 0 }
    balance { 0 }
    active { true }
  end
end
