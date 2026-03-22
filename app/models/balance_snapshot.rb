class BalanceSnapshot < ApplicationRecord
  belongs_to :account

  validates :balance, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: :account_id }
end
