FactoryBot.define do
  factory :household_membership do
    association :user
    association :household
    role { "owner" }
  end
end
