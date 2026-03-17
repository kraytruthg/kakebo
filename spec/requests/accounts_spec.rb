require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:household) { create(:household) }
  let(:user) { create(:user, household: household) }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before { post session_path, params: { email: user.email, password: "password123" } }

  describe "GET /accounts/:id" do
    it "returns success with pagination" do
      31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
      get account_path(account)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("pagy")
    end

    it "filters by category" do
      cat2 = create(:category, category_group: category_group, name: "Transport")
      create(:transaction, account: account, category: category, amount: -300, date: Date.today, memo: "Food")
      create(:transaction, account: account, category: cat2, amount: -500, date: Date.today, memo: "Train")
      get account_path(account), params: { category_id: category.id }
      expect(response.body).to include("Food")
      expect(response.body).not_to include("Train")
    end

    it "filters by memo query" do
      create(:transaction, account: account, category: category, amount: -300, date: Date.today, memo: "Lunch at cafe")
      create(:transaction, account: account, category: category, amount: -500, date: Date.today, memo: "Dinner")
      get account_path(account), params: { query: "lunch" }
      expect(response.body).to include("Lunch at cafe")
      expect(response.body).not_to include("Dinner")
    end

    it "filters by date range" do
      create(:transaction, account: account, category: category, amount: -300, date: Date.new(2026, 3, 1), memo: "Early")
      create(:transaction, account: account, category: category, amount: -500, date: Date.new(2026, 3, 15), memo: "Late")
      get account_path(account), params: { date_from: "2026-03-10" }
      expect(response.body).to include("Late")
      expect(response.body).not_to include("Early")
    end
  end
end
