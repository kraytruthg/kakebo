require "rails_helper"

RSpec.describe "FIRE Dashboard", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:budget_account) { create(:account, household: household, account_type: "budget", starting_balance: 100000, balance: 100000) }

  before { sign_in(user) }

  describe "無 FIRE 目標" do
    it "顯示目標設定表單" do
      visit reports_fire_path

      expect(page).to have_text("FIRE 目標設定")
      expect(page).to have_field("提領率 (%)")
      expect(page).to have_field("預期投報率 (%)")
      expect(page).to have_button("設定目標")
    end
  end

  describe "設定 FIRE 目標" do
    it "建立新的 FIRE 目標" do
      visit reports_fire_path

      fill_in "提領率 (%)", with: "4.0"
      fill_in "預期投報率 (%)", with: "7.0"
      fill_in "FIRE Number（留空自動計算）", with: "16500000"
      click_button "設定目標"
      wait_for_turbo

      expect(page).to have_text("FIRE 目標已設定")
      expect(page).to have_text("FIRE 進度")
      expect(page).to have_text("16,500,000")
    end
  end

  describe "已有 FIRE 目標" do
    let!(:asset_account) { create(:account, household: household, account_type: "tracking_asset", starting_balance: 5500000) }
    let!(:fire_goal) { create(:fire_goal, household: household, target_amount: 16500000) }

    it "顯示進度與目標資訊" do
      visit reports_fire_path

      expect(page).to have_text("FIRE 進度")
      expect(page).to have_text("16,500,000")
      expect(page).to have_button("更新目標")
    end

    it "更新 FIRE 目標" do
      visit reports_fire_path

      fill_in "提領率 (%)", with: "3.5"
      click_button "更新目標"
      wait_for_turbo

      expect(page).to have_text("FIRE 目標已更新")
    end
  end

  describe "tab 導航" do
    it "從支出分析到 FIRE" do
      visit reports_path
      click_on "FIRE"
      wait_for_turbo

      expect(page).to have_text("FIRE 目標設定")
    end
  end

  describe "手機版" do
    before { resize_to_mobile }
    after { resize_to_desktop }

    it "手機版顯示 FIRE dashboard" do
      visit reports_fire_path

      expect(page).to have_text("FIRE 目標設定")
      expect(page).to have_field("提領率 (%)")
    end
  end
end
