class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update ]

  def index
    @budget_accounts = Current.household.accounts.budget.active.order(:name)
    @tracking_accounts = Current.household.accounts.tracking.active.order(:name)
  end

  def show
    @transactions = @account.transactions.includes(:category, transfer_pair: :account).recent.limit(50)
    @new_transaction = Transaction.new(account: @account, date: Date.today)
  end

  def new
    @account = Account.new
  end

  def create
    @account = Current.household.accounts.build(account_params)
    if @account.save
      redirect_to accounts_path, notice: "帳戶已建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "帳戶已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :starting_balance)
  end
end
