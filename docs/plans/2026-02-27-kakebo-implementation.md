# Kakebo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立一個家庭兩人共用的 YNAB 式記帳 App，實作完整預算先決邏輯。

**Architecture:** Rails 8.1 monolith，Hotwire (Turbo + Stimulus) 處理互動，PostgreSQL 儲存資料。`BudgetEntry` 每月記錄 `budgeted` 和 `carried_over`，`available` 即時計算。認證用 `has_secure_password` + Session。

**Tech Stack:** Ruby 3.4.2, Rails 8.1.2, PostgreSQL 17 (Docker), Hotwire, Tailwind CSS v4, RSpec + Capybara

---

## Task 1: 安裝測試框架

**Files:**
- Modify: `Gemfile`
- Create: `spec/rails_helper.rb`
- Create: `spec/spec_helper.rb`

**Step 1: 加入 RSpec 相關 gems**

在 `Gemfile` 的 `group :development, :test do` 區塊加入：

```ruby
group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

**Step 2: 安裝 gems**

```bash
bundle install
```

**Step 3: 初始化 RSpec**

```bash
bin/rails generate rspec:install
```

Expected output:
```
create  .rspec
create  spec
create  spec/spec_helper.rb
create  spec/rails_helper.rb
```

**Step 4: 設定 rails_helper.rb**

在 `spec/rails_helper.rb` 的 `RSpec.configure` 區塊加入：

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end
```

**Step 5: 確認 RSpec 可以執行**

```bash
bundle exec rspec
```

Expected: `0 examples, 0 failures`

**Step 6: Commit**

```bash
git add Gemfile Gemfile.lock .rspec spec/
git commit -m "chore: install rspec, factory_bot, capybara"
```

---

## Task 2: Household 和 User 模型

**Files:**
- Create: `db/migrate/TIMESTAMP_create_households.rb`
- Create: `db/migrate/TIMESTAMP_create_users.rb`
- Create: `app/models/household.rb`
- Create: `app/models/user.rb`
- Create: `spec/models/user_spec.rb`
- Create: `spec/factories/households.rb`
- Create: `spec/factories/users.rb`

**Step 1: 建立 migrations**

```bash
bin/rails generate migration CreateHouseholds name:string:null:false
bin/rails generate migration CreateUsers household:references name:string:null:false email:string:null:false password_digest:string:null:false
```

**Step 2: 加入 email 唯一索引**

編輯 `CreateUsers` migration，在 `create_table` 區塊末加入：

```ruby
t.index :email, unique: true
```

**Step 3: 執行 migration**

```bash
bin/rails db:migrate
```

**Step 4: 撰寫 User model spec（先寫測試）**

建立 `spec/models/user_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  it { should belong_to(:household) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email).case_insensitive }
  it { should have_secure_password }
end
```

**Step 5: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/user_spec.rb
```

Expected: FAIL（User 尚未定義）

**Step 6: 建立 models**

建立 `app/models/household.rb`：

```ruby
class Household < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :category_groups, dependent: :destroy
end
```

建立 `app/models/user.rb`：

```ruby
class User < ApplicationRecord
  belongs_to :household
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }

  normalizes :email, with: -> e { e.strip.downcase }
end
```

**Step 7: 建立 Factories**

建立 `spec/factories/households.rb`：

```ruby
FactoryBot.define do
  factory :household do
    name { "#{Faker::Name.last_name} 家" }
  end
end
```

建立 `spec/factories/users.rb`：

```ruby
FactoryBot.define do
  factory :user do
    association :household
    name { Faker::Name.full_name }
    email { Faker::Internet.unique.email }
    password { "password123" }
  end
end
```

**Step 8: 執行測試確認通過**

```bash
bundle exec rspec spec/models/user_spec.rb
```

Expected: 5 examples, 0 failures

**Step 9: Commit**

```bash
git add db/migrate/ app/models/household.rb app/models/user.rb spec/
git commit -m "feat: add Household and User models with auth"
```

---

## Task 3: Current Attributes 和認證 Controller

**Files:**
- Create: `app/models/current.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/sessions_controller.rb`
- Create: `app/views/sessions/new.html.erb`
- Modify: `config/routes.rb`

**Step 1: 建立 Current model**

建立 `app/models/current.rb`：

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user

  delegate :household, to: :user, allow_nil: true
end
```

**Step 2: 修改 ApplicationController**

```ruby
class ApplicationController < ActionController::Base
  before_action :require_login

  private

  def require_login
    unless (user_id = session[:user_id]) && (Current.user = User.find_by(id: user_id))
      redirect_to new_session_path, alert: "請先登入"
    end
  end
end
```

**Step 3: 建立 SessionsController**

建立 `app/controllers/sessions_controller.rb`：

```ruby
class SessionsController < ApplicationController
  skip_before_action :require_login

  def new
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "歡迎回來，#{user.name}！"
    else
      flash.now[:alert] = "Email 或密碼錯誤"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to new_session_path
  end
end
```

**Step 4: 設定 routes**

在 `config/routes.rb` 加入：

```ruby
Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  root "budget#index"
end
```

**Step 5: 建立登入頁面**

建立 `app/views/sessions/new.html.erb`：

