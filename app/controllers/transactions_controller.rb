class TransactionsController < ApplicationController
  before_action :set_account
  before_action :set_transaction, only: [:edit, :update, :destroy]
  before_action :set_categories, only: [:edit, :update]

  def create
    @transaction = @account.transactions.build(transaction_params)
    if @transaction.save
      @account.recalculate_balance!
      set_budget_data_for_turbo_stream
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to account_path(@account), notice: "交易已新增" }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to account_path(@account), alert: "請填寫必要欄位" }
      end
    end
  end

  def edit
  end

  def update
    if @transaction.update(transaction_params)
      @account.recalculate_balance!
      redirect_back_or_to account_path(@account), notice: "交易已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    @account.recalculate_balance!
    redirect_back_or_to account_path(@account), notice: "交易已刪除"
  end

  private

  def set_categories
    @categories = Current.household.category_groups.includes(:categories)
  end

  def set_budget_data_for_turbo_stream
    return unless @transaction.category_id.present?

    year  = @transaction.date.year
    month = @transaction.date.month

    @budget_activity = Transaction
                         .joins(:account, category: { category_group: :household })
                         .where(accounts: { account_type: "budget" })
                         .where(category_groups: { household_id: Current.household.id })
                         .where(category_id: @transaction.category_id)
                         .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?",
                                year, month)
                         .sum(:amount)

    @budget_entry     = BudgetEntry.find_by(
      category_id: @transaction.category_id, year: year, month: month
    )
    @budget_available = (@budget_entry&.carried_over || 0) +
                        (@budget_entry&.budgeted || 0) +
                        @budget_activity
  end

  def set_account
    @account = Current.household.accounts.find(params[:account_id])
  end

  def set_transaction
    @transaction = @account.transactions.find(params[:id])
  end

  def transaction_params
    p = params.require(:transaction).permit(:category_id, :amount, :date, :memo)
    if p[:category_id].present?
      Category.joins(:category_group)
              .where(category_groups: { household_id: Current.household.id })
              .find(p[:category_id])
    end
    p
  end
end
