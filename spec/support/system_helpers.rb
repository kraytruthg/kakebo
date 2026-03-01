module SystemHelpers
  def sign_in(user, password: "password123")
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "密碼", with: password
    click_button "登入"
    expect(page).to have_text("Ready to Assign")
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
