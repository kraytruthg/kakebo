class ReportsController < ApplicationController
  include MonthNavigable

  def index
    @household = Current.household
    @spending_by_category = Transaction
                  .joins(:account, category: { category_group: :household })
                  .where(accounts: { account_type: "budget" })
                  .where(category_groups: { household_id: @household.id })
                  .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                  .where("amount < 0")
                  .group("categories.name")
                  .sum(:amount)
                  .transform_values { |v| -v }
                  .sort_by { |_, v| -v }
  end

  def fire
    @household = Current.household
    @fire_goal = @household.fire_goal || @household.build_fire_goal
    @net_worth_series = @household.monthly_net_worth_series
  end

  def financial_overview
    @household = Current.household
    @net_worth = @household.net_worth
    today = Date.current
    @savings_rate_month = @household.savings_rate(today.year, today.month)
    @savings_rate_year = @household.annual_savings_rate(today.year)
    @net_worth_series = @household.monthly_net_worth_series
    @income_expense_series = monthly_income_expense_series
  end

  private

  def monthly_income_expense_series
    household = Current.household
    earliest = household.transactions.minimum(:date)
    return { income: {}, expense: {} } unless earliest

    income_data = {}
    expense_data = {}
    current = earliest.beginning_of_month
    today = Date.current

    while current <= today
      year = current.year
      month = current.month
      key = "#{year}-#{month.to_s.rjust(2, '0')}"

      txns = household.budget_transactions.for_month(year, month)

      income_data[key] = txns.income.where(transfer_pair_id: nil).sum(:amount).abs
      expense_data[key] = txns.expense.sum(:amount).abs

      current = current.next_month
    end

    { income: income_data, expense: expense_data }
  end
end
