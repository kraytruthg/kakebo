module SystemHelpers
  def sign_in(user, password: "password123")
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

  def wait_for_turbo
    return if Capybara.current_driver == :rack_test

    page.assert_no_selector(
      "html[aria-busy], html[data-turbo-not-loaded], html[data-turbo-loading], html[data-turbo-preview]",
      visible: :all
    )
  end

  def drag_sortable(source, target)
    page.execute_script(<<~JS, source.native, target.native)
      var source = arguments[0];
      var target = arguments[1];
      var sourceItem = source.closest('[data-sortable-id]');
      var targetItem = target.closest('[data-sortable-id]');
      var container = sourceItem.parentElement;

      // Move source before target in DOM
      container.insertBefore(sourceItem, targetItem);

      // Build positions from new DOM order and send reorder request
      var sortableEl = container.closest('[data-controller*="sortable"]') || container;
      var url = sortableEl.dataset.sortableUrlValue;
      var items = container.querySelectorAll(':scope > [data-sortable-id]');
      var positions = Array.from(items).map(function(item, index) {
        return { id: parseInt(item.dataset.sortableId), position: index };
      });
      var tokenEl = document.querySelector('meta[name="csrf-token"]');
      var token = tokenEl ? tokenEl.content : '';

      window.__dragResult = 'pending';
      fetch(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
        body: JSON.stringify({ positions: positions })
      }).then(function(r) {
        window.__dragResult = 'ok:' + r.status;
      }).catch(function(e) {
        window.__dragResult = 'error:' + e.message;
      });
    JS
    # Wait for fetch to complete
    wait_until(timeout: 10) { page.evaluate_script("window.__dragResult !== 'pending'") }
  end

  def resize_to_mobile
    page.driver.resize(375, 812)
  end

  def resize_to_desktop
    page.driver.resize(1280, 800)
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
