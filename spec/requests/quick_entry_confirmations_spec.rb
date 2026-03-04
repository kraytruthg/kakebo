require "rails_helper"

RSpec.describe "Quick Entry Confirmations", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "午餐") }

  let(:token) { SecureRandom.hex(20) }
  let(:cache_data) do
    {
      user_id: user.id,
      amount: 350.0,
      memo: "晚餐",
      payer: nil,
      description: "晚餐"
    }
  end

  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.write("quick_entry_confirm:#{token}", cache_data, expires_in: 30.minutes)
  end

  describe "GET /quick_entry/confirm/:token" do
    it "shows confirmation page without login" do
      get "/quick_entry/confirm/#{token}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("350")
      expect(response.body).to include("晚餐")
    end

    it "returns 404 for invalid token" do
      get "/quick_entry/confirm/invalid"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /quick_entry/confirm/:token" do
    it "creates transaction and clears cache" do
      expect {
        post "/quick_entry/confirm/#{token}",
          params: { account_id: account.id, category_id: category.id, amount: 350, memo: "晚餐", date: Date.today }
      }.to change(Transaction, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("完成")
      expect(Rails.cache.read("quick_entry_confirm:#{token}")).to be_nil
    end

    it "saves mapping when remember_category is checked" do
      post "/quick_entry/confirm/#{token}",
        params: {
          account_id: account.id, category_id: category.id,
          amount: 350, memo: "晚餐", date: Date.today,
          remember_category: "1", description_keyword: "晚餐"
        }
      expect(QuickEntryMapping.find_by(keyword: "晚餐", target_type: "Category")).to be_present
    end
  end
end
