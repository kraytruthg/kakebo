class Budget::CategoryTransactionsController < ApplicationController
  before_action :set_category

  LineItem = Data.define(:date, :memo, :account_name, :amount, :type, :record)

  def index
    @year  = params[:year].to_i
    @month = params[:month].to_i

    unless @year.between?(2000, 2099) && @month.between?(1, 12)
      redirect_to budget_path and return
    end

    @accounts = Current.household.accounts.active.order(:name)
    @selected_account = params[:account_id].present? ?
                          Current.household.accounts.find_by(id: params[:account_id]) : nil

    all_items = build_line_items
    @pagy, @items = pagy_array(all_items)

    compute_running_balances(all_items) unless @selected_account
  end

  private

  def build_line_items
    transactions = category_transactions_scope
                    .preload(:account, :category)
                    .then { |q| @selected_account ? q.where(account_id: @selected_account.id) : q }
                    .to_a

    items = transactions.map do |t|
      LineItem.new(
        date: t.date,
        memo: t.memo,
        account_name: t.account.name,
        amount: t.amount,
        type: :transaction,
        record: t
      )
    end

    unless @selected_account
      BudgetEntry.where(category: @category).where.not(budgeted: 0).find_each do |be|
        items << LineItem.new(
          date: Date.new(be.year, be.month, 1),
          memo: "預算撥入",
          account_name: nil,
          amount: be.budgeted,
          type: :budget,
          record: be
        )
      end
    end

    # Sort newest first; same date: transactions before budget entries
    items.sort_by { |i| [ -i.date.to_time.to_i, i.type == :budget ? 1 : 0 ] }
  end

  def category_transactions_scope
    Transaction
      .joins(:account, category: :category_group)
      .where(category_id: @category.id)
      .where(category_groups: { household_id: Current.household.id })
      .recent
  end

  def compute_running_balances(all_items)
    latest_entry = BudgetEntry.where(category: @category)
                              .order(year: :desc, month: :desc)
                              .first
    current_available = latest_entry&.available || 0

    if @pagy.page > 1
      newer_sum = all_items.first(@pagy.offset).sum(&:amount)
    else
      newer_sum = 0
    end

    balance = current_available - newer_sum
    @running_balances = {}
    @items.each_with_index do |item, idx|
      @running_balances[idx] = balance
      balance -= item.amount
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
