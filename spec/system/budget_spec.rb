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
    expect(page).to have_text("Ready to Assign") # 等待 Turbo redirect 完成
  end

  it "顯示預算頁面與 Ready to Assign" do
    expect(page).to have_text(category_group.name.upcase)
    expect(page).to have_text(category.name)
  end

  it "點擊類別的 + 按鈕開啟新增交易 drawer" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")

    expect(page).to have_css("[data-budget-target='panel']:not(.translate-x-full)")
  end

  it "從 budget drawer 新增交易後更新本月支出" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-budget-target='panel']:not(.translate-x-full)")

    within("[data-budget-target='panel']") do
      fill_in "transaction[amount]", with: "-1000"
      fill_in "transaction[memo]", with: "午餐"
      click_button "新增交易"
    end

    within("tr", text: category.name) do
      expect(page).to have_text("-NT$1,000")
    end
  end
end
