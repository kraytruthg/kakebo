require "rails_helper"

RSpec.describe "Tracking Accounts", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }

  before { sign_in(user) }

  describe "新增 tracking 帳戶" do
    it "新增資產帳戶後顯示在帳戶列表" do
      visit accounts_path
      click_on "新增帳戶"
      wait_for_turbo

      fill_in "帳戶名稱", with: "股票帳戶"
      select "資產帳戶", from: "帳戶類型"
      fill_in "起始餘額", with: "500000"
      click_button "建立帳戶"
      wait_for_turbo

      expect(page).to have_text("帳戶已建立")
      expect(page).to have_text("股票帳戶")
      expect(page).to have_text("資產帳戶")
    end

    it "新增負債帳戶後顯示在帳戶列表" do
      visit accounts_path
      click_on "新增帳戶"
      wait_for_turbo

      fill_in "帳戶名稱", with: "房貸"
      select "負債帳戶", from: "帳戶類型"
      fill_in "起始餘額", with: "3000000"
      click_button "建立帳戶"
      wait_for_turbo

      expect(page).to have_text("帳戶已建立")
      expect(page).to have_text("房貸")
      expect(page).to have_text("負債帳戶")
    end
  end

  describe "帳戶列表分區顯示" do
    let!(:budget_account) { create(:account, household: household, name: "玉山銀行", account_type: "budget") }
    let!(:asset_account) { create(:account, household: household, name: "股票帳戶", account_type: "tracking_asset", starting_balance: 500000) }
    let!(:liability_account) { create(:account, household: household, name: "房貸", account_type: "tracking_liability", starting_balance: 3000000) }

    it "顯示三個分區" do
      visit accounts_path

      expect(page).to have_text("預算帳戶")
      expect(page).to have_text("資產帳戶")
      expect(page).to have_text("負債帳戶")
      expect(page).to have_text("玉山銀行")
      expect(page).to have_text("股票帳戶")
      expect(page).to have_text("房貸")
    end

    it "tracking 帳戶顯示更新餘額連結" do
      visit accounts_path

      expect(page).to have_link("更新餘額", count: 2)
    end
  end

  describe "更新餘額" do
    let!(:asset_account) { create(:account, household: household, name: "股票帳戶", account_type: "tracking_asset", starting_balance: 500000) }

    it "建立 balance snapshot 更新餘額" do
      visit accounts_path
      click_on "更新餘額"
      wait_for_turbo

      expect(page).to have_text("更新餘額 — 股票帳戶")
      fill_in "目前餘額", with: "550000"
      fill_in "日期", with: "2026-03-15"
      fill_in "備註（選填）", with: "Q1 估值"
      click_button "更新餘額"
      wait_for_turbo

      expect(page).to have_text("餘額已更新")
      expect(page).to have_text("550,000")
    end
  end

  describe "手機版" do
    before { resize_to_mobile }
    after { resize_to_desktop }

    let!(:budget_account) { create(:account, household: household, name: "現金", account_type: "budget") }
    let!(:asset_account) { create(:account, household: household, name: "ETF", account_type: "tracking_asset", starting_balance: 100000) }

    it "手機版帳戶列表顯示分區" do
      visit accounts_path

      expect(page).to have_text("預算帳戶")
      expect(page).to have_text("資產帳戶")
      expect(page).to have_text("現金")
      expect(page).to have_text("ETF")
    end
  end
end
