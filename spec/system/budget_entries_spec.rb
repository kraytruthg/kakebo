require "rails_helper"

RSpec.describe "BudgetEntries", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    category
    sign_in(user)
    expect(page).to have_text("全部已分配")
  end

  it "點擊已分配金額可編輯並儲存" do
    within("table") do
      within("tr", text: category.name) do
        click_on "0"
      end
    end

    input = find("input[name='budget_entry[budgeted]']")
    input.fill_in with: "3000"
    input.native.send_keys(:enter)

    expect(page).not_to have_css("input[name='budget_entry[budgeted]']")
    expect(page).to have_text("3,000")
  end

  it "ESC 鍵取消預算編輯並恢復原始金額" do
    within("table") do
      within("tr", text: category.name) do
        click_on "0"
      end
    end

    input = find("input[name='budget_entry[budgeted]']")
    input.fill_in with: "9999"
    input.native.send_keys(:escape)

    expect(page).not_to have_css("input[name='budget_entry[budgeted]']")
    expect(page).to have_text("0")
  end

  it "點擊編輯區域外取消預算編輯" do
    within("table") do
      within("tr", text: category.name) do
        click_on "0"
      end
    end
    expect(page).to have_css("input[name='budget_entry[budgeted]']")

    # Click outside the inline edit area
    page.find("body").click

    expect(page).not_to have_css("input[name='budget_entry[budgeted]']")
    expect(page).to have_text("0")
  end
end
