require "rails_helper"

RSpec.describe FireGoal, type: :model do
  it { should belong_to(:household) }
  it { should validate_numericality_of(:withdrawal_rate).is_greater_than(0) }
  it { should validate_numericality_of(:expected_return_rate).is_greater_than(0) }

  let(:household) { create(:household) }
  let!(:budget_account) { create(:account, household: household, account_type: "budget", starting_balance: 50000, balance: 50000) }

  describe "uniqueness" do
    it "only allows one fire goal per household" do
      create(:fire_goal, household: household)
      duplicate = build(:fire_goal, household: household)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#fire_number" do
    it "uses target_amount when set" do
      goal = create(:fire_goal, household: household, target_amount: 20000000)
      expect(goal.fire_number).to eq(20000000)
    end

    it "calculates from annual_expense / withdrawal_rate * 100" do
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      # Create 10 monthly expenses of -50000 well within 12 months
      10.times do |i|
        create(:transaction, account: budget_account, amount: -50000,
               date: Date.current - (i + 1).months + 1.day, category: category)
      end

      goal = create(:fire_goal, household: household, withdrawal_rate: 4.0)
      # actual_annual_expense = 500000, fire_number = 500000 / 4.0 * 100 = 12500000
      expect(goal.fire_number).to eq(12500000)
    end

    it "uses target_annual_expense when set" do
      goal = create(:fire_goal, household: household, target_annual_expense: 600000, withdrawal_rate: 4.0)
      expect(goal.fire_number).to eq(15000000)
    end
  end

  describe "#progress_percentage" do
    it "returns net_worth / fire_number * 100" do
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 5500000)
      goal = create(:fire_goal, household: household, target_amount: 16500000)

      # net_worth = 50000 + 5500000 = 5550000
      # progress = 5550000 / 16500000 * 100 = 33.6
      expect(goal.progress_percentage).to eq(33.6)
    end

    it "returns 0 when fire_number is zero" do
      goal = create(:fire_goal, household: household, target_amount: 0, target_annual_expense: 0)
      # annual_expense = 0, fire_number would be 0/4*100 = 0, but target_amount is 0
      expect(goal.progress_percentage).to eq(0)
    end
  end

  describe "#projected_fire_date" do
    it "returns today when already achieved" do
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 20000000)
      goal = create(:fire_goal, household: household, target_amount: 16500000)

      expect(goal.projected_fire_date).to eq(Date.current)
    end

    it "returns a future date when achievable" do
      asset = create(:account, household: household, account_type: "tracking_asset", starting_balance: 5000000)

      # Create income for past 6 months
      6.times do |i|
        create(:transaction, account: budget_account, amount: 100000,
               date: Date.current - (i + 1).months, category: nil, transfer_pair_id: nil)
      end

      goal = create(:fire_goal, household: household, target_amount: 16500000, expected_return_rate: 7.0)
      result = goal.projected_fire_date
      expect(result).to be > Date.current
      expect(result).to be < Date.current + 100.years
    end

    it "returns nil when not achievable within 100 years" do
      goal = create(:fire_goal, household: household, target_amount: 999999999999, expected_return_rate: 0.01)
      expect(goal.projected_fire_date).to be_nil
    end
  end
end
