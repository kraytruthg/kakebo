require "rails_helper"

RSpec.describe "Household#ready_to_assign" do
  it "equals budget account balances minus sum of all available" do
    household = create(:household)
    group = create(:category_group, household: household)
    cat1 = create(:category, category_group: group)
    cat2 = create(:category, category_group: group)
    account = create(:account, household: household, account_type: "budget", balance: 100_000)

    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 30_000, carried_over: 0)
    create(:budget_entry, category: cat2, year: 2026, month: 2, budgeted: 20_000, carried_over: 0)

    expect(household.ready_to_assign(2026, 2)).to eq(50_000)
  end
end
