# Kakebo UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fully rewrite all views with a modern card-based Linear-style UI using Indigo colors, Heroicons, sidebar layout, and Stimulus-powered interactions.

**Architecture:** Tailwind CSS v4 for styling; Stimulus controllers for drawer and toast notifications; Turbo Streams for transaction create without page reload; inline SVG Heroicons via Rails helper; BudgetEntries controller for inline budgeted editing.

**Tech Stack:** Rails 8.1.2, Tailwind CSS v4, Stimulus (importmap), Turbo Rails, Heroicons 2.x SVG inline

---

### Task 1: Heroicon helper

**Files:**
- Create: `app/helpers/icon_helper.rb`

**Step 1: Create the helper with all icons needed by this app**

```ruby
# app/helpers/icon_helper.rb
module IconHelper
  ICONS = {
    "chart-bar" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"/>',
    "credit-card" => '<path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"/>',
    "presentation-chart-line" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6"/>',
    "plus" => '<path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>',
    "trash" => '<path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>',
    "arrow-right-on-rectangle" => '<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75"/>',
    "chevron-left" => '<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/>',
    "chevron-right" => '<path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/>',
    "x-mark" => '<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>',
    "pencil-square" => '<path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"/>',
    "user" => '<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>',
    "check-circle" => '<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>',
    "exclamation-circle" => '<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>',
  }.freeze

  def icon(name, classes: "w-5 h-5")
    svg_content = ICONS[name]
    return "".html_safe unless svg_content
    content_tag(:svg, svg_content.html_safe,
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      "stroke-width": "1.5",
      stroke: "currentColor",
      class: classes,
      "aria-hidden": "true")
  end
end
```

**Step 2: Verify helper loads**

```bash
bin/rails runner "puts ApplicationController.helpers.respond_to?(:icon)"
```
Expected: `true`

**Step 3: Commit**

```bash
git add app/helpers/icon_helper.rb
git commit -m "feat: add Heroicon inline SVG helper"
```

---

### Task 2: Global layout — sidebar + bottom tab bar

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/shared/_nav.html.erb`

**Step 1: Rewrite `_nav.html.erb`**

```erb
<%# app/views/shared/_nav.html.erb %>
<%# Desktop sidebar %>
<aside class="hidden lg:fixed lg:inset-y-0 lg:left-0 lg:flex lg:w-60 lg:flex-col bg-white border-r border-slate-200 z-10">
  <div class="flex h-16 items-center px-6 border-b border-slate-100">
    <span class="text-indigo-600 font-bold text-lg tracking-tight">家計簿</span>
  </div>
  <nav class="flex-1 px-3 py-4 space-y-1">
    <%= link_to budget_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path == budget_path ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
      <%= icon "chart-bar", classes: "w-5 h-5 shrink-0" %>
      預算
    <% end %>
    <%= link_to accounts_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?(accounts_path) ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
      <%= icon "credit-card", classes: "w-5 h-5 shrink-0" %>
      帳戶
    <% end %>
    <%= link_to reports_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path == reports_path ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
      <%= icon "presentation-chart-line", classes: "w-5 h-5 shrink-0" %>
      報表
    <% end %>
  </nav>
  <div class="px-4 py-4 border-t border-slate-100">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2">
        <%= icon "user", classes: "w-4 h-4 text-slate-400" %>
        <span class="text-sm text-slate-600 truncate"><%= Current.user.name %></span>
      </div>
      <%= button_to session_path, method: :delete,
            class: "flex items-center gap-1 text-xs text-slate-400 hover:text-slate-600" do %>
        <%= icon "arrow-right-on-rectangle", classes: "w-4 h-4" %>
      <% end %>
    </div>
  </div>
</aside>

