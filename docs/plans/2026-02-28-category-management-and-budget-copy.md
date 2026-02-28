# 類別群組管理 & 預算 Copy 實作計畫

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 新增設定頁讓使用者管理類別群組，並在預算頁加入「複製上月預算」功能。

**Architecture:** 採方案 A（極簡 CRUD）。Settings namespace 下建立兩個 controller，全頁重整無 Turbo Stream。Budget copy 為 BudgetController 的一個 POST action，複製邏輯直接在 action 內實作。

**Tech Stack:** Rails 8.1, Turbo（僅用於 flash toast），Tailwind CSS v4, RSpec request specs

---

### Task 1: 新增路由

**Files:**
- Modify: `config/routes.rb`

**Step 1: 在 routes.rb 加入 settings namespace 和 budget copy 路由**

```ruby
# config/routes.rb 完整內容如下（在現有路由中加入）：
Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  get "budget", to: "budget#index", as: :budget
  post "budget/copy_from_previous", to: "budget#copy_from_previous", as: :budget_copy_from_previous
  resources :budget_entries, only: [:create]
  get "budget_entries/edit", to: "budget_entries#edit", as: :edit_budget_entries
  resources :accounts, only: [:index, :show, :new, :create, :edit, :update] do
    resources :transactions, only: [:create, :destroy]
  end
  get "reports", to: "reports#index", as: :reports

  namespace :settings do
    resources :category_groups, only: [:new, :create, :edit, :update, :destroy] do
      resources :categories, only: [:new, :create, :edit, :update, :destroy]
    end
  end
  get "settings/categories", to: "settings/category_groups#index", as: :settings_categories

  root "budget#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 2: 確認路由正確**

```bash
bin/rails routes | grep settings
```

期望看到：
```
settings_categories GET /settings/categories
settings_category_groups POST /settings/category_groups
new_settings_category_group GET /settings/category_groups/new
edit_settings_category_group GET /settings/category_groups/:id/edit
settings_category_group PATCH/PUT/DELETE /settings/category_groups/:id
...
```

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add settings routes for category management and budget copy"
```

---

### Task 2: Settings::CategoryGroupsController + Request Spec

**Files:**
- Create: `app/controllers/settings/category_groups_controller.rb`
- Create: `spec/requests/settings/category_groups_spec.rb`

**Step 1: 先建立空 controller 讓 routes 不報錯**

```ruby
# app/controllers/settings/category_groups_controller.rb
module Settings
  class CategoryGroupsController < ApplicationController
  end
end
```

同時建立 controller 目錄：
```bash
mkdir -p app/controllers/settings
```

**Step 2: 寫失敗的 request spec**

