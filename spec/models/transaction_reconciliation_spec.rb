require "rails_helper"

RSpec.describe "Transaction reconciliation", type: :model do
  let(:household) { create(:household) }
  let(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  describe "status enum" do
    it "defaults to uncleared" do
      t = create(:transaction, account: account, category: category, amount: -100, date: Date.today)
      expect(t.status).to eq("uncleared")
      expect(t).to be_uncleared
    end

    it "can be set to cleared" do
      t = create(:transaction, account: account, category: category, amount: -100, date: Date.today)
      t.update!(status: :cleared)
      expect(t).to be_cleared
    end

    it "can be set to reconciled" do
      t = create(:transaction, account: account, category: category, amount: -100, date: Date.today)
      t.update!(status: :reconciled)
      expect(t).to be_reconciled
    end
  end

  describe "reconciled lock protection" do
    let!(:transaction) do
      create(:transaction, account: account, category: category, amount: -100, date: Date.today, status: :reconciled)
    end

    it "prevents updating amount on reconciled transaction" do
      expect(transaction.update(amount: -200)).to be false
      expect(transaction.errors[:base]).to include("已對帳的交易無法修改")
    end

    it "prevents updating memo on reconciled transaction" do
      expect(transaction.update(memo: "changed")).to be false
    end

    it "prevents destroying reconciled transaction" do
      expect(transaction.destroy).to be false
      expect(transaction.errors[:base]).to include("已對帳的交易無法刪除")
    end

    it "allows status change from cleared to reconciled" do
      t = create(:transaction, account: account, category: category, amount: -100, date: Date.today, status: :cleared)
      expect(t.update(status: :reconciled)).to be true
    end
  end
end
