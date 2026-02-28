class BudgetController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @household = Current.household
    @ready_to_assign = @household.ready_to_assign(@year, @month)
    @category_groups = @household.category_groups.includes(categories: :budget_entries)
    @monthly_activities = Transaction
                            .joins(:account, category: { category_group: :household })
                            .where(accounts: { account_type: "budget" })
                            .where(category_groups: { household_id: @household.id })
                            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                            .group(:category_id)
                            .sum(:amount)
  end
end
