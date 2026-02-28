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

  def create
    @category = Category.joins(:category_group)
                        .where(category_groups: { household_id: Current.household.id })
                        .find(budget_entry_params[:category_id])
    @year  = budget_entry_params[:year].to_i
    @month = budget_entry_params[:month].to_i
    @entry = BudgetEntry.find_or_initialize_by(
      category_id: @category.id, year: @year, month: @month
    )
    @entry.budgeted = budget_entry_params[:budgeted]

    if @entry.save
      @activity  = Transaction
                     .joins(:account, category: { category_group: :household })
                     .where(accounts: { account_type: "budget" })
                     .where(category_groups: { household_id: Current.household.id })
                     .where(category_id: @category.id)
                     .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?",
                            @year, @month)
                     .sum(:amount)
      @available = (@entry.carried_over || 0) + @entry.budgeted + @activity

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to budget_path(year: @year, month: @month) }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def budget_entry_params
    params.require(:budget_entry).permit(:category_id, :year, :month, :budgeted)
  end
end
