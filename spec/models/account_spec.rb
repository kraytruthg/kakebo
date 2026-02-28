require "rails_helper"

RSpec.describe Account, type: :model do
  it { should belong_to(:household) }
  xit { should have_many(:transactions).dependent(:destroy) } # enable after Task 7 adds Transaction
  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:account_type).in_array(%w[budget tracking]) }

  describe ".budget" do
    it "returns only budget accounts" do
      household = create(:household)
      budget = create(:account, household: household, account_type: "budget")
      create(:account, household: household, account_type: "tracking")

      expect(Account.budget).to contain_exactly(budget)
    end
  end
end