```erb
<div class="min-h-screen flex items-center justify-center bg-gray-50">
  <div class="max-w-md w-full p-8 bg-white rounded-lg shadow">
    <h1 class="text-2xl font-bold text-center mb-6">家計簿 Kakebo</h1>

    <%= form_with url: session_path, class: "space-y-4" do |f| %>
      <div>
        <%= f.label :email, "Email", class: "block text-sm font-medium text-gray-700" %>
        <%= f.email_field :email, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm", required: true %>
      </div>
      <div>
        <%= f.label :password, "密碼", class: "block text-sm font-medium text-gray-700" %>
        <%= f.password_field :password, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm", required: true %>
      </div>
      <%= f.submit "登入", class: "w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 cursor-pointer" %>
    <% end %>
  </div>
</div>
```

**Step 6: 建立 seed 資料（兩個家庭成員）**

編輯 `db/seeds.rb`：

```ruby
household = Household.create!(name: "我們家")
User.create!(household: household, name: "Jerry", email: "jerry@example.com", password: "password123")
User.create!(household: household, name: "Rainy", email: "rainy@example.com", password: "password123")

puts "Seed 完成：Household #{household.name}，2 位成員"
```

**Step 7: 執行 seed**

```bash
bin/rails db:seed
```

**Step 8: Commit**

```bash
git add app/models/current.rb app/controllers/ app/views/sessions/ config/routes.rb db/seeds.rb
git commit -m "feat: add session-based authentication"
```

---

## Task 4: Account 模型

**Files:**
- Create: `db/migrate/TIMESTAMP_create_accounts.rb`
- Create: `app/models/account.rb`
- Create: `spec/models/account_spec.rb`
- Create: `spec/factories/accounts.rb`

**Step 1: 建立 migration**

```bash
bin/rails generate migration CreateAccounts household:references name:string:null:false account_type:string:null:false starting_balance:decimal balance:decimal active:boolean
```

編輯 migration 確認內容：

```ruby
def change
  create_table :accounts do |t|
    t.references :household, null: false, foreign_key: true
    t.string :name, null: false
    t.string :account_type, null: false
    t.decimal :starting_balance, precision: 12, scale: 2, default: "0.0", null: false
    t.decimal :balance, precision: 12, scale: 2, default: "0.0", null: false
    t.boolean :active, default: true, null: false
    t.timestamps
  end
end
```

**Step 2: 執行 migration**

```bash
bin/rails db:migrate
```

**Step 3: 撰寫 Account model spec**

建立 `spec/models/account_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe Account, type: :model do
  it { should belong_to(:household) }
  it { should have_many(:transactions).dependent(:destroy) }
  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:account_type).in_array(%w[budget tracking]) }

  describe ".budget" do
    it "returns only budget accounts" do
      household = create(:household)
      budget = create(:account, household: household, account_type: "budget")
      create(:account, household: household, account_type: "tracking")

      expect(Account.budget).to contain_exactly(budget)
    end
  end
end
```

**Step 4: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: FAIL

**Step 5: 建立 Account model**

建立 `app/models/account.rb`：

```ruby
class Account < ApplicationRecord
  belongs_to :household
  has_many :transactions, dependent: :destroy

  TYPES = %w[budget tracking].freeze

  validates :name, presence: true
  validates :account_type, inclusion: { in: TYPES }

  scope :budget, -> { where(account_type: "budget") }
  scope :tracking, -> { where(account_type: "tracking") }
  scope :active, -> { where(active: true) }
end
```

**Step 6: 建立 Factory**

建立 `spec/factories/accounts.rb`：

```ruby
FactoryBot.define do
  factory :account do
    association :household
    name { Faker::Bank.name }
    account_type { "budget" }
    starting_balance { 0 }
    balance { 0 }
    active { true }
  end
end
```

**Step 7: 執行測試確認通過**

```bash
bundle exec rspec spec/models/account_spec.rb
```

Expected: 5 examples, 0 failures

**Step 8: Commit**

```bash
git add db/migrate/ app/models/account.rb spec/
git commit -m "feat: add Account model"
```

---

## Task 5: CategoryGroup 和 Category 模型

**Files:**
- Create: `db/migrate/TIMESTAMP_create_category_groups.rb`
- Create: `db/migrate/TIMESTAMP_create_categories.rb`
- Create: `app/models/category_group.rb`
- Create: `app/models/category.rb`
- Create: `spec/models/category_spec.rb`
- Create: `spec/factories/category_groups.rb`
- Create: `spec/factories/categories.rb`

**Step 1: 建立 migrations**

```bash
bin/rails generate migration CreateCategoryGroups household:references name:string:null:false position:integer
bin/rails generate migration CreateCategories category_group:references name:string:null:false position:integer
```

**Step 2: 執行 migrations**

```bash
bin/rails db:migrate
```

**Step 3: 撰寫 Category model spec**

建立 `spec/models/category_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe Category, type: :model do
  it { should belong_to(:category_group) }
  it { should have_many(:budget_entries).dependent(:destroy) }
  it { should have_many(:transactions) }
  it { should validate_presence_of(:name) }
end
```

**Step 4: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/category_spec.rb
```

**Step 5: 建立 models**

建立 `app/models/category_group.rb`：

```ruby
class CategoryGroup < ApplicationRecord
  belongs_to :household
  has_many :categories, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  default_scope { order(:position) }
