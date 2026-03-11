class User < ApplicationRecord
  belongs_to :household, optional: true
  has_secure_password
  has_many :api_tokens, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_create :create_household, unless: -> { household_id.present? }

  def admin?
    admin_emails = ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).map(&:downcase)
    admin_emails.include?(email)
  end

  private

  def create_household
    self.household ||= Household.create!(name: "#{name} 的家")
  end
end
