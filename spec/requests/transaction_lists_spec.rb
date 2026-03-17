require "rails_helper"

RSpec.describe "Transaction Lists", type: :request do
  let(:household) { create(:household) }
  let(:user) { create(:user, household: household) }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  describe "GET /transactions" do
    context "when not logged in" do
      it "redirects to login" do
        get "/transactions"
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { post session_path, params: { email: user.email, password: "password123" } }

      it "returns success" do
        get "/transactions"
        expect(response).to have_http_status(:success)
      end

      it "shows transactions from current household" do
        txn = create(:transaction, account: account, category: category, amount: -500, date: Date.today, memo: "Lunch")
        get "/transactions"
        expect(response.body).to include("Lunch")
      end

      it "does not show transactions from other households" do
        other_household = create(:household)
        other_account = create(:account, household: other_household)
        other_group = create(:category_group, household: other_household)
        other_cat = create(:category, category_group: other_group)
        create(:transaction, account: other_account, category: other_cat, memo: "Secret")
        get "/transactions"
        expect(response.body).not_to include("Secret")
      end

      describe "filtering" do
        let!(:account2) { create(:account, household: household, name: "Credit Card") }
        let(:category2) { create(:category, category_group: category_group, name: "Transport") }
        let!(:txn_food) { create(:transaction, account: account, category: category, amount: -300, date: Date.new(2026, 3, 1), memo: "Lunch") }
        let!(:txn_transport) { create(:transaction, account: account2, category: category2, amount: -1500, date: Date.new(2026, 3, 10), memo: "Train") }
        let!(:txn_income) { create(:transaction, account: account, category: nil, amount: 50_000, date: Date.new(2026, 3, 15), memo: "Salary") }

        it "filters by account_id" do
          get "/transactions", params: { account_id: account.id }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters by category_id" do
          get "/transactions", params: { category_id: category.id }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters income transactions" do
          get "/transactions", params: { category_id: "income" }
          expect(response.body).to include("Salary")
          expect(response.body).not_to include("Lunch")
        end

        it "filters by date_from only" do
          get "/transactions", params: { date_from: "2026-03-05" }
          expect(response.body).to include("Train")
          expect(response.body).to include("Salary")
          expect(response.body).not_to include("Lunch")
        end

        it "filters by date_to only" do
          get "/transactions", params: { date_to: "2026-03-05" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters by date range" do
          get "/transactions", params: { date_from: "2026-03-05", date_to: "2026-03-12" }
          expect(response.body).to include("Train")
          expect(response.body).not_to include("Lunch")
          expect(response.body).not_to include("Salary")
        end

        it "filters by memo query" do
          get "/transactions", params: { query: "lunch" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "escapes ILIKE special characters in query" do
          create(:transaction, account: account, category: category, amount: -100, date: Date.today, memo: "100% off")
          get "/transactions", params: { query: "100%" }
          expect(response.body).to include("100% off")
        end

        it "combines multiple filters" do
          get "/transactions", params: { account_id: account.id, category_id: category.id, date_from: "2026-03-01", date_to: "2026-03-05" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
          expect(response.body).not_to include("Salary")
        end
      end

      describe "pagination" do
        it "paginates results — first page has 30 items, not all 31" do
          31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
          get "/transactions"
          expect(response.body.scan(/txn\d+/).uniq.size).to eq(30)
        end

        it "second page shows remaining items" do
          31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
          get "/transactions", params: { page: 2 }
          expect(response.body.scan(/txn\d+/).uniq.size).to eq(1)
        end
      end
    end
  end
end
