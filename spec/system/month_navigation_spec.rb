require "rails_helper"

RSpec.describe "月份切換", type: :system do
  let(:user) { create(:user) }
  let!(:account) { create(:account, household: user.household) }

  before { sign_in(user) }

  it "點擊下一個月切換到正確月份" do
    visit budget_path(year: 2026, month: 3)
    click_link "→"
    expect(page).to have_current_path(budget_path(year: 2026, month: 4))
  end

  it "點擊上一個月切換到正確月份" do
    visit budget_path(year: 2026, month: 3)
    click_link "←"
    expect(page).to have_current_path(budget_path(year: 2026, month: 2))
  end

  it "跨年切換：2026/01 上一月到 2025/12" do
    visit budget_path(year: 2026, month: 1)
    click_link "←"
    expect(page).to have_current_path(budget_path(year: 2025, month: 12))
  end

  it "2000/01 的上一月按鈕 disabled" do
    visit budget_path(year: 2000, month: 1)
    expect(page).to have_css("span[aria-disabled='true']", text: "←")
  end

  it "2099/12 的下一月按鈕 disabled" do
    visit budget_path(year: 2099, month: 12)
    expect(page).to have_css("span[aria-disabled='true']", text: "→")
  end

  it "非法 year 參數 redirect 到當月" do
    visit budget_path(year: "abc", month: 3)
    today = Date.today
    expect(page).to have_current_path(budget_path(year: today.year, month: today.month))
  end

  it "超界 year 參數 redirect 到當月" do
    visit budget_path(year: 9999, month: 1)
    today = Date.today
    expect(page).to have_current_path(budget_path(year: today.year, month: today.month))
  end
end
