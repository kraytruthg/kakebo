require "rails_helper"

RSpec.describe "API Quick Entry", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "午餐") }
  let(:api_token) { ApiToken.generate_for(user) }
  let(:headers) { { "Authorization" => "Bearer #{api_token.token}" } }

  def post_quick_entry(text)
    post "/api/v1/quick_entry", params: { text: text }, headers: headers
  end

  describe "POST /api/v1/quick_entry" do
    context "with matching mapping (both account and category)" do
      before do
        create(:quick_entry_mapping, household: household, keyword: "午餐", target: category)
        create(:quick_entry_mapping, household: household, keyword: "現金", target: account, target_type: "Account")
      end

      it "creates transaction and returns ok" do
        expect { post_quick_entry("現金 午餐 350") }.to change(Transaction, :count).by(1)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["status"]).to eq("ok")
        expect(body["message"]).to include("午餐")
        expect(body["message"]).to include("350")
      end
    end

    context "with category mapping but no account mapping (uses default account)" do
      before do
        create(:quick_entry_mapping, household: household, keyword: "午餐", target: category)
      end

      it "creates transaction using first budget account" do
        expect { post_quick_entry("午餐 350") }.to change(Transaction, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("ok")
        txn = Transaction.last
        expect(txn.amount).to eq(-350.to_d)
        expect(txn.category).to eq(category)
        expect(txn.account).to eq(account)
      end
    end

    context "without category mapping" do
      it "returns needs_confirmation with confirm_url" do
        post_quick_entry("晚餐 500")
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["status"]).to eq("needs_confirmation")
        expect(body["confirm_url"]).to be_present
        expect(body["confirm_url"]).to include("/quick_entry/confirm/")
      end
    end

    context "with unparseable input" do
      it "returns error" do
        post_quick_entry("hello")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["status"]).to eq("error")
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/quick_entry", params: { text: "午餐 350" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/households/:household_id/quick_entry" do
    let(:second_household) { create(:household, name: "公司帳本") }
    let!(:second_membership) { create(:household_membership, user: user, household: second_household) }
    let!(:second_account) { create(:account, household: second_household, name: "公司卡") }
    let!(:second_category_group) { create(:category_group, household: second_household, name: "辦公") }
    let!(:second_category) { create(:category, category_group: second_category_group, name: "文具") }

    context "with valid household_id and mapping" do
      before do
        create(:quick_entry_mapping, household: second_household, keyword: "文具", target: second_category)
      end

      it "creates transaction in the specified household" do
        expect {
          post "/api/v1/households/#{second_household.id}/quick_entry",
            params: { text: "文具 200" }, headers: headers
        }.to change(Transaction, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("ok")
        txn = Transaction.last
        expect(txn.account).to eq(second_account)
        expect(txn.category).to eq(second_category)
      end
    end

    context "with household user does not belong to" do
      let(:other_household) { create(:household, name: "別人的帳本") }

      it "returns 404" do
        post "/api/v1/households/#{other_household.id}/quick_entry",
          params: { text: "午餐 350" }, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without mapping (needs confirmation)" do
      let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
      end

      it "returns confirm_url and caches household_id" do
        post "/api/v1/households/#{second_household.id}/quick_entry",
          params: { text: "新品 300" }, headers: headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["status"]).to eq("needs_confirmation")

        token = body["confirm_url"].split("/").last
        cached = Rails.cache.read("quick_entry_confirm:#{token}")
        expect(cached[:household_id]).to eq(second_household.id)
      end
    end
  end
end
