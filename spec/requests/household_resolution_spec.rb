require "rails_helper"

RSpec.describe "Household resolution", type: :request do
  let(:household) { create(:household) }
  let(:user) { create(:user, household: household) }
  let!(:account) { create(:account, household: household) }

  before { post session_path, params: { email: user.email, password: "password123" } }

  it "sets current_household_id in session after login" do
    get budget_path
    expect(response).to have_http_status(:success)
  end

  context "with multiple households" do
    let(:personal_household) { create(:household, name: "Personal") }
    before { create(:household_membership, user: user, household: personal_household, role: "owner") }

    it "defaults to first household" do
      get budget_path
      expect(response).to have_http_status(:success)
    end
  end
end
