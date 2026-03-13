require "rails_helper"

RSpec.describe HouseholdMembership, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:household) }
  end

  describe "validations" do
    subject { build(:household_membership) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[owner member]) }
  end

  describe "uniqueness" do
    it "prevents duplicate user-household pairs" do
      membership = create(:household_membership)
      duplicate = build(:household_membership, user: membership.user, household: membership.household)
      expect(duplicate).not_to be_valid
    end
  end
end