<%# Mobile bottom tab bar %>
<nav class="lg:hidden fixed bottom-0 inset-x-0 bg-white border-t border-slate-200 flex z-10">
  <%= link_to budget_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs #{request.path == budget_path ? 'text-indigo-600' : 'text-slate-500'}" do %>
    <%= icon "chart-bar", classes: "w-6 h-6" %>
    預算
  <% end %>
  <%= link_to accounts_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs #{request.path.start_with?(accounts_path) ? 'text-indigo-600' : 'text-slate-500'}" do %>
    <%= icon "credit-card", classes: "w-6 h-6" %>
    帳戶
  <% end %>
  <%= link_to reports_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs #{request.path == reports_path ? 'text-indigo-600' : 'text-slate-500'}" do %>
    <%= icon "presentation-chart-line", classes: "w-6 h-6" %>
    報表
  <% end %>
</nav>
```

**Step 2: Rewrite `application.html.erb`**

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "家計簿" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <link rel="icon" href="/icon.png" type="image/png">
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="bg-slate-50 min-h-screen">
    <% if Current.user %>
      <%= render "shared/nav" %>
    <% end %>

    <%# Toast notifications %>
    <div class="fixed top-4 right-4 z-50 space-y-2" id="toasts">
      <% if notice %>
        <div data-controller="notification"
             class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl px-4 py-3 shadow-lg text-sm text-slate-700">
          <%= icon "check-circle", classes: "w-5 h-5 text-emerald-500 shrink-0" %>
          <%= notice %>
        </div>
      <% end %>
      <% if alert %>
        <div data-controller="notification"
             class="flex items-center gap-3 bg-white border border-slate-200 rounded-xl px-4 py-3 shadow-lg text-sm text-slate-700">
          <%= icon "exclamation-circle", classes: "w-5 h-5 text-red-500 shrink-0" %>
          <%= alert %>
        </div>
      <% end %>
    </div>

    <%# Content area - offset for sidebar on desktop, add bottom padding for mobile tab bar %>
    <main class="<%= Current.user ? 'lg:pl-60 pb-20 lg:pb-0' : '' %>">
      <%= yield %>
    </main>
  </body>
</html>
```

**Step 3: Start CSS watcher (in a separate terminal) and verify layout renders**

```bash
bin/dev
```

Open `http://localhost:8888` — should see sidebar on desktop, bottom tabs on mobile.

**Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb app/views/shared/_nav.html.erb
git commit -m "feat: add sidebar layout with mobile bottom tab bar"
```

---

### Task 3: Toast notification Stimulus controller

**Files:**
- Create: `app/javascript/controllers/notification_controller.js`

**Step 1: Create the controller**

```js
// app/javascript/controllers/notification_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), 3000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 0.3s"
    setTimeout(() => this.element.remove(), 300)
  }
}
```

**Step 2: Verify it auto-loads (Stimulus eager-loads all controllers)**

Trigger a flash message (e.g., save a form) — notice/alert should disappear after 3 seconds.

**Step 3: Commit**

```bash
git add app/javascript/controllers/notification_controller.js
git commit -m "feat: add toast notification Stimulus controller"
```

---

### Task 4: Login page

**Files:**
- Modify: `app/views/sessions/new.html.erb`

**Step 1: Rewrite the view**

```erb
<div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-100 to-indigo-50 px-4">
  <div class="w-full max-w-sm">
    <div class="text-center mb-8">
      <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-indigo-600 mb-4">
        <span class="text-white text-2xl font-bold">家</span>
      </div>
      <h1 class="text-2xl font-bold text-slate-900">家計簿</h1>
      <p class="text-sm text-slate-500 mt-1">記錄每一筆金錢的流向</p>
    </div>

    <div class="bg-white rounded-2xl shadow-xl p-8">
      <%= form_with url: session_path, class: "space-y-5" do |f| %>
        <div>
          <%= f.label :email, "Email", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
          <%= f.email_field :email,
                class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
                placeholder: "your@email.com",
                required: true,
                autofocus: true %>
        </div>
        <div>
          <%= f.label :password, "密碼", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
          <%= f.password_field :password,
                class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
                placeholder: "••••••••",
                required: true %>
        </div>
        <%= f.submit "登入",
              class: "w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5 px-4 rounded-lg cursor-pointer transition-colors text-sm" %>
      <% end %>
    </div>
  </div>
