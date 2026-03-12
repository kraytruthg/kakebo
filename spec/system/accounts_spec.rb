require "rails_helper"

RSpec.describe "Accounts", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }

  before { sign_in(user) }

  it "新增帳戶後出現在帳戶列表" do
    visit accounts_path
    click_on "新增帳戶"

    expect(page).to have_field("帳戶名稱")
    fill_in "帳戶名稱", with: "玉山銀行"
    select "預算帳戶", from: "帳戶類型"
    field = find_field("起始餘額")
    field.execute_script("this.value = ''")
    field.fill_in with: "10000"
    click_button "建立帳戶"

    expect(page).to have_text("帳戶已建立")
    expect(page).to have_text("玉山銀行")
  end
end
