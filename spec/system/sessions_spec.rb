require "rails_helper"

RSpec.describe "Sessions", type: :system do
  let(:user) { create(:user) }
  let!(:account) { create(:account, household: user.household) }

  describe "登入" do
    it "成功後顯示預算頁面" do
      visit new_session_path

      fill_in "Email", with: user.email
      fill_in "密碼", with: "password123"
      click_button "登入"

      expect(page).to have_text("歡迎回來")
      expect(page).to have_text("Ready to Assign")
    end

    it "密碼錯誤時顯示錯誤訊息" do
      visit new_session_path

      fill_in "Email", with: user.email
      fill_in "密碼", with: "wrongpassword"
      click_button "登入"

      expect(page).to have_text("Email 或密碼錯誤")
    end
  end

  describe "登出" do
    it "點擊登出後導向登入頁面" do
      sign_in(user)

      find("button[aria-label='登出']").click

      expect(page).to have_current_path(new_session_path)
    end
  end
end
