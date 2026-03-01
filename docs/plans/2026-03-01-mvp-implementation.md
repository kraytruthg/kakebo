# MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 補齊 Kakebo 成為可部署單人記帳 MVP 所需的六個功能：用戶註冊、月份切換、自動結轉、類別管理、交易編輯、Onboarding 引導。

**Architecture:** 沿用現有 Rails 8 架構（Hotwire / Turbo Stream / Tailwind CSS v4）。新增 UsersController、CategoryGroupsController、CategoriesController、OnboardingController，並以 concern 集中月份參數驗證邏輯。結轉邏輯封裝在 BudgetEntry model class method 中。

**Tech Stack:** Ruby 3.4.2, Rails 8.1.2, PostgreSQL 17, Hotwire (Turbo), Tailwind CSS v4, RSpec + Capybara (headless Chrome), FactoryBot, Faker

---

## Task 1：用戶註冊

**Files:**
- Create: `app/controllers/users_controller.rb`
- Create: `app/views/users/new.html.erb`
- Modify: `app/models/user.rb`
- Modify: `config/routes.rb`
- Create: `spec/system/users_spec.rb`

### Step 1：寫失敗的 system test

```ruby
# spec/system/users_spec.rb
require "rails_helper"

RSpec.describe "Users", type: :system do
  describe "註冊" do
    context "REGISTRATION_OPEN=true" do
      before { stub_const("ENV", ENV.to_h.merge("REGISTRATION_OPEN" => "true")) }

      it "填寫正確資料後成功登入並進入預算頁" do
        visit signup_path

        fill_in "姓名", with: "測試用戶"
        fill_in "Email", with: "test@example.com"
        fill_in "密碼", with: "password123"
        fill_in "確認密碼", with: "password123"
        click_button "註冊"

        expect(page).to have_text("Ready to Assign")
      end

      it "email 重複時顯示錯誤" do
        create(:user, email: "dup@example.com")
        visit signup_path

        fill_in "姓名", with: "重複用戶"
        fill_in "Email", with: "dup@example.com"
        fill_in "密碼", with: "password123"
        fill_in "確認密碼", with: "password123"
        click_button "註冊"

        expect(page).to have_text("Email 已被使用")
      end
    end

    context "REGISTRATION_OPEN=false" do
      before { stub_const("ENV", ENV.to_h.merge("REGISTRATION_OPEN" => "false")) }

      it "顯示目前不開放註冊" do
        visit signup_path
        expect(page).to have_text("目前不開放註冊")
      end
    end
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/system/users_spec.rb
```
Expected: FAIL（路由不存在）

### Step 3：新增路由

```ruby
# config/routes.rb 在 resource :session 下方加入：
get "signup", to: "users#new"
resources :users, only: [:create]
```

### Step 4：新增 User model callback

```ruby
# app/models/user.rb
class User < ApplicationRecord
  belongs_to :household, optional: true
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email, with: -> e { e.strip.downcase }

  before_create :create_household

  private

  def create_household
    self.household ||= Household.create!(name: "#{name} 的家")
  end
end
```

注意：`belongs_to :household` 改成 `optional: true`，因為 callback 在 create 時才建 household。

### Step 5：新增 UsersController

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    if ENV["REGISTRATION_OPEN"] != "true"
      render :closed and return
    end
    @user = User.new
  end

  def create
    if ENV["REGISTRATION_OPEN"] != "true"
      render :closed, status: :forbidden and return
    end

    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "歡迎加入！"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
```

### Step 6：新增 Views

```erb
<%# app/views/users/new.html.erb %>
<div class="min-h-screen flex items-center justify-center">
  <div class="w-full max-w-md p-8 bg-white rounded-2xl shadow">
    <h1 class="text-2xl font-bold mb-6">建立帳號</h1>
    <%= form_with model: @user, url: users_path do |f| %>
      <% if @user.errors.any? %>
        <div class="mb-4 p-3 bg-red-50 text-red-700 rounded">
          <% @user.errors.full_messages.each do |msg| %>
            <p><%= msg %></p>
          <% end %>
        </div>
      <% end %>
      <div class="mb-4">
        <%= f.label :name, "姓名" %>
        <%= f.text_field :name, class: "w-full border rounded px-3 py-2" %>
      </div>
      <div class="mb-4">
        <%= f.label :email, "Email" %>
        <%= f.email_field :email, class: "w-full border rounded px-3 py-2" %>
      </div>
      <div class="mb-4">
        <%= f.label :password, "密碼" %>
        <%= f.password_field :password, class: "w-full border rounded px-3 py-2" %>
      </div>
      <div class="mb-6">
        <%= f.label :password_confirmation, "確認密碼" %>
        <%= f.password_field :password_confirmation, class: "w-full border rounded px-3 py-2" %>
      </div>
      <%= f.submit "註冊", class: "w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700" %>
    <% end %>
    <p class="mt-4 text-center text-sm">已有帳號？<%= link_to "登入", new_session_path, class: "text-blue-600" %></p>
  </div>
