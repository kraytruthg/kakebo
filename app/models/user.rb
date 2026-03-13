class User < ApplicationRecord
  has_many :household_memberships, dependent: :destroy
  has_many :households, through: :household_memberships
  has_secure_password
  has_many :api_tokens, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_create :create_default_household, unless: -> { household_memberships.any? }

  def admin?
    admin_emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).map(&:downcase)
    admin_emails.include?(email)
  end

  private

  def create_default_household
    household = Household.create!(name: "#{name} 的家")
    household_memberships.build(household: household, role: "owner")
  end
end
