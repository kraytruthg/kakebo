require "rails_helper"

RSpec.describe "BudgetEntries", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /budget_entries/edit" do
    context "when no budget entry exists for this month" do
      it "returns 200" do
        get edit_budget_entries_path,
            params: { category_id: category.id, year: 2026, month: 2 }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when a budget entry exists" do
      it "returns 200 and includes the existing budgeted value" do
        create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 5000)
        get edit_budget_entries_path,
            params: { category_id: category.id, year: 2026, month: 2 }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("5000")
      end
    end

    context "with a category from another household" do
      it "raises ActiveRecord::RecordNotFound" do
        other_category = create(:category)
        expect {
          get edit_budget_entries_path,
              params: { category_id: other_category.id, year: 2026, month: 2 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "POST /budget_entries" do
    context "when no budget entry exists (create)" do
      it "creates a new BudgetEntry" do
        expect {
          post budget_entries_path,
               params: { budget_entry: { category_id: category.id,
                                         year: 2026, month: 2, budgeted: 3000 } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(BudgetEntry, :count).by(1)
        expect(BudgetEntry.last.budgeted).to eq(3000)
      end
    end

    context "when a budget entry already exists (update)" do
      it "updates budgeted without creating a new record" do
        entry = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 1000)
        expect {
          post budget_entries_path,
               params: { budget_entry: { category_id: category.id,
                                         year: 2026, month: 2, budgeted: 5000 } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.not_to change(BudgetEntry, :count)
        expect(entry.reload.budgeted).to eq(5000)
      end
    end

    context "with a category from another household" do
      it "raises ActiveRecord::RecordNotFound" do
        other_category = create(:category)
        expect {
          post budget_entries_path,
               params: { budget_entry: { category_id: other_category.id,
                                         year: 2026, month: 2, budgeted: 1000 } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when downstream months exist" do
      it "recalculates carried_over for subsequent months" do
        create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 0, carried_over: 0)
        march = create(:budget_entry, category: category, year: 2026, month: 3, budgeted: 1000, carried_over: 0)

        perform_enqueued_jobs do
          post budget_entries_path,
               params: { budget_entry: { category_id: category.id,
                                         year: 2026, month: 2, budgeted: 5000 } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end

        expect(march.reload.carried_over).to eq(5000)
      end
    end
  end
end
