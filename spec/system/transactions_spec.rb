require "rails_helper"

RSpec.describe "Transactions", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    account
    category
    sign_in(user)
    expect(page).to have_text("全部已分配")
    visit account_path(account)
  end

  it "從帳戶頁新增交易後出現在列表" do
    page.execute_script("document.querySelector('[data-action=\"drawer#open\"]').click()")
    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")

    within("[data-drawer-target='panel']") do
      fill_in "transaction[amount]", with: "-500"
      fill_in "transaction[memo]", with: "午餐"
      click_button "新增交易"
    end

    expect(page).to have_text("午餐")
    expect(page).to have_text("-500")
  end

  it "刪除交易後從列表消失" do
    create(:transaction, account: account, amount: -1000, memo: "待刪除的交易", category: category)
    visit account_path(account)

    accept_confirm do
      find("button[aria-label='刪除交易']", visible: false).click
    end

    expect(page).not_to have_text("待刪除的交易")
  end
end
