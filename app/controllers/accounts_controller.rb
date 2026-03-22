class AccountsController < ApplicationController
  include TransactionFilterable

  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @budget_accounts = Current.household.accounts.budget.active.order(:name)
    @asset_accounts = Current.household.accounts.tracking_asset.active.includes(:balance_snapshots).order(:name)
    @liability_accounts = Current.household.accounts.tracking_liability.active.includes(:balance_snapshots).order(:name)
  end

  def show
    @transaction_count = @account.transactions.count
    scope = @account.transactions
              .includes(:category, transfer_pair: :account)
              .recent

    scope = apply_transaction_filters(scope)

    @pagy, @transactions = pagy(scope)
    load_category_filter_options
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

  def destroy
    @account.destroy!
    redirect_to accounts_path, notice: "帳戶已刪除"
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :starting_balance, :investable)
  end
end
