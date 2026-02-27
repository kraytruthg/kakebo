FactoryBot.define do
  factory :household do
    name { "#{Faker::Name.last_name} 家" }
  end
end
