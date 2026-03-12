require "rails_helper"

RSpec.describe "帳戶間轉帳", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account_a) { create(:account, household: household, name: "支票帳戶", starting_balance: 10_000) }
  let!(:account_b) { create(:account, household: household, name: "儲蓄帳戶", starting_balance: 0) }

  before do
    account_a.recalculate_balance!
    account_b.recalculate_balance!
    sign_in(user)
    expect(page).to have_text("全部已分配")
  end

  describe "建立轉帳" do
    it "Happy path：從帳戶頁點轉帳，填表後兩帳戶各出現轉帳紀錄且餘額正確" do
      visit account_path(account_a)
      click_link "轉帳"

      expect(page).to have_current_path(new_transfer_path(from_account_id: account_a.id))

      select "儲蓄帳戶", from: "目標帳戶"
      fill_in "金額", with: "3000"
      fill_in "備註（選填）", with: "月存款"
      click_button "確認轉帳"

      expect(page).to have_current_path(account_path(account_a))
      expect(page).to have_text("轉帳已建立")
      expect(page).to have_text("轉出 → 儲蓄帳戶")
      expect(page).to have_text("-3,000")
      expect(page).to have_text("7,000")  # 10000 - 3000

      visit account_path(account_b)
      expect(page).to have_text("轉入 ← 支票帳戶")
      expect(page).to have_text("3,000")  # balance
    end
  end

  describe "刪除轉帳" do
    before do
      # 預先建立一筆轉帳
      visit account_path(account_a)
      click_link "轉帳"
      select "儲蓄帳戶", from: "目標帳戶"
      fill_in "金額", with: "2000"
      click_button "確認轉帳"
      expect(page).to have_text("轉帳已建立")
    end

    it "刪除轉帳後兩筆同時消失，兩帳戶餘額還原" do
      visit account_path(account_a)
      expect(page).to have_text("轉出 → 儲蓄帳戶")

      accept_confirm do
        find("button[aria-label='刪除交易']", visible: false).click
      end

      expect(page).not_to have_text("轉出 → 儲蓄帳戶")
      expect(page).to have_text("10,000")  # 還原

      visit account_path(account_b)
      expect(page).not_to have_text("轉入 ← 支票帳戶")
      expect(page).to have_text("0")  # 還原
    end
  end

  describe "錯誤情境" do
    it "來源與目標帳戶相同時顯示錯誤訊息" do
      visit new_transfer_path(from_account_id: account_a.id)
      select "支票帳戶", from: "目標帳戶"
      fill_in "金額", with: "1000"
      click_button "確認轉帳"

      expect(page).to have_current_path(transfers_path)
      expect(page).to have_text("來源與目標帳戶不可相同")
    end
  end
end
