FactoryBot.define do
  factory :quick_entry_mapping do
    association :household
    association :target, factory: :category
    keyword { Faker::Commerce.product_name }
  end
end
