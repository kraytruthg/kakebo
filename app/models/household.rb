class Household < ApplicationRecord
  include NetWorthCalculation
  include SavingsCalculation
  has_many :household_memberships, dependent: :destroy
  has_many :users, through: :household_memberships
  has_many :accounts, dependent: :destroy
  has_many :transactions, through: :accounts
  has_many :category_groups, dependent: :destroy
  has_many :quick_entry_mappings, dependent: :destroy
  has_one :fire_goal, dependent: :destroy

  def actual_annual_expense
    budget_transactions
      .where("date > ?", 12.months.ago)
      .expense.sum(:amount).abs
  end

  def average_monthly_saving(recent_months)
    total = 0
    current = Date.current
    recent_months.times do |i|
      d = current - (i + 1).months
      txns = budget_transactions.for_month(d.year, d.month)
      income = txns.income.where(transfer_pair_id: nil).sum(:amount).abs
      expense = txns.expense.sum(:amount).abs
      total += (income - expense)
    end
    total / recent_months
  end

  def ready_to_assign(year, month)
    total_budget_balance = accounts.budget.active.sum(:balance)

    entries = BudgetEntry
                .joins(category: { category_group: :household })
                .where(category_groups: { household_id: id }, year: year, month: month)

    total_available = entries.sum { |e| e.available }

    total_budget_balance - total_available
  end
end
