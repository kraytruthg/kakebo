require "rails_helper"

RSpec.describe "Siri 記帳設定", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:api_token) { ApiToken.generate_for(user) }

  before { sign_in(user) }

  context "single household user" do
    it "shows single API URL without household grouping" do
      visit settings_api_tokens_path
      expect(page).to have_field(type: "text", readonly: true, with: /\/api\/v1\/quick_entry/)
      expect(page).not_to have_text(/\/api\/v1\/households\//)
    end
  end

  context "multi-household user" do
    let(:second_household) { create(:household, name: "公司帳本") }
    let!(:second_membership) { create(:household_membership, user: user, household: second_household) }

    it "shows per-household API URLs" do
      visit settings_api_tokens_path
      expect(page).to have_text(household.name)
      expect(page).to have_text("公司帳本")
      expect(page).to have_field(type: "text", readonly: true, with: /\/api\/v1\/households\/#{household.id}\/quick_entry/)
      expect(page).to have_field(type: "text", readonly: true, with: /\/api\/v1\/households\/#{second_household.id}\/quick_entry/)
    end
  end
end
