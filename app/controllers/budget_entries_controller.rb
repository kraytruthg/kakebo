class BudgetEntriesController < ApplicationController
  def edit
    @category = Category.joins(:category_group)
                        .where(category_groups: { household_id: Current.household.id })
                        .find(params[:category_id])
    @year  = params[:year].to_i
    @month = params[:month].to_i
    @entry = BudgetEntry.find_or_initialize_by(
      category_id: @category.id, year: @year, month: @month
    )
  end
end
