require "rails_helper"

RSpec.describe BudgetEntry, type: :model do
  it { should belong_to(:category) }
  it { should validate_presence_of(:year) }
  it { should validate_presence_of(:month) }

  describe ".for_month" do
    it "returns entries for the given year/month" do
      entry = create(:budget_entry, year: 2026, month: 2)
      create(:budget_entry, year: 2026, month: 3)

      expect(BudgetEntry.for_month(2026, 2)).to contain_exactly(entry)
    end
  end

  describe "#available" do
    it "sums carried_over + budgeted + activity" do
      category = create(:category)
      account = create(:account, household: category.household)
      entry = create(:budget_entry, category: category, year: 2026, month: 2,
                     budgeted: 15_000, carried_over: 3_000)
      create(:transaction, account: account, category: category,
             amount: -5_000, date: Date.new(2026, 2, 15))

      expect(entry.available).to eq(13_000)
    end
  end

  describe "#activity" do
    it "sums transactions for the same category and month" do
      category = create(:category)
      account = create(:account, household: category.household)
      entry = create(:budget_entry, category: category, year: 2026, month: 2)
      create(:transaction, account: account, category: category, amount: -3_000, date: Date.new(2026, 2, 10))
      create(:transaction, account: account, category: category, amount: -2_000, date: Date.new(2026, 2, 20))
      create(:transaction, account: account, category: category, amount: -1_000, date: Date.new(2026, 3, 1))

      expect(entry.activity).to eq(-5_000)
    end
  end
end
