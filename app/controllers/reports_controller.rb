class ReportsController < ApplicationController
  include MonthNavigable

  def index
    @household = Current.household
    @expenses = Transaction
                  .joins(:account, category: { category_group: :household })
                  .where(accounts: { account_type: "budget" })
                  .where(category_groups: { household_id: @household.id })
                  .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                  .group("categories.name")
                  .sum(:amount)
                  .sort_by { |_, v| v }.reverse
  end
end
