require "rails_helper"

RSpec.describe Household, type: :model do
  describe "#transactions" do
    let(:household) { create(:household) }
    let!(:account) { create(:account, household: household) }
    let(:category_group) { create(:category_group, household: household) }
    let(:category) { create(:category, category_group: category_group) }
    let!(:txn) { create(:transaction, account: account, category: category, amount: -500, date: Date.today) }

    it "returns transactions through accounts" do
      expect(household.transactions).to include(txn)
    end
  end
end
