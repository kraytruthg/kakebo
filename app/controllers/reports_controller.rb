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
end
