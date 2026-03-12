require "rails_helper"

RSpec.describe "快速記帳對應管理", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "飲食") }

  before { sign_in(user) }

  it "creates a new category mapping" do
    visit settings_quick_entry_mappings_path
    click_link "新增對應"

    fill_in "關鍵字", with: "午餐"
    select "類別", from: "對應類型"
    select "飲食", from: "category_target_id"
    click_button "新增對應"

    expect(page).to have_text("對應已新增")
    expect(page).to have_text("午餐")
  end

  it "creates a new account mapping" do
    visit settings_quick_entry_mappings_path
    click_link "新增對應"

    fill_in "關鍵字", with: "Jerry"
    select "帳戶", from: "對應類型"
    expect(page).to have_css("#category_target_id[disabled]", visible: :all)
    select "現金", from: "account_target_id"
    click_button "新增對應"

    expect(page).to have_text("對應已新增")
    expect(page).to have_text("Jerry")
  end

  it "edits an existing mapping" do
    mapping = create(:quick_entry_mapping, household: household, keyword: "舊名", target: category)
    visit settings_quick_entry_mappings_path

    find(".divide-y > div", text: "舊名").find("a[href*='edit']").click

    fill_in "關鍵字", with: "新名"
    click_button "儲存"

    expect(page).to have_text("對應已更新")
    expect(page).to have_text("新名")
    expect(page).not_to have_text("舊名")
  end

  it "deletes a mapping" do
    create(:quick_entry_mapping, household: household, keyword: "要刪除", target: category)
    visit settings_quick_entry_mappings_path

    within(find(".divide-y > div", text: "要刪除")) do
      accept_confirm { find("button[type='submit']").click }
    end

    expect(page).not_to have_text("要刪除")
    expect(page).to have_text("對應已刪除")
  end
end
