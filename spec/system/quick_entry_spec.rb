require "rails_helper"

RSpec.describe "快速記帳", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household, name: "Jerry 現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "生活花費") }

  before { sign_in(user) }

  it "parses input and shows confirmation form" do
    visit new_quick_entry_path
    fill_in "input", with: "停車費 100"
    click_button "解析"

    expect(page).to have_text("確認交易")
    expect(page).to have_field("amount", with: "100.0")
    expect(page).to have_field("memo", with: "停車費")
  end

  it "creates transaction from confirmation form" do
    visit new_quick_entry_path
    fill_in "input", with: "午餐 350"
    click_button "解析"

    expect(page).to have_button("確認建立")
    select "Jerry 現金", from: "account_id"
    select "生活花費", from: "category_id"
    click_button "確認建立"

    expect(page).to have_text("交易已建立")
    expect(Transaction.last).to have_attributes(
      amount: -350.to_d,
      memo: "午餐"
    )
  end

  it "pre-fills account and category when mappings exist" do
    create(:quick_entry_mapping, household: household, keyword: "Jerry", target: account)
    create(:quick_entry_mapping, household: household, keyword: "家樂福", target: category)

    visit new_quick_entry_path
    fill_in "input", with: "紀錄 Jerry 支付 家樂福 500"
    click_button "解析"

    expect(page).to have_text("確認交易")
    expect(page).to have_select("account_id", selected: "Jerry 現金")
    expect(page).to have_select("category_id", selected: "生活花費")
  end

  it "saves new mapping when remember checkbox is checked" do
    visit new_quick_entry_path
    fill_in "input", with: "停車費 100"
    click_button "解析"

    expect(page).to have_button("確認建立")
    select "Jerry 現金", from: "account_id"
    select "生活花費", from: "category_id"
    check "remember_category"
    click_button "確認建立"

    expect(page).to have_text("交易已建立")
    expect(QuickEntryMapping.find_by(keyword: "停車費", target_type: "Category")).to be_present
  end

  it "shows error for unparseable input" do
    visit new_quick_entry_path
    fill_in "input", with: "hello"
    click_button "解析"

    expect(page).to have_text("無法解析輸入")
  end
end