```ruby
# spec/requests/settings/category_groups_spec.rb
require "rails_helper"

RSpec.describe "Settings::CategoryGroups", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /settings/categories" do
    it "returns 200" do
      get settings_categories_path
      expect(response).to have_http_status(:ok)
    end

    it "只顯示自己 household 的群組" do
      own_group   = create(:category_group, name: "我的群組", household: household)
      other_group = create(:category_group, name: "別人群組")
      get settings_categories_path
      expect(response.body).to include("我的群組")
      expect(response.body).not_to include("別人群組")
    end
  end

  describe "GET /settings/category_groups/new" do
    it "returns 200" do
      get new_settings_category_group_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /settings/category_groups" do
    it "新增群組並 redirect" do
      expect {
        post settings_category_groups_path,
             params: { category_group: { name: "日常生活" } }
      }.to change(CategoryGroup, :count).by(1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "新群組的 position 設為最大值 +1" do
      create(:category_group, household: household, position: 3)
      post settings_category_groups_path,
           params: { category_group: { name: "新群組" } }
      expect(CategoryGroup.last.position).to eq(4)
    end

    it "名稱空白時不建立" do
      expect {
        post settings_category_groups_path,
             params: { category_group: { name: "" } }
      }.not_to change(CategoryGroup, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /settings/category_groups/:id/edit" do
    it "returns 200" do
      group = create(:category_group, household: household)
      get edit_settings_category_group_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "無法存取其他 household 的群組" do
      other_group = create(:category_group)
      expect {
        get edit_settings_category_group_path(other_group)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /settings/category_groups/:id" do
    it "更新名稱並 redirect" do
      group = create(:category_group, household: household, name: "舊名")
      patch settings_category_group_path(group),
            params: { category_group: { name: "新名" } }
      expect(group.reload.name).to eq("新名")
      expect(response).to redirect_to(settings_categories_path)
    end
  end

  describe "DELETE /settings/category_groups/:id" do
    it "無類別時刪除成功並 redirect" do
      group = create(:category_group, household: household)
      expect {
        delete settings_category_group_path(group)
      }.to change(CategoryGroup, :count).by(-1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "有類別時拒絕刪除並 redirect 帶 alert" do
      group    = create(:category_group, household: household)
      _category = create(:category, category_group: group)
      expect {
        delete settings_category_group_path(group)
      }.not_to change(CategoryGroup, :count)
      expect(response).to redirect_to(settings_categories_path)
      follow_redirect!
      expect(response.body).to include("請先刪除群組內所有類別")
    end
  end
end
```

**Step 3: 執行測試確認失敗**

```bash
bundle exec rspec spec/requests/settings/category_groups_spec.rb
```

期望：多個 RoutingError 或 ActionController::RoutingError（controller 沒有 actions）

**Step 4: 實作完整 controller**

```ruby
# app/controllers/settings/category_groups_controller.rb
module Settings
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
        redirect_to settings_categories_path, notice: "群組已新增"
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
        redirect_to settings_categories_path, notice: "群組已更新"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category_group = Current.household.category_groups.find(params[:id])
      if @category_group.categories.any?
        redirect_to settings_categories_path, alert: "請先刪除群組內所有類別"
      else
        @category_group.destroy
        redirect_to settings_categories_path, notice: "群組已刪除"
      end
    end

    private

    def category_group_params
      params.require(:category_group).permit(:name)
    end
  end
end
```

**Step 5: 建立暫時空 view 讓 spec 能跑（index, new, edit）**

```bash
mkdir -p app/views/settings/category_groups
```

建立 `app/views/settings/category_groups/index.html.erb`（暫時空白）：
```erb
<p>settings index placeholder</p>
```

建立 `app/views/settings/category_groups/new.html.erb`（暫時空白）：
```erb
<p>settings new placeholder</p>
```

建立 `app/views/settings/category_groups/edit.html.erb`（暫時空白）：
```erb
<p>settings edit placeholder</p>
```

**Step 6: 執行測試確認通過**

```bash
bundle exec rspec spec/requests/settings/category_groups_spec.rb
```

期望：全部通過

**Step 7: Commit**

```bash
git add app/controllers/settings/ spec/requests/settings/ app/views/settings/
git commit -m "feat: add Settings::CategoryGroupsController with request specs"
```

---

### Task 3: Settings::CategoriesController + Request Spec

**Files:**
- Create: `app/controllers/settings/categories_controller.rb`
- Create: `spec/requests/settings/categories_spec.rb`

**Step 1: 寫失敗的 request spec**

