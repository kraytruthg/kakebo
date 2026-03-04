# Keyboard & UX Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify Drawer behavior (ESC, body lock, focus trap) across Budget and Account pages, and add keyboard-driven inline editing for budget entries (ESC cancel, click-outside cancel).

**Architecture:** Refactor into 3 Stimulus controllers — a generic `drawer_controller` (shared by both pages), a streamlined `budget_controller` (business logic only, communicates with drawer via Stimulus Outlets), and a new `inline_edit_controller` (ESC/focusout cancel for budget inline editing). Add a `BudgetEntriesController#show` endpoint to restore display state on cancel.

**Tech Stack:** Rails 8.1, Stimulus (Hotwire), Turbo Frames, RSpec + Capybara system tests

---

### Task 1: Refactor drawer_controller.js — add focus trap

The existing `drawer_controller.js` (used by Account show page) already has ESC close, backdrop click, and body scroll lock. We need to add focus trap so Tab cycles within the panel only.

**Files:**
- Modify: `app/javascript/controllers/drawer_controller.js`

**Step 1: Write the updated drawer controller**

Replace the full contents of `app/javascript/controllers/drawer_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this._escHandler = this._closeOnEsc.bind(this)
    this._tabHandler = this._trapTab.bind(this)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
    document.removeEventListener("keydown", this._tabHandler)
  }

  open() {
    this.previouslyFocused = document.activeElement
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this._tabHandler)
    this._focusFirstElement()
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this._tabHandler)
    if (this.previouslyFocused) {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  // Private

  _closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  _focusFirstElement() {
    const elements = this._focusableElements()
    if (elements.length > 0) elements[0].focus()
  }

  _trapTab(event) {
    if (event.key !== "Tab") return

    const elements = this._focusableElements()
    if (elements.length === 0) return

    const first = elements[0]
    const last = elements[elements.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  _focusableElements() {
    const selector = 'input:not([disabled]):not([type="hidden"]), button:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'
    return [...this.panelTarget.querySelectorAll(selector)]
      .filter(el => el.offsetParent !== null)
  }
}
```

**Step 2: Run existing tests to verify Account drawer still works**

Run: `bundle exec rspec spec/system/ --format documentation`
Expected: All existing tests PASS (the Account show page already uses `drawer_controller`)

**Step 3: Commit**

```bash
git add app/javascript/controllers/drawer_controller.js
git commit -m "refactor: add focus trap to drawer controller"
```

---

### Task 2: Simplify budget_controller.js — use Drawer Outlet

Remove all Drawer open/close/backdrop logic from `budget_controller.js`. It will use a Stimulus Outlet to delegate Drawer operations to the refactored `drawer_controller`.

**Files:**
- Modify: `app/javascript/controllers/budget_controller.js`

**Step 1: Write the simplified budget controller**

Replace the full contents of `app/javascript/controllers/budget_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["drawer"]
  static targets = [
    "categoryId", "categoryName",
    "form", "accountSelect",
    "outflow", "inflow"
  ]

  openWithCategory(event) {
    const { categoryId, categoryName } = event.params
    this.categoryIdTarget.value        = categoryId
    this.categoryNameTarget.textContent = categoryName
    this.updateFormAction()
    this.drawerOutlet.open()
    if (this.hasOutflowTarget) {
      this.outflowTarget.focus()
    }
  }

  closeDrawer() {
    this.drawerOutlet.close()
  }

  accountChanged() {
    this.updateFormAction()
  }

  updateFormAction() {
    const accountId = this.accountSelectTarget.value
    this.formTarget.action = `/accounts/${accountId}/transactions`
  }

  outflowInput() {
    if (this.outflowTarget.value !== "") {
      this.inflowTarget.value = ""
    }
  }

  inflowInput() {
    if (this.inflowTarget.value !== "") {
      this.outflowTarget.value = ""
    }
  }
}
```

Key changes:
- Removed `static targets` for `backdrop` and `panel`
- Added `static outlets = ["drawer"]`
- `openWithCategory` now calls `this.drawerOutlet.open()` then focuses outflow
- Added `closeDrawer()` to delegate close to the drawer outlet
- Removed `open()`, `close()`, `backdropClick()`

**Step 2: Do NOT run tests yet** — the view needs to be updated first (Task 3).

---

### Task 3: Update budget/index.html.erb — wire up Drawer outlet

Update the Budget index view to separate the Drawer into its own `drawer` controller, and connect it to the `budget` controller via Stimulus Outlet.

**Files:**
- Modify: `app/views/budget/index.html.erb`

