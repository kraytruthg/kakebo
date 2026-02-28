class ReportsController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month

    @spending_by_category = Transaction
      .joins(:account, :category)
      .where(accounts: { household_id: Current.household.id })
      .for_month(@year, @month)
      .where.not(category_id: nil)
      .group("categories.name")
      .sum(:amount)
      .transform_values(&:abs)
      .sort_by { |_, v| -v }
  end
end
