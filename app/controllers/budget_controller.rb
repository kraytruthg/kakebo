class BudgetController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @household = Current.household
    @ready_to_assign = @household.ready_to_assign(@year, @month)
    @category_groups = @household.category_groups.includes(categories: :budget_entries)
  end
end
