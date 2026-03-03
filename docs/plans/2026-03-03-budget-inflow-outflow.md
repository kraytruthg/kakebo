# Budget Inflow/Outflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the single amount field in the budget page transaction drawer with separate Outflow/Inflow fields so users enter positive numbers and the system handles sign conversion.

**Architecture:** The budget form (`_budget_form.html.erb`) gets two number fields (outflow/inflow) instead of one amount field. The Stimulus `budget_controller.js` handles mutual exclusivity (typing in one clears the other) and auto-focus. The `TransactionsController` converts outflow/inflow to a signed amount before saving. No model changes needed.

**Tech Stack:** Rails 8.1, Stimulus, Tailwind CSS v4, RSpec + Capybara

---

### Task 1: Update Stimulus Controller with Inflow/Outflow Targets and Mutual Exclusivity

**Files:**
- Modify: `app/javascript/controllers/budget_controller.js`

**Step 1: Add targets and mutual exclusivity logic**

Replace the full content of `app/javascript/controllers/budget_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "backdrop", "panel",
    "categoryId", "categoryName",
    "form", "accountSelect",
    "outflow", "inflow"
  ]

  // 開啟 Drawer 並預先設定類別
  openWithCategory(event) {
    const { categoryId, categoryName } = event.params
    this.categoryIdTarget.value        = categoryId
    this.categoryNameTarget.textContent = categoryName
    this.updateFormAction()
    this.open()
  }

  // Drawer 開關
  open() {
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    this.panelTarget.classList.remove("translate-x-full")
    if (this.hasOutflowTarget) {
      this.outflowTarget.focus()
    }
  }

  close() {
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    this.panelTarget.classList.add("translate-x-full")
  }

  backdropClick() {
    this.close()
  }

  // 帳戶下拉改變時更新 form action
  accountChanged() {
    this.updateFormAction()
  }

  updateFormAction() {
    const accountId = this.accountSelectTarget.value
    this.formTarget.action = `/accounts/${accountId}/transactions`
  }

  // Outflow/Inflow 互斥
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

**Step 2: Commit**

```bash
git add app/javascript/controllers/budget_controller.js
git commit -m "feat: add outflow/inflow targets and mutual exclusivity to budget controller"
```

---

### Task 2: Update Budget Form with Outflow/Inflow Fields

**Files:**
- Modify: `app/views/transactions/_budget_form.html.erb`

**Step 1: Replace the amount field section**

In `_budget_form.html.erb`, replace lines 46-51 (the `<%# 金額 %>` block) with two side-by-side fields:

```erb
    <%# 金額（支出 / 收入） %>
    <div class="flex gap-3">
      <div class="flex-1">
        <label class="block text-sm font-medium text-slate-700 mb-1.5">支出</label>
        <input type="number" name="transaction[outflow]" min="0" step="1"
               placeholder="例：500"
               class="block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
               data-budget-target="outflow"
               data-action="input->budget#outflowInput" />
      </div>
      <div class="flex-1">
        <label class="block text-sm font-medium text-slate-700 mb-1.5">收入</label>
        <input type="number" name="transaction[inflow]" min="0" step="1"
               placeholder="例：500"
               class="block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
               data-budget-target="inflow"
               data-action="input->budget#inflowInput" />
      </div>
    </div>
```

**Step 2: Commit**

```bash
git add app/views/transactions/_budget_form.html.erb
git commit -m "feat: replace amount field with outflow/inflow in budget form"
```

---

### Task 3: Update TransactionsController to Handle Outflow/Inflow Params

**Files:**
- Modify: `app/controllers/transactions_controller.rb`

**Step 1: Update `transaction_params` to convert outflow/inflow to amount**

In `transaction_params`, add logic to permit and convert the new fields. Replace the method (lines 78-86) with:

```ruby
  def transaction_params
    p = params.require(:transaction).permit(:category_id, :amount, :date, :memo, :outflow, :inflow)
    if p[:category_id].present?
      Category.joins(:category_group)
              .where(category_groups: { household_id: Current.household.id })
              .find(p[:category_id])
    end
    if p[:outflow].present?
      p[:amount] = -p[:outflow].to_d.abs
    elsif p[:inflow].present?
      p[:amount] = p[:inflow].to_d.abs
    end
    p.except(:outflow, :inflow)
  end
```

**Step 2: Commit**

```bash
git add app/controllers/transactions_controller.rb
git commit -m "feat: convert outflow/inflow params to signed amount in controller"
```

---

### Task 4: Write System Test for Outflow (Expense)

**Files:**
- Modify: `spec/system/budget_spec.rb`

**Step 1: Update existing test that uses the drawer**

In `spec/system/budget_spec.rb`, replace the test `"從 budget drawer 新增交易後更新本月支出"` (lines 30-48) with two tests — one for outflow and one for inflow:

```ruby
  it "從 budget drawer 用支出欄位新增交易後更新本月支出" do
    page.execute_script("document.querySelector('button[title=\"新增交易\"]').click()")
    expect(page).to have_css("[data-budget-target='panel']:not(.translate-x-full)")
    expect(page).to have_css(
      "input[name='transaction[category_id]'][value='#{category.id}']",
      visible: :all
    )

    within("[data-budget-target='panel']") do
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
    expect(page).to have_css("[data-budget-target='panel']:not(.translate-x-full)")
    expect(page).to have_css(
      "input[name='transaction[category_id]'][value='#{category.id}']",
      visible: :all
    )

    within("[data-budget-target='panel']") do
      fill_in "transaction[inflow]", with: "200"
      fill_in "transaction[memo]", with: "退款"
      click_button "新增交易"
    end

    within("tr", text: category.name) do
      expect(page).to have_text("NT$200")
    end
  end
```

**Step 2: Run the tests to verify**

```bash
bundle exec rspec spec/system/budget_spec.rb --format documentation
```

Expected: all tests pass, including the two new ones.

**Step 3: Commit**

```bash
git add spec/system/budget_spec.rb
git commit -m "test: add system tests for budget drawer outflow/inflow fields"
```

---

### Task 5: Verify No Regressions

**Step 1: Run the full test suite**

```bash
bundle exec rspec --format documentation
```

Expected: all tests pass with 0 failures.

**Step 2: Commit (only if any fix was needed)**

If any test needed fixing, commit the fix:

```bash
git commit -am "fix: address test regressions from outflow/inflow change"
```
