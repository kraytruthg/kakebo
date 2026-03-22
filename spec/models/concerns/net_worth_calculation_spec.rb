require "rails_helper"

RSpec.describe NetWorthCalculation do
  let(:household) { create(:household) }

  describe "#net_worth" do
    it "sums budget + asset - liability" do
      budget = create(:account, household: household, account_type: "budget", starting_balance: 50000, balance: 50000)
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 500000)
      liability = create(:account, household: household, account_type: "tracking_liability", starting_balance: 300000)

      expect(household.net_worth).to eq(250000)
    end

    it "uses latest snapshot for tracking accounts" do
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 100000)
      create(:balance_snapshot, account: asset, balance: 200000, date: "2026-01-01")
      create(:balance_snapshot, account: asset, balance: 300000, date: "2026-03-01")

      expect(household.net_worth).to eq(300000)
    end

    it "returns budget balance only when no tracking accounts" do
      create(:account, household: household, account_type: "budget", starting_balance: 50000, balance: 50000)

      expect(household.net_worth).to eq(50000)
    end
  end

  describe "#net_worth_at" do
    it "calculates historical net worth at month end" do
      budget = create(:account, household: household, account_type: "budget", starting_balance: 10000)
      create(:transaction, account: budget, amount: -2000, date: "2026-01-15")
      create(:transaction, account: budget, amount: -3000, date: "2026-02-20")
      create(:transaction, account: budget, amount: -1000, date: "2026-03-10")

      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 100000)
      create(:balance_snapshot, account: asset, balance: 110000, date: "2026-01-31")
      create(:balance_snapshot, account: asset, balance: 120000, date: "2026-03-01")

      # At end of Jan: budget = 10000 - 2000 = 8000, asset = 110000
      expect(household.net_worth_at(2026, 1)).to eq(118000)

      # At end of Feb: budget = 10000 - 2000 - 3000 = 5000, asset = 110000 (latest snapshot <= Feb)
      expect(household.net_worth_at(2026, 2)).to eq(115000)
    end

    it "falls back to starting_balance when no snapshot before date" do
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 50000)
      create(:balance_snapshot, account: asset, balance: 80000, date: "2026-06-01")

      expect(household.net_worth_at(2026, 3)).to eq(50000)
    end
  end

  describe "#monthly_net_worth_series" do
    it "returns hash of YYYY-MM => amount" do
      budget = create(:account, household: household, account_type: "budget", starting_balance: 10000)
      create(:transaction, account: budget, amount: -1000, date: "2026-01-15")

      series = household.monthly_net_worth_series
      expect(series).to be_a(Hash)
      expect(series["2026-01"]).to eq(9000)
    end

    it "returns empty hash when no data" do
      expect(household.monthly_net_worth_series).to eq({})
    end
  end
end
