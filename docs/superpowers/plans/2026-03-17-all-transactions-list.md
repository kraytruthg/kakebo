# All Transactions List Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a global transaction list page at `/transactions` with filtering and pagination, and upgrade the account detail page to use the same shared components.

**Architecture:** New `TransactionListsController#index` with shared partials (`_transaction_filters`, `_transaction_table`, `_transaction_cards`) reused by `AccountsController#show`. GET-param filtering (account, category, date range, memo ILIKE search) with Pagy pagination. Desktop sidebar gets a new "交易" nav item; mobile accesses via accounts page link.

**Tech Stack:** Rails 8.1, Hotwire, Tailwind CSS v4, Pagy, PostgreSQL ILIKE, RSpec + Capybara

**Spec:** `docs/superpowers/specs/2026-03-17-all-transactions-list-design.md`

---

## Chunk 1: Model + Route + Controller with Request Specs

### Task 1: Add Household#transactions association

**Files:**
- Modify: `app/models/household.rb:4` (after `has_many :accounts`)
- Test: `spec/models/household_spec.rb` (create if needed)

- [ ] **Step 1: Write the failing test**

Create `spec/models/household_spec.rb` (if it already exists, add the describe block inside the existing `RSpec.describe`):

```ruby
require "rails_helper"

RSpec.describe Household, type: :model do
  describe "#transactions" do
    let(:household) { create(:household) }
    let!(:account) { create(:account, household: household) }
    let(:category_group) { create(:category_group, household: household) }
    let(:category) { create(:category, category_group: category_group) }
    let!(:txn) { create(:transaction, account: account, category: category, amount: -500, date: Date.today) }

    it "returns transactions through accounts" do
      expect(household.transactions).to include(txn)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/household_spec.rb -v`
Expected: FAIL with `undefined method 'transactions'`

- [ ] **Step 3: Write minimal implementation**

In `app/models/household.rb`, add after line 4 (`has_many :accounts, dependent: :destroy`):

```ruby
has_many :transactions, through: :accounts
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/household_spec.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/household.rb spec/models/household_spec.rb
git commit -m "feat: add Household#transactions through association"
```

---

### Task 2: Add route and TransactionListsController

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/transaction_lists_controller.rb`
- Create: `app/views/transaction_lists/index.html.erb` (minimal placeholder)
- Test: `spec/requests/transaction_lists_spec.rb`

- [ ] **Step 1: Write the failing request spec — authentication & basic index**

Create `spec/requests/transaction_lists_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Transaction Lists", type: :request do
  let(:household) { create(:household) }
  let(:user) { create(:user, household: household) }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  describe "GET /transactions" do
    context "when not logged in" do
      it "redirects to login" do
        get "/transactions"
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { post session_path, params: { email: user.email, password: "password123" } }

      it "returns success" do
        get "/transactions"
        expect(response).to have_http_status(:success)
      end

      it "shows transactions from current household" do
        txn = create(:transaction, account: account, category: category, amount: -500, date: Date.today, memo: "Lunch")
        get "/transactions"
        expect(response.body).to include("Lunch")
      end

      it "does not show transactions from other households" do
        other_household = create(:household)
        other_account = create(:account, household: other_household)
        other_group = create(:category_group, household: other_household)
        other_cat = create(:category, category_group: other_group)
        create(:transaction, account: other_account, category: other_cat, memo: "Secret")
        get "/transactions"
        expect(response.body).not_to include("Secret")
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: FAIL with routing error

- [ ] **Step 3: Add route**

In `config/routes.rb`, add after the `resources :accounts` block (after line 13):

```ruby
resources :transaction_lists, only: [:index], path: "transactions"
```

- [ ] **Step 4: Create controller**

Create `app/controllers/transaction_lists_controller.rb` (without filtering for now — filters added in Task 3):

```ruby
class TransactionListsController < ApplicationController
  def index
    scope = Current.household.transactions
              .includes(:category, :account, transfer_pair: :account)
              .recent

    @pagy, @transactions = pagy(scope)
    @accounts = Current.household.accounts.active.order(:name)
    @categories = Current.household.category_groups.includes(:categories).order(:position)
    @total_count = Current.household.transactions.count
  end
end
```

