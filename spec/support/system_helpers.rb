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

  def wait_for_stimulus(selector, controller_name, timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop do
        connected = page.evaluate_script(<<~JS)
          (function() {
            var el = document.querySelector(#{selector.to_json});
            if (!el) return false;
            if (!window.Stimulus) return false;
            var controller = window.Stimulus.getControllerForElementAndIdentifier(el, #{controller_name.to_json});
            return !!controller;
          })()
        JS
        break if connected
        sleep 0.05
      end
    end
  rescue Timeout::Error
    # Allow test to continue; Capybara assertions will catch real failures
  end

  def fill_in_with_keyboard(locator, with:)
    field = find_field(locator)
    field.click
    field.send_keys([ :control, "a" ], :delete)
    field.send_keys(with)
  end

  def wait_for_turbo(timeout: Capybara.default_max_wait_time)
    return unless page.evaluate_script("typeof Turbo !== 'undefined'")

    # Wait until no active Turbo visit is in-flight and no preview is showing.
    # A brief initial pause ensures Turbo has time to initiate the navigation
    # after a click_button / click_link before we start polling.
    sleep 0.1
    Timeout.timeout(timeout) do
      loop do
        idle = page.evaluate_script(<<~JS)
          !document.querySelector("[data-turbo-preview]") &&
          (!Turbo.navigator.currentVisit || Turbo.navigator.currentVisit.state === "completed")
        JS
        break if idle
        sleep 0.05
      end
    end
  rescue Timeout::Error
    # Allow test to continue; Capybara assertions will catch real failures
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
