# RWD Optimization for iPhone 15 Pro Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Optimize all pages for iPhone 15 Pro (393pt) with native app-like feel — card-based lists on mobile, 5-tab bottom nav, safe area support.

**Architecture:** Progressive Tailwind optimization. Each page gets mobile-specific markup using `hidden lg:block` / `lg:hidden` to switch between desktop tables and mobile cards. No new dependencies. Desktop views remain unchanged.

**Tech Stack:** Rails 8.1.2, Tailwind CSS v4, Hotwire/Stimulus, RSpec/Capybara system tests

---

### Task 1: Safe Area + Viewport in Layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Update viewport meta tag**

Change line 5 from:
```erb
<meta name="viewport" content="width=device-width,initial-scale=1">
```
to:
```erb
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
```

**Step 2: Add safe area CSS for Tailwind v4**

Add after line 11 (`javascript_importmap_tags`):
```erb
<style>
  .pb-safe { padding-bottom: env(safe-area-inset-bottom, 0px); }
  .pt-safe { padding-top: env(safe-area-inset-top, 0px); }
</style>
```

**Step 3: Run existing tests to verify no breakage**

Run: `bundle exec rspec spec/system/sessions_spec.rb --format progress`
Expected: All pass

**Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat: add viewport-fit=cover and safe area CSS utilities"
```

---

### Task 2: Bottom Navigation — Reduce to 5 Tabs + Safe Area

**Files:**
- Modify: `app/views/shared/_nav.html.erb`
- Modify: `config/routes.rb`
- Create: `app/controllers/settings_controller.rb`
- Create: `app/views/settings/index.html.erb`

**Step 1: Add settings root route**

In `config/routes.rb`, add inside the `namespace :settings` block (after line 19):
```ruby
namespace :settings do
  root to: "settings#index"
  # ... existing routes ...
end
```

Also add a named route helper. Change line 32:
```ruby
get "settings/categories", to: "settings/category_groups#index", as: :settings_categories
```
Keep it as is — we'll add the settings root via the namespace.

Actually, the namespace `root` gives us `settings_root_path`. Let's add it as the first line in the namespace block:

In `config/routes.rb`, change:
```ruby
namespace :settings do
  resources :category_groups, only: [ :new, :create, :edit, :update, :destroy ] do
```
to:
```ruby
namespace :settings do
  get "", to: "settings#index", as: :root
  resources :category_groups, only: [ :new, :create, :edit, :update, :destroy ] do
```

**Step 2: Create settings controller**

Create `app/controllers/settings_controller.rb`:
```ruby
class Settings::SettingsController < ApplicationController
  def index
  end
end
```

Wait — namespace `settings` means the controller should be at `app/controllers/settings/settings_controller.rb`. Actually, `to: "settings#index"` inside `namespace :settings` resolves to `Settings::SettingsController#index`. Let's verify: `namespace :settings { get "", to: "settings#index" }` → `Settings::SettingsController#index`. That's awkward. Better approach:

In `config/routes.rb`, outside the namespace, add:
```ruby
get "settings", to: "settings#index", as: :settings_root
```

Then create `app/controllers/settings_controller.rb`:
```ruby
class SettingsController < ApplicationController
  def index
  end
end
```

**Step 3: Create settings index view**

