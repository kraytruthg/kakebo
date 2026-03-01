require "rails_helper"

RSpec.describe "Onboarding", type: :system do
  context "新用戶（無帳戶）" do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it "登入後導向 onboarding 頁" do
      visit root_path
      expect(page).to have_current_path(onboarding_path)
      expect(page).to have_text("開始設定")
    end

    it "建立帳戶後可進入預算頁" do
      visit onboarding_path
      click_link "新增帳戶"
      fill_in "名稱", with: "玉山銀行"
      select "預算帳戶", from: "帳戶類型"
      fill_in "起始餘額", with: "50000"
      click_button "建立帳戶"
      expect(page).to have_text("帳戶已建立")
      visit root_path
      expect(page).to have_current_path(budget_path)
    end
  end

  context "已有帳戶的用戶" do
    let(:user)    { create(:user) }
    let!(:account) { create(:account, household: user.household) }

    before { sign_in(user) }

    it "不觸發 onboarding，直接進入預算頁" do
      visit root_path
      expect(page).to have_current_path(budget_path)
    end
  end
end
