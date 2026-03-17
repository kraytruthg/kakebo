class TransactionListsController < ApplicationController
  include TransactionFilterable

  def index
    scope = Current.household.transactions
              .includes(:category, :account, transfer_pair: :account)
              .recent

    scope = apply_transaction_filters(scope)

    @pagy, @transactions = pagy(scope)
    @accounts = Current.household.accounts.active.order(:name)
    @categories = Current.household.category_groups.includes(:categories).order(:position)
    @total_count = Current.household.transactions.count
  end
end