</div>
```

```erb
<%# app/views/users/closed.html.erb %>
<div class="min-h-screen flex items-center justify-center">
  <div class="text-center">
    <h1 class="text-2xl font-bold mb-2">目前不開放註冊</h1>
    <p class="text-gray-500">請聯絡管理員取得帳號。</p>
    <%= link_to "回到登入頁", new_session_path, class: "mt-4 inline-block text-blue-600" %>
  </div>
</div>
```

### Step 7：執行測試確認通過

```bash
bundle exec rspec spec/system/users_spec.rb
```
Expected: 3 examples, 0 failures

### Step 8：Commit

```bash
git add app/controllers/users_controller.rb app/views/users/ app/models/user.rb config/routes.rb spec/system/users_spec.rb
git commit -m "feat: add user registration with REGISTRATION_OPEN guard"
```

---

## Task 2：月份切換

**Files:**
- Create: `app/controllers/concerns/month_navigable.rb`
- Modify: `app/controllers/budget_controller.rb`
- Modify: `app/controllers/reports_controller.rb`
- Modify: `app/views/budget/index.html.erb`
- Modify: `app/views/reports/index.html.erb`
- Create: `app/views/shared/_month_nav.html.erb`
- Create: `spec/system/month_navigation_spec.rb`

### Step 1：寫失敗的 system test

```ruby
# spec/system/month_navigation_spec.rb
require "rails_helper"

RSpec.describe "月份切換", type: :system do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "點擊下一個月切換到正確月份" do
    visit budget_path(year: 2026, month: 3)
    click_link "→"
    expect(page).to have_current_path(budget_path(year: 2026, month: 4))
  end

  it "點擊上一個月切換到正確月份" do
    visit budget_path(year: 2026, month: 3)
    click_link "←"
    expect(page).to have_current_path(budget_path(year: 2026, month: 2))
  end

  it "跨年切換：2026/01 上一月到 2025/12" do
    visit budget_path(year: 2026, month: 1)
    click_link "←"
    expect(page).to have_current_path(budget_path(year: 2025, month: 12))
  end

  it "2000/01 的上一月按鈕 disabled" do
    visit budget_path(year: 2000, month: 1)
    expect(page).to have_css("span[aria-disabled='true']", text: "←")
  end

  it "2099/12 的下一月按鈕 disabled" do
    visit budget_path(year: 2099, month: 12)
    expect(page).to have_css("span[aria-disabled='true']", text: "→")
  end

  it "非法 year 參數 redirect 到當月" do
    visit budget_path(year: "abc", month: 3)
    today = Date.today
    expect(page).to have_current_path(budget_path(year: today.year, month: today.month))
  end

  it "超界 year 參數 redirect 到當月" do
    visit budget_path(year: 9999, month: 1)
    today = Date.today
    expect(page).to have_current_path(budget_path(year: today.year, month: today.month))
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/system/month_navigation_spec.rb
```
Expected: FAIL

### Step 3：新增 MonthNavigable concern

```ruby
# app/controllers/concerns/month_navigable.rb
module MonthNavigable
  extend ActiveSupport::Concern

  YEAR_MIN  = 2000
  YEAR_MAX  = 2099

  included do
    before_action :set_month_params
  end

  private

  def set_month_params
    raw_year  = params[:year]
    raw_month = params[:month]

    year  = raw_year&.to_i
    month = raw_month&.to_i

    if raw_year.blank? && raw_month.blank?
      @year  = Date.today.year
      @month = Date.today.month
      return
    end

    unless year&.between?(YEAR_MIN, YEAR_MAX) && month&.between?(1, 12)
      redirect_to request.path, year: Date.today.year, month: Date.today.month and return
    end

    @year  = year
    @month = month
  end

  def prev_month
    date = Date.new(@year, @month, 1).prev_month
    { year: date.year, month: date.month }
  end

  def next_month
    date = Date.new(@year, @month, 1).next_month
    { year: date.year, month: date.month }
  end

  def at_lower_bound?
    @year == YEAR_MIN && @month == 1
  end

  def at_upper_bound?
    @year == YEAR_MAX && @month == 12
  end

  helper_method :prev_month, :next_month, :at_lower_bound?, :at_upper_bound?
