require "rails_helper"

RSpec.describe BalanceSnapshot, type: :model do
  it { should belong_to(:account) }
  it { should validate_presence_of(:balance) }
  it { should validate_presence_of(:date) }

  describe "uniqueness" do
    it "rejects duplicate date for the same account" do
      account = create(:account, account_type: "tracking_asset")
      create(:balance_snapshot, account: account, balance: 1000, date: "2026-03-01")

      duplicate = build(:balance_snapshot, account: account, balance: 2000, date: "2026-03-01")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to be_present
    end

    it "allows same date for different accounts" do
      household = create(:household)
      account1 = create(:account, household: household, account_type: "tracking_asset")
      account2 = create(:account, household: household, account_type: "tracking_asset")

      create(:balance_snapshot, account: account1, balance: 1000, date: "2026-03-01")
      snapshot = build(:balance_snapshot, account: account2, balance: 2000, date: "2026-03-01")
      expect(snapshot).to be_valid
    end
  end
end