Create `app/views/settings/index.html.erb`:
```erb
<div class="px-4 py-6 lg:max-w-2xl lg:mx-auto lg:px-6 lg:py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">設定</h1>

  <div class="space-y-3">
    <%= link_to settings_categories_path, class: "flex items-center justify-between bg-white rounded-xl border border-slate-100 px-5 py-4 hover:border-indigo-200 hover:shadow-sm transition-all" do %>
      <div class="flex items-center gap-3">
        <%= icon "squares-2x2", classes: "w-5 h-5 text-slate-400" %>
        <span class="text-sm font-medium text-slate-800">類別管理</span>
      </div>
      <%= icon "chevron-right", classes: "w-4 h-4 text-slate-400" %>
    <% end %>

    <%= link_to settings_quick_entry_mappings_path, class: "flex items-center justify-between bg-white rounded-xl border border-slate-100 px-5 py-4 hover:border-indigo-200 hover:shadow-sm transition-all" do %>
      <div class="flex items-center gap-3">
        <%= icon "key", classes: "w-5 h-5 text-slate-400" %>
        <span class="text-sm font-medium text-slate-800">快速記帳對應</span>
      </div>
      <%= icon "chevron-right", classes: "w-4 h-4 text-slate-400" %>
    <% end %>

    <% if Current.user.admin? %>
      <%= link_to admin_users_path, class: "flex items-center justify-between bg-white rounded-xl border border-slate-100 px-5 py-4 hover:border-indigo-200 hover:shadow-sm transition-all" do %>
        <div class="flex items-center gap-3">
          <%= icon "users", classes: "w-5 h-5 text-slate-400" %>
          <span class="text-sm font-medium text-slate-800">使用者管理</span>
        </div>
        <%= icon "chevron-right", classes: "w-4 h-4 text-slate-400" %>
      <% end %>
    <% end %>
  </div>
</div>
```

**Step 4: Update mobile bottom nav to 5 tabs**

In `app/views/shared/_nav.html.erb`, replace the entire mobile bottom nav section (lines 53-85) with:
```erb
<%# Mobile bottom tab bar %>
<nav class="lg:hidden fixed bottom-0 inset-x-0 bg-white border-t border-slate-200 flex z-10 pb-safe" aria-label="行動裝置導覽">
  <%= link_to budget_path, class: "flex-1 flex flex-col items-center py-2 gap-0.5 min-h-[44px] justify-center #{request.path == budget_path ? 'text-indigo-600' : 'text-slate-400'}" do %>
    <%= icon "chart-bar", classes: "w-6 h-6" %>
    <span class="text-[10px] font-medium">預算</span>
  <% end %>
  <%= link_to accounts_path, class: "flex-1 flex flex-col items-center py-2 gap-0.5 min-h-[44px] justify-center #{request.path.start_with?(accounts_path) ? 'text-indigo-600' : 'text-slate-400'}" do %>
    <%= icon "credit-card", classes: "w-6 h-6" %>
    <span class="text-[10px] font-medium">帳戶</span>
  <% end %>
  <%= link_to reports_path, class: "flex-1 flex flex-col items-center py-2 gap-0.5 min-h-[44px] justify-center #{request.path == reports_path ? 'text-indigo-600' : 'text-slate-400'}" do %>
    <%= icon "presentation-chart-line", classes: "w-6 h-6" %>
    <span class="text-[10px] font-medium">報表</span>
  <% end %>
  <%= link_to new_quick_entry_path, class: "flex-1 flex flex-col items-center py-2 gap-0.5 min-h-[44px] justify-center #{request.path.start_with?('/quick_entry') ? 'text-indigo-600' : 'text-slate-400'}" do %>
    <%= icon "bolt", classes: "w-6 h-6" %>
    <span class="text-[10px] font-medium">記帳</span>
  <% end %>
  <%= link_to settings_root_path, class: "flex-1 flex flex-col items-center py-2 gap-0.5 min-h-[44px] justify-center #{request.path.start_with?('/settings') || request.path.start_with?('/admin') ? 'text-indigo-600' : 'text-slate-400'}" do %>
    <%= icon "cog-6-tooth", classes: "w-6 h-6" %>
    <span class="text-[10px] font-medium">設定</span>
  <% end %>
</nav>
```

**Step 5: Update desktop sidebar to include Settings entry**

In the desktop sidebar nav (lines 23-30), replace the 類別管理 and 記帳對應 links with a single Settings link. Keep the individual links for desktop but also add a Settings entry. Actually — keep the desktop sidebar unchanged since it has room for all items. The desktop sidebar is fine with 6-7 items.

No change needed for desktop sidebar.

**Step 6: Run tests**

Run: `bundle exec rspec spec/system/budget_spec.rb spec/system/sessions_spec.rb --format progress`
Expected: All pass (nav changes should not break existing tests since system tests click by text)

