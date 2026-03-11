class ApiToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true

  def self.generate_for(user, name: nil)
    create!(user: user, token: SecureRandom.hex(32), name: name)
  end

  def self.authenticate(raw_token)
    return nil if raw_token.blank?
    api_token = find_by(token: raw_token)
    return nil unless api_token
    api_token.update_column(:last_used_at, Time.current) if api_token.last_used_at.nil? || api_token.last_used_at < 5.minutes.ago
    api_token.user
  end
end
