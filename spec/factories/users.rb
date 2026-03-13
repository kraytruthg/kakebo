FactoryBot.define do
  factory :user do
    transient do
      household { nil }
    end

    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { "password123" }

    after(:build) do |user, evaluator|
      if evaluator.household
        user.household_memberships.build(household: evaluator.household, role: "owner")
      end
    end
  end
end
