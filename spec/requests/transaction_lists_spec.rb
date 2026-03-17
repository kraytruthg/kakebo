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
    end
  end
end
