require "rails_helper"

RSpec.describe "Reports", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household) }
  let!(:group) { create(:category_group, household: household, name: "食費") }
  let!(:category) { create(:category, category_group: group, name: "外食") }

  before { sign_in(user) }

  describe "空白狀態" do
    it "無支出時顯示空白提示" do
      visit reports_path
      expect(page).to have_text("本月尚無支出紀錄")
    end
  end

  describe "有支出資料" do
    before do
      create(:transaction,
             account: account, category: category,
             amount: -1000, date: Date.today, memo: "午餐")
      create(:transaction,
             account: account, category: category,
             amount: -500, date: Date.today, memo: "晚餐")
      visit reports_path
    end

    it "顯示類別名稱與總金額" do
      expect(page).to have_text("外食")
      expect(page).to have_text("NT$1,500")
    end

    it "顯示各類別支出列表標題" do
      expect(page).to have_text("各類別支出")
    end

    it "顯示總計列" do
      expect(page).to have_text("總計")
    end
  end

  describe "月份導覽" do
    it "可切換到上個月" do
      visit reports_path
      prev = Date.today.prev_month
      click_link "←"
      expect(page).to have_current_path(/year=#{prev.year}/)
      expect(page).to have_current_path(/month=#{prev.month}/)
    end
  end
end
