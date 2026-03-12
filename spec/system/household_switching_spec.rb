require "rails_helper"

RSpec.describe "Household switching", type: :system do
  let(:household1) { create(:household, name: "家庭帳本") }
  let(:household2) { create(:household, name: "個人零用錢") }
  let(:user) { create(:user, household: household1) }
  let!(:account1) { create(:account, household: household1, name: "家用戶頭") }
  let!(:account2) { create(:account, household: household2, name: "零用錢錢包") }

  before do
    create(:household_membership, user: user, household: household2, role: "owner")
    sign_in(user)
  end

  it "switches between households" do
    visit accounts_path
    expect(page).to have_content("家用戶頭")
    expect(page).not_to have_content("零用錢錢包")

    find("[data-testid='household-switcher'] summary").click
    click_button "個人零用錢"

    # Wait for redirect to complete — nav should show new household name
    expect(page).to have_css("[data-testid='household-switcher']", text: "個人零用錢")

    visit accounts_path
    expect(page).to have_content("零用錢錢包")
    expect(page).not_to have_content("家用戶頭")
  end

  it "does not show switcher when user has only one household" do
    single_user = create(:user)
    create(:account, household: single_user.households.first)
    sign_in(single_user)
    visit accounts_path
    expect(page).not_to have_css("[data-testid='household-switcher']")
  end
end
