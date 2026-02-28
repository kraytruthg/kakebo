# 預算分配 & 快速新增交易 實作計畫

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在預算頁面實作 inline 編輯「已分配」金額，以及每個類別 row 旁快速新增交易。

**Architecture:** 使用 Turbo Frame 實作 inline 編輯（BudgetEntriesController），使用 Stimulus budget controller + Drawer 實作快速新增交易，Turbo Stream 同步更新頁面上各數字欄位。

**Tech Stack:** Rails 8.1.2, Hotwire (Turbo + Stimulus), Tailwind CSS v4, RSpec request specs

---

## 環境確認

- 執行測試：`bundle exec rspec`
- 啟動 server：`bin/rails server -p 8888`
- DB：`docker compose up -d`（若未啟動）

---

## Task 1：新增 BudgetEntriesController 路由與空 controller

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/budget_entries_controller.rb`
- Create: `spec/requests/budget_entries_spec.rb`

**Step 1: 在 routes.rb 新增路由**

在 `config/routes.rb` 的 `get "budget"` 那行後面加入：

```ruby
resources :budget_entries, only: [:create] do
  collection do
    get :edit
  end
end
```

這會產生：
- `GET  /budget_entries/edit` → `budget_entries#edit`（as: `edit_budget_entry`）
- `POST /budget_entries`      → `budget_entries#create`（as: `budget_entries`）

**Step 2: 建立空 controller**

```ruby
# app/controllers/budget_entries_controller.rb
class BudgetEntriesController < ApplicationController
end
```

**Step 3: 確認路由正確**

```bash
bin/rails routes | grep budget_entr
```

預期輸出包含：
```
edit_budget_entries GET  /budget_entries/edit(.:format)  budget_entries#edit
       budget_entries POST /budget_entries(.:format)       budget_entries#create
```

---

## Task 2：BudgetEntriesController#edit（TDD）

**Files:**
- Modify: `spec/requests/budget_entries_spec.rb`
- Modify: `app/controllers/budget_entries_controller.rb`
- Create: `app/views/budget_entries/edit.html.erb`

**Step 1: 寫失敗的 request spec**

```ruby
# spec/requests/budget_entries_spec.rb
require "rails_helper"

RSpec.describe "BudgetEntries", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /budget_entries/edit" do
    context "when no budget entry exists for this month" do
      it "returns 200" do
        get edit_budget_entries_path,
            params: { category_id: category.id, year: 2026, month: 2 }
        expect(response).to have_http_status(:ok)
      end
    end

    context "when a budget entry exists" do
      it "returns 200 and includes the existing budgeted value" do
        create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 5000)
        get edit_budget_entries_path,
            params: { category_id: category.id, year: 2026, month: 2 }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("5000")
      end
    end

    context "with a category from another household" do
      it "raises ActiveRecord::RecordNotFound" do
        other_category = create(:category)
        expect {
          get edit_budget_entries_path,
              params: { category_id: other_category.id, year: 2026, month: 2 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
```

**Step 2: 執行確認失敗**

```bash
bundle exec rspec spec/requests/budget_entries_spec.rb
```

預期：`AbstractController::ActionNotFound` 或類似錯誤。

**Step 3: 實作 edit action**

```ruby
# app/controllers/budget_entries_controller.rb
class BudgetEntriesController < ApplicationController
  def edit
    @category = Category.joins(:category_group)
                        .where(category_groups: { household_id: Current.household.id })
                        .find(params[:category_id])
    @year  = params[:year].to_i
    @month = params[:month].to_i
    @entry = BudgetEntry.find_or_initialize_by(
      category_id: @category.id, year: @year, month: @month
    )
  end
end
```

**Step 4: 建立 edit view（Turbo Frame with inline input）**

