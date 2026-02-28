FactoryBot.define do
  factory :transaction do
    association :account
    association :category
    amount { -1_000 }
    date { Date.today }
    memo { Faker::Lorem.sentence }
  end
end
