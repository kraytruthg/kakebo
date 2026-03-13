require "rails_helper"

RSpec.describe "類別管理", type: :system do
  let(:user) { create(:user) }
  let!(:group) { create(:category_group, household: user.households.first, name: "日常開銷") }

  before { sign_in(user) }

  it "新增 CategoryGroup" do
    visit settings_categories_path
    click_link "新增群組"
    fill_in "名稱", with: "娛樂"
    click_button "新增群組"
    expect(page).to have_text("娛樂")
  end

  it "新增 Category" do
    visit settings_categories_path
    within("[data-sortable-id='#{group.id}']") { click_link "新增類別" }
    fill_in "名稱", with: "電影"
    click_button "新增類別"
    expect(page).to have_text("電影")
  end

  it "重新命名 CategoryGroup" do
    visit settings_categories_path
    within(".space-y-4 > [data-sortable-id='#{group.id}']") { find("a[href*='edit']").click }
    fill_in "名稱", with: "每日花費"
    click_button "儲存"
    expect(page).to have_text("每日花費")
  end

  it "刪除空的 Category 成功" do
    cat = create(:category, category_group: group, name: "無交易")
    visit settings_categories_path
    within(".divide-y > [data-sortable-id='#{cat.id}']") do
      accept_confirm { find("button[type='submit']").click }
    end
    expect(page).not_to have_text("無交易")
  end

  it "刪除有交易的 Category 顯示錯誤" do
    cat = create(:category, category_group: group, name: "有交易")
    account = create(:account, household: user.households.first, account_type: "budget")
    create(:transaction, account: account, category: cat, amount: -500, date: Date.today)
    visit settings_categories_path
    within(".divide-y > [data-sortable-id='#{cat.id}']") do
      accept_confirm { find("button[type='submit']").click }
    end
    expect(page).to have_text("此類別有交易記錄，無法刪除")
  end

  it "拖曳調整 CategoryGroup 順序" do
    group2 = create(:category_group, household: user.households.first, name: "娛樂", position: 2)
    visit settings_categories_path

    source = find(".space-y-4 > [data-sortable-id='#{group2.id}'] .drag-handle")
    target = find(".space-y-4 > [data-sortable-id='#{group.id}'] .drag-handle")

    source.drag_to(target)

    wait_until { group2.reload.position < group.reload.position }
  end

  it "拖曳調整 Category 順序" do
    cat1 = create(:category, category_group: group, name: "食物", position: 0)
    cat2 = create(:category, category_group: group, name: "交通", position: 1)
    visit settings_categories_path

    source = find(:css, ".divide-y > [data-sortable-id='#{cat2.id}'] .drag-handle")
    target = find(:css, ".divide-y > [data-sortable-id='#{cat1.id}'] .drag-handle")
    source.drag_to(target)

    wait_until { cat2.reload.position < cat1.reload.position }
  end

  it "編輯時將 Category 換到其他群組" do
    group2 = create(:category_group, household: user.households.first, name: "娛樂")
    cat = create(:category, category_group: group, name: "電影")
    visit settings_categories_path

    within(".divide-y[data-controller='sortable'] [data-sortable-id='#{cat.id}']") do
      find("a[href*='edit']").click
    end
    select "娛樂", from: "所屬群組"
    click_button "儲存"

    expect(page).to have_text("類別已更新")
    expect(cat.reload.category_group).to eq(group2)
  end
end
