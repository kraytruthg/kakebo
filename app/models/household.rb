class Household < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :users, through: :household_memberships
  has_many :accounts, dependent: :destroy
  has_many :category_groups, dependent: :destroy
  has_many :quick_entry_mappings, dependent: :destroy
  belongs_to :default_account, class_name: "Account", optional: true

  def ready_to_assign(year, month)
    total_budget_balance = accounts.budget.active.sum(:balance)

    entries = BudgetEntry
                .joins(category: { category_group: :household })
                .where(category_groups: { household_id: id }, year: year, month: month)

    total_available = entries.sum { |e| e.available }

    total_budget_balance - total_available
  end
end
