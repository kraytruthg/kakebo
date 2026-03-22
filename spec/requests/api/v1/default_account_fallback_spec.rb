require "rails_helper"

RSpec.describe "Default account fallback for quick entry", type: :request do
  let(:user) { create(:user) }
  let(:household_a) { user.households.first }
  let(:household_b) { create(:household, name: "公司帳本") }
  let!(:membership_b) { create(:household_membership, user: user, household: household_b) }

  let!(:account_a) { create(:account, household: household_a, name: "現金") }
  let!(:account_b) { create(:account, household: household_b, name: "公司卡") }

  let!(:group_a) { create(:category_group, household: household_a, name: "日常") }
  let!(:category_a) { create(:category, category_group: group_a, name: "午餐") }
  let!(:group_b) { create(:category_group, household: household_b, name: "辦公") }
  let!(:category_b) { create(:category, category_group: group_b, name: "文具") }

  let(:api_token) { ApiToken.generate_for(user) }
  let(:headers) { { "Authorization" => "Bearer #{api_token.token}" } }

  before do
    QuickEntryMapping.create!(household: household_a, keyword: "午餐", target_type: "Category", target_id: category_a.id)
    QuickEntryMapping.create!(household: household_b, keyword: "文具", target_type: "Category", target_id: category_b.id)
  end

  context "when user's default account belongs to the target household" do
    before { user.update!(default_account: account_a) }

    it "uses the user's default account" do
      post "/api/v1/quick_entry", params: { text: "午餐 350" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(Transaction.last.account).to eq(account_a)
    end
  end

  context "when user's default account belongs to a different household" do
    before { user.update!(default_account: account_a) }

    it "falls back to the first budget account in the target household" do
      post "/api/v1/households/#{household_b.id}/quick_entry", params: { text: "文具 200" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(Transaction.last.account).to eq(account_b)
    end
  end

  context "when user has no default account" do
    it "falls back to the first budget account in the household" do
      post "/api/v1/quick_entry", params: { text: "午餐 350" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(Transaction.last.account).to eq(account_a)
    end
  end
end
