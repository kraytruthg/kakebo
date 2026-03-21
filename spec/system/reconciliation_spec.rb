require "rails_helper"

RSpec.describe "Account reconciliation", type: :system do
  before { driven_by :selenium, using: :headless_chrome }

  let(:user) { create(:user, password: "password123") }
  let(:household) { user.households.first }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }
  let!(:account) { create(:account, household: household, name: "玉山銀行", account_type: "budget", starting_balance: 10_000, balance: 9_000, reconciled_balance: 10_000) }
  let!(:t1) { create(:transaction, account: account, category: category, amount: -500, date: Date.today, memo: "午餐", status: :uncleared) }
  let!(:t2) { create(:transaction, account: account, category: category, amount: -300, date: Date.today, memo: "咖啡", status: :uncleared) }
  let!(:t3) { create(:transaction, account: account, category: category, amount: -200, date: Date.today, memo: "書籍", status: :uncleared) }

  before { sign_in user }

  describe "desktop" do
    before { page.driver.browser.manage.window.resize_to(1280, 800) }

    it "completes reconciliation when difference is zero" do
      visit account_path(account)
      click_link "對帳"

      expect(page).to have_text("對帳 — 玉山銀行")
      expect(page).to have_text("待確認交易（3 筆）")

      # Enter bank balance
      field = find("input[data-reconciliation-target='bankBalance']")
      field.fill_in with: "9000"

      # Check all 3 transactions, waiting for each toggle to complete
      within("#reconciliation-row-#{t1.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t1.id}[data-cleared='true']")

      within("#reconciliation-row-#{t2.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t2.id}[data-cleared='true']")

      within("#reconciliation-row-#{t3.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t3.id}[data-cleared='true']")

      # Difference should be 0
      expect(page).to have_css("[data-reconciliation-target='difference']", text: "$0")

      click_button "完成對帳"
      expect(page).to have_text("對帳完成")

      # Transactions should be reconciled
      expect(t1.reload.status).to eq("reconciled")
      expect(t2.reload.status).to eq("reconciled")
      expect(t3.reload.status).to eq("reconciled")

      # Account should be updated
      account.reload
      expect(account.reconciled_balance).to eq(9_000)
      expect(account.last_reconciled_at).not_to be_nil
    end

    it "shows reconciled transactions as locked" do
      t1.update!(status: :reconciled)

      visit account_path(account)
      expect(page).to have_text("已鎖定")
    end

    it "prevents completing reconciliation when difference is not zero" do
      visit new_account_reconciliation_path(account)

      field = find("input[data-reconciliation-target='bankBalance']")
      field.fill_in with: "9999"

      within("#reconciliation-row-#{t1.id}") { click_button }

      expect(page).to have_button("完成對帳", disabled: true)
    end

    it "cancels reconciliation and resets cleared transactions" do
      t1.update!(status: :cleared)

      visit new_account_reconciliation_path(account)
      accept_confirm { click_button "取消對帳" }

      expect(page).to have_current_path(account_path(account))
      expect(t1.reload.status).to eq("uncleared")
    end
  end

  describe "mobile" do
    before { page.driver.browser.manage.window.resize_to(375, 812) }

    it "can complete reconciliation on mobile" do
      visit new_account_reconciliation_path(account)

      expect(page).to have_text("對帳 — 玉山銀行")

      field = find("input[data-reconciliation-target='bankBalance']")
      field.fill_in with: "9000"

      within("#reconciliation-row-#{t1.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t1.id}[data-cleared='true']")

      within("#reconciliation-row-#{t2.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t2.id}[data-cleared='true']")

      within("#reconciliation-row-#{t3.id}") { click_button }
      expect(page).to have_css("#reconciliation-row-#{t3.id}[data-cleared='true']")

      expect(page).to have_css("[data-reconciliation-target='difference']", text: "$0")

      click_button "完成對帳"
      expect(page).to have_text("對帳完成")
    end
  end
end
