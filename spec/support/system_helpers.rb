module SystemHelpers
  def sign_in(user, password: "password123")
    visit "about:blank"
    page.driver.browser.manage.delete_all_cookies
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "密碼", with: password
    click_button "登入"
    expect(page).not_to have_current_path(new_session_path)
  end

  def wait_until(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop do
        break if yield
        sleep 0.1
      end
    end
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
