require "rails_helper"

RSpec.describe "交易編輯", type: :system do
  let(:user)    { create(:user) }
  let!(:account) { create(:account, household: user.households.first, account_type: "budget") }
  let!(:group)   { create(:category_group, household: user.households.first) }
  let!(:cat1)    { create(:category, category_group: group, name: "餐費") }
  let!(:cat2)    { create(:category, category_group: group, name: "交通") }
  let!(:txn)     { create(:transaction, account: account, category: cat1, amount: -500, date: Date.today, memo: "午餐") }

  before { sign_in(user) }

  it "修改金額後顯示成功通知" do
    visit account_path(account)
    within("#transaction-#{txn.id}") { click_link "編輯" }
    fill_in "金額", with: "-800"
    click_button "更新"
    expect(page).to have_text("交易已更新")
  end

  it "修改類別後顯示成功通知" do
    visit account_path(account)
    within("#transaction-#{txn.id}") { click_link "編輯" }
    select "交通", from: "類別"
    click_button "更新"
    expect(page).to have_text("交易已更新")
  end

  it "金額留空時顯示驗證錯誤" do
    visit account_path(account)
    within("#transaction-#{txn.id}") { click_link "編輯" }
    fill_in "金額", with: ""
    click_button "更新"
    expect(page).to have_text("編輯交易")
    expect(page).to have_text("Amount 不能為空白")
  end
end
