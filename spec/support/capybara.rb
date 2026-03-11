Capybara.default_max_wait_time = 5

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,900")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chrome
  end

  config.after(:each, type: :system) do
    Capybara.current_session.driver.browser.manage.delete_all_cookies rescue nil
    Capybara.reset_sessions!
  end
end
