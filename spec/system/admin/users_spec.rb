require "rails_helper"

RSpec.describe "Admin user management", type: :system do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
  end

  let!(:household) { create(:household, name: "我們家") }
  let!(:admin) { create(:user, name: "Admin", email: "admin@example.com", password: "password123", household: household) }
  let!(:other_user) { create(:user, name: "Rainy", email: "rainy@example.com", password: "password123", household: household) }
  let!(:account) { create(:account, household: household) }

  describe "user list" do
    it "shows all users with their household" do
      sign_in(admin)
      visit admin_users_path

      expect(page).to have_content("用戶管理")
      expect(page).to have_content("Admin")
      expect(page).to have_content("admin@example.com")
      expect(page).to have_content("Rainy")
      expect(page).to have_content("rainy@example.com")
      expect(page).to have_content("我們家")
    end
  end

  describe "create user" do
    it "creates a user assigned to an existing household" do
      sign_in(admin)
      visit new_admin_user_path

      fill_in "姓名", with: "New User"
      fill_in "Email", with: "newuser@example.com"
      fill_in "密碼", with: "password123"
      fill_in "確認密碼", with: "password123"
      select "我們家", from: "家庭"
      click_button "建立用戶"

      expect(page).to have_content("用戶已建立")
      expect(page).to have_content("New User")
      expect(page).to have_content("newuser@example.com")
      expect(User.find_by(email: "newuser@example.com").households.first).to eq(household)
    end

    it "shows validation errors for invalid input" do
      sign_in(admin)
      visit new_admin_user_path
      click_button "建立用戶"

      expect(page).to have_content("Name")
    end
  end

  describe "edit user" do
    it "updates user name and email" do
      sign_in(admin)
      visit edit_admin_user_path(other_user)

      fill_in "姓名", with: "Updated Name"
      fill_in "Email", with: "updated@example.com"
      click_button "更新用戶"

      expect(page).to have_content("用戶已更新")
      expect(page).to have_content("Updated Name")
      expect(page).to have_content("updated@example.com")
    end

    it "resets password when provided" do
      sign_in(admin)
      visit edit_admin_user_path(other_user)

      fill_in "新密碼", with: "newpassword123"
      fill_in "確認新密碼", with: "newpassword123"
      click_button "更新用戶"

      expect(page).to have_content("用戶已更新")

      # Verify new password works by logging out and back in
      find("button[aria-label='登出']").click
      sign_in(other_user.reload, password: "newpassword123")
      expect(page).to have_content("預算")
    end

    it "does not change password when fields are blank" do
      sign_in(admin)
      visit edit_admin_user_path(other_user)

      fill_in "姓名", with: "Same Password"
      click_button "更新用戶"

      expect(page).to have_content("用戶已更新")

      # Verify old password still works
      find("button[aria-label='登出']").click
      sign_in(other_user.reload, password: "password123")
      expect(page).to have_content("預算")
    end
  end
end

RSpec.describe "Admin access control", type: :system do
  let!(:household) { create(:household) }
  let!(:account) { create(:account, household: household) }
  let!(:user) { create(:user, household: household) }

  it "does not show admin link for non-admin users" do
    sign_in(user)
    visit budget_path
    expect(page).not_to have_link("管理", exact: true)
  end

  it "redirects non-admin from admin pages" do
    sign_in(user)
    visit admin_users_path
    expect(page).to have_current_path(budget_path, ignore_query: true)
    expect(page).to have_content("權限不足")
  end
end