end
```

### Step 4：更新 BudgetController

```ruby
# app/controllers/budget_controller.rb
class BudgetController < ApplicationController
  include MonthNavigable

  def index
    @household = Current.household
    @ready_to_assign = @household.ready_to_assign(@year, @month)
    @category_groups = @household.category_groups.includes(categories: :budget_entries)
    @monthly_activities = Transaction
                            .joins(:account, category: { category_group: :household })
                            .where(accounts: { account_type: "budget" })
                            .where(category_groups: { household_id: @household.id })
                            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                            .group(:category_id)
                            .sum(:amount)
  end
end
```

（移除 `@year` / `@month` 的設定，改由 concern 處理）

### Step 5：更新 ReportsController

```ruby
# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  include MonthNavigable

  def index
    @household = Current.household
    @expenses = Transaction
                  .joins(:account, category: { category_group: :household })
                  .where(accounts: { account_type: "budget" })
                  .where(category_groups: { household_id: @household.id })
                  .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", @year, @month)
                  .group("categories.name")
                  .sum(:amount)
                  .sort_by { |_, v| v }.reverse
  end
end
```

### Step 6：新增月份導覽 partial

```erb
<%# app/views/shared/_month_nav.html.erb %>
<div class="flex items-center gap-4">
  <% if at_lower_bound? %>
    <span class="text-gray-300 cursor-not-allowed" aria-disabled="true">←</span>
  <% else %>
    <%= link_to "←", request.path + "?" + { year: prev_month[:year], month: prev_month[:month] }.to_query,
        class: "text-gray-600 hover:text-black" %>
  <% end %>

  <span class="font-semibold"><%= "#{@year} 年 #{@month} 月" %></span>

  <% if at_upper_bound? %>
    <span class="text-gray-300 cursor-not-allowed" aria-disabled="true">→</span>
  <% else %>
    <%= link_to "→", request.path + "?" + { year: next_month[:year], month: next_month[:month] }.to_query,
        class: "text-gray-600 hover:text-black" %>
  <% end %>
</div>
```

### Step 7：在 budget/index.html.erb 和 reports/index.html.erb 加入月份導覽

在兩個頁面的標題區域加入：

```erb
<%= render "shared/month_nav" %>
```

### Step 8：執行測試確認通過

```bash
bundle exec rspec spec/system/month_navigation_spec.rb
```
Expected: 7 examples, 0 failures

### Step 9：Commit

```bash
git add app/controllers/concerns/month_navigable.rb app/controllers/budget_controller.rb app/controllers/reports_controller.rb app/views/shared/_month_nav.html.erb app/views/budget/index.html.erb app/views/reports/index.html.erb spec/system/month_navigation_spec.rb
git commit -m "feat: add month navigation with boundary validation"
```

---

## Task 3：自動結轉

**Files:**
- Modify: `app/models/budget_entry.rb`
- Modify: `app/controllers/budget_controller.rb`
- Create: `spec/models/budget_entry_spec.rb`（補充 initialize_month! 測試）
- Create: `spec/system/auto_carry_over_spec.rb`

### Step 1：寫失敗的 model spec

```ruby
# spec/models/budget_entry_spec.rb（在現有檔案補充，或新建）
require "rails_helper"

RSpec.describe BudgetEntry, type: :model do
  describe ".initialize_month!" do
    let(:household) { create(:household) }
    let(:group)     { create(:category_group, household: household) }
    let!(:cat)      { create(:category, category_group: group) }

    context "上個月有 BudgetEntry" do
      before do
        create(:budget_entry, category: cat, year: 2026, month: 2,
               budgeted: 3000, carried_over: 0)
        # activity 為 0（無交易），available = 0 + 3000 + 0 = 3000
      end

      it "用上月 available 建立本月 carried_over" do
        BudgetEntry.initialize_month!(household, 2026, 3)
        entry = BudgetEntry.find_by(category: cat, year: 2026, month: 3)
        expect(entry.carried_over).to eq(3000)
        expect(entry.budgeted).to eq(0)
      end
    end

    context "上個月無 BudgetEntry" do
      it "carried_over 為 0" do
        BudgetEntry.initialize_month!(household, 2026, 3)
        entry = BudgetEntry.find_by(category: cat, year: 2026, month: 3)
        expect(entry.carried_over).to eq(0)
      end
    end

    context "本月已有 BudgetEntry" do
      before do
        create(:budget_entry, category: cat, year: 2026, month: 3,
               budgeted: 1000, carried_over: 500)
      end

      it "不覆蓋已存在的 entry" do
        BudgetEntry.initialize_month!(household, 2026, 3)
        entry = BudgetEntry.find_by(category: cat, year: 2026, month: 3)
        expect(entry.budgeted).to eq(1000)
        expect(entry.carried_over).to eq(500)
      end
    end
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/models/budget_entry_spec.rb
```
Expected: FAIL（initialize_month! 不存在）

### Step 3：新增 BudgetEntry.initialize_month!

```ruby
# app/models/budget_entry.rb（在 class 內新增）

