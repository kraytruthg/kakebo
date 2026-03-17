require "rails_helper"

RSpec.describe "Accounts", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }

  before { sign_in(user) }

  it "新增帳戶後出現在帳戶列表" do
    visit accounts_path
    click_on "新增帳戶"

    expect(page).to have_field("帳戶名稱")
    fill_in "帳戶名稱", with: "玉山銀行"
    select "預算帳戶", from: "帳戶類型"
    field = find_field("起始餘額")
    field.native.clear
    field.send_keys("10000")
    click_button "建立帳戶"

    expect(page).to have_text("帳戶已建立")
    expect(page).to have_text("玉山銀行")
  end

  describe "刪除帳戶" do
    let!(:account) { create(:account, household: household, name: "測試帳戶", account_type: "budget") }

    it "從帳戶詳情頁刪除帳戶" do
      create(:transaction, account: account, amount: -100, date: Date.today)

      visit account_path(account)
      expect(page).to have_text("測試帳戶")

      accept_confirm do
        click_button "刪除"
      end

      expect(page).to have_text("帳戶已刪除")
      expect(page).not_to have_text("測試帳戶")
    end

    context "when account is the default account" do
      before { household.update!(default_account: account) }

      it "clears default_account after deletion" do
        visit account_path(account)

        accept_confirm do
          click_button "刪除"
        end

        expect(page).to have_text("帳戶已刪除")
        expect(household.reload.default_account_id).to be_nil
      end
    end
  end

  describe "帳戶詳情頁篩選與分頁" do
    let!(:account) { create(:account, household: household, name: "現金") }
    let!(:group) { create(:category_group, household: household, name: "生活") }
    let!(:category1) { create(:category, category_group: group, name: "食費") }
    let!(:category2) { create(:category, category_group: group, name: "交通") }

    it "帳戶頁支援類別篩選", js: true do
      create(:transaction, account: account, category: category1, amount: -300, date: Date.today, memo: "午餐")
      create(:transaction, account: account, category: category2, amount: -500, date: Date.today, memo: "電車")
      visit account_path(account, category_id: category1.id)
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "帳戶頁支援分頁", js: true do
      31.times { |i| create(:transaction, account: account, category: category1, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
      visit account_path(account)
      expect(page).to have_css("nav.pagy")
    end

    describe "手機版", js: true do
      before { page.driver.browser.manage.window.resize_to(375, 812) }
      after { page.driver.browser.manage.window.resize_to(1280, 800) }

      it "帳戶詳情頁手機版顯示篩選和卡片" do
        create(:transaction, account: account, category: category1, amount: -300, date: Date.today, memo: "午餐")
        visit account_path(account)
        expect(page).to have_css("[id^='transaction-mobile-']")
      end
    end
  end
end