end
```

建立 `app/models/category.rb`：

```ruby
class Category < ApplicationRecord
  belongs_to :category_group
  has_many :budget_entries, dependent: :destroy
  has_many :transactions

  validates :name, presence: true

  default_scope { order(:position) }

  delegate :household, to: :category_group
end
```

**Step 6: 建立 Factories**

建立 `spec/factories/category_groups.rb`：

```ruby
FactoryBot.define do
  factory :category_group do
    association :household
    name { Faker::Commerce.department }
    sequence(:position)
  end
end
```

建立 `spec/factories/categories.rb`：

```ruby
FactoryBot.define do
  factory :category do
    association :category_group
    name { Faker::Commerce.product_name }
    sequence(:position)
  end
end
```

**Step 7: 執行測試確認通過**

```bash
bundle exec rspec spec/models/category_spec.rb
```

**Step 8: Commit**

```bash
git add db/migrate/ app/models/category_group.rb app/models/category.rb spec/
git commit -m "feat: add CategoryGroup and Category models"
```

---

## Task 6: BudgetEntry 模型（核心邏輯）

**Files:**
- Create: `db/migrate/TIMESTAMP_create_budget_entries.rb`
- Create: `app/models/budget_entry.rb`
- Create: `spec/models/budget_entry_spec.rb`
- Create: `spec/factories/budget_entries.rb`

**Step 1: 建立 migration**

```bash
bin/rails generate migration CreateBudgetEntries category:references year:integer:null:false month:integer:null:false budgeted:decimal carried_over:decimal
```

編輯 migration 加入 precision 和 unique index：

```ruby
def change
  create_table :budget_entries do |t|
    t.references :category, null: false, foreign_key: true
    t.integer :year, null: false
    t.integer :month, null: false
    t.decimal :budgeted, precision: 12, scale: 2, default: "0.0", null: false
    t.decimal :carried_over, precision: 12, scale: 2, default: "0.0", null: false
    t.timestamps
  end

  add_index :budget_entries, [:category_id, :year, :month], unique: true
end
```

**Step 2: 執行 migration**

```bash
bin/rails db:migrate
```

**Step 3: 撰寫 BudgetEntry spec（先寫測試）**

建立 `spec/models/budget_entry_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe BudgetEntry, type: :model do
  it { should belong_to(:category) }
  it { should validate_presence_of(:year) }
  it { should validate_presence_of(:month) }

  describe ".for_month" do
    it "returns entries for the given year/month" do
      entry = create(:budget_entry, year: 2026, month: 2)
      create(:budget_entry, year: 2026, month: 3)

      expect(BudgetEntry.for_month(2026, 2)).to contain_exactly(entry)
    end
  end

  describe "#available" do
    it "sums carried_over + budgeted + activity" do
      category = create(:category)
      account = create(:account, household: category.household)
      entry = create(:budget_entry, category: category, year: 2026, month: 2,
                     budgeted: 15_000, carried_over: 3_000)
      create(:transaction, account: account, category: category,
             amount: -5_000, date: Date.new(2026, 2, 15))

      expect(entry.available).to eq(13_000)
    end
  end

  describe "#activity" do
    it "sums transactions for the same category and month" do
      category = create(:category)
      account = create(:account, household: category.household)
      entry = create(:budget_entry, category: category, year: 2026, month: 2)
      create(:transaction, account: account, category: category, amount: -3_000, date: Date.new(2026, 2, 10))
      create(:transaction, account: account, category: category, amount: -2_000, date: Date.new(2026, 2, 20))
      create(:transaction, account: account, category: category, amount: -1_000, date: Date.new(2026, 3, 1))

      expect(entry.activity).to eq(-5_000)
    end
  end
end
```

**Step 4: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/budget_entry_spec.rb
```

**Step 5: 建立 BudgetEntry model**

建立 `app/models/budget_entry.rb`：

```ruby
class BudgetEntry < ApplicationRecord
  belongs_to :category

  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :category_id, uniqueness: { scope: [:year, :month] }

  scope :for_month, ->(year, month) { where(year: year, month: month) }

  def activity
    category.transactions
            .where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
            .sum(:amount)
  end

  def available
    carried_over + budgeted + activity
  end
end
```

**Step 6: 建立 Factory**

建立 `spec/factories/budget_entries.rb`：

```ruby
FactoryBot.define do
  factory :budget_entry do
    association :category
    year { 2026 }
    month { 2 }
    budgeted { 0 }
    carried_over { 0 }
  end
end
```

**Step 7: 執行測試確認通過**

```bash
bundle exec rspec spec/models/budget_entry_spec.rb
```

Expected: all pass

**Step 8: Commit**

```bash
git add db/migrate/ app/models/budget_entry.rb spec/
git commit -m "feat: add BudgetEntry model with available calculation"
```

---

## Task 7: Transaction 模型

**Files:**
- Create: `db/migrate/TIMESTAMP_create_transactions.rb`
- Create: `app/models/transaction.rb`
- Create: `spec/models/transaction_spec.rb`
- Create: `spec/factories/transactions.rb`

**Step 1: 建立 migration**

```bash
bin/rails generate migration CreateTransactions account:references category:references amount:decimal date:date:null:false memo:string transfer_pair_id:integer
```

