class Household < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :category_groups, dependent: :destroy

  def ready_to_assign(year, month)
    total_budget_balance = accounts.budget.active.sum(:balance)
    total_available = category_groups
                        .joins(categories: :budget_entries)
                        .where(budget_entries: { year: year, month: month })
                        .sum("budget_entries.carried_over + budget_entries.budgeted")
    # activity 部分透過 transactions 計算
    total_activity = Transaction
                       .joins(:account, :category)
                       .where(accounts: { household_id: id, account_type: "budget" })
                       .where("EXTRACT(year FROM transactions.date) = ?", year)
                       .where("EXTRACT(month FROM transactions.date) = ?", month)
                       .sum(:amount)

    total_budget_balance - total_available - total_activity
  end
end
