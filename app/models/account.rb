class Account < ApplicationRecord
  belongs_to :household
  has_many :transactions, dependent: :destroy
  has_many :balance_snapshots, dependent: :destroy

  before_destroy :clear_default_account

  TYPES = %w[budget tracking_asset tracking_liability].freeze

  validates :name, presence: true
  validates :account_type, inclusion: { in: TYPES }

  scope :budget, -> { where(account_type: "budget") }
  scope :tracking_asset, -> { where(account_type: "tracking_asset") }
  scope :tracking_liability, -> { where(account_type: "tracking_liability") }
  scope :tracking, -> { where(account_type: %w[tracking_asset tracking_liability]) }
  scope :active, -> { where(active: true) }
  scope :investable, -> { where(investable: true) }

  def budget?
    account_type == "budget"
  end

  def tracking?
    asset? || liability?
  end

  def asset?
    account_type == "tracking_asset"
  end

  def liability?
    account_type == "tracking_liability"
  end

  def current_balance
    if budget?
      starting_balance + transactions.sum(:amount)
    else
      balance_snapshots.order(date: :desc).first&.balance || starting_balance
    end
  end

  def recalculate_balance!
    calculated = starting_balance + transactions.sum(:amount)
    update_columns(balance: calculated)
  end

  private

  def clear_default_account
    User.where(default_account_id: id).update_all(default_account_id: nil)
  end
end