- [ ] **Step 5: Create minimal view placeholder**

Create `app/views/transaction_lists/index.html.erb`:

```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">交易紀錄</h1>
  <% @transactions.each do |t| %>
    <div><%= t.memo %> <%= format_amount(t.amount) %></div>
  <% end %>
</div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: All 3 tests PASS

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/transaction_lists_controller.rb app/views/transaction_lists/index.html.erb spec/requests/transaction_lists_spec.rb
git commit -m "feat: add TransactionListsController with route and basic request specs"
```

---

### Task 3: Filter request specs

**Files:**
- Modify: `spec/requests/transaction_lists_spec.rb`

- [ ] **Step 1: Add filter specs**

Append inside the `"when logged in"` context in `spec/requests/transaction_lists_spec.rb`:

```ruby
      describe "filtering" do
        let!(:account2) { create(:account, household: household, name: "Credit Card") }
        let(:category2) { create(:category, category_group: category_group, name: "Transport") }
        let!(:txn_food) { create(:transaction, account: account, category: category, amount: -300, date: Date.new(2026, 3, 1), memo: "Lunch") }
        let!(:txn_transport) { create(:transaction, account: account2, category: category2, amount: -1500, date: Date.new(2026, 3, 10), memo: "Train") }
        let!(:txn_income) { create(:transaction, account: account, category: nil, amount: 50_000, date: Date.new(2026, 3, 15), memo: "Salary") }

        it "filters by account_id" do
          get "/transactions", params: { account_id: account.id }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters by category_id" do
          get "/transactions", params: { category_id: category.id }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters income transactions" do
          get "/transactions", params: { category_id: "income" }
          expect(response.body).to include("Salary")
          expect(response.body).not_to include("Lunch")
        end

        it "filters by date_from only" do
          get "/transactions", params: { date_from: "2026-03-05" }
          expect(response.body).to include("Train")
          expect(response.body).to include("Salary")
          expect(response.body).not_to include("Lunch")
        end

        it "filters by date_to only" do
          get "/transactions", params: { date_to: "2026-03-05" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "filters by date range" do
          get "/transactions", params: { date_from: "2026-03-05", date_to: "2026-03-12" }
          expect(response.body).to include("Train")
          expect(response.body).not_to include("Lunch")
          expect(response.body).not_to include("Salary")
        end

        it "filters by memo query" do
          get "/transactions", params: { query: "lunch" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
        end

        it "escapes ILIKE special characters in query" do
          create(:transaction, account: account, category: category, amount: -100, date: Date.today, memo: "100% off")
          get "/transactions", params: { query: "100%" }
          expect(response.body).to include("100% off")
        end

        it "combines multiple filters" do
          get "/transactions", params: { account_id: account.id, category_id: category.id, date_from: "2026-03-01", date_to: "2026-03-05" }
          expect(response.body).to include("Lunch")
          expect(response.body).not_to include("Train")
          expect(response.body).not_to include("Salary")
        end
      end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: Filter tests FAIL (controller has no filtering logic yet)

- [ ] **Step 3: Create TransactionFilterable concern and update controller**

Create `app/controllers/concerns/transaction_filterable.rb`:

```ruby
module TransactionFilterable
  extend ActiveSupport::Concern

  private

  def apply_transaction_filters(scope)
    scope = scope.where(account_id: params[:account_id]) if params[:account_id].present?

    if params[:category_id] == "income"
      scope = scope.where(category_id: nil).where(transfer_pair_id: nil)
    elsif params[:category_id].present?
      scope = scope.where(category_id: params[:category_id])
    end

    scope = scope.where("date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("date <= ?", params[:date_to]) if params[:date_to].present?

    if params[:query].present?
      sanitized = ActiveRecord::Base.sanitize_sql_like(params[:query])
      scope = scope.where("memo ILIKE ?", "%#{sanitized}%")
    end

    scope
  end
end
```

Update `app/controllers/transaction_lists_controller.rb`:

```ruby
class TransactionListsController < ApplicationController
  include TransactionFilterable

  def index
    scope = Current.household.transactions
              .includes(:category, :account, transfer_pair: :account)
              .recent

    scope = apply_transaction_filters(scope)

    @pagy, @transactions = pagy(scope)
    @accounts = Current.household.accounts.active.order(:name)
    @categories = Current.household.category_groups.includes(:categories).order(:position)
    @total_count = Current.household.transactions.count
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/concerns/transaction_filterable.rb app/controllers/transaction_lists_controller.rb spec/requests/transaction_lists_spec.rb
git commit -m "feat: add filtering to TransactionListsController with request specs"
```

---

### Task 4: Pagination request spec

**Files:**
- Modify: `spec/requests/transaction_lists_spec.rb`

- [ ] **Step 1: Add pagination spec**

Append inside the `"when logged in"` context:

```ruby
      describe "pagination" do
        it "paginates results — first page has 30 items, not all 31" do
          31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
          get "/transactions"
          # First page should have 30 transactions, not all 31
          expect(response.body.scan(/txn\d+/).uniq.size).to eq(30)
        end

        it "second page shows remaining items" do
          31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
          get "/transactions", params: { page: 2 }
          expect(response.body.scan(/txn\d+/).uniq.size).to eq(1)
        end
      end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: PASS (pagination works via Pagy in controller, view renders memo text)

- [ ] **Step 3: Commit**

```bash
git add spec/requests/transaction_lists_spec.rb
git commit -m "test: add pagination request spec for transaction lists"
```

---

## Chunk 2: Shared Partials + Full Views

### Task 5: Extract shared transaction filter partial

**Files:**
- Create: `app/views/shared/_transaction_filters.html.erb`

- [ ] **Step 1: Create the filter partial**

Create `app/views/shared/_transaction_filters.html.erb`:

```erb
<%# locals: (filter_url:, accounts:, categories:, show_account_filter: true) %>
<%= form_with url: filter_url, method: :get, data: { turbo: false } do |f| %>
  <%# Desktop filters %>
  <div class="hidden lg:flex flex-wrap gap-3 mb-5 items-center">
    <% if show_account_filter %>
      <%= f.select :account_id,
            options_from_collection_for_select(accounts, :id, :name, params[:account_id]&.to_i),
            { include_blank: "所有帳戶" },
            class: "rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    <% end %>
    <%= f.select :category_id,
          grouped_options_for_select(
            categories.map { |g| [g.name, g.categories.map { |c| [c.name, c.id.to_s] }] } + [["", [["收入", "income"]]]],
            params[:category_id]
          ),
          { include_blank: "所有類別" },
          class: "rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    <%= f.date_field :date_from, value: params[:date_from],
          class: "rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500",
          placeholder: "開始日期" %>
    <span class="text-slate-400 text-sm">~</span>
    <%= f.date_field :date_to, value: params[:date_to],
          class: "rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500",
          placeholder: "結束日期" %>
    <div class="flex-1 min-w-[180px]">
      <%= f.search_field :query, value: params[:query],
            placeholder: "搜尋備註...",
            class: "w-full rounded-lg border border-slate-200 px-3 py-1.5 text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>
    <%= f.submit "篩選", class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-1.5 rounded-lg cursor-pointer transition-colors" %>
    <% if params[:account_id].present? || params[:category_id].present? || params[:date_from].present? || params[:date_to].present? || params[:query].present? %>
      <%= link_to "清除", filter_url, class: "text-sm text-slate-400 hover:text-slate-600" %>
    <% end %>
  </div>

  <%# Mobile filters %>
  <div class="lg:hidden flex flex-wrap gap-2 mb-4 px-0">
    <% if show_account_filter %>
      <%= f.select :account_id,
            options_from_collection_for_select(accounts, :id, :name, params[:account_id]&.to_i),
            { include_blank: "所有帳戶" },
            class: "rounded-full border border-slate-200 px-3 py-1.5 text-xs text-slate-600" %>
    <% end %>
    <%= f.select :category_id,
          grouped_options_for_select(
            categories.map { |g| [g.name, g.categories.map { |c| [c.name, c.id.to_s] }] } + [["", [["收入", "income"]]]],
            params[:category_id]
          ),
          { include_blank: "所有類別" },
          class: "rounded-full border border-slate-200 px-3 py-1.5 text-xs text-slate-600" %>
    <%= f.date_field :date_from, value: params[:date_from],
          class: "rounded-full border border-slate-200 px-3 py-1.5 text-xs text-slate-600 w-[130px]" %>
    <%= f.date_field :date_to, value: params[:date_to],
          class: "rounded-full border border-slate-200 px-3 py-1.5 text-xs text-slate-600 w-[130px]" %>
    <%= f.search_field :query, value: params[:query],
          placeholder: "搜尋備註...",
          class: "flex-1 min-w-[120px] rounded-full border border-slate-200 px-3 py-1.5 text-xs text-slate-600" %>
    <%= f.submit "篩選", class: "bg-indigo-600 text-white text-xs font-medium px-3 py-1.5 rounded-full cursor-pointer" %>
    <% if params[:account_id].present? || params[:category_id].present? || params[:date_from].present? || params[:date_to].present? || params[:query].present? %>
      <%= link_to "清除", filter_url, class: "text-xs text-slate-400 hover:text-slate-600 py-1.5" %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/shared/_transaction_filters.html.erb
git commit -m "feat: add shared transaction filters partial"
```

---

### Task 6: Extract shared transaction table and cards partials

**Files:**
- Create: `app/views/shared/_transaction_table.html.erb`
- Create: `app/views/shared/_transaction_cards.html.erb`

- [ ] **Step 1: Create the desktop table partial**

Create `app/views/shared/_transaction_table.html.erb`.

Important: The account show page's Turbo Stream (`create.turbo_stream.erb`) targets `id="transactions-tbody"` and `id="transactions-empty"`. The shared partial must preserve these IDs via parameters so Turbo Stream keeps working.

```erb
<%# locals: (transactions:, show_account_column: true, tbody_id: nil, empty_row_id: nil, empty_message: "沒有符合條件的交易紀錄") %>
<div class="hidden lg:block bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
  <table class="w-full">
    <thead>
      <tr class="border-b border-slate-100">
        <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">日期</th>
        <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">備註</th>
        <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">類別</th>
        <% if show_account_column %>
          <th class="text-left px-5 py-3 text-xs font-medium text-slate-400">帳戶</th>
        <% end %>
        <th class="text-right px-5 py-3 text-xs font-medium text-slate-400">金額</th>
        <th class="px-5 py-3"></th>
      </tr>
    </thead>
    <tbody id="<%= tbody_id %>">
      <% if transactions.empty? %>
        <tr id="<%= empty_row_id %>">
          <td colspan="<%= show_account_column ? 6 : 5 %>" class="text-center py-16 text-slate-400">
            <p class="text-sm"><%= empty_message %></p>
          </td>
        </tr>
      <% else %>
        <% transactions.each do |t| %>
          <tr class="border-t border-slate-50 hover:bg-slate-50 group transition-colors <%= 'bg-purple-50/50' if t.transfer? %>"
              id="transaction-<%= t.id %>">
            <td class="px-5 py-3 text-sm text-slate-500"><%= t.date.strftime("%Y/%m/%d") %></td>
            <td class="px-5 py-3 text-sm text-slate-800"><%= t.memo.presence || "─" %></td>
            <td class="px-5 py-3 text-sm text-slate-400">
              <% if t.transfer? %>
                <% partner_name = t.transfer_pair.account.name %>
                <span class="text-purple-600"><%= t.amount < 0 ? "轉出 → #{partner_name}" : "轉入 ← #{partner_name}" %></span>
              <% elsif t.income? %>
                <span class="italic">收入</span>
              <% else %>
                <%= t.category&.name %>
              <% end %>
            </td>
            <% if show_account_column %>
              <td class="px-5 py-3 text-sm text-slate-400"><%= t.account.name %></td>
            <% end %>
            <td class="px-5 py-3 text-right text-sm font-medium <%= t.amount < 0 ? 'text-red-500' : 'text-emerald-600' %>">
              <%= format_amount(t.amount) %>
            </td>
            <td class="px-5 py-3">
              <div class="flex items-center gap-2 justify-end">
                <% unless t.transfer? %>
                  <%= link_to "編輯", edit_account_transaction_path(t.account, t),
                      class: "opacity-0 group-hover:opacity-100 transition-opacity text-sm text-blue-500 hover:text-blue-700" %>
                <% end %>
                <% if t.transfer? %>
                  <%= button_to transfer_path(t),
                        method: :delete,
                        data: { turbo_confirm: "確定刪除這筆轉帳？兩個帳戶的對應紀錄都會一併刪除。" },
                        class: "opacity-0 group-hover:opacity-100 transition-opacity text-slate-300 hover:text-red-500",
                        aria: { label: "刪除交易" } do %>
                    <%= icon "trash", classes: "w-4 h-4" %>
                  <% end %>
                <% else %>
                  <%= button_to account_transaction_path(t.account, t),
                        method: :delete,
                        data: { turbo_confirm: "確定刪除這筆交易？" },
                        class: "opacity-0 group-hover:opacity-100 transition-opacity text-slate-300 hover:text-red-500",
                        aria: { label: "刪除交易" } do %>
                    <%= icon "trash", classes: "w-4 h-4" %>
                  <% end %>
                <% end %>
              </div>
            </td>
          </tr>
        <% end %>
      <% end %>
    </tbody>
  </table>
</div>
```

- [ ] **Step 2: Create the mobile cards partial**

Create `app/views/shared/_transaction_cards.html.erb`:

```erb
<%# locals: (transactions:, show_account_name: true, empty_message: "沒有符合條件的交易紀錄") %>
<div class="lg:hidden space-y-2">
  <% if transactions.empty? %>
    <div class="bg-white rounded-xl border border-slate-100 py-12 text-center text-slate-400">
      <p class="text-sm"><%= empty_message %></p>
    </div>
  <% else %>
    <% transactions.each do |t| %>
      <div class="<%= t.transfer? ? 'bg-purple-50/50 border-purple-100' : 'bg-white border-slate-100' %> rounded-xl border px-4 py-3"
           id="transaction-mobile-<%= t.id %>">
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="text-xs text-slate-400"><%= t.date.strftime("%m/%d") %></span>
              <span class="text-sm text-slate-800 truncate"><%= t.memo.presence || "─" %></span>
            </div>
            <p class="text-xs text-slate-400 mt-0.5">
              <% if t.transfer? %>
                <% partner_name = t.transfer_pair.account.name %>
                <span class="text-purple-600"><%= t.amount < 0 ? "轉出 → #{partner_name}" : "轉入 ← #{partner_name}" %></span>
              <% elsif t.income? %>
                <span class="italic">收入</span><%= " · #{t.account.name}" if show_account_name %>
              <% else %>
                <%= t.category&.name %><%= " · #{t.account.name}" if show_account_name %>
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

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_transaction_table.html.erb app/views/shared/_transaction_cards.html.erb
git commit -m "feat: add shared transaction table and cards partials"
```

---

### Task 7: Build the full transaction lists index view

**Files:**
- Modify: `app/views/transaction_lists/index.html.erb`

- [ ] **Step 1: Replace placeholder with full view**

Overwrite `app/views/transaction_lists/index.html.erb`:

```erb
<div class="px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8">
  <div class="mb-6">
    <h1 class="text-xl lg:text-2xl font-bold text-slate-900">交易紀錄</h1>
    <span class="text-xs text-slate-400">共 <%= @total_count %> 筆</span>
  </div>

  <%= render "shared/transaction_filters",
        filter_url: transaction_lists_path,
        accounts: @accounts,
        categories: @categories,
        show_account_filter: true %>

  <%= render "shared/transaction_table",
        transactions: @transactions,
        show_account_column: true %>

  <%= render "shared/transaction_cards",
        transactions: @transactions,
        show_account_name: true %>

  <% if @pagy.pages > 1 %>
    <nav class="mt-6 flex justify-center">
      <%== @pagy.series_nav %>
    </nav>
  <% end %>
</div>
```

- [ ] **Step 2: Run request specs to verify everything still passes**

Run: `bundle exec rspec spec/requests/transaction_lists_spec.rb -v`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add app/views/transaction_lists/index.html.erb
git commit -m "feat: build full transaction lists index view with shared partials"
```

---

### Task 8: Add sidebar and mobile navigation

**Files:**
- Modify: `app/views/shared/_nav.html.erb`
- Modify: `app/views/accounts/index.html.erb`

- [ ] **Step 1: Add "交易" to desktop sidebar**

In `app/views/shared/_nav.html.erb`, add after the 帳戶 link (after line 46, the `<% end %>` closing the accounts link):

```erb
    <%= link_to transaction_lists_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?('/transactions') ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
      <%= icon "list-bullet", classes: "w-5 h-5 shrink-0" %>
      交易
    <% end %>
```

- [ ] **Step 2: Add "所有交易" link to accounts index page**

In `app/views/accounts/index.html.erb`, add after the `<h1>` and before the `新增帳戶` button. Replace the header div (lines 2-9):

```erb
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-slate-900">帳戶</h1>
    <div class="flex items-center gap-2">
      <%= link_to transaction_lists_path,
            class: "inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-900 border border-slate-200 rounded-lg px-3 py-2 transition-colors" do %>
        <%= icon "list-bullet", classes: "w-4 h-4" %>
        所有交易
      <% end %>
      <%= link_to new_account_path,
            class: "inline-flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors" do %>
        <%= icon "plus", classes: "w-4 h-4" %>
        新增帳戶
      <% end %>
    </div>
  </div>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_nav.html.erb app/views/accounts/index.html.erb
git commit -m "feat: add transaction list navigation in sidebar and accounts page"
```

---

## Chunk 3: Account Page Upgrade

### Task 9: Upgrade AccountsController#show with pagination and filtering

**Files:**
- Modify: `app/controllers/accounts_controller.rb`
- Modify: `app/views/accounts/show.html.erb`

- [ ] **Step 1: Write request spec for account page pagination**

Create `spec/requests/accounts_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:household) { create(:household) }
  let(:user) { create(:user, household: household) }
  let!(:account) { create(:account, household: household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group) }

  before { post session_path, params: { email: user.email, password: "password123" } }

  describe "GET /accounts/:id" do
    it "returns success with pagination" do
      31.times { |i| create(:transaction, account: account, category: category, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
      get account_path(account)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("pagy")
    end

    it "filters by category" do
      cat2 = create(:category, category_group: category_group, name: "Transport")
      create(:transaction, account: account, category: category, amount: -300, date: Date.today, memo: "Food")
      create(:transaction, account: account, category: cat2, amount: -500, date: Date.today, memo: "Train")
      get account_path(account), params: { category_id: category.id }
      expect(response.body).to include("Food")
      expect(response.body).not_to include("Train")
    end

    it "filters by memo query" do
      create(:transaction, account: account, category: category, amount: -300, date: Date.today, memo: "Lunch at cafe")
      create(:transaction, account: account, category: category, amount: -500, date: Date.today, memo: "Dinner")
      get account_path(account), params: { query: "lunch" }
      expect(response.body).to include("Lunch at cafe")
      expect(response.body).not_to include("Dinner")
    end

    it "filters by date range" do
      create(:transaction, account: account, category: category, amount: -300, date: Date.new(2026, 3, 1), memo: "Early")
      create(:transaction, account: account, category: category, amount: -500, date: Date.new(2026, 3, 15), memo: "Late")
      get account_path(account), params: { date_from: "2026-03-10" }
      expect(response.body).to include("Late")
      expect(response.body).not_to include("Early")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/accounts_spec.rb -v`
Expected: FAIL (no pagination yet, filter params not handled)

- [ ] **Step 3: Update AccountsController#show**

Add `include TransactionFilterable` at the top of `app/controllers/accounts_controller.rb` (line 2), then replace the `show` method:

```ruby
class AccountsController < ApplicationController
  include TransactionFilterable

  # ... existing before_action ...

  def show
    @transaction_count = @account.transactions.count
    scope = @account.transactions
              .includes(:category, transfer_pair: :account)
              .recent

    scope = apply_transaction_filters(scope)

    @pagy, @transactions = pagy(scope)
    @categories = Current.household.category_groups.includes(:categories).order(:position)
    @new_transaction = Transaction.new(account: @account, date: Date.today)
  end
```

The `account_id` filter param won't be present on the account page (filter partial hides it), so it's harmless that the concern includes it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/accounts_spec.rb -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/accounts_controller.rb spec/requests/accounts_spec.rb
git commit -m "feat: add pagination and filtering to AccountsController#show"
```

---

### Task 10: Update account show view to use shared partials

**Files:**
- Modify: `app/views/accounts/show.html.erb`

- [ ] **Step 1: Replace transaction list section with shared partials**

Replace the mobile transaction cards section (lines 48-80) and the desktop transaction table section (lines 82-109) in `app/views/accounts/show.html.erb` with:

```erb
  <%= render "shared/transaction_filters",
        filter_url: account_path(@account),
        accounts: [],
        categories: @categories,
        show_account_filter: false %>

  <%= render "shared/transaction_table",
        transactions: @transactions,
        show_account_column: false,
        tbody_id: "transactions-tbody",
        empty_row_id: "transactions-empty",
        empty_message: "還沒有交易紀錄" %>

  <%= render "shared/transaction_cards",
        transactions: @transactions,
        show_account_name: false,
        empty_message: "還沒有交易紀錄" %>

  <% if @pagy.pages > 1 %>
    <nav class="mt-6 flex justify-center">
      <%== @pagy.series_nav %>
    </nav>
  <% end %>
```

Important: `tbody_id: "transactions-tbody"` and `empty_row_id: "transactions-empty"` preserve the DOM IDs that `create.turbo_stream.erb` targets for Turbo Stream prepend/remove when adding new transactions via the drawer.

Keep the drawer section (lines 111-132) unchanged.

- [ ] **Step 2: Run existing account system specs to verify nothing breaks**

Run: `bundle exec rspec spec/system/accounts_spec.rb spec/system/transactions_spec.rb -v`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add app/views/accounts/show.html.erb
git commit -m "refactor: use shared partials for account show transaction list"
```

---

## Chunk 4: System Specs

### Task 11: System specs for global transaction list (desktop)

**Files:**
- Create: `spec/system/transaction_lists_spec.rb`

- [ ] **Step 1: Write desktop system specs**

Create `spec/system/transaction_lists_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Transaction Lists", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.households.first }
  let!(:account1) { create(:account, household: household, name: "現金") }
  let!(:account2) { create(:account, household: household, name: "信用卡") }
  let!(:group) { create(:category_group, household: household, name: "生活") }
  let!(:category1) { create(:category, category_group: group, name: "食費") }
  let!(:category2) { create(:category, category_group: group, name: "交通") }
  let!(:txn_food) do
    create(:transaction, account: account1, category: category1,
           amount: -300, date: Date.new(2026, 3, 5), memo: "午餐")
  end
  let!(:txn_transport) do
    create(:transaction, account: account2, category: category2,
           amount: -1500, date: Date.new(2026, 3, 10), memo: "電車")
  end
  let!(:txn_income) do
    create(:transaction, account: account1, category: nil,
           amount: 50_000, date: Date.new(2026, 3, 15), memo: "薪水")
  end

  before { sign_in(user) }

  describe "桌面版", js: true do
    it "從側邊欄進入交易列表" do
      visit budget_path
      within("aside") do
        click_link "交易"
      end
      expect(page).to have_text("交易紀錄")
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
      expect(page).to have_text("薪水")
    end

    it "篩選帳戶" do
      visit transaction_lists_path
      select "現金", from: "account_id"
      click_button "篩選"
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "篩選類別" do
      visit transaction_lists_path
      select "食費", from: "category_id"
      click_button "篩選"
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
      expect(page).not_to have_text("薪水")
    end

    it "搜尋備註" do
      visit transaction_lists_path
      fill_in "query", with: "午餐"
      click_button "篩選"
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "日期範圍篩選" do
      visit transaction_lists_path
      fill_in "date_from", with: "2026-03-08"
      fill_in "date_to", with: "2026-03-12"
      click_button "篩選"
      expect(page).to have_text("電車")
      expect(page).not_to have_text("午餐")
      expect(page).not_to have_text("薪水")
    end

    it "清除篩選" do
      visit transaction_lists_path(account_id: account1.id)
      click_link "清除"
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
    end

    it "分頁導航" do
      31.times do |i|
        create(:transaction, account: account1, category: category1,
               amount: -100, date: Date.new(2026, 3, 1) + i.days, memo: "交易#{i}")
      end
      visit transaction_lists_path
      expect(page).to have_css("nav.pagy")
    end

    it "刪除交易" do
      visit transaction_lists_path
      accept_confirm do
        within("#transaction-#{txn_food.id}") do
          find("button[aria-label='刪除交易']", visible: false).click
        end
      end
      expect(page).not_to have_text("午餐")
      expect(page).to have_text("電車")
    end
  end

  describe "手機版", js: true do
    before do
      Capybara.current_session.resize_to(375, 812)
    end

    after do
      Capybara.current_session.resize_to(1280, 800)
    end

    it "從帳戶頁進入所有交易" do
      visit accounts_path
      click_link "所有交易"
      expect(page).to have_text("交易紀錄")
      expect(page).to have_text("午餐")
      expect(page).to have_text("電車")
    end

    it "手機版顯示卡片式列表" do
      visit transaction_lists_path
      expect(page).to have_css("[id^='transaction-mobile-']")
    end

    it "手機版篩選" do
      visit transaction_lists_path
      select "現金", from: "account_id"
      click_button "篩選"
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end
  end
end
```

- [ ] **Step 2: Run system specs**

Run: `bundle exec rspec spec/system/transaction_lists_spec.rb -v`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add spec/system/transaction_lists_spec.rb
git commit -m "test: add system specs for global transaction list (desktop + mobile)"
```

---

### Task 12: System specs for account page upgrade

**Files:**
- Modify: `spec/system/accounts_spec.rb` (or create new section)

- [ ] **Step 1: Add account page filter and pagination system specs**

Append to `spec/system/accounts_spec.rb` (or create separate describe block):

```ruby
  describe "帳戶詳情頁篩選與分頁" do
    let!(:account) { create(:account, household: household, name: "現金") }
    let!(:group) { create(:category_group, household: household, name: "生活") }
    let!(:category1) { create(:category, category_group: group, name: "食費") }
    let!(:category2) { create(:category, category_group: group, name: "交通") }

    it "帳戶頁支援類別篩選", js: true do
      create(:transaction, account: account, category: category1, amount: -300, date: Date.today, memo: "午餐")
      create(:transaction, account: account, category: category2, amount: -500, date: Date.today, memo: "電車")
      visit account_path(account)
      select "食費", from: "category_id"
      click_button "篩選"
      expect(page).to have_text("午餐")
      expect(page).not_to have_text("電車")
    end

    it "帳戶頁支援分頁", js: true do
      31.times { |i| create(:transaction, account: account, category: category1, amount: -100, date: Date.today - i.days, memo: "txn#{i}") }
      visit account_path(account)
      expect(page).to have_css("nav.pagy")
    end

    describe "手機版", js: true do
      before { Capybara.current_session.resize_to(375, 812) }
      after { Capybara.current_session.resize_to(1280, 800) }

      it "帳戶詳情頁手機版顯示篩選和卡片" do
        create(:transaction, account: account, category: category1, amount: -300, date: Date.today, memo: "午餐")
        visit account_path(account)
        expect(page).to have_css("[id^='transaction-mobile-']")
      end
    end
  end
```

Note: The existing `accounts_spec.rb` has `let(:household) { user.households.first }` at the top level but no `account` let, so we define `let!(:account)` inside this describe block.

- [ ] **Step 2: Run the full accounts system spec**

Run: `bundle exec rspec spec/system/accounts_spec.rb -v`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add spec/system/accounts_spec.rb
git commit -m "test: add system specs for account page filtering and pagination"
```

---

### Task 13: Run full test suite and fix any regressions

**Files:** None (verification only)

- [ ] **Step 1: Run rubocop**

Run: `bin/rubocop`
Expected: No offenses

- [ ] **Step 2: Fix any rubocop issues if found**

- [ ] **Step 3: Run the full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS, 0 failures

- [ ] **Step 4: Fix any failing tests**

Common issues to watch for:
- Existing account show specs may break due to pagination changes (no more `limit(50)`)
- Existing transaction specs may need updates if they relied on the old account show view structure
- The `_row.html.erb` partial is no longer used by account show — check if any specs reference it

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test regressions from transaction list refactor"
```