def self.initialize_month!(household, year, month)
  prev = Date.new(year, month, 1).prev_month
  prev_year  = prev.year
  prev_month = prev.month

  ActiveRecord::Base.transaction do
    household.category_groups.includes(:categories).each do |group|
      group.categories.each do |category|
        next if exists?(category: category, year: year, month: month)

        prev_entry = find_by(category: category, year: prev_year, month: prev_month)
        carried    = prev_entry ? prev_entry.available : 0

        create!(
          category:     category,
          year:         year,
          month:        month,
          carried_over: carried,
          budgeted:     0
        )
      end
    end
  end
end
```

注意：`carried` 的值是 `prev_entry.available`，而 `available` 是 `carried_over + budgeted + activity`，所以包含了上月的實際餘額。

### Step 4：在 BudgetController#index 呼叫初始化

```ruby
# app/controllers/budget_controller.rb（在 index 最前面加）
def index
  @household = Current.household
  BudgetEntry.initialize_month!(@household, @year, @month)  # 新增這行
  @ready_to_assign = @household.ready_to_assign(@year, @month)
  # ... 其餘不變
end
```

### Step 5：確認 factory 有 carried_over 和 budgeted 欄位

```ruby
# spec/factories/budget_entries.rb（確認或更新）
FactoryBot.define do
  factory :budget_entry do
    association :category
    year         { Date.today.year }
    month        { Date.today.month }
    budgeted     { 0 }
    carried_over { 0 }
  end
end
```

### Step 6：執行 model spec 確認通過

```bash
bundle exec rspec spec/models/budget_entry_spec.rb
```
Expected: 3 examples, 0 failures

### Step 7：寫 system test

```ruby
# spec/system/auto_carry_over_spec.rb
require "rails_helper"

RSpec.describe "自動結轉", type: :system do
  let(:user)  { create(:user) }
  let!(:group) { create(:category_group, household: user.household) }
  let!(:cat)   { create(:category, category_group: group) }

  before { sign_in(user) }

  it "首次瀏覽某月時自動建立 BudgetEntry" do
    visit budget_path(year: 2026, month: 5)
    expect(BudgetEntry.where(category: cat, year: 2026, month: 5)).to exist
  end

  it "上月有 available 時帶入 carried_over" do
    create(:budget_entry, category: cat, year: 2026, month: 4, budgeted: 2000, carried_over: 0)
    visit budget_path(year: 2026, month: 5)
    entry = BudgetEntry.find_by(category: cat, year: 2026, month: 5)
    expect(entry.carried_over).to eq(2000)
  end

  it "上月無資料時 carried_over 為 0" do
    visit budget_path(year: 2026, month: 5)
    entry = BudgetEntry.find_by(category: cat, year: 2026, month: 5)
    expect(entry.carried_over).to eq(0)
  end
end
```

### Step 8：執行所有相關測試

```bash
bundle exec rspec spec/models/budget_entry_spec.rb spec/system/auto_carry_over_spec.rb
```
Expected: 6 examples, 0 failures

### Step 9：Commit

```bash
git add app/models/budget_entry.rb app/controllers/budget_controller.rb spec/models/budget_entry_spec.rb spec/system/auto_carry_over_spec.rb spec/factories/budget_entries.rb
git commit -m "feat: auto carry-over when viewing a new month"
```

---

## Task 4：類別管理

**Files:**
- Create: `app/controllers/category_groups_controller.rb`
- Create: `app/controllers/categories_controller.rb`
- Create: `app/views/category_groups/index.html.erb`
- Create: `app/views/category_groups/_form.html.erb`
- Create: `app/views/categories/_form.html.erb`
- Modify: `app/models/category.rb`
- Modify: `app/models/category_group.rb`
- Modify: `config/routes.rb`
- Create: `spec/system/categories_spec.rb`

### Step 1：寫失敗的 system test

```ruby
# spec/system/categories_spec.rb
require "rails_helper"

