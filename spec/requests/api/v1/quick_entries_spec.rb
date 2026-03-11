require "rails_helper"

RSpec.describe "API Quick Entry", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }
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
end
