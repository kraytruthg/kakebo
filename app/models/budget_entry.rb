class BudgetEntry < ApplicationRecord
  belongs_to :category

  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :category_id, uniqueness: { scope: [:year, :month] }

  scope :for_month, ->(year, month) { where(year: year, month: month) }

  def activity
    category.transactions
            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
            .sum(:amount)
  end

  def available
    carried_over + budgeted + activity
  end
end
