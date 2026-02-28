require "rails_helper"

RSpec.describe Transaction, type: :model do
  it { should belong_to(:account) }
  it { should belong_to(:category).optional }
  it { should validate_presence_of(:amount) }
  it { should validate_presence_of(:date) }

  describe ".for_month" do
    it "returns transactions in the given month" do
      account = create(:account)
      t1 = create(:transaction, account: account, date: Date.new(2026, 2, 15))
      create(:transaction, account: account, date: Date.new(2026, 3, 1))

      expect(Transaction.for_month(2026, 2)).to contain_exactly(t1)
    end
  end

  describe "income transaction" do
    it "allows nil category for income" do
      account = create(:account)
      transaction = build(:transaction, account: account, category: nil, amount: 80_000)
      expect(transaction).to be_valid
    end
  end
end
