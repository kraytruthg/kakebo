require "rails_helper"

RSpec.describe "Budget copy_from_previous", type: :request do
  let(:user)     { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household) }
  let(:group)    { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: group) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /budget/copy_from_previous" do
    context "上月有預算且本月為 0" do
      it "複製預算並 redirect 帶 notice" do
        create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 3000)
        expect {
          post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        }.to change(BudgetEntry, :count).by(1)
        new_entry = BudgetEntry.find_by(category: category, year: 2026, month: 2)
        expect(new_entry.budgeted).to eq(3000)
        expect(response).to redirect_to(budget_path(year: 2026, month: 2))
        follow_redirect!
        expect(response.body).to include("複製")
      end
    end

    context "本月已有手動設定的預算（budgeted != 0）" do
      it "不覆蓋，跳過該類別" do
        create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 3000)
        existing = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 5000)
        post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        expect(existing.reload.budgeted).to eq(5000)
      end
    end

    context "上月沒有任何預算" do
      it "redirect 帶 alert 提示無可複製" do
        post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        expect(response).to redirect_to(budget_path(year: 2026, month: 2))
        follow_redirect!
        expect(response.body).to include("無預算可複製")
      end
    end

    context "1 月複製（跨年）" do
      it "從去年 12 月複製" do
        create(:budget_entry, category: category, year: 2025, month: 12, budgeted: 2000)
        post budget_copy_from_previous_path, params: { year: 2026, month: 1 }
        new_entry = BudgetEntry.find_by(category: category, year: 2026, month: 1)
        expect(new_entry.budgeted).to eq(2000)
      end
    end

    context "when downstream months exist" do
      it "recalculates carried_over for subsequent months" do
        create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 3000)
        march = create(:budget_entry, category: category, year: 2026, month: 3, budgeted: 0, carried_over: 0)

        perform_enqueued_jobs do
          post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        end

        expect(march.reload.carried_over).to eq(3000)
      end
    end
  end
end
