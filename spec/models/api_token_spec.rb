require "rails_helper"

RSpec.describe ApiToken, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires a user" do
      token = ApiToken.new(token: SecureRandom.hex(32))
      expect(token).not_to be_valid
      expect(token.errors[:user]).to be_present
    end
  end

  describe ".generate_for" do
    it "creates a token for the user" do
      api_token = ApiToken.generate_for(user, name: "iPhone Shortcut")
      expect(api_token).to be_persisted
      expect(api_token.token).to be_present
      expect(api_token.token.length).to eq(64)
      expect(api_token.name).to eq("iPhone Shortcut")
      expect(api_token.user).to eq(user)
    end
  end

  describe ".authenticate" do
    it "returns user for valid token" do
      api_token = ApiToken.generate_for(user)
      expect(ApiToken.authenticate(api_token.token)).to eq(user)
    end

    it "updates last_used_at" do
      api_token = ApiToken.generate_for(user)
      expect { ApiToken.authenticate(api_token.token) }
        .to change { api_token.reload.last_used_at }
    end

    it "returns nil for invalid token" do
      expect(ApiToken.authenticate("invalid")).to be_nil
    end
  end
end
