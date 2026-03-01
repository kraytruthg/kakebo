FactoryBot.define do
  factory :budget_entry do
    association :category
    year         { Date.today.year }
    month        { Date.today.month }
    budgeted { 0 }
    carried_over { 0 }
  end
end
