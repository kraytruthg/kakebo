require "rails_helper"

RSpec.describe "Siri Quick Entry Integration", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "午餐") }
  let(:api_token) { ApiToken.generate_for(user) }
  let(:headers) { { "Authorization" => "Bearer #{api_token.token}" } }

  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
  end

  it "full flow: API → confirm page → transaction created → mapping remembered → auto-create" do
    # Step 1: API call without mapping → needs confirmation
    post "/api/v1/quick_entry", params: { text: "晚餐 500" }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("needs_confirmation")
    confirm_url = response.parsed_body["confirm_url"]
    expect(confirm_url).to be_present

    # Extract path from full URL for request spec
    confirm_path = URI.parse(confirm_url).path
    token = confirm_path.split("/").last

    # Step 2: Visit confirm page (no login needed)
    get confirm_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("500")

    # Step 3: Submit with category + remember
    post "/quick_entry/confirm/#{token}", params: {
      account_id: account.id,
      category_id: category.id,
      amount: 500,
      memo: "晚餐",
      date: Date.today.to_s,
      remember_category: "1",
      description_keyword: "晚餐"
    }

    expect(Transaction.last.amount).to eq(-500.to_d)
    expect(QuickEntryMapping.find_by(keyword: "晚餐", target_type: "Category")).to be_present

    # Step 4: Next API call with same keyword → auto-created
    expect {
      post "/api/v1/quick_entry", params: { text: "晚餐 300" }, headers: headers
    }.to change(Transaction, :count).by(1)
    expect(response.parsed_body["status"]).to eq("ok")
    expect(Transaction.last.amount).to eq(-300.to_d)
  end
end
