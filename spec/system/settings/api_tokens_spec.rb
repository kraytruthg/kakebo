require "rails_helper"

RSpec.describe "Settings: API Tokens", type: :system do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "generates a new API token" do
    visit settings_api_tokens_path
    click_button "產生新 Token"

    expect(page).to have_text("Token 已產生")
    expect(page).to have_text("iPhone Shortcut")
  end

  it "revokes an API token" do
    ApiToken.generate_for(user, name: "Test")
    visit settings_api_tokens_path

    expect(page).to have_text("Test")
    accept_confirm { click_button "撤銷" }

    expect(page).not_to have_text("Test")
    expect(ApiToken.count).to eq(0)
  end
end