**Step 1: Update the view**

The changes needed in `app/views/budget/index.html.erb`:

1. Add `data-budget-drawer-outlet="#budget-drawer"` to the top-level `div` (line 1)
2. Wrap the Drawer backdrop+panel in a `div` with `data-controller="drawer"` and `id="budget-drawer"` (lines 100-120)
3. Change `data-budget-target` to `data-drawer-target` on backdrop and panel
4. Change `data-action="click->budget#backdropClick"` to `data-action="click->drawer#backdropClick"`
5. Change `data-action="budget#close"` on close button to `data-action="drawer#close"`
6. Change `data-action="turbo:submit-end->budget#close"` in the form partial to `data-action="turbo:submit-end->budget#closeDrawer"`

**Updated view (full file):**

```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8"
     data-controller="budget"
     data-budget-drawer-outlet="#budget-drawer">
  <%# Month navigation %>
  <div class="flex items-center justify-between mb-6">
    <div class="flex items-center gap-4">
      <%= render "shared/month_nav" %>
    </div>

    <%= button_to budget_copy_from_previous_path,
          params: { year: @year, month: @month },
          method: :post,
          class: "flex items-center gap-1.5 text-xs text-slate-500 hover:text-indigo-600 border border-slate-200 hover:border-indigo-300 px-3 py-1.5 rounded-lg transition-colors" do %>
      <%= icon "document-duplicate", classes: "w-3.5 h-3.5" %>
      複製上月
    <% end %>
  </div>

  <%# Budget summary cards %>
  <div class="grid grid-cols-2 gap-4 mb-6">
    <div class="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-6 text-white shadow-lg shadow-indigo-200">
      <p class="text-indigo-200 text-sm font-medium mb-1">全部已分配</p>
      <p id="total-budgeted" class="text-4xl font-bold tracking-tight">
        <%= number_to_currency(@total_budgeted, unit: "NT$", precision: 0) %>
      </p>
      <p class="text-indigo-300 text-xs mt-2">本月已分配的預算</p>
    </div>
    <div class="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-6 text-white shadow-lg shadow-indigo-200">
      <p class="text-indigo-200 text-sm font-medium mb-1">剩餘可分配</p>
      <p id="ready-to-assign" class="text-4xl font-bold tracking-tight">
        <%= number_to_currency(@ready_to_assign, unit: "NT$", precision: 0) %>
      </p>
      <p class="text-indigo-300 text-xs mt-2">可分配給各類別的預算</p>
    </div>
  </div>

  <%# Category groups %>
  <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
    <table class="w-full">
      <thead>
        <tr class="border-b border-slate-100">
          <th class="text-left px-5 py-3 text-xs font-medium text-slate-400 uppercase tracking-wider">類別</th>
          <th class="text-right px-5 py-3 text-xs font-medium text-slate-400 uppercase tracking-wider">已分配</th>
          <th class="text-right px-5 py-3 text-xs font-medium text-slate-400 uppercase tracking-wider">本月支出</th>
          <th class="text-right px-5 py-3 text-xs font-medium text-slate-400 uppercase tracking-wider">可用</th>
          <th class="px-3 py-3"></th>
        </tr>
      </thead>
      <tbody>
        <% @category_groups.each do |group| %>
          <tr class="bg-slate-50">
            <td colspan="4" class="px-5 py-2 text-xs font-semibold text-slate-500 uppercase tracking-wider">
              <%= group.name %>
            </td>
          </tr>
          <% group.categories.each do |category| %>
            <% entry = category.budget_entries.find { |e| e.year == @year && e.month == @month } %>
            <% budgeted = entry&.budgeted || 0 %>
            <% activity = @monthly_activities[category.id] || 0 %>
            <% available = (entry&.carried_over || 0) + budgeted + activity %>
            <tr class="border-t border-slate-50 hover:bg-slate-50 group transition-colors">
              <td class="px-5 py-3 text-sm text-slate-700 border-l-2 border-transparent group-hover:border-indigo-400 transition-colors">
                <%= link_to category.name,
                      budget_category_transactions_path(@year, @month, category),
                      class: "hover:text-indigo-600 hover:underline transition-colors" %>
              </td>
              <td class="px-5 py-3 text-right text-sm text-slate-600">
                <turbo-frame id="budget-entry-<%= category.id %>">
                  <%= link_to edit_budget_entries_path(category_id: category.id, year: @year, month: @month),
                        class: "cursor-pointer hover:text-indigo-600 transition-colors" do %>
                    <%= number_to_currency(budgeted, unit: "NT$", precision: 0) %>
                  <% end %>
                </turbo-frame>
              </td>
              <td class="px-5 py-3 text-right text-sm <%= activity < 0 ? 'text-red-500' : 'text-slate-600' %>">
                <span id="activity-<%= category.id %>">
                  <%= number_to_currency(activity, unit: "NT$", precision: 0) %>
                </span>
              </td>
              <td class="px-5 py-3 text-right text-sm font-semibold">
                <span id="available-<%= category.id %>"
                      class="<%= available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
                  <%= number_to_currency(available, unit: "NT$", precision: 0) %>
                </span>
              </td>
              <td class="px-3 py-3 text-center opacity-0 group-hover:opacity-100 transition-opacity">
                <button data-action="budget#openWithCategory"
                        data-budget-category-id-param="<%= category.id %>"
                        data-budget-category-name-param="<%= category.name %>"
                        class="text-indigo-400 hover:text-indigo-700 transition-colors"
                        title="新增交易">
                  <%= icon "plus-circle", classes: "w-5 h-5" %>
                </button>
              </td>
            </tr>
          <% end %>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# Drawer (shared controller) %>
  <div id="budget-drawer" data-controller="drawer">
    <%# Backdrop %>
    <div data-drawer-target="backdrop"
         class="fixed inset-0 bg-black/40 z-40 opacity-0 pointer-events-none transition-opacity duration-200"
         data-action="click->drawer#backdropClick">
    </div>

    <%# Panel %>
    <div data-drawer-target="panel"
         class="fixed inset-y-0 right-0 w-full sm:w-96 bg-white shadow-2xl z-50 translate-x-full transition-transform duration-300 ease-in-out flex flex-col">
      <div class="flex items-center justify-between px-5 py-4 border-b border-slate-100">
        <h2 class="text-base font-semibold text-slate-900">新增交易</h2>
        <button data-action="drawer#close"
                class="text-slate-400 hover:text-slate-700 transition-colors"
                aria-label="關閉">
          <%= icon "x-mark", classes: "w-5 h-5" %>
        </button>
      </div>
      <div class="flex-1 overflow-y-auto px-5 py-5">
        <%= render "transactions/budget_form" %>
      </div>
    </div>
  </div>
</div>
```

