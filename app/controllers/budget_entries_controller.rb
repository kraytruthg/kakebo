class BudgetEntriesController < ApplicationController
  before_action :set_category_and_entry

  def edit; end

  def create
    @entry.budgeted = budget_entry_params[:budgeted]

    if @entry.save
      @activity        = @entry.activity
      @available       = @entry.available
      @ready_to_assign = Current.household.ready_to_assign(@year, @month)
      @total_budgeted  = BudgetEntry
                           .joins(category: { category_group: :household })
                           .where(category_groups: { household_id: Current.household.id }, year: @year, month: @month)
                           .sum(:budgeted)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to budget_path(year: @year, month: @month) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_category_and_entry
    p = params.key?(:budget_entry) ? budget_entry_params : params
    @category = Category.joins(:category_group)
                        .where(category_groups: { household_id: Current.household.id })
                        .find(p[:category_id])
    @year  = p[:year].to_i
    @month = p[:month].to_i
    @entry = BudgetEntry.find_or_initialize_by(
      category_id: @category.id, year: @year, month: @month
    )
  end

  def budget_entry_params
    params.require(:budget_entry).permit(:category_id, :year, :month, :budgeted)
  end
end
