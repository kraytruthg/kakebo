require "rails_helper"

RSpec.describe User, "household management" do
  describe "auto-creates a household when none is assigned" do
    it "creates a household and membership on user creation" do
      user = User.create!(name: "Test", email: "test@example.com", password: "password123")
      expect(user.households.count).to eq(1)
      expect(user.households.first.name).to eq("Test 的家")
      expect(user.household_memberships.first.role).to eq("owner")
    end
  end

  describe "does not create a household when one is provided" do
    it "uses the provided household via membership" do
      household = create(:household, name: "Existing")
      user = User.new(name: "Test", email: "test2@example.com", password: "password123")
      user.household_memberships.build(household: household, role: "member")
      user.save!
      expect(user.households).to eq([household])
    end
  end
end
