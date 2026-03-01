require "rails_helper"

RSpec.describe "Accounts", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }

  before do
    sign_in(user)
    expect(page).to have_text("Ready to Assign")
  end

  it "新增帳戶後出現在帳戶列表" do
    visit accounts_path
    click_on "新增帳戶"

    fill_in "帳戶名稱", with: "玉山銀行"
    select "預算帳戶", from: "類型"
    fill_in "起始餘額", with: "10000"
    click_button "建立帳戶"

    expect(page).to have_text("帳戶已建立")
    expect(page).to have_text("玉山銀行")
  end
end
