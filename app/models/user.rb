class User < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :households, through: :household_memberships
  has_secure_password
  has_many :api_tokens, dependent: :destroy
  belongs_to :default_account, class_name: "Account", optional: true

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :default_account_belongs_to_household, if: :default_account_id_changed?

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_create :create_default_household, unless: -> { household_memberships.any? }

  def admin?
    admin_emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).map(&:downcase)
    admin_emails.include?(email)
  end

  def default_account_for(household)
    if default_account && default_account.household_id == household.id
      default_account
    else
      household.accounts.budget.active.first || household.accounts.active.first
    end
  end

  private

  def create_default_household
    household = Household.create!(name: "#{name} 的家")
    household_memberships.build(household: household, role: "owner")
  end

  def default_account_belongs_to_household
    return unless default_account

    unless Account.where(id: default_account_id, household_id: household_ids).exists?
      errors.add(:default_account, "must belong to one of the user's households")
    end
  end
end
