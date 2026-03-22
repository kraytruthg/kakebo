require "rails_helper"

RSpec.describe SavingsCalculation do
  let(:household) { create(:household) }
  let!(:account) { create(:account, household: household, account_type: "budget") }

  describe "#savings_rate" do
    it "calculates (income - expense) / income * 100" do
      create(:transaction, account: account, amount: 100000, date: "2026-03-01", category: nil, transfer_pair_id: nil)
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      create(:transaction, account: account, amount: -60000, date: "2026-03-15", category: category)

      expect(household.savings_rate(2026, 3)).to eq(40.0)
    end

    it "returns 0 when no income" do
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      create(:transaction, account: account, amount: -5000, date: "2026-03-10", category: category)

      expect(household.savings_rate(2026, 3)).to eq(0)
    end

    it "excludes transfer income" do
      other_account = create(:account, household: household, account_type: "budget")
      t1 = create(:transaction, account: other_account, amount: -50000, date: "2026-03-01", category: nil)
      t2 = create(:transaction, account: account, amount: 50000, date: "2026-03-01", category: nil, transfer_pair_id: t1.id)
      t1.update_columns(transfer_pair_id: t2.id)

      # Only transfer income, no real income -> savings rate is 0
      expect(household.savings_rate(2026, 3)).to eq(0)
    end
  end

  describe "#annual_savings_rate" do
    it "aggregates full year of income and expenses" do
      create(:transaction, account: account, amount: 100000, date: "2026-01-01", category: nil, transfer_pair_id: nil)
      create(:transaction, account: account, amount: 100000, date: "2026-06-01", category: nil, transfer_pair_id: nil)
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      create(:transaction, account: account, amount: -80000, date: "2026-03-15", category: category)
      create(:transaction, account: account, amount: -50000, date: "2026-09-15", category: category)

      # income=200000, expense=130000, rate=(70000/200000)*100=35.0
      expect(household.annual_savings_rate(2026)).to eq(35.0)
    end
  end
end
