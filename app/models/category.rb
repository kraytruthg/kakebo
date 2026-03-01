class Category < ApplicationRecord
  belongs_to :category_group
  has_many :budget_entries, dependent: :destroy
  has_many :transactions

  validates :name, presence: true

  default_scope { order(:position) }

  delegate :household, to: :category_group

  before_destroy :prevent_if_has_transactions

  private

  def prevent_if_has_transactions
    count = transactions.count
    if count > 0
      errors.add(:base, "此分類有 #{count} 筆交易，請先移除或重新分類")
      throw :abort
    end
  end
end
