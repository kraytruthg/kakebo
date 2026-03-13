require "rails_helper"

RSpec.describe "自動結轉", type: :system do
  let(:user)   { create(:user) }
  let!(:acct)  { create(:account, household: user.households.first) }
  let!(:group) { create(:category_group, household: user.households.first) }
  let!(:cat)   { create(:category, category_group: group) }

  before { sign_in(user) }

  it "首次瀏覽某月時自動建立 BudgetEntry" do
    visit budget_path(year: 2026, month: 5)
    expect(BudgetEntry.where(category: cat, year: 2026, month: 5)).to exist
  end

  it "上月有 available 時帶入 carried_over" do
    create(:budget_entry, category: cat, year: 2026, month: 6, budgeted: 2000, carried_over: 0)
    visit budget_path(year: 2026, month: 7)
    entry = BudgetEntry.find_by(category: cat, year: 2026, month: 7)
    expect(entry.carried_over).to eq(2000)
  end

  it "上月無資料時 carried_over 為 0" do
    visit budget_path(year: 2026, month: 8)
    entry = BudgetEntry.find_by(category: cat, year: 2026, month: 8)
    expect(entry.carried_over).to eq(0)
  end
end
