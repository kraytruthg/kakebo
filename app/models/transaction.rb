class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true
  belongs_to :transfer_pair, class_name: "Transaction", foreign_key: :transfer_pair_id, optional: true

  validates :amount, presence: true
  validates :date, presence: true

  scope :for_month, ->(year, month) {
    where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
  }

  scope :income, -> { where(category_id: nil) }
  scope :expense, -> { where.not(category_id: nil) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }

  delegate :household, to: :account

  after_commit :trigger_recalculation, on: [ :create, :destroy ]
  after_commit :trigger_recalculation_on_update, on: :update

  def transfer?
    transfer_pair_id.present?
  end

  def income?
    category_id.nil? && !transfer?
  end

  private

  def trigger_recalculation
    return if category_id.nil?
    BudgetEntryRecalculationJob.perform_later(category_id, date.year, date.month)
  end

  def trigger_recalculation_on_update
    trigger_recalculation
    if saved_change_to_category_id?
      old_category_id = saved_changes["category_id"].first
      BudgetEntryRecalculationJob.perform_later(old_category_id, date.year, date.month) if old_category_id
    end
  end
end