```erb
<%# app/views/budget_entries/edit.html.erb %>
<turbo-frame id="budget-entry-<%= @category.id %>">
  <%= form_with url: budget_entries_path, data: { turbo: true } do |f| %>
    <%= f.hidden_field :category_id, value: @category.id %>
    <%= f.hidden_field :year,        value: @year %>
    <%= f.hidden_field :month,       value: @month %>
    <%= f.number_field :budgeted,
          value: @entry.budgeted.to_i,
          autofocus: true,
          step: 1,
          class: "w-28 text-right rounded border border-indigo-400 px-2 py-1 text-sm
                  focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    <%= f.submit "✓",
          class: "ml-1 text-sm text-indigo-600 hover:text-indigo-800 cursor-pointer" %>
  <% end %>
</turbo-frame>
```

**Step 5: 執行確認通過**

```bash
bundle exec rspec spec/requests/budget_entries_spec.rb
```

預期：3 examples, 0 failures

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/budget_entries_controller.rb app/views/budget_entries/edit.html.erb spec/requests/budget_entries_spec.rb
git commit -m "feat: add BudgetEntriesController#edit with Turbo Frame inline input"
```

---

## Task 3：BudgetEntriesController#create（TDD，upsert）

**Files:**
- Modify: `spec/requests/budget_entries_spec.rb`
- Modify: `app/controllers/budget_entries_controller.rb`
- Create: `app/views/budget_entries/create.turbo_stream.erb`

**Step 1: 在 spec 加入 create 的測試**

在 `describe "GET /budget_entries/edit"` 區塊後面加：

```ruby
describe "POST /budget_entries" do
  context "when no budget entry exists (create)" do
    it "creates a new BudgetEntry" do
      expect {
        post budget_entries_path,
             params: { budget_entry: { category_id: category.id,
                                       year: 2026, month: 2, budgeted: 3000 } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(BudgetEntry, :count).by(1)
      expect(BudgetEntry.last.budgeted).to eq(3000)
    end
  end

  context "when a budget entry already exists (update)" do
    it "updates budgeted without creating a new record" do
      entry = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 1000)
      expect {
        post budget_entries_path,
             params: { budget_entry: { category_id: category.id,
                                       year: 2026, month: 2, budgeted: 5000 } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(BudgetEntry, :count)
      expect(entry.reload.budgeted).to eq(5000)
    end
  end

  context "with a category from another household" do
    it "raises ActiveRecord::RecordNotFound" do
      other_category = create(:category)
      expect {
        post budget_entries_path,
             params: { budget_entry: { category_id: other_category.id,
                                       year: 2026, month: 2, budgeted: 1000 } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

**Step 2: 執行確認失敗**

```bash
bundle exec rspec spec/requests/budget_entries_spec.rb -e "POST"
```

**Step 3: 實作 create action（含 upsert 邏輯）**

在 `BudgetEntriesController` 裡加入：

```ruby
def create
  @category = Category.joins(:category_group)
                      .where(category_groups: { household_id: Current.household.id })
                      .find(budget_entry_params[:category_id])
  @year  = budget_entry_params[:year].to_i
  @month = budget_entry_params[:month].to_i
  @entry = BudgetEntry.find_or_initialize_by(
    category_id: @category.id, year: @year, month: @month
  )
  @entry.budgeted = budget_entry_params[:budgeted]

  if @entry.save
    @activity  = Transaction
                   .joins(:account, category: { category_group: :household })
                   .where(accounts: { account_type: "budget" })
                   .where(category_groups: { household_id: Current.household.id })
                   .where(category_id: @category.id)
                   .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?",
                          @year, @month)
                   .sum(:amount)
    @available = (@entry.carried_over || 0) + @entry.budgeted + @activity

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to budget_path(year: @year, month: @month) }
    end
  else
    head :unprocessable_entity
  end
end

private

def budget_entry_params
  params.require(:budget_entry).permit(:category_id, :year, :month, :budgeted)
end
```

**Step 4: 建立 Turbo Stream view**

```erb
<%# app/views/budget_entries/create.turbo_stream.erb %>
<%= turbo_stream.replace "budget-entry-#{@category.id}" do %>
  <turbo-frame id="budget-entry-<%= @category.id %>">
    <%= link_to edit_budget_entries_path(category_id: @category.id, year: @year, month: @month),
          class: "cursor-pointer hover:text-indigo-600 transition-colors" do %>
      <%= number_to_currency(@entry.budgeted, unit: "NT$", precision: 0) %>
    <% end %>
  </turbo-frame>
<% end %>

<%= turbo_stream.replace "available-#{@category.id}" do %>
  <span id="available-<%= @category.id %>"
        class="font-semibold <%= @available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
    <%= number_to_currency(@available, unit: "NT$", precision: 0) %>
  </span>
<% end %>
```

**Step 5: 執行所有 spec 確認通過**

```bash
bundle exec rspec spec/requests/budget_entries_spec.rb
```

預期：6 examples, 0 failures

**Step 6: 確認既有測試全部通過**

```bash
bundle exec rspec
```

預期：0 failures

**Step 7: Commit**

```bash
git add app/controllers/budget_entries_controller.rb app/views/budget_entries/create.turbo_stream.erb spec/requests/budget_entries_spec.rb
git commit -m "feat: BudgetEntriesController#create with upsert and Turbo Stream"
```

---

## Task 4：更新 budget/index.html.erb 實現 inline 編輯

**Files:**
- Modify: `app/views/budget/index.html.erb`

**Step 1: 修改「已分配」欄位，包進 Turbo Frame**

把目前的「已分配」 `<td>`：

```erb
<td class="px-5 py-3 text-right text-sm text-slate-600">
  <%= number_to_currency(budgeted, unit: "NT$", precision: 0) %>
</td>
```

改成：

```erb
<td class="px-5 py-3 text-right text-sm text-slate-600">
  <turbo-frame id="budget-entry-<%= category.id %>">
    <%= link_to edit_budget_entries_path(category_id: category.id, year: @year, month: @month),
          class: "cursor-pointer hover:text-indigo-600 transition-colors" do %>
      <%= number_to_currency(budgeted, unit: "NT$", precision: 0) %>
    <% end %>
  </turbo-frame>
</td>
```

**Step 2: 幫「本月支出」與「可用」加上 id span**

「本月支出」`<td>` 改成：

```erb
<td class="px-5 py-3 text-right text-sm <%= activity < 0 ? 'text-red-500' : 'text-slate-600' %>">
  <span id="activity-<%= category.id %>">
    <%= number_to_currency(activity, unit: "NT$", precision: 0) %>
  </span>
</td>
```

「可用」`<td>` 改成：

```erb
<td class="px-5 py-3 text-right text-sm font-semibold">
  <span id="available-<%= category.id %>"
        class="<%= available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
    <%= number_to_currency(available, unit: "NT$", precision: 0) %>
  </span>
</td>
```

**Step 3: 啟動 server 手動測試 inline 編輯**

```bash
bin/rails server -p 8888
```

- 前往 `http://localhost:8888/budget`
- 點擊任一「已分配」金額
- 應跳出 input，輸入數字按 ✓ 應更新並顯示新金額，「可用」也隨之更新

**Step 4: 確認測試通過**

```bash
bundle exec rspec
```

**Step 5: Commit**

```bash
git add app/views/budget/index.html.erb
git commit -m "feat: inline budget edit via Turbo Frame in budget index"
```

---

## Task 5：更新 TransactionsController，使新增交易後可更新預算列

**Files:**
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `app/views/transactions/create.turbo_stream.erb`

**Step 1: 在 TransactionsController 新增 private helper**

在 `private` 區塊加入：

```ruby
def set_budget_data_for_turbo_stream
  return unless @transaction.category_id.present?

  year  = @transaction.date.year
  month = @transaction.date.month

  @budget_activity = Transaction
                       .joins(:account, category: { category_group: :household })
                       .where(accounts: { account_type: "budget" })
                       .where(category_groups: { household_id: Current.household.id })
                       .where(category_id: @transaction.category_id)
                       .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?",
                              year, month)
                       .sum(:amount)

  @budget_entry     = BudgetEntry.find_by(
    category_id: @transaction.category_id, year: year, month: month
  )
  @budget_available = (@budget_entry&.carried_over || 0) +
                      (@budget_entry&.budgeted || 0) +
                      @budget_activity
end
```

在 `create` action 的 `@account.recalculate_balance!` 那行後加：

```ruby
set_budget_data_for_turbo_stream
```

**Step 2: 更新 create.turbo_stream.erb，條件式更新預算列**

```erb
<%# app/views/transactions/create.turbo_stream.erb %>
<%= turbo_stream.remove "transactions-empty" %>
<%= turbo_stream.prepend "transactions-tbody" do %>
  <%= render "transactions/row", transaction: @transaction, account: @account %>
<% end %>

<% if @budget_activity %>
  <%= turbo_stream.replace "activity-#{@transaction.category_id}" do %>
    <span id="activity-<%= @transaction.category_id %>"
          class="<%= @budget_activity < 0 ? 'text-red-500' : 'text-slate-600' %>">
      <%= number_to_currency(@budget_activity, unit: "NT$", precision: 0) %>
    </span>
  <% end %>

  <%= turbo_stream.replace "available-#{@transaction.category_id}" do %>
    <span id="available-<%= @transaction.category_id %>"
          class="font-semibold <%= @budget_available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
      <%= number_to_currency(@budget_available, unit: "NT$", precision: 0) %>
    </span>
  <% end %>
<% end %>
```

（Turbo Stream 對不存在的 target 會靜默忽略，所以在帳戶頁使用時不受影響。）

**Step 3: 確認所有測試通過**

```bash
bundle exec rspec
```

預期：0 failures

**Step 4: Commit**

```bash
git add app/controllers/transactions_controller.rb app/views/transactions/create.turbo_stream.erb
git commit -m "feat: update transaction create to broadcast budget row changes via Turbo Stream"
```

---

## Task 6：建立 budget Stimulus controller

**Files:**
- Create: `app/javascript/controllers/budget_controller.js`

**Step 1: 建立 Stimulus controller**

```javascript
// app/javascript/controllers/budget_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "backdrop", "panel",
    "categoryId", "categoryName",
    "form", "accountSelect"
  ]

  // 開啟 Drawer 並預先設定類別
  openWithCategory(event) {
    const { categoryId, categoryName } = event.params
    this.categoryIdTarget.value       = categoryId
    this.categoryNameTarget.textContent = categoryName
    this.updateFormAction()
    this.open()
  }

  // Drawer 開關
  open() {
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    this.panelTarget.classList.remove("translate-x-full")
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
}
```

**Step 2: 確認 Stimulus controller 已自動註冊**

Kakebo 使用 stimulus-loading 的 `eagerLoadControllersFrom`，放在 `app/javascript/controllers/` 下的檔案會自動載入。確認 `app/javascript/controllers/index.js` 是否有：

```javascript
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

如果有，不需額外修改。

**Step 3: Commit**

```bash
git add app/javascript/controllers/budget_controller.js
git commit -m "feat: add budget Stimulus controller for drawer and category pre-fill"
```

---

## Task 7：在 budget/index.html.erb 新增 Drawer UI 與快速新增按鈕

**Files:**
- Modify: `app/views/budget/index.html.erb`
- Create: `app/views/transactions/_budget_form.html.erb`

**Step 1: 建立 budget transaction form partial**

```erb
<%# app/views/transactions/_budget_form.html.erb %>
<% first_account = Current.household.accounts.budget.first %>
<%= form_with url: account_transactions_path(first_account),
      data: {
        budget_target: "form",
        turbo_stream: true,
        action: "turbo:submit-end->budget#close"
      } do |f| %>
  <div class="space-y-5">

    <%# 類別（唯讀顯示 + hidden input） %>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">類別</label>
      <div class="block w-full rounded-lg border border-slate-200 bg-slate-50 px-3.5 py-2.5 text-sm text-slate-600"
           data-budget-target="categoryName">
      </div>
      <%= f.hidden_field :category_id, data: { budget_target: "categoryId" } %>
    </div>

    <%# 帳戶選擇（控制 form action） %>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">帳戶</label>
      <%= f.select :account_id,
            options_for_select(
              Current.household.accounts.budget.map { |a| [a.name, a.id] }
            ),
            {},
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm
                    focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
            data: {
              budget_target: "accountSelect",
              action: "change->budget#accountChanged"
            } %>
    </div>

    <%# 日期 %>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">日期</label>
      <%= f.date_field :date, value: Date.today,
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm
                    focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>

    <%# 金額 %>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">金額</label>
      <%= f.number_field :amount, step: 1, placeholder: "支出填負數，例：-500",
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm
                    focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>

    <%# 備註 %>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">備註</label>
      <%= f.text_field :memo, placeholder: "例：午餐",
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm
                    focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>

    <%= f.submit "新增交易",
          class: "w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5
                  rounded-lg cursor-pointer transition-colors text-sm" %>
  </div>
<% end %>
```

**Step 2: 更新 budget/index.html.erb**

把最外層 `<div class="max-w-4xl ...">` 改成加上 `data-controller="budget"`：

```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8" data-controller="budget">
```

在 `<thead>` 的 header row 最後加一欄空白 `<th>`：

```erb
<th class="px-3 py-3"></th>
```

在 category row（`<tr class="border-t ...">`）最後加操作欄：

```erb
<td class="px-3 py-3 text-center opacity-0 group-hover:opacity-100 transition-opacity">
  <button data-action="budget#openWithCategory"
          data-budget-category-id-param="<%= category.id %>"
          data-budget-category-name-param="<%= category.name %>"
          class="text-indigo-400 hover:text-indigo-700 transition-colors"
          title="新增交易">
    <%= icon "plus-circle", classes: "w-5 h-5" %>
  </button>
</td>
```

在 `</div>` 最後（整個 view 的結尾）加入 Drawer HTML：

```erb
<%# Drawer backdrop %>
<div data-budget-target="backdrop"
     class="fixed inset-0 bg-black/40 z-40 opacity-0 pointer-events-none transition-opacity duration-200"
     data-action="click->budget#backdropClick">
</div>

<%# Drawer panel %>
<div data-budget-target="panel"
     class="fixed inset-y-0 right-0 w-full sm:w-96 bg-white shadow-2xl z-50 translate-x-full transition-transform duration-300 ease-in-out flex flex-col">
  <div class="flex items-center justify-between px-5 py-4 border-b border-slate-100">
    <h2 class="text-base font-semibold text-slate-900">新增交易</h2>
    <button data-action="budget#close"
            class="text-slate-400 hover:text-slate-700 transition-colors"
            aria-label="關閉">
      <%= icon "x-mark", classes: "w-5 h-5" %>
    </button>
  </div>
  <div class="flex-1 overflow-y-auto px-5 py-5">
    <%= render "transactions/budget_form" %>
  </div>
</div>
```

**Step 3: 手動測試快速新增交易**

```bash
bin/rails server -p 8888
```

- 前往 `http://localhost:8888/budget`
- hover 任一類別 row，應出現 `+` 按鈕
- 點擊 `+` 應開啟 Drawer，類別名稱已填入，帳戶可選擇
- 填入金額送出，Drawer 關閉，「本月支出」與「可用」應即時更新

**Step 4: 確認所有測試通過**

```bash
bundle exec rspec
```

預期：0 failures

**Step 5: Commit**

```bash
git add app/views/budget/index.html.erb app/views/transactions/_budget_form.html.erb
git commit -m "feat: add quick transaction drawer to budget index with budget row live update"
```

---

## 完成檢查清單

- [ ] 點擊「已分配」金額可 inline 編輯，Enter 儲存，「可用」同步更新
- [ ] Inline 編輯更新既有 BudgetEntry（不重複建立）
- [ ] hover category row 出現 `+` 按鈕
- [ ] 點擊 `+` 開啟 Drawer，類別唯讀顯示，帳戶可選
- [ ] 送出交易後「本月支出」「可用」即時更新，Drawer 自動關閉
- [ ] 在帳戶頁新增交易的既有功能不受影響
- [ ] `bundle exec rspec` 0 failures