</div>
```

**Step 2: Visual check**

Visit `http://localhost:8888/session/new` — should see centered card with gradient background.

**Step 3: Commit**

```bash
git add app/views/sessions/new.html.erb
git commit -m "feat: redesign login page with Indigo branding"
```

---

### Task 5: Budget page

**Files:**
- Modify: `app/views/budget/index.html.erb`

**Step 1: Rewrite the view**

```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
  <%# Month navigation %>
  <div class="flex items-center justify-between mb-6">
    <%= link_to budget_path(year: (@month == 1 ? @year - 1 : @year), month: (@month == 1 ? 12 : @month - 1)),
          class: "flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900 transition-colors" do %>
      <%= icon "chevron-left", classes: "w-4 h-4" %>
      上個月
    <% end %>
    <h1 class="text-lg font-semibold text-slate-900"><%= "#{@year} 年 #{@month} 月" %></h1>
    <%= link_to budget_path(year: (@month == 12 ? @year + 1 : @year), month: (@month == 12 ? 1 : @month + 1)),
          class: "flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900 transition-colors" do %>
      下個月
      <%= icon "chevron-right", classes: "w-4 h-4" %>
    <% end %>
  </div>

  <%# Ready to Assign hero card %>
  <div class="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-6 mb-6 text-white shadow-lg shadow-indigo-200">
    <p class="text-indigo-200 text-sm font-medium mb-1">Ready to Assign</p>
    <p class="text-4xl font-bold tracking-tight">
      <%= number_to_currency(@ready_to_assign, unit: "NT$", precision: 0) %>
    </p>
    <p class="text-indigo-300 text-xs mt-2">可分配給各類別的預算</p>
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
                <%= category.name %>
              </td>
              <td class="px-5 py-3 text-right text-sm text-slate-600">
                <%= number_to_currency(budgeted, unit: "NT$", precision: 0) %>
              </td>
              <td class="px-5 py-3 text-right text-sm <%= activity < 0 ? 'text-red-500' : 'text-slate-600' %>">
                <%= number_to_currency(activity, unit: "NT$", precision: 0) %>
              </td>
              <td class="px-5 py-3 text-right text-sm font-semibold <%= available < 0 ? 'text-red-600' : 'text-emerald-600' %>">
                <%= number_to_currency(available, unit: "NT$", precision: 0) %>
              </td>
            </tr>
          <% end %>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

**Step 2: Visual check**

Visit `http://localhost:8888/budget` — should see Indigo hero card and clean table.

**Step 3: Commit**

```bash
git add app/views/budget/index.html.erb
git commit -m "feat: redesign budget page with Indigo hero card and card table"
```

---

### Task 6: Accounts index page

**Files:**
- Modify: `app/views/accounts/index.html.erb`
- Modify: `app/views/accounts/_form.html.erb`
- Modify: `app/views/accounts/new.html.erb`
- Modify: `app/views/accounts/edit.html.erb`

**Step 1: Rewrite accounts index**

