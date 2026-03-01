class BudgetEntry < ApplicationRecord
  belongs_to :category

  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :category_id, uniqueness: { scope: [:year, :month] }

  scope :for_month, ->(year, month) { where(year: year, month: month) }

  def self.initialize_month!(household, year, month)
    prev = Date.new(year, month, 1).prev_month
    prev_year  = prev.year
    prev_month = prev.month

    ActiveRecord::Base.transaction do
      household.category_groups.includes(:categories).each do |group|
        group.categories.each do |category|
          next if exists?(category: category, year: year, month: month)

          prev_entry = find_by(category: category, year: prev_year, month: prev_month)
          carried    = prev_entry ? prev_entry.available : 0

          create!(
            category:     category,
            year:         year,
            month:        month,
            carried_over: carried,
            budgeted:     0
          )
        end
      end
    end
  end

  def activity
    category.transactions
            .joins(:account)
            .where(accounts: { account_type: "budget" })
            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
            .sum(:amount)
  end

  def available
    carried_over + budgeted + activity
  end
end
