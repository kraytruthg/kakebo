class TransactionsController < ApplicationController
  before_action :set_account

  def create
    @transaction = @account.transactions.build(transaction_params)
    if @transaction.save
      @account.recalculate_balance!
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

  def destroy
    transaction = @account.transactions.find(params[:id])
    transaction.destroy
    @account.recalculate_balance!
    redirect_to account_path(@account), notice: "交易已刪除"
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:account_id])
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
