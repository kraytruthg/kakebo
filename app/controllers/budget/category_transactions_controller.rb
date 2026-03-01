class Budget::CategoryTransactionsController < ApplicationController
  def index
    @category = Category
                  .joins(:category_group)
                  .where(category_groups: { household_id: Current.household.id })
                  .find(params[:category_id])

    @year  = params[:year].to_i
    @month = params[:month].to_i

    @accounts = Current.household.accounts.active.order(:name)
    @selected_account = params[:account_id].present? ?
                          Current.household.accounts.find_by(id: params[:account_id]) : nil

    @transactions = Transaction
                      .joins(:account, category: :category_group)
                      .where(category_id: @category.id)
                      .where(category_groups: { household_id: Current.household.id })
                      .for_month(@year, @month)
                      .then { |q| @selected_account ? q.where(account_id: @selected_account.id) : q }
                      .recent

    @total = @transactions.sum(:amount)
  end
end
