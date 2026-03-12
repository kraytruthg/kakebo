require "rails_helper"

RSpec.describe "Multi-household workflow", type: :system do
  it "allows a user to create a personal household and track expenses separately" do
    # 1. Sign in with existing household
    household = create(:household, name: "家庭帳本")
    user = create(:user, household: household)
    account = create(:account, household: household, name: "家用戶頭", account_type: "budget")
    sign_in(user)

    # 2. Create personal household via settings
    visit settings_root_path
    within("main") { click_on "新增帳本" }
    fill_in "名稱", with: "Jerry 零用錢"
    click_button "建立"

    # 3. Should see success message
    expect(page).to have_content("帳本已建立")

    # 4. Switch back to family household
    find("[data-testid='household-switcher'] summary").click
    click_button "家庭帳本"

    # Wait for redirect to complete — should land on budget page
    expect(page).to have_current_path(budget_path)
    expect(page).to have_css("[data-testid='household-switcher'] summary", text: "家庭帳本")

    visit accounts_path
    expect(page).to have_content("家用戶頭")

    # 5. Switch to personal household
    find("[data-testid='household-switcher'] summary").click
    click_button "Jerry 零用錢"

    # New household has no accounts, so it redirects to onboarding
    expect(page).to have_current_path(onboarding_path)
    expect(page).to have_css("[data-testid='household-switcher'] summary", text: "Jerry 零用錢")

    visit accounts_path
    expect(page).not_to have_content("家用戶頭")
  end
end
