require "rails_helper"

RSpec.describe "Budget", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    account
    category
    sign_in(user)
    expect(page).to have_text("全部已分配") # 等待 Turbo redirect 完成
  end

  it "顯示預算頁面與兩個預算摘要卡片" do
    expect(page).to have_text("全部已分配")
    expect(page).to have_text("剩餘可分配")
    expect(page).to have_text(/#{Regexp.escape(category_group.name)}/i)
    expect(page).to have_text(category.name)
  end

  it "點擊類別的 + 按鈕開啟新增交易 drawer" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")

    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
  end

  it "從 budget drawer 用支出欄位新增交易後更新本月支出" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
    expect(page).to have_css(
      "input[name='transaction[category_id]'][value='#{category.id}']",
      visible: :all
    )

    within("[data-drawer-target='panel']") do
      fill_in "transaction[outflow]", with: "1000"
      fill_in "transaction[memo]", with: "午餐"
      click_button "新增交易"
    end

    within("tr", text: category.name) do
      expect(page).to have_text("-1,000")
    end
  end

  it "從 budget drawer 用收入欄位新增退款交易" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
    expect(page).to have_css(
      "input[name='transaction[category_id]'][value='#{category.id}']",
      visible: :all
    )

    within("[data-drawer-target='panel']") do
      fill_in "transaction[inflow]", with: "200"
      fill_in "transaction[memo]", with: "退款"
      click_button "新增交易"
    end

    within("tr", text: category.name) do
      expect(page).to have_text("200")
    end
  end

  it "ESC 鍵關閉 budget drawer" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")

    find("body").send_keys(:escape)

    expect(page).to have_css("[data-drawer-target='panel'].translate-x-full", visible: :all)
  end

  it "點擊背景關閉 budget drawer" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")

    page.execute_script("document.querySelector('[data-drawer-target=\"backdrop\"]').click()")

    expect(page).to have_css("[data-drawer-target='panel'].translate-x-full", visible: :all)
  end

  it "分配預算後即時更新全部已分配與剩餘可分配" do
    within("tr", text: category.name) do
      click_link "0"
      fill_in "budget_entry[budgeted]", with: "5000"
      find("input[name='budget_entry[budgeted]']").send_keys(:enter)
    end

    expect(page).to have_css("#total-budgeted", text: "5,000")
    expect(page).to have_css("#ready-to-assign", text: "-5,000")
  end
end
