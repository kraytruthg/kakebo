require "rails_helper"

RSpec.describe "Category Transactions", type: :system do
  let(:user)      { create(:user) }
  let(:household) { user.household }
  let!(:account1) { create(:account, household: household, name: "現金") }
  let!(:account2) { create(:account, household: household, name: "信用卡") }
  let!(:group)    { create(:category_group, household: household, name: "生活") }
  let!(:category) { create(:category, category_group: group, name: "食費") }
  let!(:txn1) do
    create(:transaction,
           account: account1, category: category,
           amount: -300, date: Date.new(2026, 3, 1), memo: "早餐")
  end
  let!(:txn2) do
    create(:transaction,
           account: account2, category: category,
           amount: -600, date: Date.new(2026, 3, 5), memo: "晚餐")
  end

  before { sign_in(user) }

  describe "從預算頁進入類別交易頁" do
    it "點擊類別名稱連結可進入明細頁" do
      visit budget_path(year: 2026, month: 3)
      click_link "食費"
      expect(page).to have_text("食費")
      expect(page).to have_text("2026年3月")
    end
  end

  describe "交易列表" do
    before do
      visit budget_category_transactions_path(2026, 3, category)
    end

    it "顯示跨帳戶的交易" do
      expect(page).to have_text("早餐")
      expect(page).to have_text("晚餐")
      expect(page).to have_text("現金")
      expect(page).to have_text("信用卡")
    end

    it "顯示合計金額" do
      expect(page).to have_text("-NT$900")
    end

    it "帳戶篩選只顯示該帳戶的交易" do
      click_link "現金"
      expect(page).to have_text("早餐")
      expect(page).not_to have_text("晚餐")
    end

    it "刪除交易後從列表消失" do
      accept_confirm do
        within("#transaction-#{txn1.id}") do
          find("button[aria-label='刪除交易']", visible: false).click
        end
      end
      expect(page).not_to have_text("早餐")
      expect(page).to have_text("晚餐")
    end
  end

  describe "編輯交易" do
    before do
      visit budget_category_transactions_path(2026, 3, category)
    end

    it "點擊編輯後可修改備註，更新後仍在明細頁" do
      edit_link = within("#transaction-#{txn1.id}") { find("a", text: "編輯", visible: false) }
      visit edit_link[:href]
      fill_in "備忘", with: "早餐（updated）"
      click_button "更新"
      expect(page).to have_text("食費")
    end
  end
end
