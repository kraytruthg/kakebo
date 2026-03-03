require "rails_helper"

RSpec.describe "Admin authorization", type: :request do
  let!(:household) { create(:household) }

  describe "when not logged in" do
    it "redirects to login" do
      get admin_users_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "when logged in as non-admin" do
    let!(:user) { create(:user, household: household) }

    before do
      post session_path, params: { email: user.email, password: "password123" }
    end

    it "redirects to root with alert" do
      get admin_users_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("權限不足")
    end
  end

  describe "when logged in as admin" do
    let!(:admin) { create(:user, email: "admin@example.com", household: household) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
      post session_path, params: { email: admin.email, password: "password123" }
    end

    it "allows access" do
      get admin_users_path
      expect(response).to have_http_status(:ok)
    end
  end
end
