class TransactionListsController < ApplicationController
  def index
    scope = Current.household.transactions
              .includes(:category, :account, transfer_pair: :account)
              .recent

    @pagy, @transactions = pagy(scope)
    @accounts = Current.household.accounts.active.order(:name)
    @categories = Current.household.category_groups.includes(:categories).order(:position)
    @total_count = Current.household.transactions.count
  end
end