```ruby
# spec/requests/settings/categories_spec.rb
require "rails_helper"

RSpec.describe "Settings::Categories", type: :request do
  let(:user)     { create(:user) }
  let(:household) { user.household }
  let(:group)    { create(:category_group, household: household) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /settings/category_groups/:id/categories/new" do
    it "returns 200" do
      get new_settings_category_group_category_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "無法存取其他 household 的群組" do
      other_group = create(:category_group)
      expect {
        get new_settings_category_group_category_path(other_group)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /settings/category_groups/:id/categories" do
    it "新增類別並 redirect" do
      expect {
        post settings_category_group_categories_path(group),
             params: { category: { name: "餐廳" } }
      }.to change(Category, :count).by(1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "新類別的 position 設為最大值 +1" do
      create(:category, category_group: group, position: 2)
      post settings_category_group_categories_path(group),
           params: { category: { name: "新類別" } }
      expect(Category.last.position).to eq(3)
    end

    it "名稱空白時不建立" do
      expect {
        post settings_category_group_categories_path(group),
             params: { category: { name: "" } }
      }.not_to change(Category, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /settings/category_groups/:id/categories/:id/edit" do
    it "returns 200" do
      category = create(:category, category_group: group)
      get edit_settings_category_group_category_path(group, category)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /settings/category_groups/:id/categories/:id" do
    it "更新類別名稱並 redirect" do
      category = create(:category, category_group: group, name: "舊名")
      patch settings_category_group_category_path(group, category),
            params: { category: { name: "新名" } }
      expect(category.reload.name).to eq("新名")
      expect(response).to redirect_to(settings_categories_path)
    end
  end

  describe "DELETE /settings/category_groups/:id/categories/:id" do
    it "無交易時刪除成功" do
      category = create(:category, category_group: group)
      expect {
        delete settings_category_group_category_path(group, category)
      }.to change(Category, :count).by(-1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "有交易時拒絕刪除並帶 alert" do
      category = create(:category, category_group: group)
      account  = create(:account, household: household, account_type: "budget")
      create(:transaction, account: account, category: category, amount: -500, date: Date.today)
      expect {
        delete settings_category_group_category_path(group, category)
      }.not_to change(Category, :count)
      expect(response).to redirect_to(settings_categories_path)
      follow_redirect!
      expect(response.body).to include("此類別有交易記錄")
    end
  end
end
```

**Step 2: 執行測試確認失敗**

```bash
bundle exec rspec spec/requests/settings/categories_spec.rb
```

**Step 3: 實作 controller**

```ruby
# app/controllers/settings/categories_controller.rb
module Settings
  class CategoriesController < ApplicationController
    before_action :set_category_group

    def new
      @category = @category_group.categories.build
    end

    def create
      @category = @category_group.categories.build(category_params)
      @category.position = @category_group.categories.maximum(:position).to_i + 1
      if @category.save
        redirect_to settings_categories_path, notice: "類別已新增"
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
        redirect_to settings_categories_path, notice: "類別已更新"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category = @category_group.categories.find(params[:id])
      if @category.transactions.any?
        redirect_to settings_categories_path, alert: "此類別有交易記錄，無法刪除"
      else
        @category.destroy
        redirect_to settings_categories_path, notice: "類別已刪除"
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
end
```

**Step 4: 建立暫時空 view**

```bash
mkdir -p app/views/settings/categories
```

建立 `app/views/settings/categories/new.html.erb`：
```erb
<p>categories new placeholder</p>
```

建立 `app/views/settings/categories/edit.html.erb`：
```erb
<p>categories edit placeholder</p>
```

**Step 5: 執行測試確認通過**

```bash
bundle exec rspec spec/requests/settings/categories_spec.rb
```

**Step 6: Commit**

```bash
git add app/controllers/settings/categories_controller.rb app/views/settings/categories/ spec/requests/settings/categories_spec.rb
git commit -m "feat: add Settings::CategoriesController with request specs"
```

---

### Task 4: Budget Copy Action + Request Spec

**Files:**
- Modify: `app/controllers/budget_controller.rb`
- Create: `spec/requests/budget_copy_spec.rb`

**Step 1: 寫失敗的 request spec**

