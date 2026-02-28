require "rails_helper"

RSpec.describe BudgetEntryRecalculationJob, type: :job do
  describe "#perform" do
    it "updates carried_over for all subsequent months" do
      household = create(:household)
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      account = create(:account, household: household)

      # 1月 entry：budgeted 5000，沒有交易，available = 5000
      jan = create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 5_000, carried_over: 0)
      # 2月 entry：carried_over 還是舊的 0，job 應該把它更新成 5000
      feb = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 3_000, carried_over: 0)

      BudgetEntryRecalculationJob.new.perform(category.id, 2026, 1)

      expect(feb.reload.carried_over).to eq(5_000)
    end
  end
end
