class BalanceSnapshotsController < ApplicationController
  before_action :set_account

  def new
    @balance_snapshot = @account.balance_snapshots.build(date: Date.current)
  end

  def create
    @balance_snapshot = @account.balance_snapshots.build(balance_snapshot_params)

    if @balance_snapshot.save
      redirect_to accounts_path, notice: "餘額已更新"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Current.household.accounts.tracking.find(params[:account_id])
  end

  def balance_snapshot_params
    params.require(:balance_snapshot).permit(:balance, :date, :note)
  end
end