**Step 7: Commit**

```bash
git add app/controllers/settings_controller.rb app/views/settings/index.html.erb app/views/shared/_nav.html.erb config/routes.rb
git commit -m "feat: add settings hub page and reduce mobile nav to 5 tabs"
```

---

### Task 3: Budget Page — Mobile Card Layout

**Files:**
- Modify: `app/views/budget/index.html.erb`

**Step 1: Update container to full-width on mobile**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8"
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8"
```

**Step 2: Make summary cards responsive**

Change the summary cards section (lines 20-35) — update text sizes:
```erb
<%# Budget summary cards %>
<div class="grid grid-cols-2 gap-3 lg:gap-4 mb-6">
  <div class="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-4 lg:p-6 text-white shadow-lg shadow-indigo-200">
    <p class="text-indigo-200 text-xs lg:text-sm font-medium mb-1">全部已分配</p>
    <p id="total-budgeted" class="text-2xl lg:text-4xl font-bold tracking-tight">
      <%= format_amount(@total_budgeted) %>
    </p>
    <p class="text-indigo-300 text-[10px] lg:text-xs mt-1 lg:mt-2">本月已分配的預算</p>
  </div>
  <div class="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-4 lg:p-6 text-white shadow-lg shadow-indigo-200">
    <p class="text-indigo-200 text-xs lg:text-sm font-medium mb-1">剩餘可分配</p>
    <p id="ready-to-assign" class="text-2xl lg:text-4xl font-bold tracking-tight">
      <%= format_amount(@ready_to_assign) %>
    </p>
    <p class="text-indigo-300 text-[10px] lg:text-xs mt-1 lg:mt-2">可分配給各類別的預算</p>
  </div>
</div>
```

**Step 3: Add mobile card view for categories (before the existing table)**

After the summary cards and before the table `<div>`, add the mobile card view:
```erb
<%# Mobile card view %>
<div class="lg:hidden space-y-4">
  <% @category_groups.each do |group| %>
    <div>
      <h3 class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2 px-1"><%= group.name %></h3>
      <div class="space-y-2">
        <% group.categories.each do |category| %>
          <% entry = category.budget_entries.find { |e| e.year == @year && e.month == @month } %>
          <% budgeted = entry&.budgeted || 0 %>
          <% activity = @monthly_activities[category.id] || 0 %>
          <% available = (entry&.carried_over || 0) + budgeted + activity %>
          <% spent_pct = budgeted > 0 ? [(-activity / budgeted.to_f * 100).round, 100].min : 0 %>
          <%= link_to budget_category_transactions_path(@year, @month, category),
                class: "block bg-white rounded-xl border border-slate-100 px-4 py-3 active:bg-slate-50 transition-colors" do %>
            <div class="flex items-center justify-between mb-1.5">
              <span class="text-sm font-medium text-slate-800"><%= category.name %></span>
              <span class="text-sm font-semibold <%= available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
                剩 <%= format_amount(available) %>
              </span>
            </div>
            <div class="flex items-center justify-between text-xs text-slate-400 mb-2">
              <span>預算 <%= format_amount(budgeted) %></span>
              <span>支出 <%= format_amount(activity) %></span>
            </div>
            <div class="w-full bg-slate-100 rounded-full h-1.5">
              <div class="h-1.5 rounded-full <%= spent_pct > 90 ? 'bg-red-500' : 'bg-indigo-500' %>"
                   style="width: <%= [spent_pct, 0].max %>%"></div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

**Step 4: Hide existing table on mobile**

Change the table wrapper (line 38):
```erb
<div class="hidden lg:block bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/system/budget_spec.rb --format progress`
Expected: All pass (system tests use desktop viewport by default via headless_chrome)

**Step 6: Commit**

```bash
git add app/views/budget/index.html.erb
git commit -m "feat: add mobile card layout for budget page"
```

---

### Task 4: Accounts Index — Full-Width Mobile

