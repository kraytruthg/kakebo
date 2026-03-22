FactoryBot.define do
  factory :balance_snapshot do
    association :account
    balance { 10000 }
    date { Date.current }
  end
end
