require "rails_helper"

RSpec.describe "Per-user default account", type: :model do
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }
  let(:household) { user_a.households.first }
  let!(:account_cash) { create(:account, household: household, name: "現金") }
  let!(:account_credit) { create(:account, household: household, name: "信用卡") }

  before do
    user_b.household_memberships.create!(household: household, role: "member")
  end

  describe "independent default account per user" do
    it "allows two users in the same household to have different default accounts" do
      user_a.update!(default_account: account_cash)
      user_b.update!(default_account: account_credit)

      expect(user_a.reload.default_account).to eq(account_cash)
      expect(user_b.reload.default_account).to eq(account_credit)
    end

    it "changing one user's default account does not affect the other" do
      user_a.update!(default_account: account_cash)
      user_b.update!(default_account: account_cash)

      user_a.update!(default_account: account_credit)

      expect(user_a.reload.default_account).to eq(account_credit)
      expect(user_b.reload.default_account).to eq(account_cash)
    end
  end

  describe "validation" do
    it "accepts an account belonging to the user's household" do
      user_a.default_account = account_cash
      expect(user_a).to be_valid
    end

    it "rejects an account not belonging to any of the user's households" do
      other_household = create(:household, name: "Other")
      other_account = create(:account, household: other_household, name: "Other Account")

      user_a.default_account = other_account
      expect(user_a).not_to be_valid
      expect(user_a.errors[:default_account]).to be_present
    end

    it "allows nil default account" do
      user_a.default_account = nil
      expect(user_a).to be_valid
    end
  end
end
