# Category Transactions Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 從預算頁點擊類別，進入跨帳戶的交易明細頁，可依帳戶篩選，可編輯與刪除交易。

**Architecture:** 新增 `Budget::CategoryTransactionsController#index`，路由 `/budget/:year/:month/categories/:category_id/transactions`；同時補齊現有 `TransactionsController` 的 `edit`/`update` action（view 已存在但 routes/controller 尚未實作）。預算頁類別名稱改為連結。

**Tech Stack:** Ruby on Rails 8, Hotwire (Turbo Drive), Tailwind CSS v4, RSpec + Capybara System Specs

---

### Task 1: 補齊 Transactions edit/update（修復現有缺口）

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/transactions_controller.rb`

目前 `_row.html.erb` 已有 `edit_account_transaction_path` 連結，但路由和 controller 還沒有 `edit`/`update`。

**Step 1: 寫失敗 system spec**

在 `spec/system/transaction_edit_spec.rb`（已存在）確認現有測試會跑但可能因路由缺失而失敗：

```bash
bundle exec rspec spec/system/transaction_edit_spec.rb
```

預期結果：失敗（`ActionController::RoutingError` 或找不到 edit path）

**Step 2: 修改 routes.rb，加入 edit/update**

找到這段：
```ruby
resources :transactions, only: [:create, :destroy]
```

改為：
```ruby
resources :transactions, only: [:create, :edit, :update, :destroy]
```

**Step 3: 在 TransactionsController 加入 edit 和 update action**

在 `destroy` 之前新增：

```ruby
def edit
  @transaction = @account.transactions.find(params[:id])
  @categories = Current.household.category_groups.includes(:categories)
end

def update
  @transaction = @account.transactions.find(params[:id])
  if @transaction.update(transaction_params)
    @account.recalculate_balance!
    redirect_back_or_to account_path(@account), notice: "交易已更新"
  else
    @categories = Current.household.category_groups.includes(:categories)
    render :edit, status: :unprocessable_entity
  end
end
```

在 `transaction_params` 加入 `:memo`（已有），確認 permit 清單正確：
```ruby
def transaction_params
  p = params.require(:transaction).permit(:category_id, :amount, :date, :memo)
  if p[:category_id].present?
    Category.joins(:category_group)
            .where(category_groups: { household_id: Current.household.id })
            .find(p[:category_id])
  end
  p
end
```
（此方法已存在，不需更改）

**Step 4: 跑測試確認通過**

```bash
bundle exec rspec spec/system/transaction_edit_spec.rb
```

預期：2 examples, 0 failures

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/transactions_controller.rb
git commit -m "feat: add edit/update to TransactionsController"
```

---

### Task 2: 新增路由與 Budget::CategoryTransactionsController

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/budget/category_transactions_controller.rb`

**Step 1: 寫失敗 request spec（或直接寫 system spec，見 Task 4）**

先新增 system spec 骨架（不會跑，只是讓 `visit` 確認路由存在）。跳過此 step，直接實作 controller（Task 4 補完 system spec）。

**Step 2: 在 routes.rb 加入新路由**

在 `get "reports"...` 之前加入：

```ruby
get "budget/:year/:month/categories/:category_id/transactions",
    to: "budget/category_transactions#index",
    as: :budget_category_transactions
```

**Step 3: 建立 controller**

建立 `app/controllers/budget/category_transactions_controller.rb`：

```ruby
class Budget::CategoryTransactionsController < ApplicationController
  def index
    @category = Category
                  .joins(:category_group)
                  .where(category_groups: { household_id: Current.household.id })
                  .find(params[:category_id])

    @year  = params[:year].to_i
    @month = params[:month].to_i

    @accounts = Current.household.accounts.active.order(:name)
    @selected_account = params[:account_id].present? ?
                          Current.household.accounts.find_by(id: params[:account_id]) : nil

    @transactions = Transaction
                      .joins(:account, category: :category_group)
                      .where(category_id: @category.id)
                      .where(category_groups: { household_id: Current.household.id })
                      .for_month(@year, @month)
                      .then { |q| @selected_account ? q.where(account_id: @selected_account.id) : q }
                      .recent

    @total = @transactions.sum(:amount)
  end
end
```

**Step 4: 確認 Rails 路由正確**

```bash
bin/rails routes | grep category_transactions
```

預期輸出包含：
```
budget_category_transactions  GET  /budget/:year/:month/categories/:category_id/transactions  budget/category_transactions#index
```

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/budget/category_transactions_controller.rb
git commit -m "feat: add Budget::CategoryTransactionsController"
```

---

### Task 3: 建立 category transactions 頁面 View

