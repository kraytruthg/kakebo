require "rails_helper"

RSpec.describe "Household switches", type: :request do
  let(:household1) { create(:household, name: "家庭帳本") }
  let(:household2) { create(:household, name: "個人零用錢") }
  let(:user) { create(:user, household: household1) }

  before do
    create(:household_membership, user: user, household: household2, role: "owner")
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /household_switch" do
    it "switches to another household the user belongs to" do
      post household_switch_path, params: { household_id: household2.id }
      expect(response).to redirect_to(root_path)
    end

    it "rejects switching to a household the user does not belong to" do
      other_household = create(:household)
      expect {
        post household_switch_path, params: { household_id: other_household.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
