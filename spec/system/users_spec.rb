require "rails_helper"

RSpec.describe "Users", type: :system do
  describe "註冊" do
    context "REGISTRATION_OPEN=true" do
      before { stub_const("ENV", ENV.to_h.merge("REGISTRATION_OPEN" => "true")) }

      it "填寫正確資料後成功登入並進入預算頁" do
        visit signup_path

        fill_in "姓名", with: "測試用戶"
        fill_in "Email", with: "test@example.com"
        fill_in "密碼", with: "password123"
        fill_in "確認密碼", with: "password123"
        click_button "註冊"

        expect(page).to have_text("開始設定")
      end

      it "email 重複時顯示錯誤" do
        create(:user, email: "dup@example.com")
        visit signup_path

        fill_in "姓名", with: "重複用戶"
        fill_in "Email", with: "dup@example.com"
        fill_in "密碼", with: "password123"
        fill_in "確認密碼", with: "password123"
        click_button "註冊"

        expect(page).to have_text("Email 已被使用")
      end
    end

    context "REGISTRATION_OPEN=false" do
      before { stub_const("ENV", ENV.to_h.merge("REGISTRATION_OPEN" => "false")) }

      it "顯示目前不開放註冊" do
        visit signup_path
        expect(page).to have_text("目前不開放註冊")
      end
    end
  end
end