RSpec.describe "類別管理", type: :system do
  let(:user) { create(:user) }
  let!(:group) { create(:category_group, household: user.household, name: "日常開銷") }

  before { sign_in(user) }

  it "新增 CategoryGroup" do
    visit category_groups_path
    click_link "新增群組"
    fill_in "名稱", with: "娛樂"
    click_button "儲存"
    expect(page).to have_text("娛樂")
  end

  it "新增 Category" do
    visit category_groups_path
    within("#group-#{group.id}") { click_link "新增類別" }
    fill_in "名稱", with: "電影"
    click_button "儲存"
    expect(page).to have_text("電影")
  end

  it "重新命名 CategoryGroup" do
    visit category_groups_path
    within("#group-#{group.id}") { click_link "編輯" }
    fill_in "名稱", with: "每日花費"
    click_button "儲存"
    expect(page).to have_text("每日花費")
  end

  it "刪除空的 Category 成功" do
    cat = create(:category, category_group: group, name: "無交易")
    visit category_groups_path
    within("#category-#{cat.id}") { click_button "刪除" }
    expect(page).not_to have_text("無交易")
  end

  it "刪除有交易的 Category 顯示錯誤" do
    cat = create(:category, category_group: group, name: "有交易")
    account = create(:account, household: user.household, account_type: "budget")
    create(:transaction, account: account, category: cat, amount: -500, date: Date.today)
    visit category_groups_path
    within("#category-#{cat.id}") { click_button "刪除" }
    expect(page).to have_text("有交易")
    expect(page).to have_text("筆交易")
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/system/categories_spec.rb
```
Expected: FAIL

### Step 3：新增路由

```ruby
# config/routes.rb
resources :category_groups do
  resources :categories, only: [:new, :create, :edit, :update, :destroy]
end
```

### Step 4：在 Category model 加刪除保護

```ruby
# app/models/category.rb
before_destroy :prevent_if_has_transactions

private

def prevent_if_has_transactions
  count = transactions.count
  if count > 0
    errors.add(:base, "此分類有 #{count} 筆交易，請先移除或重新分類")
    throw :abort
  end
end
```

### Step 5：在 CategoryGroup model 加刪除保護

```ruby
# app/models/category_group.rb
class CategoryGroup < ApplicationRecord
  belongs_to :household
  has_many :categories, dependent: :destroy

  validates :name, presence: true

  default_scope { order(:position) }

  before_destroy :prevent_if_has_categories

  private

  def prevent_if_has_categories
    if categories.any?
      errors.add(:base, "請先移除此群組內的所有類別")
      throw :abort
    end
  end
end
```

### Step 6：新增 CategoryGroupsController

```ruby
# app/controllers/category_groups_controller.rb
class CategoryGroupsController < ApplicationController
  def index
    @category_groups = Current.household.category_groups.includes(:categories)
  end

  def new
    @category_group = Current.household.category_groups.build
  end

  def create
    @category_group = Current.household.category_groups.build(category_group_params)
    @category_group.position = Current.household.category_groups.maximum(:position).to_i + 1
    if @category_group.save
      redirect_to category_groups_path, notice: "群組已新增"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @category_group = Current.household.category_groups.find(params[:id])
  end

  def update
    @category_group = Current.household.category_groups.find(params[:id])
    if @category_group.update(category_group_params)
      redirect_to category_groups_path, notice: "群組已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category_group = Current.household.category_groups.find(params[:id])
    if @category_group.destroy
      redirect_to category_groups_path, notice: "群組已刪除"
    else
      redirect_to category_groups_path, alert: @category_group.errors.full_messages.to_sentence
    end
  end

  private

  def category_group_params
    params.require(:category_group).permit(:name)
  end
end
```

### Step 7：新增 CategoriesController

```ruby
# app/controllers/categories_controller.rb
class CategoriesController < ApplicationController
  before_action :set_category_group

  def new
    @category = @category_group.categories.build
  end

  def create
    @category = @category_group.categories.build(category_params)
    @category.position = @category_group.categories.maximum(:position).to_i + 1
    if @category.save
      redirect_to category_groups_path, notice: "類別已新增"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @category = @category_group.categories.find(params[:id])
  end

  def update
    @category = @category_group.categories.find(params[:id])
    if @category.update(category_params)
      redirect_to category_groups_path, notice: "類別已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category = @category_group.categories.find(params[:id])
    if @category.destroy
      redirect_to category_groups_path, notice: "類別已刪除"
    else
      redirect_to category_groups_path, alert: @category.errors.full_messages.to_sentence
    end
  end

  private

  def set_category_group
    @category_group = Current.household.category_groups.find(params[:category_group_id])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
