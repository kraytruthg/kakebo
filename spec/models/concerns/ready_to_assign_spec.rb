require "rails_helper"

RSpec.describe "Household#ready_to_assign" do
  let(:household) { create(:household) }
  let(:group) { create(:category_group, household: household) }
  let(:cat1) { create(:category, category_group: group) }
  let(:cat2) { create(:category, category_group: group) }
  let!(:account) { create(:account, household: household, account_type: "budget", balance: 100_000) }

  it "equals budget account balance minus sum of all category available" do
    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 30_000, carried_over: 0)
    create(:budget_entry, category: cat2, year: 2026, month: 2, budgeted: 20_000, carried_over: 0)

    # no transactions: available(cat1)=30,000 available(cat2)=20,000
    # RTA = 100,000 - 50,000 = 50,000
    expect(household.ready_to_assign(2026, 2)).to eq(50_000)
  end

  it "reduces available when expenses are recorded" do
    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 30_000, carried_over: 0)
    create(:budget_entry, category: cat2, year: 2026, month: 2, budgeted: 20_000, carried_over: 0)
    create(:transaction, account: account, category: cat1, amount: -8_000, date: Date.new(2026, 2, 15))
    account.update_columns(balance: 92_000)  # reflect the spending

    # available(cat1) = 0 + 30,000 + (-8,000) = 22,000
    # available(cat2) = 0 + 20,000 + 0        = 20,000
    # RTA = 92,000 - 42,000 = 50,000
    expect(household.ready_to_assign(2026, 2)).to eq(50_000)
  end

  it "increases when income is deposited (balance goes up, no category assigned)" do
    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 30_000, carried_over: 0)
    account.update_columns(balance: 130_000)  # income deposited

    # available(cat1) = 30,000
    # RTA = 130,000 - 30,000 = 100,000
    expect(household.ready_to_assign(2026, 2)).to eq(100_000)
  end

  it "ignores tracking accounts" do
    create(:account, household: household, account_type: "tracking", balance: 500_000)
    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 10_000, carried_over: 0)

    # only budget account (100,000) counts
    expect(household.ready_to_assign(2026, 2)).to eq(90_000)
  end
end