編輯 migration：

```ruby
def change
  create_table :transactions do |t|
    t.references :account, null: false, foreign_key: true
    t.references :category, foreign_key: true  # nullable（income 交易 category 為 nil）
    t.decimal :amount, precision: 12, scale: 2, null: false
    t.date :date, null: false
    t.string :memo
    t.integer :transfer_pair_id  # 轉帳時兩筆互相對應

    t.timestamps
  end

  add_index :transactions, :date
  add_index :transactions, :transfer_pair_id
end
```

**Step 2: 執行 migration**

```bash
bin/rails db:migrate
```

**Step 3: 撰寫 Transaction spec**

建立 `spec/models/transaction_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe Transaction, type: :model do
  it { should belong_to(:account) }
  it { should belong_to(:category).optional }
  it { should validate_presence_of(:amount) }
  it { should validate_presence_of(:date) }

  describe ".for_month" do
    it "returns transactions in the given month" do
      account = create(:account)
      t1 = create(:transaction, account: account, date: Date.new(2026, 2, 15))
      create(:transaction, account: account, date: Date.new(2026, 3, 1))

      expect(Transaction.for_month(2026, 2)).to contain_exactly(t1)
    end
  end

  describe "income transaction" do
    it "allows nil category for income" do
      account = create(:account)
      transaction = build(:transaction, account: account, category: nil, amount: 80_000)
      expect(transaction).to be_valid
    end
  end
end
```

**Step 4: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/transaction_spec.rb
```

**Step 5: 建立 Transaction model**

建立 `app/models/transaction.rb`：

```ruby
class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  validates :amount, presence: true
  validates :date, presence: true

  scope :for_month, ->(year, month) {
    where("EXTRACT(year FROM date) = ? AND EXTRACT(month FROM date) = ?", year, month)
  }

  scope :income, -> { where(category_id: nil) }
  scope :expense, -> { where.not(category_id: nil) }
  scope :recent, -> { order(date: :desc, created_at: :desc) }

  delegate :household, to: :account

  def transfer?
    transfer_pair_id.present?
  end

  def income?
    category_id.nil? && !transfer?
  end
end
```

**Step 6: 建立 Factory**

建立 `spec/factories/transactions.rb`：

```ruby
FactoryBot.define do
  factory :transaction do
    association :account
    association :category
    amount { -1_000 }
    date { Date.today }
    memo { Faker::Lorem.sentence }
  end
end
```

**Step 7: 執行測試確認通過**

```bash
bundle exec rspec spec/models/transaction_spec.rb
```

**Step 8: 更新 Account 的 balance 邏輯**

在 `app/models/account.rb` 加入：

```ruby
def recalculate_balance!
  calculated = starting_balance + transactions.sum(:amount)
  update_columns(balance: calculated)
end
```

**Step 9: Commit**

```bash
git add db/migrate/ app/models/transaction.rb app/models/account.rb spec/
git commit -m "feat: add Transaction model"
```

---

## Task 8: BudgetEntryRecalculationJob（Rollover 邏輯）

**Files:**
- Create: `app/jobs/budget_entry_recalculation_job.rb`
- Create: `spec/jobs/budget_entry_recalculation_job_spec.rb`

**Step 1: 撰寫 Job spec**

建立 `spec/jobs/budget_entry_recalculation_job_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe BudgetEntryRecalculationJob, type: :job do
  describe "#perform" do
    it "updates carried_over for all subsequent months" do
      household = create(:household)
      group = create(:category_group, household: household)
      category = create(:category, category_group: group)
      account = create(:account, household: household)

      # 1月 entry：budgeted 5000，沒有交易，available = 5000
      jan = create(:budget_entry, category: category, year: 2026, month: 1, budgeted: 5_000, carried_over: 0)
      # 2月 entry：carried_over 還是舊的 0，job 應該把它更新成 5000
      feb = create(:budget_entry, category: category, year: 2026, month: 2, budgeted: 3_000, carried_over: 0)

      BudgetEntryRecalculationJob.new.perform(category.id, 2026, 1)

      expect(feb.reload.carried_over).to eq(5_000)
    end
  end
end
```

**Step 2: 執行測試確認失敗**

```bash
bundle exec rspec spec/jobs/budget_entry_recalculation_job_spec.rb
```

**Step 3: 建立 Job**

建立 `app/jobs/budget_entry_recalculation_job.rb`：

```ruby
class BudgetEntryRecalculationJob < ApplicationJob
  queue_as :default

  def perform(category_id, from_year, from_month)
    category = Category.find(category_id)

    # 取得從指定月份開始（含）的所有 entries，按時間排序
    entries = category.budget_entries
                      .where("(year > ?) OR (year = ? AND month >= ?)", from_year, from_year, from_month)
                      .order(:year, :month)

    previous_available = previous_month_available(category, from_year, from_month)

    entries.each do |entry|
      entry.update_columns(carried_over: previous_available)
      previous_available = entry.available
    end
  end

  private

  def previous_month_available(category, year, month)
    prev_year, prev_month = month == 1 ? [year - 1, 12] : [year, month - 1]
    prev_entry = category.budget_entries.find_by(year: prev_year, month: prev_month)
    prev_entry&.available || 0
  end