**Step 2: Update the budget form partial**

In `app/views/transactions/_budget_form.html.erb`, change the `turbo:submit-end` action from `budget#close` to `budget#closeDrawer`:

On line 10, change:
```erb
action: "turbo:submit-end->budget#close"
```
to:
```erb
action: "turbo:submit-end->budget#closeDrawer"
```

**Step 3: Run existing tests**

Run: `bundle exec rspec spec/system/budget_spec.rb --format documentation`

The existing tests use selectors like `[data-budget-target='panel']` which have changed to `[data-drawer-target='panel']`. These tests need to be updated.

**Step 4: Update existing test selectors in budget_spec.rb**

In `spec/system/budget_spec.rb`, replace:
- `[data-budget-target='panel']` → `[data-drawer-target='panel']`

Updated tests (lines 27, 32, 38):

```ruby
it "點擊類別的 + 按鈕開啟新增交易 drawer" do
  page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")

  expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
end

it "從 budget drawer 用支出欄位新增交易後更新本月支出" do
  page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
  expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
  expect(page).to have_css(
    "input[name='transaction[category_id]'][value='#{category.id}']",
    visible: :all
  )

  within("[data-drawer-target='panel']") do
    fill_in "transaction[outflow]", with: "1000"
    fill_in "transaction[memo]", with: "午餐"
    click_button "新增交易"
  end

  within("tr", text: category.name) do
    expect(page).to have_text("-NT$1,000")
  end
end

it "從 budget drawer 用收入欄位新增退款交易" do
  page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
  expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")
  expect(page).to have_css(
    "input[name='transaction[category_id]'][value='#{category.id}']",
    visible: :all
  )

  within("[data-drawer-target='panel']") do
    fill_in "transaction[inflow]", with: "200"
    fill_in "transaction[memo]", with: "退款"
    click_button "新增交易"
  end

  within("tr", text: category.name) do
    expect(page).to have_text("NT$200")
  end
end
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/system/budget_spec.rb spec/system/budget_entries_spec.rb --format documentation`
Expected: All PASS

**Step 6: Commit**

```bash
git add app/javascript/controllers/budget_controller.js app/views/budget/index.html.erb app/views/transactions/_budget_form.html.erb spec/system/budget_spec.rb
git commit -m "refactor: simplify budget controller to use drawer outlet"
```

