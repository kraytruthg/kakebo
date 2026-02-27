class User < ApplicationRecord
  belongs_to :household
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }

  normalizes :email, with: -> e { e.strip.downcase }
end
