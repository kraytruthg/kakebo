class TransfersController < ApplicationController
  def new
    @accounts = Current.household.accounts.active.order(:name)
    @from_account_id = params[:from_account_id]
  end

  def create
    from_account = Current.household.accounts.find(params[:from_account_id])
    to_account   = Current.household.accounts.find(params[:to_account_id])
    amount       = params[:amount].to_d
    date         = params[:date]
    memo         = params[:memo].presence

    if from_account.id == to_account.id
      @error = "來源與目標帳戶不可相同"
      @accounts = Current.household.accounts.active.order(:name)
      @from_account_id = params[:from_account_id]
      return render :new, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      outgoing = from_account.transactions.create!(
        amount: -amount, date: date, memo: memo, category_id: nil
      )
      incoming = to_account.transactions.create!(
        amount: amount, date: date, memo: memo, category_id: nil,
        transfer_pair_id: outgoing.id
      )
      outgoing.update!(transfer_pair_id: incoming.id)
    end

    from_account.recalculate_balance!
    to_account.recalculate_balance!
    redirect_to account_path(from_account), notice: "轉帳已建立"
  rescue ActiveRecord::RecordInvalid => e
    @error = e.message
    @accounts = Current.household.accounts.active.order(:name)
    @from_account_id = params[:from_account_id]
    render :new, status: :unprocessable_entity
  end

  def destroy
    transaction = Transaction
                    .joins(:account)
                    .where(accounts: { household_id: Current.household.id })
                    .find(params[:id])

    pair         = transaction.transfer_pair
    from_account = transaction.account
    to_account   = pair&.account

    transaction.destroy
    pair&.destroy
    from_account.recalculate_balance!
    to_account&.recalculate_balance!

    redirect_back_or_to accounts_path, notice: "轉帳已刪除"
  end
end
