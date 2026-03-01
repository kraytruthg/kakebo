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

    @transactions = Transaction
                      .joins(:account, category: :category_group)
                      .preload(:account, :category)
                      .where(category_id: @category.id)
                      .where(category_groups: { household_id: Current.household.id })
                      .for_month(@year, @month)
                      .then { |q| @selected_account ? q.where(account_id: @selected_account.id) : q }
                      .recent

    @total = @transactions.sum(:amount)
  end

  private

  def set_category
    @category = Category
                  .joins(:category_group)
                  .where(category_groups: { household_id: Current.household.id })
                  .find_by(id: params[:category_id])
    redirect_to budget_path unless @category
  end
end