**Files:**
- Create: `app/views/budget/category_transactions/index.html.erb`

**Step 1: 建立 view 目錄並新增 index**

建立 `app/views/budget/category_transactions/index.html.erb`：

```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
  <%# Header %>
  <div class="mb-6">
    <%= link_to budget_path(year: @year, month: @month),
          class: "inline-flex items-center gap-1 text-sm text-slate-400 hover:text-slate-700 mb-2" do %>
      <%= icon "chevron-left", classes: "w-4 h-4" %>
      預算
    <% end %>
    <h1 class="text-2xl font-bold text-slate-900">
      <%= @category.name %>
      <span class="text-slate-400 font-normal text-lg ml-2">
        <%= @year %>年<%= @month %>月
      </span>
    </h1>
  </div>

  <%# Account filter chips %>
  <div class="flex flex-wrap gap-2 mb-5">
    <%= link_to "全部",
          budget_category_transactions_path(@year, @month, @category),
          class: "px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{@selected_account.nil? ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}" %>
    <% @accounts.each do |account| %>
      <%= link_to account.name,
            budget_category_transactions_path(@year, @month, @category, account_id: account.id),
            class: "px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{@selected_account&.id == account.id ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}" %>
    <% end %>
  </div>

  <%# Transaction table %>
  <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
    <table class="w-full">
      <thead>
        <tr class="border-b border-slate-100">
          <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">日期</th>
          <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">備註</th>
          <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">帳戶</th>
          <th class="text-right px-5 py-3 text-xs font-medium text-slate-400">金額</th>
          <th class="px-5 py-3"></th>
        </tr>
      </thead>
      <tbody>
        <% if @transactions.empty? %>
          <tr>
            <td colspan="5" class="text-center py-16 text-slate-400">
              <p class="text-sm">本月沒有此類別的交易紀錄</p>
            </td>
          </tr>
        <% else %>
          <% @transactions.each do |t| %>
            <tr class="border-t border-slate-50 hover:bg-slate-50 group transition-colors"
                id="transaction-<%= t.id %>">
              <td class="px-5 py-3 text-sm text-slate-500"><%= t.date.strftime("%m/%d") %></td>
              <td class="px-5 py-3 text-sm text-slate-800"><%= t.memo.presence || "─" %></td>
              <td class="px-5 py-3 text-sm text-slate-400"><%= t.account.name %></td>
              <td class="px-5 py-3 text-right text-sm font-medium <%= t.amount < 0 ? 'text-red-500' : 'text-emerald-600' %>">
                <%= number_to_currency(t.amount, unit: "NT$", precision: 0) %>
              </td>
              <td class="px-5 py-3 text-right flex items-center gap-2 justify-end">
                <%= link_to "編輯",
                      edit_account_transaction_path(t.account, t),
                      class: "opacity-0 group-hover:opacity-100 transition-opacity text-sm text-blue-500 hover:text-blue-700" %>
                <%= button_to account_transaction_path(t.account, t),
                      method: :delete,
                      data: { turbo_confirm: "確定刪除這筆交易？" },
                      class: "opacity-0 group-hover:opacity-100 transition-opacity text-slate-300 hover:text-red-500",
                      aria: { label: "刪除交易" } do %>
                  <%= icon "trash", classes: "w-4 h-4" %>
                <% end %>
              </td>
            </tr>
          <% end %>
        <% end %>
      </tbody>
      <% unless @transactions.empty? %>
        <tfoot>
          <tr class="border-t border-slate-200 bg-slate-50">
            <td colspan="3" class="px-5 py-3 text-sm font-medium text-slate-500">合計</td>
            <td class="px-5 py-3 text-right text-sm font-bold <%= @total < 0 ? 'text-red-600' : 'text-emerald-600' %>">
              <%= number_to_currency(@total, unit: "NT$", precision: 0) %>
            </td>
            <td></td>
          </tr>
        </tfoot>
      <% end %>
    </table>
  </div>
</div>
```

**Step 2: 手動驗證頁面可存取（啟動 server 後測試）**

```bash
bin/rails server
```

在瀏覽器開啟 `/budget/2026/3/categories/1/transactions`（替換真實 category id），確認頁面正確顯示。

**Step 3: Commit**

```bash
git add app/views/budget/category_transactions/index.html.erb
git commit -m "feat: add category transactions index view"
```

---

### Task 4: 預算頁類別名稱改為連結

**Files:**
- Modify: `app/views/budget/index.html.erb:51-53`

**Step 1: 找到類別名稱的 td，加上 link_to**

