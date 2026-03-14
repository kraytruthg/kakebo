class Account < ApplicationRecord
  belongs_to :household
  has_many :transactions, dependent: :destroy

  before_destroy :clear_default_account

  TYPES = %w[budget tracking].freeze

  validates :name, presence: true
  validates :account_type, inclusion: { in: TYPES }

  scope :budget, -> { where(account_type: "budget") }
  scope :tracking, -> { where(account_type: "tracking") }
  scope :active, -> { where(active: true) }

  def budget?
    account_type == "budget"
  end

  def recalculate_balance!
    calculated = starting_balance + transactions.sum(:amount)
    update_columns(balance: calculated)
  end

  private

  def clear_default_account
    household.update!(default_account_id: nil) if household.default_account_id == id
  end
end