```ruby
# spec/requests/budget_copy_spec.rb
require "rails_helper"

RSpec.describe "Budget copy_from_previous", type: :request do
  let(:user)     { create(:user) }
  let(:household) { user.household }
  let(:group)    { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: group) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /budget/copy_from_previous" do
    context "上月有預算且本月為 0" do
      it "複製預算並 redirect 帶 notice" do
        create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 3000)
        expect {
          post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        }.to change(BudgetEntry, :count).by(1)
        new_entry = BudgetEntry.find_by(category: category, year: 2026, month: 2)
        expect(new_entry.budgeted).to eq(3000)
        expect(response).to redirect_to(budget_path(year: 2026, month: 2))
        follow_redirect!
        expect(response.body).to include("複製")
      end
    end

    context "本月已有手動設定的預算（budgeted != 0）" do
      it "不覆蓋，跳過該類別" do
        create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 3000)
        existing = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 5000)
        post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        expect(existing.reload.budgeted).to eq(5000)
      end
    end

    context "上月沒有任何預算" do
      it "redirect 帶 alert 提示無可複製" do
        post budget_copy_from_previous_path, params: { year: 2026, month: 2 }
        expect(response).to redirect_to(budget_path(year: 2026, month: 2))
        follow_redirect!
        expect(response.body).to include("無預算可複製")
      end
    end

    context "1 月複製（跨年）" do
      it "從去年 12 月複製" do
        create(:budget_entry, category: category, year: 2025, month: 12, budgeted: 2000)
        post budget_copy_from_previous_path, params: { year: 2026, month: 1 }
        new_entry = BudgetEntry.find_by(category: category, year: 2026, month: 1)
        expect(new_entry.budgeted).to eq(2000)
      end
    end
  end
end
```

**Step 2: 執行測試確認失敗**

```bash
bundle exec rspec spec/requests/budget_copy_spec.rb
```

**Step 3: 在 BudgetController 加入 copy_from_previous action**

```ruby
# app/controllers/budget_controller.rb
class BudgetController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
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

  def copy_from_previous
    year  = params[:year].to_i
    month = params[:month].to_i
    prev_year  = month == 1 ? year - 1 : year
    prev_month = month == 1 ? 12 : month - 1

    categories = Current.household.category_groups
                        .includes(:categories)
                        .flat_map(&:categories)

    copied_count = 0
    categories.each do |category|
      prev_entry = BudgetEntry.find_by(category_id: category.id, year: prev_year, month: prev_month)
      next unless prev_entry&.budgeted&.nonzero?

      current_entry = BudgetEntry.find_or_initialize_by(
        category_id: category.id, year: year, month: month
      )
      next if current_entry.persisted? && current_entry.budgeted.nonzero?

      current_entry.budgeted = prev_entry.budgeted
      current_entry.save!
      copied_count += 1
    end

    if copied_count > 0
      redirect_to budget_path(year: year, month: month),
                  notice: "已從 #{prev_month} 月複製 #{copied_count} 個類別的預算"
    else
      redirect_to budget_path(year: year, month: month), alert: "上月無預算可複製"
    end
  end
end
```

**Step 4: 執行測試確認通過**

```bash
bundle exec rspec spec/requests/budget_copy_spec.rb
```

**Step 5: Commit**

```bash
git add app/controllers/budget_controller.rb spec/requests/budget_copy_spec.rb
git commit -m "feat: add BudgetController#copy_from_previous with request spec"
```

---

### Task 5: Settings 設定頁 Views

**Files:**
- Modify: `app/views/settings/category_groups/index.html.erb`
- Modify: `app/views/settings/category_groups/new.html.erb`
- Modify: `app/views/settings/category_groups/edit.html.erb`
- Create: `app/views/settings/categories/new.html.erb`
- Create: `app/views/settings/categories/edit.html.erb`

**Step 1: 實作 index.html.erb**

