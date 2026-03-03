require "rails_helper"

RSpec.describe "Admin user management", type: :system do
  before do
    driven_by :selenium, using: :headless_chrome
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
  end

  let!(:household) { create(:household, name: "我們家") }
  let!(:admin) { create(:user, name: "Admin", email: "admin@example.com", password: "password123", household: household) }
  let!(:other_user) { create(:user, name: "Rainy", email: "rainy@example.com", password: "password123", household: household) }

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
end
