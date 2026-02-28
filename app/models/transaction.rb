class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  validates :amount, presence: true
  validates :date, presence: true

  scope :for_month, ->(year, month) {
    where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
  }

  scope :income, -> { where(category_id: nil) }
  scope :expense, -> { where.not(category_id: nil) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }

  delegate :household, to: :account

  after_commit :trigger_recalculation, on: [:create, :update, :destroy]

  def transfer?
    transfer_pair_id.present?
  end

  def income?
    category_id.nil? && !transfer?
  end

  private

  def trigger_recalculation
    return if category_id.nil?
    BudgetEntryRecalculationJob.perform_later(
      category_id,
      date.year,
      date.month
    )
  end
end
