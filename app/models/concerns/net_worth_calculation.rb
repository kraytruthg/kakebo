module NetWorthCalculation
  extend ActiveSupport::Concern

  def net_worth
    sum_balances(accounts)
  end

  def investable_net_worth
    sum_balances(accounts.investable)
  end

  def non_investable_net_worth
    scope = accounts.where(investable: false)
    sum_tracking(scope.tracking_asset) - sum_tracking(scope.tracking_liability)
  end

  def net_worth_at(year, month)
    end_date = Date.new(year, month, -1)

    budget_sum = accounts.budget.sum do |a|
      a.starting_balance + a.transactions.where("date <= ?", end_date).sum(:amount)
    end

    tracking_sum = accounts.tracking.sum do |a|
      snapshot = a.balance_snapshots.where("date <= ?", end_date).order(date: :desc).first
      balance = snapshot&.balance || a.starting_balance
      a.liability? ? -balance : balance
    end

    budget_sum + tracking_sum
  end

  def monthly_net_worth_series
    earliest = earliest_data_date
    return {} unless earliest

    result = {}
    current = earliest.beginning_of_month
    today = Date.current

    while current <= today
      year = current.year
      month = current.month
      result["#{year}-#{month.to_s.rjust(2, '0')}"] = net_worth_at(year, month)
      current = current.next_month
    end

    result
  end

  private

  def sum_balances(base_scope)
    budget_sum = base_scope.budget.sum(:balance)
    asset_sum = sum_tracking(base_scope.tracking_asset)
    liability_sum = sum_tracking(base_scope.tracking_liability)
    budget_sum + asset_sum - liability_sum
  end

  def sum_tracking(scope)
    scope.sum { |a| a.current_balance }
  end

  def earliest_data_date
    dates = []

    earliest_transaction = transactions.minimum(:date)
    dates << earliest_transaction if earliest_transaction

    earliest_snapshot = BalanceSnapshot.joins(:account).where(accounts: { household_id: id }).minimum(:date)
    dates << earliest_snapshot if earliest_snapshot

    dates.min
  end
end
