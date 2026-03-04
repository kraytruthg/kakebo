class BudgetController < ApplicationController
  include MonthNavigable

  def index
    @household = Current.household
    BudgetEntry.initialize_month!(@household, @year, @month)
    @ready_to_assign = @household.ready_to_assign(@year, @month)
    @total_budgeted = BudgetEntry
                        .joins(category: { category_group: :household })
                        .where(category_groups: { household_id: @household.id }, year: @year, month: @month)
                        .sum(:budgeted)
    @category_groups = @household.category_groups.includes(categories: :budget_entries)
    @monthly_activities = Transaction
                            .joins(:account, category: { category_group: :household })
                            .where(accounts: { account_type: "budget" })
                            .where(category_groups: { household_id: @household.id })
                            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                            .group(:category_id)
                            .sum(:amount)
  end

  def copy_from_previous
    year  = params[:year].to_i
    month = params[:month].to_i
    prev_year  = month == 1 ? year - 1 : year
    prev_month = month == 1 ? 12 : month - 1

    categories = Current.household.category_groups
                        .includes(:categories)
                        .flat_map(&:categories)

    copied_count = 0
    categories.each do |category|
      prev_entry = BudgetEntry.find_by(category_id: category.id, year: prev_year, month: prev_month)
      next unless prev_entry&.budgeted&.nonzero?

      current_entry = BudgetEntry.find_or_initialize_by(
        category_id: category.id, year: year, month: month
      )
      next if current_entry.persisted? && current_entry.budgeted.nonzero?

      current_entry.budgeted = prev_entry.budgeted
      current_entry.save!
      next_date = Date.new(year, month, 1).next_month
      BudgetEntryRecalculationJob.perform_later(category.id, next_date.year, next_date.month)
      copied_count += 1
    end

    if copied_count > 0
      redirect_to budget_path(year: year, month: month),
                  notice: "已從 #{prev_month} 月複製 #{copied_count} 個類別的預算"
    else
      redirect_to budget_path(year: year, month: month), alert: "上月無預算可複製"
    end
  end
end
