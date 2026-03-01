class TransfersController < ApplicationController
  def new
    @accounts = Current.household.accounts.active.order(:name)
    @from_account_id = params[:from_account_id]
  end

  def create
    # Task 4 實作
  end

  def destroy
    # Task 6 實作
  end
end