```erb
<%# app/views/accounts/index.html.erb %>
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-slate-900">帳戶</h1>
    <%= link_to new_account_path,
          class: "inline-flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors" do %>
      <%= icon "plus", classes: "w-4 h-4" %>
      新增帳戶
    <% end %>
  </div>

  <% total_budget = @budget_accounts.sum(&:balance) %>
  <% total_all = (@budget_accounts + @tracking_accounts).sum(&:balance) %>

  <% [["預算帳戶", @budget_accounts], ["追蹤帳戶", @tracking_accounts]].each do |label, accounts| %>
    <% next if accounts.empty? %>
    <div class="mb-6">
      <h2 class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3"><%= label %></h2>
      <div class="space-y-2">
        <% accounts.each do |account| %>
          <% pct = total_all > 0 ? (account.balance / total_all * 100).round : 0 %>
          <%= link_to account_path(account), class: "block bg-white rounded-xl border border-slate-100 px-5 py-4 hover:border-indigo-200 hover:shadow-sm transition-all" do %>
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-slate-800"><%= account.name %></span>
              <span class="text-base font-bold text-slate-900">
                <%= number_to_currency(account.balance, unit: "NT$", precision: 0) %>
              </span>
            </div>
            <div class="w-full bg-slate-100 rounded-full h-1.5">
              <div class="bg-indigo-500 h-1.5 rounded-full" style="width: <%= pct %>%"></div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

**Step 2: Rewrite `_form.html.erb`**

```erb
<%# app/views/accounts/_form.html.erb %>
<%= form_with model: account, class: "space-y-5" do |f| %>
  <div>
    <%= f.label :name, "帳戶名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <%= f.text_field :name,
          class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
          placeholder: "例：玉山銀行" %>
  </div>
  <div>
    <%= f.label :account_type, "類型", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <%= f.select :account_type,
          [["預算帳戶", "budget"], ["追蹤帳戶", "tracking"]],
          {},
          class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
  </div>
  <div>
    <%= f.label :starting_balance, "起始餘額", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <%= f.number_field :starting_balance,
          step: 1,
          class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent",
          placeholder: "0" %>
  </div>
  <div class="flex gap-3 pt-2">
    <%= f.submit account.new_record? ? "建立帳戶" : "更新帳戶",
          class: "flex-1 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5 rounded-lg cursor-pointer transition-colors text-sm" %>
    <%= link_to "取消", accounts_path, class: "flex-1 text-center bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold py-2.5 rounded-lg transition-colors text-sm" %>
  </div>
<% end %>
```

**Step 3: Rewrite `new.html.erb` and `edit.html.erb`**

```erb
<%# app/views/accounts/new.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <div class="mb-6">
    <%= link_to accounts_path, class: "inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900" do %>
      <%= icon "chevron-left", classes: "w-4 h-4" %>
      帳戶列表
    <% end %>
    <h1 class="text-xl font-bold text-slate-900 mt-2">新增帳戶</h1>
  </div>
  <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
    <%= render "form", account: @account %>
  </div>
</div>
```

```erb
<%# app/views/accounts/edit.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <div class="mb-6">
    <%= link_to account_path(@account), class: "inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900" do %>
      <%= icon "chevron-left", classes: "w-4 h-4" %>
      <%= @account.name %>
    <% end %>
    <h1 class="text-xl font-bold text-slate-900 mt-2">編輯帳戶</h1>
  </div>
  <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6">
    <%= render "form", account: @account %>
  </div>
