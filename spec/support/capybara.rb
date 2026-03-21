require "capybara/cuprite"

Capybara.default_max_wait_time = ENV["CI"] ? 10 : 5

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1400, 900 ],
    headless: true,
    process_timeout: 10,
    browser_options: {
      "no-sandbox": nil,
      "disable-dev-shm-usage": nil
    }
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite
  end

  config.after(:each, type: :system) do
    Capybara.reset_sessions!
  end
end