```erb
<%# app/views/settings/category_groups/index.html.erb %>
<div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-slate-900">類別管理</h1>
    <%= link_to new_settings_category_group_path,
          class: "flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors" do %>
      <%= icon "plus", classes: "w-4 h-4" %>
      新增群組
    <% end %>
  </div>

  <div class="space-y-4">
    <% @category_groups.each do |group| %>
      <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <%# Group header %>
        <div class="flex items-center justify-between px-5 py-3 bg-slate-50 border-b border-slate-100">
          <span class="text-sm font-semibold text-slate-700"><%= group.name %></span>
          <div class="flex items-center gap-2">
            <%= link_to edit_settings_category_group_path(group),
                  class: "text-xs text-slate-500 hover:text-indigo-600 transition-colors" do %>
              <%= icon "pencil", classes: "w-4 h-4" %>
            <% end %>
            <%= button_to settings_category_group_path(group), method: :delete,
                  data: { turbo_confirm: "確定要刪除「#{group.name}」群組嗎？" },
                  class: "text-xs text-slate-400 hover:text-red-500 transition-colors" do %>
              <%= icon "trash", classes: "w-4 h-4" %>
            <% end %>
          </div>
        </div>

        <%# Categories %>
        <div class="divide-y divide-slate-50">
          <% group.categories.each do |category| %>
            <div class="flex items-center justify-between px-5 py-2.5">
              <span class="text-sm text-slate-700"><%= category.name %></span>
              <div class="flex items-center gap-2">
                <%= link_to edit_settings_category_group_category_path(group, category),
                      class: "text-slate-400 hover:text-indigo-600 transition-colors" do %>
                  <%= icon "pencil", classes: "w-4 h-4" %>
                <% end %>
                <%= button_to settings_category_group_category_path(group, category), method: :delete,
                      data: { turbo_confirm: "確定要刪除「#{category.name}」嗎？" },
                      class: "text-slate-400 hover:text-red-500 transition-colors" do %>
                  <%= icon "trash", classes: "w-4 h-4" %>
                <% end %>
              </div>
            </div>
          <% end %>

          <%# Add category link %>
          <div class="px-5 py-2.5">
            <%= link_to new_settings_category_group_category_path(group),
                  class: "flex items-center gap-1.5 text-xs text-indigo-500 hover:text-indigo-700 transition-colors" do %>
              <%= icon "plus", classes: "w-3.5 h-3.5" %>
              新增類別
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <% if @category_groups.empty? %>
      <div class="text-center py-12 text-slate-400 text-sm">
        尚無類別群組，請先新增群組
      </div>
    <% end %>
  </div>
</div>
```

**Step 2: 實作 category_groups/new.html.erb**

```erb
<%# app/views/settings/category_groups/new.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">新增群組</h1>

  <%= form_with model: [:settings, @category_group], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :name, "群組名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :name, autofocus: true,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% @category_group.errors[:name].each do |msg| %>
        <p class="text-xs text-red-500 mt-1"><%= msg %></p>
      <% end %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "新增群組",
            class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "取消", settings_categories_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 3: 實作 category_groups/edit.html.erb**

```erb
<%# app/views/settings/category_groups/edit.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">編輯群組</h1>

  <%= form_with model: [:settings, @category_group], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :name, "群組名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :name, autofocus: true,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% @category_group.errors[:name].each do |msg| %>
        <p class="text-xs text-red-500 mt-1"><%= msg %></p>
      <% end %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "儲存",
            class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "取消", settings_categories_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 4: 實作 categories/new.html.erb**

```erb
<%# app/views/settings/categories/new.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-1">新增類別</h1>
  <p class="text-sm text-slate-500 mb-6">群組：<%= @category_group.name %></p>

  <%= form_with model: [:settings, @category_group, @category], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :name, "類別名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :name, autofocus: true,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% @category.errors[:name].each do |msg| %>
        <p class="text-xs text-red-500 mt-1"><%= msg %></p>
      <% end %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "新增類別",
            class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "取消", settings_categories_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 5: 實作 categories/edit.html.erb**

```erb
<%# app/views/settings/categories/edit.html.erb %>
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-1">編輯類別</h1>
  <p class="text-sm text-slate-500 mb-6">群組：<%= @category_group.name %></p>

  <%= form_with model: [:settings, @category_group, @category], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :name, "類別名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :name, autofocus: true,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% @category.errors[:name].each do |msg| %>
        <p class="text-xs text-red-500 mt-1"><%= msg %></p>
      <% end %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "儲存",
            class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "取消", settings_categories_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 6: Commit**

