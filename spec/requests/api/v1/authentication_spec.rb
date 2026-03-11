require "rails_helper"

RSpec.describe "API Authentication", type: :request do
  let(:user) { create(:user) }
  let!(:account) { create(:account, household: user.household) }
  let(:api_token) { ApiToken.generate_for(user) }

  describe "without token" do
    it "returns 401" do
      post "/api/v1/quick_entry", params: { text: "午餐 350" }
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("Invalid or missing API token")
    end
  end

  describe "with invalid token" do
    it "returns 401" do
      post "/api/v1/quick_entry",
        params: { text: "午餐 350" },
        headers: { "Authorization" => "Bearer invalid" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "with valid token" do
    it "does not return 401" do
      post "/api/v1/quick_entry",
        params: { text: "午餐 350" },
        headers: { "Authorization" => "Bearer #{api_token.token}" }
      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