---

### Task 4: Add BudgetEntries#show endpoint

Add a `show` action that returns a single category's budget entry in display mode (turbo-frame with the link). This is used by the `inline_edit_controller` to restore the display state when cancelling an edit.

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/budget_entries_controller.rb`
- Create: `app/views/budget_entries/show.html.erb`

**Step 1: Add the route**

In `config/routes.rb`, change line 8 from:
```ruby
resources :budget_entries, only: [ :create ]
```
to:
```ruby
resources :budget_entries, only: [ :create, :show ]
```

The `show` action will use the BudgetEntry `id` as the identifier. But since budget entries might not exist yet (value is 0), we need a different approach. We'll use the same GET params style as `edit`:

Actually, let's use a custom route instead, to keep the same query-param pattern as edit:

In `config/routes.rb`, add after line 9 (`get "budget_entries/edit"...`):
```ruby
get "budget_entries/show", to: "budget_entries#show", as: :show_budget_entry
```

**Step 2: Add the controller action**

In `app/controllers/budget_entries_controller.rb`, add the `show` action after `edit` (after line 11):

```ruby
def show
  @category = Category.joins(:category_group)
                      .where(category_groups: { household_id: Current.household.id })
                      .find(params[:category_id])
  @year  = params[:year].to_i
  @month = params[:month].to_i
  @entry = BudgetEntry.find_or_initialize_by(
    category_id: @category.id, year: @year, month: @month
  )
end
```

**Step 3: Create the show view**

Create `app/views/budget_entries/show.html.erb`:

```erb
<turbo-frame id="budget-entry-<%= @category.id %>">
  <%= link_to edit_budget_entries_path(category_id: @category.id, year: @year, month: @month),
        class: "cursor-pointer hover:text-indigo-600 transition-colors" do %>
    <%= number_to_currency(@entry.budgeted, unit: "NT$", precision: 0) %>
  <% end %>
</turbo-frame>
```

This is the same markup that exists in `budget/index.html.erb` (lines 66-71) and in `budget_entries/create.turbo_stream.erb` (lines 2-7).

**Step 4: Run existing tests**

Run: `bundle exec rspec spec/system/budget_entries_spec.rb spec/system/budget_spec.rb --format documentation`
Expected: All PASS (no behavior changed)

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/budget_entries_controller.rb app/views/budget_entries/show.html.erb
git commit -m "feat: add budget entries show endpoint for inline edit cancel"
```

---

### Task 5: Create inline_edit_controller.js

Create the Stimulus controller that handles ESC cancel and focusout cancel for budget inline editing.

**Files:**
- Create: `app/javascript/controllers/inline_edit_controller.js`

**Step 1: Write the controller**

Create `app/javascript/controllers/inline_edit_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { restoreUrl: String }

  connect() {
    this._handleFocusOut = this._onFocusOut.bind(this)
    this.element.addEventListener("focusout", this._handleFocusOut)
  }

  disconnect() {
    this.element.removeEventListener("focusout", this._handleFocusOut)
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this._cancel()
    }
  }

  // Private

  _onFocusOut(event) {
    // Use requestAnimationFrame to let the browser set the new activeElement
    requestAnimationFrame(() => {
      // If the new focused element is still within this controller's element, do nothing
      if (this.element.contains(document.activeElement)) return

      this._cancel()
    })
  }

  _cancel() {
    if (!this.hasRestoreUrlValue) return

    // Set the turbo-frame's src to trigger a Turbo reload of the display state
    const frame = this.element.closest("turbo-frame") || this.element
    frame.src = this.restoreUrlValue
  }
}
```

**Step 2: No tests needed yet** — the view integration happens in Task 6.

**Step 3: Commit**

```bash
git add app/javascript/controllers/inline_edit_controller.js
git commit -m "feat: add inline edit controller with ESC and focusout cancel"
```

---

### Task 6: Wire up inline_edit_controller in budget_entries/edit.html.erb

Connect the `inline_edit_controller` to the budget entry edit form, so ESC and focusout cancel the edit.

**Files:**
- Modify: `app/views/budget_entries/edit.html.erb`

**Step 1: Update the edit view**

Replace the full contents of `app/views/budget_entries/edit.html.erb`:

