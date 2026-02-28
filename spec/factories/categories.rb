FactoryBot.define do
  factory :category do
    association :category_group
    name { Faker::Commerce.product_name }
    sequence(:position)
  end
end