**Files:**
- Modify: `app/views/accounts/index.html.erb`

**Step 1: Update container**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/system/accounts_spec.rb --format progress`
Expected: All pass

**Step 3: Commit**

```bash
git add app/views/accounts/index.html.erb
git commit -m "feat: full-width mobile container for accounts index"
```

---

### Task 5: Accounts Show — Mobile Card Layout for Transactions

**Files:**
- Modify: `app/views/accounts/show.html.erb`

**Step 1: Update container**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8"
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8"
```

**Step 2: Make hero header stack vertically on mobile**

Replace the hero header (lines 5-38) with:
```erb
<%# Hero header %>
<div class="mb-6">
  <%= link_to accounts_path, class: "inline-flex items-center gap-1 text-sm text-slate-400 hover:text-slate-700 mb-2" do %>
    <%= icon "chevron-left", classes: "w-4 h-4" %>
    帳戶
  <% end %>
  <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between">
    <div class="mb-4 lg:mb-0">
      <h1 class="text-xl lg:text-2xl font-bold text-slate-900"><%= @account.name %></h1>
      <span class="inline-block mt-1 text-xs font-medium px-2 py-0.5 rounded-full <%= @account.budget? ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-600' %>">
        <%= @account.budget? ? "預算帳戶" : "追蹤帳戶" %>
      </span>
    </div>
    <div class="lg:text-right">
      <p class="text-2xl lg:text-3xl font-bold text-slate-900">
        <%= format_amount(@account.balance) %>
      </p>
      <div class="flex gap-2 mt-3 lg:justify-end">
        <%= link_to edit_account_path(@account),
              class: "inline-flex items-center gap-1.5 text-xs text-slate-500 hover:text-slate-900 border border-slate-200 rounded-lg px-3 py-1.5 transition-colors" do %>
          <%= icon "pencil-square", classes: "w-3.5 h-3.5" %>
          編輯
        <% end %>
        <%= link_to new_transfer_path(from_account_id: @account.id),
              class: "inline-flex items-center gap-1.5 text-xs text-slate-500 hover:text-slate-900 border border-slate-200 rounded-lg px-3 py-1.5 transition-colors" do %>
          <%= icon "arrows-right-left", classes: "w-3.5 h-3.5" %>
          轉帳
        <% end %>
        <button data-action="drawer#open"
                class="inline-flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-1.5 rounded-lg transition-colors">
          <%= icon "plus", classes: "w-4 h-4" %>
          新增交易
        </button>
      </div>
    </div>
  </div>
</div>
```

**Step 3: Add mobile card view for transactions (before existing table)**

Add before the table `<div>` (line 41):
```erb
<%# Mobile transaction cards %>
<div class="lg:hidden space-y-2" id="transaction-list-mobile">
  <% if @transactions.empty? %>
    <div class="bg-white rounded-xl border border-slate-100 py-12 text-center text-slate-400">
      <p class="text-sm">還沒有交易紀錄</p>
      <p class="text-xs mt-1">點擊「新增交易」開始記帳</p>
    </div>
  <% else %>
    <% @transactions.each do |t| %>
      <div class="bg-white rounded-xl border border-slate-100 px-4 py-3" id="transaction-mobile-<%= t.id %>">
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="text-xs text-slate-400"><%= t.date.strftime("%m/%d") %></span>
              <span class="text-sm text-slate-800 truncate"><%= t.memo.presence || "─" %></span>
            </div>
            <p class="text-xs text-slate-400 mt-0.5">
              <% if t.transfer? %>
                <% partner_name = t.transfer_pair.account.name %>
                <%= t.amount < 0 ? "轉出 → #{partner_name}" : "轉入 ← #{partner_name}" %>
              <% else %>
                <%= t.category&.name || "收入" %>
              <% end %>
            </p>
          </div>
          <span class="text-sm font-semibold ml-3 <%= t.amount < 0 ? 'text-red-500' : 'text-emerald-600' %>">
            <%= format_amount(t.amount) %>
          </span>
        </div>
      </div>
    <% end %>
  <% end %>
</div>
```