</div>
```

**Step 4: Commit**

```bash
git add app/views/accounts/
git commit -m "feat: redesign accounts pages with card layout"
```

---

### Task 7: Slide-over Drawer Stimulus controller

**Files:**
- Create: `app/javascript/controllers/drawer_controller.js`

**Step 1: Create the controller**

```js
// app/javascript/controllers/drawer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    document.body.classList.remove("overflow-hidden")
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  connect() {
    this._escHandler = this.closeOnEsc.bind(this)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/drawer_controller.js
git commit -m "feat: add slide-over Drawer Stimulus controller"
```

---

### Task 8: Account show page with Drawer

**Files:**
- Modify: `app/views/accounts/show.html.erb`
- Create: `app/views/transactions/_form.html.erb`

**Step 1: Create transaction form partial**

```erb
<%# app/views/transactions/_form.html.erb %>
<%= form_with url: account_transactions_path(account),
      data: { turbo_stream: true } do |f| %>
  <div class="space-y-5">
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">日期</label>
      <%= f.date_field :date, value: Date.today,
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">類別</label>
      <%= f.select :category_id,
            options_for_select(
              Current.household.category_groups.includes(:categories).flat_map { |g|
                g.categories.map { |c| ["#{g.name} / #{c.name}", c.id] }
              }
            ),
            { include_blank: "收入（直接到 RTA）" },
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">金額</label>
      <%= f.number_field :amount, step: 1, placeholder: "支出填負數，例：-500",
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">備註</label>
      <%= f.text_field :memo, placeholder: "例：午餐",
            class: "block w-full rounded-lg border border-slate-300 px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" %>
    </div>
    <%= f.submit "新增交易",
          class: "w-full bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5 rounded-lg cursor-pointer transition-colors text-sm" %>
  </div>
<% end %>
```

**Step 2: Rewrite `accounts/show.html.erb`**

```erb
<%# app/views/accounts/show.html.erb %>
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8"
     data-controller="drawer">

  <%# Hero header %>
  <div class="flex items-start justify-between mb-6">
    <div>
      <%= link_to accounts_path, class: "inline-flex items-center gap-1 text-sm text-slate-400 hover:text-slate-700 mb-2" do %>
        <%= icon "chevron-left", classes: "w-4 h-4" %>
        帳戶
      <% end %>
      <h1 class="text-2xl font-bold text-slate-900"><%= @account.name %></h1>
      <span class="inline-block mt-1 text-xs font-medium px-2 py-0.5 rounded-full <%= @account.budget? ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-600' %>">
        <%= @account.budget? ? "預算帳戶" : "追蹤帳戶" %>
      </span>
    </div>
    <div class="text-right">
      <p class="text-3xl font-bold text-slate-900">
        <%= number_to_currency(@account.balance, unit: "NT$", precision: 0) %>
      </p>
      <div class="flex gap-2 mt-3">
        <%= link_to edit_account_path(@account),
              class: "inline-flex items-center gap-1.5 text-xs text-slate-500 hover:text-slate-900 border border-slate-200 rounded-lg px-3 py-1.5 transition-colors" do %>
          <%= icon "pencil-square", classes: "w-3.5 h-3.5" %>
          編輯
        <% end %>
        <button data-action="drawer#open"
                class="inline-flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-1.5 rounded-lg transition-colors">
          <%= icon "plus", classes: "w-4 h-4" %>
          新增交易
        </button>
      </div>
    </div>
  </div>

  <%# Transaction list %>
  <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden" id="transaction-list">
    <% if @transactions.empty? %>
      <div class="text-center py-16 text-slate-400">
        <p class="text-sm">還沒有交易紀錄</p>
        <p class="text-xs mt-1">點擊「新增交易」開始記帳</p>
      </div>
    <% else %>
      <table class="w-full">
        <thead>
          <tr class="border-b border-slate-100">
            <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">日期</th>
            <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">備註</th>
            <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">類別</th>
            <th class="text-right px-5 py-3 text-xs font-medium text-slate-400">金額</th>
            <th class="px-5 py-3"></th>
          </tr>
        </thead>
        <tbody>
          <% @transactions.each do |t| %>
            <%= render "transactions/row", transaction: t, account: @account %>
          <% end %>
        </tbody>
      </table>
    <% end %>
  </div>

  <%# Slide-over Drawer %>
  <div data-drawer-target="backdrop"
       class="fixed inset-0 bg-black/40 z-40 opacity-0 pointer-events-none transition-opacity duration-200"
       data-action="click->drawer#backdropClick">
  </div>
  <div data-drawer-target="panel"
       class="fixed inset-y-0 right-0 w-full sm:w-96 bg-white shadow-2xl z-50 translate-x-full transition-transform duration-300 ease-in-out flex flex-col">
    <div class="flex items-center justify-between px-5 py-4 border-b border-slate-100">
      <h2 class="text-base font-semibold text-slate-900">新增交易</h2>
      <button data-action="drawer#close" class="text-slate-400 hover:text-slate-700 transition-colors">
        <%= icon "x-mark", classes: "w-5 h-5" %>
      </button>
    </div>
    <div class="flex-1 overflow-y-auto px-5 py-5">
      <%= render "transactions/form", account: @account %>
    </div>
  </div>
</div>
```

**Step 3: Create transaction row partial (used by Turbo Stream too)**

```erb
<%# app/views/transactions/_row.html.erb %>
<tr class="border-t border-slate-50 hover:bg-slate-50 group transition-colors" id="<%= dom_id(transaction) %>">
  <td class="px-5 py-3 text-sm text-slate-500"><%= transaction.date.strftime("%m/%d") %></td>
  <td class="px-5 py-3 text-sm text-slate-800"><%= transaction.memo.presence || "─" %></td>
  <td class="px-5 py-3 text-sm text-slate-400"><%= transaction.category&.name || "收入" %></td>
  <td class="px-5 py-3 text-right text-sm font-medium <%= transaction.amount < 0 ? 'text-red-500' : 'text-emerald-600' %>">
    <%= number_to_currency(transaction.amount, unit: "NT$", precision: 0) %>
  </td>
  <td class="px-5 py-3 text-right">
    <%= button_to account_transaction_path(account, transaction),
          method: :delete,
          data: { turbo_confirm: "確定刪除這筆交易？" },
          class: "opacity-0 group-hover:opacity-100 transition-opacity text-slate-300 hover:text-red-500" do %>
      <%= icon "trash", classes: "w-4 h-4" %>
    <% end %>
  </td>
</tr>
```

**Step 4: Commit**

```bash
git add app/views/accounts/show.html.erb app/views/transactions/
git commit -m "feat: redesign account show with slide-over drawer"
```

---

### Task 9: Turbo Stream for transaction create

**Files:**
- Modify: `app/controllers/transactions_controller.rb`
- Create: `app/views/transactions/create.turbo_stream.erb`

**Step 1: Update TransactionsController to respond with Turbo Stream**

Add format response to `create`:

```ruby
def create
  @transaction = @account.transactions.build(transaction_params)
  if @transaction.save
    @account.recalculate_balance!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_path(@account), notice: "交易已新增" }
    end
  else
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { message: "請填寫必要欄位", type: :alert }) }
      format.html { redirect_to account_path(@account), alert: "請填寫必要欄位" }
    end
  end
