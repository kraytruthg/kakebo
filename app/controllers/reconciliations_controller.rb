class ReconciliationsController < ApplicationController
  before_action :set_account

  def new
    @transactions = @account.transactions
                            .where(status: [ :uncleared, :cleared ])
                            .includes(:category, transfer_pair: :account)
                            .order(date: :desc, created_at: :desc)
    @reconciled_balance = @account.reconciled_balance
    @cleared_sum = @account.transactions.cleared.sum(:amount)
  end

  def create
    if params[:cancel]
      @account.transactions.cleared.update_all(status: :uncleared)
      redirect_to account_path(@account), notice: "對帳已取消"
      return
    end

    bank_balance = BigDecimal(params[:bank_balance].to_s)
    cleared_sum = @account.transactions.cleared.sum(:amount)
    confirmed_balance = @account.reconciled_balance + cleared_sum
    difference = bank_balance - confirmed_balance

    if difference != 0
      redirect_to new_account_reconciliation_path(@account),
                  alert: "差額為 #{helpers.format_amount(difference)}，請檢查交易"
      return
    end

    ActiveRecord::Base.transaction do
      @account.transactions.cleared.update_all(status: :reconciled)
      @account.update!(
        reconciled_balance: bank_balance,
        last_reconciled_at: Time.current
      )
    end

    redirect_to account_path(@account), notice: "對帳完成"
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:account_id])
  end
end
