require "rails_helper"

RSpec.describe "BudgetEntries", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    category
    sign_in(user)
    expect(page).to have_text("全部已分配")
  end

  it "點擊已分配金額可編輯並儲存" do
    click_on "NT$0", match: :first

    fill_in "budget_entry[budgeted]", with: "3000"
    find("input[type=submit][value='✓']").click

    expect(page).to have_text("NT$3,000")
  end
end
