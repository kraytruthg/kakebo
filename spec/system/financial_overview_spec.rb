require "rails_helper"

RSpec.describe "Financial Overview", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:budget_account) { create(:account, household: household, account_type: "budget", starting_balance: 100000, balance: 100000) }

  before { sign_in(user) }

  describe "tab 導航" do
    it "從支出分析切換到財務總覽" do
      visit reports_path
      expect(page).to have_link("財務總覽")

      click_on "財務總覽"
      wait_for_turbo

      expect(page).to have_text("淨資產")
      expect(page).to have_text("儲蓄率（本月）")
      expect(page).to have_text("儲蓄率（年）")
    end
  end

  describe "財務指標顯示" do
    let!(:asset_account) { create(:account, household: household, account_type: "tracking_asset", starting_balance: 500000) }
    let!(:liability_account) { create(:account, household: household, account_type: "tracking_liability", starting_balance: 200000) }

    it "顯示淨資產與儲蓄率" do
      visit reports_financial_overview_path

      # net_worth = 100000 + 500000 - 200000 = 400000
      expect(page).to have_text("400,000")
      expect(page).to have_text("淨資產走勢")
      expect(page).to have_text("收支趨勢")
    end
  end

  describe "無資料時顯示空狀態" do
    it "顯示尚無資料" do
      visit reports_financial_overview_path

      expect(page).to have_text("淨資產")
    end
  end

  describe "手機版" do
    before { resize_to_mobile }
    after { resize_to_desktop }

    it "手機版顯示財務總覽" do
      visit reports_financial_overview_path

      expect(page).to have_text("淨資產")
      expect(page).to have_text("儲蓄率（本月）")
    end
  end
end
