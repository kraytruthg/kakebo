require "rails_helper"

RSpec.describe "Transaction Lists", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account1) { create(:account, household: household, name: "現金") }
  let!(:account2) { create(:account, household: household, name: "信用卡") }
  let!(:group) { create(:category_group, household: household, name: "生活") }
  let!(:category1) { create(:category, category_group: group, name: "食費") }
  let!(:category2) { create(:category, category_group: group, name: "交通") }
  let!(:txn_food) do
    create(:transaction, account: account1, category: category1,
           amount: -300, date: Date.new(2026, 3, 5), memo: "午餐")
  end
  let!(:txn_transport) do
    create(:transaction, account: account2, category: category2,
           amount: -1500, date: Date.new(2026, 3, 10), memo: "電車")
  end
  let!(:txn_income) do
    create(:transaction, account: account1, category: nil,
           amount: 50_000, date: Date.new(2026, 3, 15), memo: "薪水")
  end

  before { sign_in(user) }

  describe "桌面版", js: true do
    it "從側邊欄進入交易列表" do
      visit budget_path
      within("aside") do
        click_link "交易"
      end
      wait_for_turbo
      expect(page).to have_text("交易紀錄")
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
      expect(page).to have_text("薪水")
    end

    it "篩選帳戶" do
      visit transaction_lists_path(account_id: account1.id)
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "篩選類別" do
      visit transaction_lists_path(category_id: category1.id)
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
      expect(page).not_to have_text("薪水")
    end

    it "搜尋備註" do
      visit transaction_lists_path(query: "午餐")
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "日期範圍篩選" do
      visit transaction_lists_path(date_from: "2026-03-08", date_to: "2026-03-12")
      expect(page).to have_text("電車")
      expect(page).not_to have_text("午餐")
      expect(page).not_to have_text("薪水")
    end

    it "清除篩選" do
      visit transaction_lists_path(account_id: account1.id)
      first(:link, "清除").click
      wait_for_turbo
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
    end

    it "分頁導航" do
      31.times do |i|
        create(:transaction, account: account1, category: category1,
               amount: -100, date: Date.new(2026, 3, 1) + i.days, memo: "交易#{i}")
      end
      visit transaction_lists_path
      expect(page).to have_css("nav.pagy")
    end

    it "刪除交易" do
      visit transaction_lists_path
      accept_confirm do
        within("#transaction-#{txn_food.id}") do
          find("button[aria-label='刪除交易']", visible: false).click
        end
      end
      expect(page).not_to have_text("午餐")
      expect(page).to have_text("電車")
    end
  end

  describe "手機版", js: true do
    before do
      resize_to_mobile
    end

    after do
      resize_to_desktop
    end

    it "從帳戶頁進入所有交易" do
      visit accounts_path
      click_link "所有交易"
      wait_for_turbo
      expect(page).to have_text("交易紀錄")
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
    end

    it "手機版顯示卡片式列表" do
      visit transaction_lists_path
      expect(page).to have_css("[id^='transaction-mobile-']")
    end

    it "手機版篩選" do
      visit transaction_lists_path(account_id: account1.id)
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end
  end
end
