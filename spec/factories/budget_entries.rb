FactoryBot.define do
  factory :budget_entry do
    association :category
    year { 2026 }
    month { 2 }
    budgeted { 0 }
    carried_over { 0 }
  end
end
