FactoryBot.define do
  factory :category_group do
    association :household
    name { Faker::Commerce.department }
    sequence(:position)
  end
end