```

### Step 8：新增 Views

```erb
<%# app/views/category_groups/index.html.erb %>
<div class="max-w-2xl mx-auto p-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">類別管理</h1>
    <%= link_to "新增群組", new_category_group_path, class: "btn-primary" %>
  </div>

  <% @category_groups.each do |group| %>
    <div id="group-<%= group.id %>" class="mb-6 border rounded-xl p-4">
      <div class="flex justify-between items-center mb-3">
        <h2 class="font-semibold text-lg"><%= group.name %></h2>
        <div class="flex gap-2">
          <%= link_to "編輯", edit_category_group_path(group), class: "text-sm text-blue-600" %>
          <%= button_to "刪除", category_group_path(group), method: :delete,
              class: "text-sm text-red-500",
              data: { turbo_confirm: "確定要刪除這個群組嗎？" } %>
        </div>
      </div>

      <% group.categories.each do |cat| %>
        <div id="category-<%= cat.id %>" class="flex justify-between items-center py-2 border-t">
          <span><%= cat.name %></span>
          <div class="flex gap-2">
            <%= link_to "編輯", edit_category_group_category_path(group, cat), class: "text-sm text-blue-600" %>
            <%= button_to "刪除", category_group_category_path(group, cat), method: :delete,
                class: "text-sm text-red-500",
                data: { turbo_confirm: "確定要刪除這個類別嗎？" } %>
          </div>
        </div>
      <% end %>

      <%= link_to "新增類別", new_category_group_category_path(group), class: "text-sm text-blue-600 mt-2 inline-block" %>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/category_groups/_form.html.erb %>
<%= form_with model: @category_group do |f| %>
  <% if @category_group.errors.any? %>
    <div class="mb-4 p-3 bg-red-50 text-red-700 rounded">
      <% @category_group.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>
  <div class="mb-4">
    <%= f.label :name, "名稱" %>
    <%= f.text_field :name, class: "w-full border rounded px-3 py-2" %>
  </div>
  <%= f.submit "儲存", class: "bg-blue-600 text-white px-4 py-2 rounded" %>
<% end %>
```

```erb
<%# app/views/category_groups/new.html.erb %>
<div class="max-w-md mx-auto p-6">
  <h1 class="text-xl font-bold mb-4">新增群組</h1>
  <%= render "form" %>
</div>
```

```erb
<%# app/views/category_groups/edit.html.erb %>
<div class="max-w-md mx-auto p-6">
  <h1 class="text-xl font-bold mb-4">編輯群組</h1>
  <%= render "form" %>
</div>
```

```erb
<%# app/views/categories/_form.html.erb %>
<%= form_with model: [@category_group, @category] do |f| %>
  <% if @category.errors.any? %>
    <div class="mb-4 p-3 bg-red-50 text-red-700 rounded">
      <% @category.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>
  <div class="mb-4">
    <%= f.label :name, "名稱" %>
    <%= f.text_field :name, class: "w-full border rounded px-3 py-2" %>
  </div>
  <%= f.submit "儲存", class: "bg-blue-600 text-white px-4 py-2 rounded" %>
<% end %>
```

```erb
<%# app/views/categories/new.html.erb %>
<div class="max-w-md mx-auto p-6">
  <h1 class="text-xl font-bold mb-4">新增類別</h1>
  <%= render "form" %>
</div>
```

```erb
<%# app/views/categories/edit.html.erb %>
<div class="max-w-md mx-auto p-6">
  <h1 class="text-xl font-bold mb-4">編輯類別</h1>
  <%= render "form" %>
</div>
```

### Step 9：在導覽列加入「類別管理」連結

在 `app/views/shared/_nav.html.erb` 加入：

```erb
<%= link_to "類別管理", category_groups_path %>
```

### Step 10：執行測試確認通過

```bash
bundle exec rspec spec/system/categories_spec.rb
```
Expected: 5 examples, 0 failures

### Step 11：Commit

```bash
git add app/controllers/category_groups_controller.rb app/controllers/categories_controller.rb app/views/category_groups/ app/views/categories/ app/models/category.rb app/models/category_group.rb config/routes.rb spec/system/categories_spec.rb
git commit -m "feat: add category and category group management"
```

---

## Task 5：交易編輯

**Files:**
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `config/routes.rb`
- Create: `app/views/transactions/edit.html.erb`
- Create: `app/views/transactions/update.turbo_stream.erb`
- Modify: `app/views/transactions/_row.html.erb`
- Create: `spec/system/transaction_edit_spec.rb`

### Step 1：寫失敗的 system test

```ruby
# spec/system/transaction_edit_spec.rb
require "rails_helper"