```erb
<turbo-frame id="budget-entry-<%= @category.id %>"
             data-controller="inline-edit"
             data-inline-edit-restore-url-value="<%= show_budget_entry_path(category_id: @category.id, year: @year, month: @month) %>">
  <%= form_with url: budget_entries_path, scope: :budget_entry, data: { turbo: true } do |f| %>
    <%= f.hidden_field :category_id, value: @category.id %>
    <%= f.hidden_field :year,        value: @year %>
    <%= f.hidden_field :month,       value: @month %>
    <%= f.number_field :budgeted,
          value: @entry.budgeted.to_i,
          autofocus: true,
          step: 1,
          class: "w-28 text-right rounded border border-indigo-400 px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500",
          data: { action: "keydown->inline-edit#keydown" } %>
    <%= f.submit "✓",
          class: "ml-1 text-sm text-indigo-600 hover:text-indigo-800 cursor-pointer" %>
  <% end %>
</turbo-frame>
```

Changes:
- Added `data-controller="inline-edit"` and `data-inline-edit-restore-url-value` on the turbo-frame
- Added `data: { action: "keydown->inline-edit#keydown" }` on the number input

**Step 2: Run existing tests**

Run: `bundle exec rspec spec/system/budget_entries_spec.rb --format documentation`
Expected: All PASS (the normal edit/submit flow is unchanged)

**Step 3: Commit**

```bash
git add app/views/budget_entries/edit.html.erb
git commit -m "feat: wire inline edit controller to budget entry edit form"
```

---

### Task 7: System tests — Drawer keyboard interactions

Write system tests for the unified Drawer behavior on the Budget page: ESC close, backdrop click close.

**Files:**
- Modify: `spec/system/budget_spec.rb`

**Step 1: Write the tests**

Add these tests to the existing `spec/system/budget_spec.rb`, inside the existing `RSpec.describe` block:

```ruby
it "ESC 鍵關閉 budget drawer" do
  page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
  expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")

  find("body").send_keys(:escape)

  expect(page).to have_css("[data-drawer-target='panel'].translate-x-full", visible: :all)
end

it "點擊背景關閉 budget drawer" do
  page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
  expect(page).to have_css("[data-drawer-target='panel']:not(.translate-x-full)")

  find("[data-drawer-target='backdrop']").click

  expect(page).to have_css("[data-drawer-target='panel'].translate-x-full", visible: :all)
end
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/system/budget_spec.rb --format documentation`
Expected: All PASS

**Step 3: Commit**

```bash
git add spec/system/budget_spec.rb
git commit -m "test: add system tests for budget drawer ESC and backdrop close"
```

---

### Task 8: System tests — InlineEdit keyboard interactions

Write system tests for the budget inline edit ESC cancel behavior.

**Files:**
- Modify: `spec/system/budget_entries_spec.rb`

**Step 1: Write the tests**

Add these tests to the existing `spec/system/budget_entries_spec.rb`, inside the existing `RSpec.describe` block:

```ruby
it "ESC 鍵取消預算編輯並恢復原始金額" do
  click_on "NT$0", match: :first

  expect(page).to have_css("input[name='budget_entry[budgeted]']")

  fill_in "budget_entry[budgeted]", with: "9999"
  find("input[name='budget_entry[budgeted]']").send_keys(:escape)

  expect(page).not_to have_css("input[name='budget_entry[budgeted]']")
  expect(page).to have_text("NT$0")
end

it "點擊編輯區域外取消預算編輯" do
  click_on "NT$0", match: :first

  expect(page).to have_css("input[name='budget_entry[budgeted]']")

  # Click outside the inline edit area
  find("th", text: "類別").click

  expect(page).not_to have_css("input[name='budget_entry[budgeted]']")
  expect(page).to have_text("NT$0")
end
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/system/budget_entries_spec.rb --format documentation`
Expected: All PASS

**Step 3: Commit**

```bash
git add spec/system/budget_entries_spec.rb
git commit -m "test: add system tests for inline edit ESC and focusout cancel"
```

---

### Task 9: Verify Account show page still works

Run existing system tests for the Account show page to confirm the refactored `drawer_controller.js` works correctly there too.

**Files:**
- No changes — verification only

**Step 1: Find and run account-related system tests**

Run: `bundle exec rspec spec/system/ --format documentation`
Expected: All PASS

If any account-related tests reference old drawer behavior, they should still work since we only added features (focus trap) to `drawer_controller.js` — the existing API (`open`, `close`, `backdropClick`, targets) is unchanged.

**Step 2: Commit** (only if test fixes were needed)

---

### Task 10: Final full test run

Run all system tests to confirm nothing is broken.

**Step 1: Run all tests**

Run: `bundle exec rspec --format documentation`
Expected: All PASS, 0 failures

**Step 2: Commit** (only if fixes were needed)
