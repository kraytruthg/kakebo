class HouseholdMembership < ApplicationRecord
  belongs_to :user
  belongs_to :household

  ROLES = %w[owner member].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :household_id }
end
