require "rails_helper"

RSpec.describe Account, type: :model do
  it { should belong_to(:household) }
  it { should have_many(:transactions).dependent(:destroy) }
  it { should have_many(:balance_snapshots).dependent(:destroy) }
  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:account_type).in_array(%w[budget tracking_asset tracking_liability]) }

  let(:household) { create(:household) }

  describe "scopes" do
    let!(:budget_account) { create(:account, household: household, account_type: "budget") }
    let!(:asset_account) { create(:account, household: household, account_type: "tracking_asset") }
    let!(:liability_account) { create(:account, household: household, account_type: "tracking_liability") }

    describe ".budget" do
      it "returns only budget accounts" do
        expect(Account.budget).to contain_exactly(budget_account)
      end
    end

    describe ".tracking_asset" do
      it "returns only tracking asset accounts" do
        expect(Account.tracking_asset).to contain_exactly(asset_account)
      end
    end

    describe ".tracking_liability" do
      it "returns only tracking liability accounts" do
        expect(Account.tracking_liability).to contain_exactly(liability_account)
      end
    end

    describe ".tracking" do
      it "returns both asset and liability accounts" do
        expect(Account.tracking).to contain_exactly(asset_account, liability_account)
      end
    end
  end

  describe "predicate methods" do
    it "#budget? returns true for budget accounts" do
      account = build(:account, account_type: "budget")
      expect(account.budget?).to be true
      expect(account.tracking?).to be false
    end

    it "#tracking? returns true for tracking accounts" do
      asset = build(:account, account_type: "tracking_asset")
      liability = build(:account, account_type: "tracking_liability")
      expect(asset.tracking?).to be true
      expect(liability.tracking?).to be true
    end

    it "#asset? returns true only for tracking_asset" do
      account = build(:account, account_type: "tracking_asset")
      expect(account.asset?).to be true
      expect(account.liability?).to be false
    end

    it "#liability? returns true only for tracking_liability" do
      account = build(:account, account_type: "tracking_liability")
      expect(account.liability?).to be true
      expect(account.asset?).to be false
    end
  end

  describe "#current_balance" do
    context "budget account" do
      it "returns starting_balance + sum of transactions" do
        account = create(:account, household: household, account_type: "budget", starting_balance: 1000)
        create(:transaction, account: account, amount: 500, date: Date.current)
        create(:transaction, account: account, amount: -200, date: Date.current)

        expect(account.current_balance).to eq(1300)
      end
    end

    context "tracking account with snapshots" do
      it "returns the most recent snapshot balance" do
        account = create(:account, household: household, account_type: "tracking_asset", starting_balance: 5000)
        create(:balance_snapshot, account: account, balance: 10000, date: "2026-01-01")
        create(:balance_snapshot, account: account, balance: 12000, date: "2026-03-01")

        expect(account.current_balance).to eq(12000)
      end
    end

    context "tracking account without snapshots" do
      it "returns starting_balance" do
        account = create(:account, household: household, account_type: "tracking_asset", starting_balance: 5000)

        expect(account.current_balance).to eq(5000)
      end
    end
  end
end