end
```

**Step 4: 執行測試確認通過**

```bash
bundle exec rspec spec/jobs/budget_entry_recalculation_job_spec.rb
```

**Step 5: 在 Transaction after_commit 觸發 Job**

在 `app/models/transaction.rb` 加入：

```ruby
after_commit :trigger_recalculation, on: [:create, :update, :destroy]

private

def trigger_recalculation
  return if category_id.nil?
  BudgetEntryRecalculationJob.perform_later(
    category_id,
    date.year,
    date.month
  )
end
```

**Step 6: Commit**

```bash
git add app/jobs/ spec/jobs/ app/models/transaction.rb
git commit -m "feat: add BudgetEntryRecalculationJob for rollover logic"
```

---

## Task 9: Ready to Assign 計算

**Files:**
- Create: `app/models/concerns/ready_to_assign.rb`
- Modify: `app/models/household.rb`
- Create: `spec/models/concerns/ready_to_assign_spec.rb`

**Step 1: 撰寫 RTA spec**

建立 `spec/models/concerns/ready_to_assign_spec.rb`：

```ruby
require "rails_helper"

RSpec.describe "Household#ready_to_assign" do
  it "equals budget account balances minus sum of all available" do
    household = create(:household)
    group = create(:category_group, household: household)
    cat1 = create(:category, category_group: group)
    cat2 = create(:category, category_group: group)
    account = create(:account, household: household, account_type: "budget", balance: 100_000)

    create(:budget_entry, category: cat1, year: 2026, month: 2, budgeted: 30_000, carried_over: 0)
    create(:budget_entry, category: cat2, year: 2026, month: 2, budgeted: 20_000, carried_over: 0)

    expect(household.ready_to_assign(2026, 2)).to eq(50_000)
  end
end
```

**Step 2: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/concerns/ready_to_assign_spec.rb
```

**Step 3: 實作 RTA 方法**

在 `app/models/household.rb` 加入：

```ruby
def ready_to_assign(year, month)
  total_budget_balance = accounts.budget.active.sum(:balance)
  total_available = category_groups
                      .joins(categories: :budget_entries)
                      .where(budget_entries: { year: year, month: month })
                      .sum("budget_entries.carried_over + budget_entries.budgeted")
  # activity 部分透過 transactions 計算
  total_activity = Transaction
                     .joins(:account, :category)
                     .where(accounts: { household_id: id, account_type: "budget" })
                     .where("EXTRACT(year FROM transactions.date) = ?", year)
                     .where("EXTRACT(month FROM transactions.date) = ?", month)
                     .sum(:amount)

  total_budget_balance - total_available - total_activity
end
```

**Step 4: 執行測試確認通過**

```bash
bundle exec rspec spec/models/concerns/ready_to_assign_spec.rb
```

**Step 5: Commit**

```bash
git add app/models/household.rb spec/models/
git commit -m "feat: add ready_to_assign calculation on Household"
```

---

## Task 10: 應用程式 Layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/shared/_nav.html.erb`
- Create: `app/controllers/budget_controller.rb`

**Step 1: 建立基本 BudgetController**

建立 `app/controllers/budget_controller.rb`：

```ruby
class BudgetController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @household = Current.household
    @ready_to_assign = @household.ready_to_assign(@year, @month)
    @category_groups = @household.category_groups.includes(categories: :budget_entries)
  end
end
```

**Step 2: 更新 application layout**

編輯 `app/views/layouts/application.html.erb`：

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Kakebo</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="bg-gray-100 min-h-screen">
    <% if Current.user %>
      <%= render "shared/nav" %>
    <% end %>

    <% if notice %>
      <div class="bg-green-100 text-green-800 px-4 py-2 text-sm"><%= notice %></div>
    <% end %>
    <% if alert %>
      <div class="bg-red-100 text-red-800 px-4 py-2 text-sm"><%= alert %></div>
    <% end %>

    <%= yield %>
  </body>
</html>
```

**Step 3: 建立導覽列**

建立 `app/views/shared/_nav.html.erb`：

```erb
<nav class="bg-green-700 text-white px-6 py-3 flex items-center justify-between">
  <div class="flex items-center gap-6">
    <span class="font-bold text-lg">家計簿</span>
    <%= link_to "預算", root_path, class: "hover:text-green-200 text-sm" %>
    <%= link_to "帳戶", accounts_path, class: "hover:text-green-200 text-sm" %>
    <%= link_to "報表", reports_path, class: "hover:text-green-200 text-sm" %>
  </div>
  <div class="flex items-center gap-4 text-sm">
    <span><%= Current.user.name %></span>
    <%= button_to "登出", session_path, method: :delete, class: "hover:text-green-200" %>
  </div>
