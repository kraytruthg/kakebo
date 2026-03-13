require "rails_helper"

RSpec.describe "Settings: Households", type: :system do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "creates a new household" do
    visit settings_root_path
    within("main") { click_on "新增帳本" }

    fill_in "名稱", with: "個人零用錢"
    click_button "建立"

    expect(page).to have_content("帳本已建立")
    expect(user.reload.households.count).to eq(2)
  end
end