**Step 4: Hide existing table on mobile**

Change the table wrapper (line 41 — original) to:
```erb
<div class="hidden lg:block bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden" id="transaction-list">
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/system/transactions_spec.rb spec/system/accounts_spec.rb --format progress`
Expected: All pass

**Step 6: Commit**

```bash
git add app/views/accounts/show.html.erb
git commit -m "feat: mobile card layout for account transactions"
```

---

### Task 6: Category Transactions — Mobile Card Layout

**Files:**
- Modify: `app/views/budget/category_transactions/index.html.erb`

**Step 1: Update container**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
```

**Step 2: Add mobile card view (before existing table)**

Add after the filter chips section (after line 25) and before the table:
```erb
<%# Mobile transaction cards %>
<div class="lg:hidden space-y-2">
  <% if @items.empty? %>
    <div class="bg-white rounded-xl border border-slate-100 py-12 text-center text-slate-400">
      <p class="text-sm">沒有此類別的交易紀錄</p>
    </div>
  <% else %>
    <% @items.each do |item| %>
      <% if item.type == :budget %>
        <div class="bg-indigo-50/50 rounded-xl border border-indigo-100 px-4 py-3">
          <div class="flex items-center justify-between">
            <div>
              <span class="text-xs text-slate-400"><%= item.date.strftime("%m/%d") %></span>
              <span class="text-sm text-indigo-600 font-medium ml-2"><%= item.memo %></span>
            </div>
            <span class="text-sm font-medium text-indigo-600"><%= format_amount(item.amount) %></span>
          </div>
        </div>
      <% else %>
        <div class="bg-white rounded-xl border border-slate-100 px-4 py-3">
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-xs text-slate-400"><%= item.date.strftime("%m/%d") %></span>
                <span class="text-sm text-slate-800 truncate"><%= item.memo.presence || "─" %></span>
              </div>
              <p class="text-xs text-slate-400 mt-0.5"><%= item.account_name %></p>
            </div>
            <span class="text-sm font-semibold ml-3 <%= item.amount < 0 ? 'text-red-500' : 'text-emerald-600' %>">
              <%= format_amount(item.amount) %>
            </span>
          </div>
        </div>
      <% end %>
    <% end %>
  <% end %>
</div>
```

**Step 3: Hide existing table on mobile**

Change the table wrapper (line 28) from:
```erb
<div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
```
to:
```erb
<div class="hidden lg:block bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/system/category_transactions_spec.rb --format progress`
Expected: All pass

**Step 5: Commit**

```bash
git add app/views/budget/category_transactions/index.html.erb
git commit -m "feat: mobile card layout for category transactions"
```

---

### Task 7: Reports Page — Smaller Pie Chart on Mobile

**Files:**
- Modify: `app/views/reports/index.html.erb`

