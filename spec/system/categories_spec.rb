require "rails_helper"

RSpec.describe "類別管理", type: :system do
  let(:user) { create(:user) }
  let!(:group) { create(:category_group, household: user.household, name: "日常開銷") }

  before { sign_in(user) }

  it "新增 CategoryGroup" do
    visit category_groups_path
    click_link "新增群組"
    fill_in "名稱", with: "娛樂"
    click_button "儲存"
    expect(page).to have_text("娛樂")
  end

  it "新增 Category" do
    visit category_groups_path
    within("#group-#{group.id}") { click_link "新增類別" }
    fill_in "名稱", with: "電影"
    click_button "儲存"
    expect(page).to have_text("電影")
  end

  it "重新命名 CategoryGroup" do
    visit category_groups_path
    within("#group-#{group.id}") { click_link "編輯" }
    fill_in "名稱", with: "每日花費"
    click_button "儲存"
    expect(page).to have_text("每日花費")
  end

  it "刪除空的 Category 成功" do
    cat = create(:category, category_group: group, name: "無交易")
    visit category_groups_path
    within("#category-#{cat.id}") { click_button "刪除" }
    expect(page).not_to have_text("無交易")
  end

  it "刪除有交易的 Category 顯示錯誤" do
    cat = create(:category, category_group: group, name: "有交易")
    account = create(:account, household: user.household, account_type: "budget")
    create(:transaction, account: account, category: cat, amount: -500, date: Date.today)
    visit category_groups_path
    within("#category-#{cat.id}") { click_button "刪除" }
    expect(page).to have_text("有交易")
    expect(page).to have_text("筆交易")
  end
end
