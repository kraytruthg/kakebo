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

  let(:household) { create(:household) }
  let(:account_a) { create(:account, household: household) }
  let(:account_b) { create(:account, household: household) }

  describe "#transfer?" do
    it "transfer_pair_id 為 nil 時回傳 false" do
      txn = create(:transaction, account: account_a, transfer_pair_id: nil)
      expect(txn.transfer?).to eq(false)
    end

    it "transfer_pair_id 存在時回傳 true" do
      outgoing = create(:transaction, account: account_a, category: nil, transfer_pair_id: nil)
      incoming = create(:transaction, account: account_b, category: nil, transfer_pair_id: outgoing.id)
      outgoing.update!(transfer_pair_id: incoming.id)
      expect(outgoing.reload.transfer?).to eq(true)
    end
  end

  describe "#income?" do
    it "category 有值時回傳 false" do
      txn = create(:transaction, account: account_a)
      expect(txn.income?).to eq(false)
    end

    it "category 為 nil 且非轉帳時回傳 true" do
      txn = create(:transaction, account: account_a, category: nil, transfer_pair_id: nil)
      expect(txn.income?).to eq(true)
    end

    it "轉帳交易回傳 false（即使 category 為 nil）" do
      outgoing = create(:transaction, account: account_a, category: nil, transfer_pair_id: nil)
      incoming = create(:transaction, account: account_b, category: nil, transfer_pair_id: outgoing.id)
      outgoing.update!(transfer_pair_id: incoming.id)
      expect(outgoing.reload.income?).to eq(false)
    end
  end

  describe "#transfer_pair" do
    it "回傳互相關聯的另一筆交易" do
      outgoing = create(:transaction, account: account_a, category: nil, transfer_pair_id: nil)
      incoming = create(:transaction, account: account_b, category: nil, transfer_pair_id: outgoing.id)
      outgoing.update!(transfer_pair_id: incoming.id)
      expect(outgoing.reload.transfer_pair).to eq(incoming)
      expect(incoming.reload.transfer_pair).to eq(outgoing)
    end
  end
end
