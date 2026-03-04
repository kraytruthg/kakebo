class Budget::CategoryTransactionsController < ApplicationController
  before_action :set_category

  def index
    @year  = params[:year].to_i
    @month = params[:month].to_i

    unless @year.between?(2000, 2099) && @month.between?(1, 12)
      redirect_to budget_path and return
    end

    @accounts = Current.household.accounts.active.order(:name)
    @selected_account = params[:account_id].present? ?
                          Current.household.accounts.find_by(id: params[:account_id]) : nil

    base_query = category_transactions_scope
                  .preload(:account, :category)
                  .then { |q| @selected_account ? q.where(account_id: @selected_account.id) : q }

    @pagy, @transactions = pagy(base_query)

    compute_running_balances unless @selected_account
  end

  private

  def category_transactions_scope
    Transaction
      .joins(:account, category: :category_group)
      .where(category_id: @category.id)
      .where(category_groups: { household_id: Current.household.id })
      .recent
  end

  def compute_running_balances
    current_entry = BudgetEntry.find_by(
      category: @category,
      year: @year,
      month: @month
    )
    current_available = current_entry&.available || 0

    if @pagy.page > 1
      newer_ids = category_transactions_scope.limit(@pagy.offset).select(:id)
      newer_sum = Transaction.where(id: newer_ids).sum(:amount)
    else
      newer_sum = 0
    end

    balance = current_available - newer_sum
    @running_balances = {}
    @transactions.each do |tx|
      @running_balances[tx.id] = balance
      balance -= tx.amount
    end
  end

  def set_category
    @category = Category
                  .joins(:category_group)
                  .where(category_groups: { household_id: Current.household.id })
                  .find_by(id: params[:category_id])
    redirect_to(budget_path) and return unless @category
  end
end