RSpec.describe "交易編輯", type: :system do
  let(:user)    { create(:user) }
  let!(:account) { create(:account, household: user.household, account_type: "budget") }
  let!(:group)   { create(:category_group, household: user.household) }
  let!(:cat1)    { create(:category, category_group: group, name: "餐費") }
  let!(:cat2)    { create(:category, category_group: group, name: "交通") }
  let!(:txn)     { create(:transaction, account: account, category: cat1, amount: -500, date: Date.today, memo: "午餐") }

  before { sign_in(user) }

  it "修改金額後帳戶頁更新" do
    visit account_path(account)
    within("#transaction-#{txn.id}") { click_link "編輯" }
    fill_in "金額", with: "-800"
    click_button "更新"
    expect(page).to have_text("800")
  end

  it "修改類別後兩方 available 都更新" do
    create(:budget_entry, category: cat1, year: Date.today.year, month: Date.today.month, budgeted: 3000, carried_over: 0)
    create(:budget_entry, category: cat2, year: Date.today.year, month: Date.today.month, budgeted: 2000, carried_over: 0)

    visit account_path(account)
    within("#transaction-#{txn.id}") { click_link "編輯" }
    select "交通", from: "類別"
    click_button "更新"
    expect(page).to have_text("更新")
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/system/transaction_edit_spec.rb
```
Expected: FAIL

### Step 3：新增路由

```ruby
# config/routes.rb（更新 transactions 的 only 清單）
resources :accounts, only: [:index, :show, :new, :create, :edit, :update] do
  resources :transactions, only: [:create, :destroy, :edit, :update]
end
```

### Step 4：在 TransactionsController 新增 edit / update action

```ruby
# app/controllers/transactions_controller.rb（新增）

def edit
  @transaction = @account.transactions.find(params[:id])
  @categories  = Current.household.category_groups.includes(:categories)
end

def update
  @transaction = @account.transactions.find(params[:id])
  if @transaction.update(transaction_params)
    @account.recalculate_balance!
    set_budget_data_for_turbo_stream
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_path(@account), notice: "交易已更新" }
    end
  else
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
    end
  end
end
```

### Step 5：新增 edit view

```erb
<%# app/views/transactions/edit.html.erb %>
<div class="max-w-md mx-auto p-6">
  <h1 class="text-xl font-bold mb-4">編輯交易</h1>
  <%= form_with model: [@account, @transaction] do |f| %>
    <div class="mb-4">
      <%= f.label :date, "日期" %>
      <%= f.date_field :date, class: "w-full border rounded px-3 py-2" %>
    </div>
    <div class="mb-4">
      <%= f.label :amount, "金額" %>
      <%= f.number_field :amount, step: 1, class: "w-full border rounded px-3 py-2" %>
    </div>
    <div class="mb-4">
      <%= f.label :category_id, "類別" %>
      <%= f.select :category_id,
          @categories.map { |g| [g.name, g.categories.map { |c| [c.name, c.id] }] },
          { include_blank: "（無類別）" },
          class: "w-full border rounded px-3 py-2" %>
    </div>
    <div class="mb-6">
      <%= f.label :memo, "備忘" %>
      <%= f.text_field :memo, class: "w-full border rounded px-3 py-2" %>
    </div>
    <%= f.submit "更新", class: "bg-blue-600 text-white px-4 py-2 rounded" %>
    <%= link_to "取消", account_path(@account), class: "ml-3 text-gray-500" %>
  <% end %>
</div>
```

### Step 6：新增 update.turbo_stream.erb

```erb
<%# app/views/transactions/update.turbo_stream.erb %>
<%= turbo_stream.replace "transaction-#{@transaction.id}" do %>
  <%= render "transactions/row", transaction: @transaction, account: @account %>
<% end %>

<% if @budget_entry %>
  <%= turbo_stream.replace "budget-category-#{@transaction.category_id}" do %>
    <%# 根據現有 budget view 的 partial 更新對應類別的顯示 %>
  <% end %>
<% end %>
```

### Step 7：在 transactions/_row.html.erb 加入編輯連結

在每筆交易列加入：

```erb
<div id="transaction-<%= transaction.id %>" class="...">
  <%# 現有內容 %>
  <%= link_to "編輯", edit_account_transaction_path(account, transaction), class: "text-sm text-blue-600" %>
</div>
```

### Step 8：執行測試確認通過

```bash
bundle exec rspec spec/system/transaction_edit_spec.rb
```
Expected: 2 examples, 0 failures

### Step 9：Commit

```bash
git add app/controllers/transactions_controller.rb app/views/transactions/edit.html.erb app/views/transactions/update.turbo_stream.erb app/views/transactions/_row.html.erb config/routes.rb spec/system/transaction_edit_spec.rb
git commit -m "feat: add transaction edit with Turbo Stream update"
```

---

## Task 6：Onboarding 引導

**Files:**
- Create: `app/controllers/onboarding_controller.rb`
- Create: `app/views/onboarding/index.html.erb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/system/onboarding_spec.rb`

### Step 1：寫失敗的 system test

```ruby
# spec/system/onboarding_spec.rb
require "rails_helper"