</nav>
```

**Step 4: 建立 budget index view（基本骨架）**

建立 `app/views/budget/index.html.erb`：

```erb
<div class="max-w-5xl mx-auto p-6">
  <%# 月份導航 %>
  <div class="flex items-center justify-between mb-6">
    <%= link_to "← 上個月", budget_path(year: @year, month: @month == 1 ? 12 : @month - 1,
                                         year: @month == 1 ? @year - 1 : @year),
                class: "text-green-700 hover:underline" %>
    <h2 class="text-xl font-bold"><%= "#{@year} 年 #{@month} 月" %></h2>
    <%= link_to "下個月 →", budget_path(year: @month == 12 ? @year + 1 : @year,
                                         month: @month == 12 ? 1 : @month + 1),
                class: "text-green-700 hover:underline" %>
  </div>

  <%# Ready to Assign %>
  <div class="bg-green-600 text-white rounded-lg p-4 mb-6">
    <p class="text-sm opacity-80">Ready to Assign</p>
    <p class="text-3xl font-bold"><%= number_to_currency(@ready_to_assign, unit: "NT$", precision: 0) %></p>
  </div>

  <%# 類別列表 %>
  <div class="bg-white rounded-lg shadow overflow-hidden">
    <table class="w-full">
      <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
        <tr>
          <th class="text-left px-4 py-3">類別</th>
          <th class="text-right px-4 py-3">已分配</th>
          <th class="text-right px-4 py-3">本月支出</th>
          <th class="text-right px-4 py-3">可用</th>
        </tr>
      </thead>
      <tbody>
        <% @category_groups.each do |group| %>
          <tr class="bg-gray-100">
            <td colspan="4" class="px-4 py-2 font-semibold text-sm text-gray-700"><%= group.name %></td>
          </tr>
          <% group.categories.each do |category| %>
            <% entry = category.budget_entries.find { |e| e.year == @year && e.month == @month } %>
            <% budgeted = entry&.budgeted || 0 %>
            <% activity = entry&.activity || 0 %>
            <% available = entry&.available || 0 %>
            <tr class="border-t hover:bg-gray-50">
              <td class="px-4 py-3 text-sm"><%= category.name %></td>
              <td class="px-4 py-3 text-right text-sm">
                <%= number_to_currency(budgeted, unit: "NT$", precision: 0) %>
              </td>
              <td class="px-4 py-3 text-right text-sm text-red-600">
                <%= number_to_currency(activity, unit: "NT$", precision: 0) %>
              </td>
              <td class="px-4 py-3 text-right text-sm font-medium <%= available < 0 ? 'text-red-600' : 'text-green-700' %>">
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

**Step 5: 更新 routes**

```ruby
Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  get "budget", to: "budget#index", as: :budget
  resources :accounts
  get "reports", to: "reports#index", as: :reports
  root "budget#index"
end
```

**Step 6: Commit**

```bash
git add app/controllers/budget_controller.rb app/views/ config/routes.rb
git commit -m "feat: add budget page basic layout"
```

---

## Task 11: Accounts Controller 和 Views

**Files:**
- Create: `app/controllers/accounts_controller.rb`
- Create: `app/views/accounts/`

**Step 1: 建立 AccountsController**

建立 `app/controllers/accounts_controller.rb`：

```ruby
class AccountsController < ApplicationController
  before_action :set_account, only: [:show, :edit, :update]

  def index
    @budget_accounts = Current.household.accounts.budget.active.order(:name)
    @tracking_accounts = Current.household.accounts.tracking.active.order(:name)
  end

  def show
    @transactions = @account.transactions.recent.limit(50)
    @new_transaction = Transaction.new(account: @account, date: Date.today)
  end

  def new
    @account = Account.new
  end

  def create
    @account = Current.household.accounts.build(account_params)
    if @account.save
      redirect_to accounts_path, notice: "帳戶已建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "帳戶已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :starting_balance)
  end
end
```

**Step 2: 建立 TransactionsController**

建立 `app/controllers/transactions_controller.rb`：

```ruby
class TransactionsController < ApplicationController
  before_action :set_account

  def create
    @transaction = @account.transactions.build(transaction_params)
    if @transaction.save
      @account.recalculate_balance!
      redirect_to account_path(@account), notice: "交易已新增"
    else
      redirect_to account_path(@account), alert: "請填寫必要欄位"
    end
  end

  def destroy
    transaction = @account.transactions.find(params[:id])
    transaction.destroy
    @account.recalculate_balance!
    redirect_to account_path(@account), notice: "交易已刪除"
  end

  private

  def set_account
    @account = Current.household.accounts.find(params[:account_id])
  end

  def transaction_params
    params.require(:transaction).permit(:category_id, :amount, :date, :memo)
  end
end
```

**Step 3: 更新 routes 加入 transactions**

```ruby
resources :accounts do
  resources :transactions, only: [:create, :destroy]
end
```

**Step 4: 建立 accounts views**

建立 `app/views/accounts/index.html.erb`：

```erb
<div class="max-w-5xl mx-auto p-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">帳戶</h1>
    <%= link_to "新增帳戶", new_account_path, class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700" %>
  </div>

  <div class="grid grid-cols-2 gap-6">
    <div>
      <h2 class="font-semibold text-gray-700 mb-3">預算帳戶</h2>
      <% @budget_accounts.each do |account| %>
        <%= link_to account_path(account), class: "block bg-white rounded shadow p-4 mb-2 hover:shadow-md" do %>
          <div class="flex justify-between">
            <span><%= account.name %></span>
            <span class="font-bold"><%= number_to_currency(account.balance, unit: "NT$", precision: 0) %></span>
          </div>
        <% end %>
      <% end %>
    </div>
    <div>
      <h2 class="font-semibold text-gray-700 mb-3">追蹤帳戶</h2>
      <% @tracking_accounts.each do |account| %>
        <%= link_to account_path(account), class: "block bg-white rounded shadow p-4 mb-2 hover:shadow-md" do %>
          <div class="flex justify-between">
            <span><%= account.name %></span>
            <span class="font-bold"><%= number_to_currency(account.balance, unit: "NT$", precision: 0) %></span>
          </div>
        <% end %>
      <% end %>
    </div>
  </div>
</div>
```

