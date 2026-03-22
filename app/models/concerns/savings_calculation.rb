module SavingsCalculation
  extend ActiveSupport::Concern

  def savings_rate(year, month)
    calculate_savings_rate(budget_transactions.for_month(year, month))
  end

  def annual_savings_rate(year)
    calculate_savings_rate(budget_transactions.where("EXTRACT(year FROM date) = ?", year))
  end

  def budget_transactions
    transactions.joins(:account).where(accounts: { account_type: "budget" })
  end

  private

  def calculate_savings_rate(txns)
    income = txns.income.where(transfer_pair_id: nil).sum(:amount).abs
    expense = txns.expense.sum(:amount).abs
    return 0 if income.zero?
    ((income - expense) / income * 100).round(1)
  end
end