```bash
git add app/views/settings/
git commit -m "feat: add settings views for category group and category management"
```

---

### Task 6: 導覽列加入設定連結

**Files:**
- Modify: `app/views/shared/_nav.html.erb`

**Step 1: 在 sidebar nav 加設定連結，在手機 tab bar 加第四個 tab**

在 `_nav.html.erb` 的 `<nav>` 區塊（reports 連結之後）加入：

```erb
<%# 在 reports link 之後，sidebar nav 區塊內加入 %>
<%= link_to settings_categories_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?('/settings') ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
  <%= icon "cog-6-tooth", classes: "w-5 h-5 shrink-0" %>
  設定
<% end %>
```

在手機 `<nav>` 區塊（reports link 之後）加入：

```erb
<%= link_to settings_categories_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs #{request.path.start_with?('/settings') ? 'text-indigo-600' : 'text-slate-500'}" do %>
  <%= icon "cog-6-tooth", classes: "w-6 h-6" %>
  設定
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/shared/_nav.html.erb
git commit -m "feat: add settings link to sidebar and mobile nav"
```

---

### Task 7: 預算頁加入「複製上月」按鈕

**Files:**
- Modify: `app/views/budget/index.html.erb`

**Step 1: 在月份導覽列右側加按鈕**

找到月份導覽的 `<div class="flex items-center justify-between mb-6">` 區塊，把現有的兩個導覽連結和標題包在一個子 div 裡，右側加按鈕：

將現有：
```erb
<div class="flex items-center justify-between mb-6">
  <%= link_to budget_path(...) ... %>上個月<% end %>
  <h1 ...>...</h1>
  <%= link_to budget_path(...) ... %>下個月<% end %>
</div>
```

改為：
```erb
<div class="flex items-center justify-between mb-6">
  <div class="flex items-center gap-4">
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

  <%= button_to "複製上月", budget_copy_from_previous_path,
        params: { year: @year, month: @month },
        method: :post,
        class: "flex items-center gap-1.5 text-xs text-slate-500 hover:text-indigo-600 border border-slate-200 hover:border-indigo-300 px-3 py-1.5 rounded-lg transition-colors" do %>
    <%= icon "document-duplicate", classes: "w-3.5 h-3.5" %>
    複製上月
  <% end %>
</div>
```

注意：`button_to` 內已有 icon 和文字，但 `button_to` 的 block 用法需確認 Rails 版本支援。可改為簡化版：

```erb
<%= button_to budget_copy_from_previous_path,
      params: { year: @year, month: @month },
      method: :post,
      class: "flex items-center gap-1.5 text-xs text-slate-500 hover:text-indigo-600 border border-slate-200 hover:border-indigo-300 px-3 py-1.5 rounded-lg transition-colors" do %>
  <%= icon "document-duplicate", classes: "w-3.5 h-3.5" %>
  複製上月
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/budget/index.html.erb
git commit -m "feat: add copy-from-previous button to budget index"
```

---

### Task 8: 全部測試通過

**Step 1: 跑所有 spec**

```bash
bundle exec rspec
```

期望：所有測試通過，0 failures

**Step 2: 手動驗證（browser）**

1. 前往 `/settings/categories` → 應看到類別群組列表
2. 新增群組 → 應出現在列表
3. 新增類別到群組 → 應出現在群組下方
4. 編輯/刪除 → 正確行為
5. 前往 `/budget` → 應看到「複製上月」按鈕
6. 點擊複製上月 → flash 訊息正確顯示

**Step 3: 最終 commit（如有未提交的修改）**

```bash
bundle exec rspec
git status
```