建立 `app/views/accounts/show.html.erb`：

```erb
<div class="max-w-5xl mx-auto p-6">
  <div class="flex items-center gap-4 mb-6">
    <%= link_to "← 帳戶列表", accounts_path, class: "text-green-700 hover:underline text-sm" %>
    <h1 class="text-2xl font-bold"><%= @account.name %></h1>
    <span class="text-2xl font-bold text-green-700">
      <%= number_to_currency(@account.balance, unit: "NT$", precision: 0) %>
    </span>
  </div>

  <%# 新增交易表單 %>
  <div class="bg-white rounded-lg shadow p-4 mb-6">
    <h2 class="font-semibold mb-3">新增交易</h2>
    <%= form_with url: account_transactions_path(@account) do |f| %>
      <div class="grid grid-cols-4 gap-3">
        <div>
          <%= f.date_field :date, value: Date.today, class: "w-full border rounded px-2 py-1 text-sm" %>
        </div>
        <div>
          <%= f.select :category_id,
                options_for_select(Current.household.category_groups.includes(:categories).flat_map { |g|
                  g.categories.map { |c| ["#{g.name} / #{c.name}", c.id] }
                }),
                { include_blank: "收入（直接到 RTA）" },
                class: "w-full border rounded px-2 py-1 text-sm" %>
        </div>
        <div>
          <%= f.number_field :amount, placeholder: "金額（支出用負數）", step: 1,
                             class: "w-full border rounded px-2 py-1 text-sm" %>
        </div>
        <div class="flex gap-2">
          <%= f.text_field :memo, placeholder: "備註", class: "flex-1 border rounded px-2 py-1 text-sm" %>
          <%= f.submit "新增", class: "bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700" %>
        </div>
      </div>
    <% end %>
  </div>

  <%# 交易清單 %>
  <div class="bg-white rounded-lg shadow overflow-hidden">
    <table class="w-full">
      <thead class="bg-gray-50 text-xs text-gray-500 uppercase">
        <tr>
          <th class="text-left px-4 py-3">日期</th>
          <th class="text-left px-4 py-3">備註</th>
          <th class="text-left px-4 py-3">類別</th>
          <th class="text-right px-4 py-3">金額</th>
          <th class="px-4 py-3"></th>
        </tr>
      </thead>
      <tbody>
        <% @transactions.each do |t| %>
          <tr class="border-t hover:bg-gray-50">
            <td class="px-4 py-3 text-sm"><%= t.date.strftime("%m/%d") %></td>
            <td class="px-4 py-3 text-sm"><%= t.memo %></td>
            <td class="px-4 py-3 text-sm text-gray-500"><%= t.category&.name || "收入" %></td>
            <td class="px-4 py-3 text-right text-sm font-medium <%= t.amount < 0 ? 'text-red-600' : 'text-green-700' %>">
              <%= number_to_currency(t.amount, unit: "NT$", precision: 0) %>
            </td>
            <td class="px-4 py-3 text-right">
              <%= button_to "刪除", account_transaction_path(@account, t),
                            method: :delete,
                            data: { turbo_confirm: "確定刪除？" },
                            class: "text-xs text-gray-400 hover:text-red-600" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

**Step 5: 建立 new/edit account views（略，使用 form partial）**

建立 `app/views/accounts/_form.html.erb`：

```erb
<%= form_with model: account, class: "space-y-4" do |f| %>
  <div>
    <%= f.label :name, "帳戶名稱" %>
    <%= f.text_field :name, class: "mt-1 block w-full border rounded px-3 py-2" %>
  </div>
  <div>
    <%= f.label :account_type, "類型" %>
    <%= f.select :account_type, [["預算帳戶", "budget"], ["追蹤帳戶", "tracking"]],
                 {}, class: "mt-1 block w-full border rounded px-3 py-2" %>
  </div>
  <div>
    <%= f.label :starting_balance, "起始餘額" %>
    <%= f.number_field :starting_balance, step: 1, class: "mt-1 block w-full border rounded px-3 py-2" %>
  </div>
  <%= f.submit class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700 cursor-pointer" %>
<% end %>
```

建立 `app/views/accounts/new.html.erb`：

```erb
<div class="max-w-md mx-auto p-6">
  <h1 class="text-2xl font-bold mb-6">新增帳戶</h1>
  <%= render "form", account: @account %>
</div>
```

**Step 6: Commit**

```bash
git add app/controllers/accounts_controller.rb app/controllers/transactions_controller.rb app/views/accounts/ config/routes.rb
git commit -m "feat: add accounts and transactions CRUD"
```

---

## Task 12: 基本 Seed 資料

**Files:**
- Modify: `db/seeds.rb`

**Step 1: 補充完整 Seed 資料**

更新 `db/seeds.rb`：

```ruby
household = Household.find_or_create_by!(name: "我們家")
jerry = User.find_or_create_by!(email: "jerry@example.com") do |u|
  u.household = household
  u.name = "Jerry"
  u.password = "password123"
