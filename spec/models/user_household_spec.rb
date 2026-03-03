require "rails_helper"

RSpec.describe User, "household creation" do
  it "auto-creates a household when none is assigned" do
    user = User.create!(name: "Test", email: "test@example.com", password: "password123")
    expect(user.household).to be_present
    expect(user.household.name).to eq("Test 的家")
  end

  it "does not create a household when one is already assigned" do
    existing_household = create(:household, name: "我們家")
    user = User.create!(name: "Test", email: "test2@example.com", password: "password123", household: existing_household)
    expect(user.household).to eq(existing_household)
    expect(Household.count).to eq(1)
  end
end
