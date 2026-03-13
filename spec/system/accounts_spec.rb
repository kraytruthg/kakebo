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
    find_field("起始餘額").execute_script("this.value = '10000'; this.dispatchEvent(new Event('input', { bubbles: true }))")
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
end