end
User.find_or_create_by!(email: "rainy@example.com") do |u|
  u.household = household
  u.name = "Rainy"
  u.password = "password123"
end

# 帳戶
checking = Account.find_or_create_by!(household: household, name: "玉山銀行") do |a|
  a.account_type = "budget"
  a.starting_balance = 50_000
  a.balance = 50_000
end
Account.find_or_create_by!(household: household, name: "現金") do |a|
  a.account_type = "budget"
  a.starting_balance = 5_000
  a.balance = 5_000
end

# 類別群組和類別
bills = CategoryGroup.find_or_create_by!(household: household, name: "固定支出", position: 1)
Category.find_or_create_by!(category_group: bills, name: "房租", position: 1)
Category.find_or_create_by!(category_group: bills, name: "電費", position: 2)
Category.find_or_create_by!(category_group: bills, name: "網路費", position: 3)

daily = CategoryGroup.find_or_create_by!(household: household, name: "日常開銷", position: 2)
food = Category.find_or_create_by!(category_group: daily, name: "餐費", position: 1)
Category.find_or_create_by!(category_group: daily, name: "日用品", position: 2)
Category.find_or_create_by!(category_group: daily, name: "交通", position: 3)

savings = CategoryGroup.find_or_create_by!(household: household, name: "儲蓄目標", position: 3)
Category.find_or_create_by!(category_group: savings, name: "旅遊基金", position: 1)
Category.find_or_create_by!(category_group: savings, name: "緊急備用金", position: 2)

# 2月的 BudgetEntry
current_year, current_month = Date.today.year, Date.today.month
[bills, daily, savings].each do |group|
  group.categories.each do |cat|
    BudgetEntry.find_or_create_by!(category: cat, year: current_year, month: current_month)
  end
end

puts "Seed 完成！登入帳號：jerry@example.com / password123"
```

**Step 2: 重新執行 seed**

```bash
bin/rails db:seed
```

**Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "chore: add comprehensive seed data"
```

---

## Task 13: 啟動並確認基本功能

**Step 1: 確認所有測試通過**

```bash
bundle exec rspec
```

Expected: all pass

**Step 2: 啟動開發伺服器**

```bash
bin/dev
```

**Step 3: 開啟瀏覽器確認**

訪問 `http://localhost:3000`，應該跳轉到登入頁。
用 `jerry@example.com / password123` 登入，應該看到預算頁面。

**Step 4: Commit（如有任何修正）**

```bash
git add -A
git commit -m "fix: initial integration fixes"
```

---

## Task 14: Reports 頁面（基本版）

**Files:**
- Create: `app/controllers/reports_controller.rb`
- Create: `app/views/reports/index.html.erb`

**Step 1: 建立 ReportsController**

建立 `app/controllers/reports_controller.rb`：

```ruby
class ReportsController < ApplicationController
  def index
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month

    @spending_by_category = Transaction
      .joins(:account, :category)
      .where(accounts: { household_id: Current.household.id })
      .for_month(@year, @month)
      .where.not(category_id: nil)
      .group("categories.name")
      .sum(:amount)
      .transform_values(&:abs)
      .sort_by { |_, v| -v }
  end
end
```

**Step 2: 建立 reports index view**

建立 `app/views/reports/index.html.erb`：

```erb
<div class="max-w-5xl mx-auto p-6">
  <h1 class="text-2xl font-bold mb-6"><%= "#{@year} 年 #{@month} 月 報表" %></h1>

  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="font-semibold mb-4">各類別支出</h2>
    <% total = @spending_by_category.sum { |_, v| v } %>
    <% @spending_by_category.each do |name, amount| %>
      <div class="flex items-center gap-4 mb-3">
        <span class="w-32 text-sm truncate"><%= name %></span>
        <div class="flex-1 bg-gray-200 rounded-full h-4">
          <div class="bg-green-500 h-4 rounded-full"
               style="width: <%= total > 0 ? (amount / total * 100).round : 0 %>%"></div>
        </div>
        <span class="w-24 text-right text-sm font-medium">
          <%= number_to_currency(amount, unit: "NT$", precision: 0) %>
        </span>
      </div>
    <% end %>
    <div class="border-t pt-3 mt-3 flex justify-between font-semibold">
      <span>總計</span>
      <span><%= number_to_currency(total, unit: "NT$", precision: 0) %></span>
    </div>
  </div>
</div>
```

**Step 3: Commit**

```bash
git add app/controllers/reports_controller.rb app/views/reports/
git commit -m "feat: add basic reports page"
```

---

## 完成後確認清單

- [ ] `bundle exec rspec` 全部通過
- [ ] `docker compose up -d && bin/dev` 可以啟動
- [ ] 可以登入、看到預算頁面
- [ ] 可以新增帳戶、交易
- [ ] BudgetEntry 的 `available` 計算正確
- [ ] RTA 顯示正確

---

## 環境提醒

```bash
# 開始開發
docker compose up -d
bin/dev

# 結束
docker compose down

# 執行測試
bundle exec rspec
```