end
```

**Step 2: Create the Turbo Stream template**

```erb
<%# app/views/transactions/create.turbo_stream.erb %>
<%= turbo_stream.prepend "transaction-list tbody" do %>
  <%= render "transactions/row", transaction: @transaction, account: @account %>
<% end %>
```

Note: The drawer is closed via the form submission response—add a Stimulus action on `turbo:submit-end` to close if successful. Update the form partial's `form_with` to add:

```erb
<%= form_with url: account_transactions_path(account),
      data: { turbo_stream: true, action: "turbo:submit-end->drawer#close" } do |f| %>
```

**Step 3: Verify**

1. Open account show page
2. Click「新增交易」— drawer slides in
3. Fill form and submit
4. Transaction appears at top of list without page reload
5. Drawer closes automatically

**Step 4: Commit**

```bash
git add app/controllers/transactions_controller.rb app/views/transactions/create.turbo_stream.erb app/views/transactions/_form.html.erb
git commit -m "feat: add Turbo Stream for transaction create with drawer auto-close"
```

---

### Task 10: Reports page with CSS pie chart

**Files:**
- Modify: `app/views/reports/index.html.erb`

**Step 1: Rewrite the view**

```erb
<div class="max-w-4xl mx-auto px-4 sm:px-6 py-8">
  <%# Month navigation %>
  <div class="flex items-center justify-between mb-6">
    <%= link_to reports_path(year: (@month == 1 ? @year - 1 : @year), month: (@month == 1 ? 12 : @month - 1)),
          class: "flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900" do %>
      <%= icon "chevron-left", classes: "w-4 h-4" %>
      上個月
    <% end %>
    <h1 class="text-lg font-semibold text-slate-900"><%= "#{@year} 年 #{@month} 月 報表" %></h1>
    <%= link_to reports_path(year: (@month == 12 ? @year + 1 : @year), month: (@month == 12 ? 1 : @month + 1)),
          class: "flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900" do %>
      下個月
      <%= icon "chevron-right", classes: "w-4 h-4" %>
    <% end %>
  </div>

  <% total = @spending_by_category.sum { |_, v| v } %>

  <% if @spending_by_category.empty? %>
    <div class="bg-white rounded-2xl border border-slate-100 p-16 text-center text-slate-400">
      <p class="text-sm">本月尚無支出紀錄</p>
    </div>
  <% else %>
    <%# CSS conic-gradient pie chart %>
    <%
      palette = %w[#6366f1 #8b5cf6 #ec4899 #f43f5e #f97316 #eab308 #22c55e #14b8a6 #0ea5e9]
      categories_with_color = @spending_by_category.each_with_index.map { |(name, amt), i| [name, amt, palette[i % palette.size]] }
      segments = categories_with_color.reduce([]) do |acc, (name, amt, color)|
        start = acc.empty? ? 0 : acc.last[:end]
        pct = total > 0 ? (amt / total * 100.0) : 0
        acc + [{ name: name, amt: amt, color: color, start: start, end: start + pct }]
      end
      conic = segments.map { |s| "#{s[:color]} #{s[:start].round(1)}% #{s[:end].round(1)}%" }.join(", ")
    %>
    <div class="grid lg:grid-cols-2 gap-6">
      <%# Pie chart %>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 flex flex-col items-center justify-center">
        <div class="w-48 h-48 rounded-full mb-6" style="background: conic-gradient(<%= conic %>)"></div>
        <div class="w-full space-y-2">
          <% segments.each do |s| %>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full shrink-0" style="background: <%= s[:color] %>"></div>
              <span class="text-xs text-slate-600 flex-1 truncate"><%= s[:name] %></span>
              <span class="text-xs font-medium text-slate-800">
                <%= total > 0 ? "#{(s[:amt] / total * 100).round}%" : "0%" %>
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <%# Category breakdown %>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
        <div class="px-5 py-4 border-b border-slate-100">
          <h2 class="text-sm font-semibold text-slate-700">各類別支出</h2>
        </div>
        <div class="divide-y divide-slate-50">
          <% segments.each do |s| %>
            <div class="px-5 py-3 flex items-center gap-3">
              <div class="w-2.5 h-2.5 rounded-full shrink-0" style="background: <%= s[:color] %>"></div>
              <span class="text-sm text-slate-700 flex-1 truncate"><%= s[:name] %></span>
              <span class="text-sm font-semibold text-slate-900">
                <%= number_to_currency(s[:amt], unit: "NT$", precision: 0) %>
              </span>
            </div>
          <% end %>
          <div class="px-5 py-3 flex items-center justify-between bg-slate-50">
            <span class="text-sm font-semibold text-slate-700">總計</span>
            <span class="text-sm font-bold text-slate-900">
              <%= number_to_currency(total, unit: "NT$", precision: 0) %>
            </span>
          </div>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

**Step 2: Add month param to ReportsController** (currently doesn't read `month` from params for navigation links — verify it does, no change needed since it already reads `params[:month]`)

**Step 3: Commit**

```bash
git add app/views/reports/index.html.erb
git commit -m "feat: redesign reports page with CSS conic-gradient pie chart"
```

---

### Task 11: Run full test suite and cleanup

**Step 1: Run tests**

```bash
bundle exec rspec
```

Expected: 31 examples, 0 failures

**Step 2: Remove unused hello_controller.js**

```bash
rm app/javascript/controllers/hello_controller.js
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: remove unused hello_controller"
```