RSpec.describe "Onboarding", type: :system do
  context "新用戶（無帳戶）" do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it "登入後導向 onboarding 頁" do
      visit root_path
      expect(page).to have_current_path(onboarding_path)
      expect(page).to have_text("開始設定")
    end

    it "建立帳戶後可進入預算頁" do
      visit onboarding_path
      click_link "新增帳戶"
      fill_in "名稱", with: "玉山銀行"
      select "預算帳戶", from: "帳戶類型"
      fill_in "起始餘額", with: "50000"
      click_button "建立帳戶"
      visit root_path
      expect(page).to have_current_path(budget_path)
    end
  end

  context "已有帳戶的用戶" do
    let(:user)    { create(:user) }
    let!(:account) { create(:account, household: user.household) }

    before { sign_in(user) }

    it "不觸發 onboarding，直接進入預算頁" do
      visit root_path
      expect(page).to have_current_path(budget_path)
    end
  end
end
```

### Step 2：執行確認測試失敗

```bash
bundle exec rspec spec/system/onboarding_spec.rb
```
Expected: FAIL

### Step 3：新增路由

```ruby
# config/routes.rb
get "onboarding", to: "onboarding#index", as: :onboarding
```

### Step 4：新增 OnboardingController

```ruby
# app/controllers/onboarding_controller.rb
class OnboardingController < ApplicationController
  def index
  end
end
```

### Step 5：在 ApplicationController 加 onboarding redirect

```ruby
# app/controllers/application_controller.rb
before_action :require_login
before_action :redirect_to_onboarding_if_needed

private

def redirect_to_onboarding_if_needed
  return unless current_user_needs_onboarding?
  redirect_to onboarding_path
end

def current_user_needs_onboarding?
  Current.user &&
    !request.path.start_with?("/onboarding") &&
    !request.path.start_with?("/accounts") &&
    !request.path.start_with?("/sessions") &&
    Current.household.accounts.none?
end
```

### Step 6：新增 onboarding view

```erb
<%# app/views/onboarding/index.html.erb %>
<div class="min-h-screen flex items-center justify-center bg-gray-50">
  <div class="max-w-lg w-full p-8 bg-white rounded-2xl shadow text-center">
    <h1 class="text-2xl font-bold mb-2">歡迎使用 Kakebo！</h1>
    <p class="text-gray-500 mb-8">開始設定你的帳本，只需要幾個步驟。</p>

    <div class="text-left space-y-4 mb-8">
      <div class="flex items-start gap-3">
        <span class="w-8 h-8 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold shrink-0">1</span>
        <div>
          <p class="font-semibold">建立第一個帳戶</p>
          <p class="text-sm text-gray-500">例如：玉山銀行、現金</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <span class="w-8 h-8 bg-gray-200 text-gray-400 rounded-full flex items-center justify-center font-bold shrink-0">2</span>
        <div>
          <p class="font-semibold text-gray-400">確認預設類別</p>
          <p class="text-sm text-gray-400">系統已建立基本分類，可之後調整</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <span class="w-8 h-8 bg-gray-200 text-gray-400 rounded-full flex items-center justify-center font-bold shrink-0">3</span>
        <div>
          <p class="font-semibold text-gray-400">開始記帳</p>
          <p class="text-sm text-gray-400">分配預算，記錄每一筆收支</p>
        </div>
      </div>
    </div>

    <%= link_to "新增帳戶", new_account_path, class: "inline-block bg-blue-600 text-white px-8 py-3 rounded-xl text-lg hover:bg-blue-700" %>
  </div>
</div>
```

### Step 7：執行測試確認通過

```bash
bundle exec rspec spec/system/onboarding_spec.rb
```
Expected: 3 examples, 0 failures

### Step 8：執行全部測試確認沒有 regression

```bash
bundle exec rspec
```
Expected: 0 failures

### Step 9：Commit

```bash
git add app/controllers/onboarding_controller.rb app/views/onboarding/ app/controllers/application_controller.rb config/routes.rb spec/system/onboarding_spec.rb
git commit -m "feat: add onboarding flow for new users without accounts"
```

---

## 最終驗收

所有 Task 完成後執行：

```bash
bundle exec rspec
```

Expected: 0 failures，所有 system tests 通過。