**Step 1: Update container**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
```

**Step 2: Update pie chart size**

Change line 26:
```erb
<div class="w-48 h-48 rounded-full mb-6" style="background: conic-gradient(<%= conic %>)"></div>
```
to:
```erb
<div class="w-40 h-40 lg:w-48 lg:h-48 rounded-full mb-6" style="background: conic-gradient(<%= conic %>)"></div>
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/system/reports_spec.rb --format progress`
Expected: All pass

**Step 4: Commit**

```bash
git add app/views/reports/index.html.erb
git commit -m "feat: responsive pie chart and full-width container for reports"
```

---

### Task 8: Quick Entry — Full-Width Mobile

**Files:**
- Modify: `app/views/quick_entry/new.html.erb`

**Step 1: Update container**

Change line 1 from:
```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-lg lg:mx-auto lg:px-6 lg:py-8">
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/system/quick_entry_spec.rb --format progress`
Expected: All pass

**Step 3: Commit**

```bash
git add app/views/quick_entry/new.html.erb
git commit -m "feat: full-width mobile container for quick entry"
```

---

### Task 9: Settings Pages — Full-Width Mobile

**Files:**
- Modify: `app/views/settings/category_groups/index.html.erb`
- Modify: `app/views/settings/quick_entry_mappings/index.html.erb`
- Modify: `app/views/admin/users/index.html.erb`

**Step 1: Update category groups container**

Change line 1 from:
```erb
<div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-2xl lg:mx-auto lg:px-6 lg:py-8">
```

**Step 2: Update quick entry mappings container**

Change line 1 from:
```erb
<div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-2xl lg:mx-auto lg:px-6 lg:py-8">
```

**Step 3: Update admin users container and wrap table for overflow**

Change line 1 from:
```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
```
to:
```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
```

Also wrap the table in an overflow container. Change line 11:
```erb
<div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
```
to:
```erb
<div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden overflow-x-auto">
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/system/categories_spec.rb spec/system/quick_entry_mappings_spec.rb spec/system/admin/users_spec.rb --format progress`
Expected: All pass

**Step 5: Commit**

```bash
git add app/views/settings/category_groups/index.html.erb app/views/settings/quick_entry_mappings/index.html.erb app/views/admin/users/index.html.erb
git commit -m "feat: full-width mobile containers for settings pages"
```

---

### Task 10: Month Nav — Consistent Styling

**Files:**
- Modify: `app/views/shared/_month_nav.html.erb`

**Step 1: Update color classes to use slate instead of gray**

Replace the entire file with:
```erb
<div class="flex items-center gap-3">
  <% if at_lower_bound? %>
    <span class="text-slate-300 cursor-not-allowed" aria-disabled="true">←</span>
  <% else %>
    <%= link_to "←", request.path + "?" + { year: prev_month[:year], month: prev_month[:month] }.to_query,
        class: "text-slate-500 hover:text-slate-900 p-1" %>
  <% end %>

  <span class="text-sm lg:text-base font-semibold text-slate-800"><%= "#{@year} 年 #{@month} 月" %></span>

  <% if at_upper_bound? %>
    <span class="text-slate-300 cursor-not-allowed" aria-disabled="true">→</span>
  <% else %>
    <%= link_to "→", request.path + "?" + { year: next_month[:year], month: next_month[:month] }.to_query,
        class: "text-slate-500 hover:text-slate-900 p-1" %>
  <% end %>
</div>
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/system/month_navigation_spec.rb --format progress`
Expected: All pass

**Step 3: Commit**

```bash
git add app/views/shared/_month_nav.html.erb
git commit -m "fix: consistent slate color palette in month navigation"
```

---

### Task 11: Run Full Test Suite

**Step 1: Run all system tests**

Run: `bundle exec rspec spec/system/ --format progress`
Expected: All pass (71+ examples, 0 failures)

**Step 2: Run all specs**

Run: `bundle exec rspec --format progress`
Expected: All pass

**Step 3: If any test fails, fix it before proceeding**

Most likely issue: system tests that look for specific elements by CSS class. Since we only add `hidden lg:block` to existing tables (not removing them), and Capybara runs at desktop width, tests should pass unchanged.

**Step 4: Commit any test fixes**

```bash
git commit -m "fix: update specs for RWD changes"
```

---

### Task 12: Manual Visual Verification

**Step 1: Start the dev server**

Run: `bin/rails server -p 8888`

**Step 2: Verify in Chrome DevTools mobile view**

Open `http://localhost:8888` in Chrome, use DevTools → Toggle Device Toolbar → iPhone 15 Pro (393×852).

Check each page:
- [ ] Login page — centered form
- [ ] Budget page — card layout, progress bars, summary cards
- [ ] Accounts index — full-width cards
- [ ] Account show — stacked header, transaction cards
- [ ] Reports — single column, smaller pie chart
- [ ] Category transactions — card layout, filter chips
- [ ] Quick entry — full-width form
- [ ] Settings hub — menu list with arrows
- [ ] Category management — full-width
- [ ] Quick entry mappings — full-width
- [ ] Bottom nav — 5 tabs, safe area padding

**Step 3: Fix any visual issues found**

**Step 4: Final commit if needed**