找到這段（約第 50-53 行）：
```erb
<td class="px-5 py-3 text-sm text-slate-700 border-l-2 border-transparent group-hover:border-indigo-400 transition-colors">
  <%= category.name %>
</td>
```

改為：
```erb
<td class="px-5 py-3 text-sm text-slate-700 border-l-2 border-transparent group-hover:border-indigo-400 transition-colors">
  <%= link_to category.name,
        budget_category_transactions_path(@year, @month, category),
        class: "hover:text-indigo-600 hover:underline transition-colors" %>
</td>
```

**Step 2: 跑現有 budget spec 確認不壞**

```bash
bundle exec rspec spec/system/budget_spec.rb
```

預期：全部通過

**Step 3: Commit**

```bash
git add app/views/budget/index.html.erb
git commit -m "feat: link category name to transactions page from budget"
```

---

### Task 5: System Spec

**Files:**
- Create: `spec/system/category_transactions_spec.rb`

**Step 1: 寫 system spec**

建立 `spec/system/category_transactions_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe "Category Transactions", type: :system do
  let(:user)      { create(:user) }
  let(:household) { user.household }
  let!(:account1) { create(:account, household: household, name: "現金") }
  let!(:account2) { create(:account, household: household, name: "信用卡") }
  let!(:group)    { create(:category_group, household: household, name: "生活") }
  let!(:category) { create(:category, category_group: group, name: "食費") }
  let!(:txn1) do
    create(:transaction,
           account: account1, category: category,
           amount: -300, date: Date.new(2026, 3, 1), memo: "早餐")
  end
  let!(:txn2) do
    create(:transaction,
           account: account2, category: category,
           amount: -600, date: Date.new(2026, 3, 5), memo: "晚餐")
  end

  before { sign_in(user) }

  describe "從預算頁進入類別交易頁" do
    it "點擊類別名稱連結可進入明細頁" do
      visit budget_path(year: 2026, month: 3)
      click_link "食費"
      expect(page).to have_text("食費")
      expect(page).to have_text("2026年3月")
    end
  end

  describe "交易列表" do
    before do
      visit budget_category_transactions_path(2026, 3, category)
    end

    it "顯示跨帳戶的交易" do
      expect(page).to have_text("早餐")
      expect(page).to have_text("晚餐")
      expect(page).to have_text("現金")
      expect(page).to have_text("信用卡")
    end

    it "顯示合計金額" do
      expect(page).to have_text("-NT$900")
    end

    it "帳戶篩選只顯示該帳戶的交易" do
      click_link "現金"
      expect(page).to have_text("早餐")
      expect(page).not_to have_text("晚餐")
    end

    it "刪除交易後消失" do
      accept_confirm do
        within("#transaction-#{txn1.id}") do
          find("button[aria-label='刪除交易']", visible: false).click
        end
      end
      expect(page).not_to have_text("早餐")
      expect(page).to have_text("晚餐")
    end
  end

  describe "編輯交易" do
    before do
      visit budget_category_transactions_path(2026, 3, category)
    end

    it "點擊編輯後可修改備註，更新後仍在明細頁" do
      within("#transaction-#{txn1.id}") { click_link "編輯" }
      fill_in "備忘", with: "早餐（updated）"
      click_button "更新"
      expect(page).to have_text("食費")
    end
  end
end
```

**Step 2: 跑 spec（預期有一些失敗，先確認測試本身語法正確）**

```bash
bundle exec rspec spec/system/category_transactions_spec.rb --format documentation
```

**Step 3: 修正任何問題後確認全部通過**

```bash
bundle exec rspec spec/system/category_transactions_spec.rb
```

預期：7 examples, 0 failures

**Step 4: 跑全套測試確認沒有 regression**

```bash
bundle exec rspec
```

預期：全部通過

**Step 5: Commit**

```bash
git add spec/system/category_transactions_spec.rb
git commit -m "test: add system spec for category transactions page"
```

---

### Task 6: 刪除後的 Redirect 修正（選用）

> 注意：`TransactionsController#destroy` 目前固定 `redirect_to account_path(@account)`。從 category transactions 頁刪除後會跳到帳戶頁，而非回到明細頁。若想改善體驗，在 `destroy` 使用 `redirect_back_or_to`：

**Files:**
- Modify: `app/controllers/transactions_controller.rb:22-25`

```ruby
def destroy
  transaction = @account.transactions.find(params[:id])
  transaction.destroy
  @account.recalculate_balance!
  redirect_back_or_to account_path(@account), notice: "交易已刪除"
end
```

```bash
git add app/controllers/transactions_controller.rb
git commit -m "fix: redirect back after transaction destroy"
```
