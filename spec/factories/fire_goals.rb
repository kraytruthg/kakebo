FactoryBot.define do
  factory :fire_goal do
    association :household
    withdrawal_rate { 4.0 }
    expected_return_rate { 7.0 }
  end
end
