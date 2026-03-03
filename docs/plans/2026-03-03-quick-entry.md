# Quick Entry（快速記帳）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users type natural language like "紀錄 Jerry 支付 家樂福採買 100" and automatically create a transaction with the right category and account, using configurable keyword mappings.

**Architecture:** Rule-based regex parser extracts payer/description/amount from text input. A polymorphic `QuickEntryMapping` table maps keywords to Categories or Accounts. A confirmation screen lets users review/edit before saving, with an option to save new mappings. Settings CRUD manages mappings.

**Tech Stack:** Rails 8.1, RSpec, FactoryBot, Capybara system tests, Tailwind CSS v4, Turbo

---

### Task 1: QuickEntryMapping Model + Migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_quick_entry_mappings.rb`
- Create: `app/models/quick_entry_mapping.rb`
- Create: `spec/models/quick_entry_mapping_spec.rb`
- Create: `spec/factories/quick_entry_mappings.rb`
- Modify: `app/models/household.rb` (add association)

**Step 1: Write the failing test**

Create `spec/models/quick_entry_mapping_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe QuickEntryMapping, type: :model do
  it { should belong_to(:household) }
  it { should belong_to(:target) }
  it { should validate_presence_of(:keyword) }

  describe "target_type validation" do
    let(:household) { create(:household) }
    let(:category) { create(:category, category_group: create(:category_group, household: household)) }

    it "allows Category target_type" do
      mapping = build(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      expect(mapping).to be_valid
    end

    it "allows Account target_type" do
      account = create(:account, household: household)
      mapping = build(:quick_entry_mapping, household: household, target: account, keyword: "Jerry")
      expect(mapping).to be_valid
    end

    it "rejects invalid target_type" do
      mapping = QuickEntryMapping.new(household: household, keyword: "test", target_type: "User", target_id: 1)
      expect(mapping).not_to be_valid
      expect(mapping.errors[:target_type]).to be_present
    end
  end

  describe "keyword uniqueness" do
    let(:household) { create(:household) }
    let(:category) { create(:category, category_group: create(:category_group, household: household)) }

    it "rejects duplicate keyword within same household and target_type" do
      create(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      duplicate = build(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      expect(duplicate).not_to be_valid
    end

    it "allows same keyword for different target_types in same household" do
      account = create(:account, household: household)
      create(:quick_entry_mapping, household: household, target: category, keyword: "Jerry")
      mapping = build(:quick_entry_mapping, household: household, target: account, keyword: "Jerry")
      expect(mapping).to be_valid
    end

    it "allows same keyword in different households" do
      other_household = create(:household)
      other_category = create(:category, category_group: create(:category_group, household: other_household))
      create(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      mapping = build(:quick_entry_mapping, household: other_household, target: other_category, keyword: "食物")
      expect(mapping).to be_valid
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/quick_entry_mapping_spec.rb`
Expected: FAIL — model and table don't exist yet

**Step 3: Generate migration and create model**

Run: `bin/rails generate migration CreateQuickEntryMappings household:references keyword:string target_type:string target_id:bigint`

Then edit the migration to add index:

```ruby
class CreateQuickEntryMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :quick_entry_mappings do |t|
      t.references :household, null: false, foreign_key: true
      t.string :keyword, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.timestamps
    end

    add_index :quick_entry_mappings, [ :household_id, :target_type, :keyword ], unique: true, name: "idx_quick_entry_mappings_unique_keyword"
  end
end
```

Run: `bin/rails db:migrate`

Create `app/models/quick_entry_mapping.rb`:

```ruby
class QuickEntryMapping < ApplicationRecord
  ALLOWED_TARGET_TYPES = %w[Category Account].freeze

  belongs_to :household
  belongs_to :target, polymorphic: true

  validates :keyword, presence: true
  validates :keyword, uniqueness: { scope: [ :household_id, :target_type ] }
  validates :target_type, inclusion: { in: ALLOWED_TARGET_TYPES }
end
```

Add association to `app/models/household.rb`:

```ruby
has_many :quick_entry_mappings, dependent: :destroy
```

Create `spec/factories/quick_entry_mappings.rb`:

```ruby
FactoryBot.define do
  factory :quick_entry_mapping do
    association :household
    association :target, factory: :category
    keyword { Faker::Commerce.product_name }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/quick_entry_mapping_spec.rb`
Expected: PASS — all examples green

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add QuickEntryMapping model with polymorphic target"
```

---

### Task 2: QuickEntryParser Service

**Files:**
- Create: `app/services/quick_entry_parser.rb`
- Create: `spec/services/quick_entry_parser_spec.rb`

**Step 1: Write the failing test**

Create `spec/services/quick_entry_parser_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe QuickEntryParser do
  describe ".parse" do
    it "parses full format: 紀錄 Jerry 支付 家樂福採買 100" do
      result = QuickEntryParser.parse("紀錄 Jerry 支付 家樂福採買 100")
      expect(result).to eq({ payer: "Jerry", description: "家樂福採買", amount: 100.0 })
    end

    it "parses full format with 記錄 variant" do
      result = QuickEntryParser.parse("記錄 Jerry 支付 停車費 50")
      expect(result).to eq({ payer: "Jerry", description: "停車費", amount: 50.0 })
    end

    it "parses full format with decimal amount" do
      result = QuickEntryParser.parse("紀錄 Jerry 支付 咖啡 99.5")
      expect(result).to eq({ payer: "Jerry", description: "咖啡", amount: 99.5 })
    end

    it "parses short format without verb: Jerry 停車費 100" do
      result = QuickEntryParser.parse("Jerry 停車費 100")
      expect(result).to eq({ payer: "Jerry", description: "停車費", amount: 100.0 })
    end

    it "parses minimal format: 停車費 100" do
      result = QuickEntryParser.parse("停車費 100")
      expect(result).to eq({ payer: nil, description: "停車費", amount: 100.0 })
    end

    it "parses multi-word description: 家樂福採買 2500" do
      result = QuickEntryParser.parse("家樂福採買 2500")
      expect(result).to eq({ payer: nil, description: "家樂福採買", amount: 2500.0 })
    end

    it "handles extra whitespace" do
      result = QuickEntryParser.parse("  紀錄  Jerry  支付  午餐  350  ")
      expect(result).to eq({ payer: "Jerry", description: "午餐", amount: 350.0 })
    end

    it "returns nil for unparseable input" do
      result = QuickEntryParser.parse("hello")
      expect(result).to be_nil
    end

    it "returns nil for empty string" do
      result = QuickEntryParser.parse("")
      expect(result).to be_nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/quick_entry_parser_spec.rb`
Expected: FAIL — file doesn't exist

**Step 3: Write minimal implementation**

Create `app/services/quick_entry_parser.rb`:

```ruby
class QuickEntryParser
  # Supported formats (most specific first):
  #   紀錄/記錄 {payer} 支付 {description} {amount}
  #   {payer} {description} {amount}
  #   {description} {amount}
  FULL_PATTERN = /\A(?:紀錄|記錄)\s+(\S+)\s+支付\s+(.+?)\s+(\d+(?:\.\d+)?)\z/
  SHORT_PATTERN = /\A(\S+)\s+(.+?)\s+(\d+(?:\.\d+)?)\z/
  MINIMAL_PATTERN = /\A(.+?)\s+(\d+(?:\.\d+)?)\z/

  def self.parse(input)
    text = input.to_s.strip.gsub(/\s+/, " ")
    return nil if text.empty?

    if (match = text.match(FULL_PATTERN))
      { payer: match[1], description: match[2], amount: Float(match[3]) }
    elsif (match = text.match(SHORT_PATTERN))
      { payer: match[1], description: match[2], amount: Float(match[3]) }
    elsif (match = text.match(MINIMAL_PATTERN))
      { payer: nil, description: match[1], amount: Float(match[2]) }
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/quick_entry_parser_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/services/quick_entry_parser.rb spec/services/quick_entry_parser_spec.rb
git commit -m "feat: add QuickEntryParser service for natural language parsing"
```

---

### Task 3: QuickEntryResolver Service

**Files:**
- Create: `app/services/quick_entry_resolver.rb`
- Create: `spec/services/quick_entry_resolver_spec.rb`

**Step 1: Write the failing test**

Create `spec/services/quick_entry_resolver_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe QuickEntryResolver do
  let(:household) { create(:household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group, name: "生活花費") }
  let!(:account) { create(:account, household: household, name: "Jerry 現金") }

  describe ".resolve" do
    context "with both mappings found" do
      before do
        create(:quick_entry_mapping, household: household, keyword: "家樂福採買", target: category)
        create(:quick_entry_mapping, household: household, keyword: "Jerry", target: account)
      end

      it "resolves account, category, memo, amount, and date" do
        parsed = { payer: "Jerry", description: "家樂福採買", amount: 100.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to eq(account)
        expect(result[:category]).to eq(category)
        expect(result[:memo]).to eq("家樂福採買")
        expect(result[:amount]).to eq(-100.0)
        expect(result[:date]).to eq(Date.today)
      end
    end

    context "with no category mapping" do
      it "returns nil for category" do
        parsed = { payer: nil, description: "未知消費", amount: 200.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:category]).to be_nil
        expect(result[:memo]).to eq("未知消費")
        expect(result[:amount]).to eq(-200.0)
      end
    end

    context "with no account mapping" do
      it "returns nil for account" do
        create(:quick_entry_mapping, household: household, keyword: "午餐", target: category)
        parsed = { payer: "Unknown", description: "午餐", amount: 150.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to be_nil
        expect(result[:category]).to eq(category)
      end
    end

    context "with no payer" do
      it "returns nil for account when payer is nil" do
        parsed = { payer: nil, description: "午餐", amount: 50.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to be_nil
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/quick_entry_resolver_spec.rb`
Expected: FAIL — file doesn't exist

**Step 3: Write minimal implementation**

Create `app/services/quick_entry_resolver.rb`:

```ruby
class QuickEntryResolver
  def self.resolve(parsed, household)
    account = nil
    category = nil

    if parsed[:payer].present?
      mapping = household.quick_entry_mappings.find_by(keyword: parsed[:payer], target_type: "Account")
      account = mapping&.target
    end

    if parsed[:description].present?
      mapping = household.quick_entry_mappings.find_by(keyword: parsed[:description], target_type: "Category")
      category = mapping&.target
    end

    {
      account: account,
      category: category,
      memo: parsed[:description],
      amount: -parsed[:amount].abs,
      date: Date.today
    }
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/quick_entry_resolver_spec.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/services/quick_entry_resolver.rb spec/services/quick_entry_resolver_spec.rb
git commit -m "feat: add QuickEntryResolver service for mapping lookup"
```

---

### Task 4: QuickEntryController (new + create)

**Files:**
- Create: `app/controllers/quick_entry_controller.rb`
- Create: `app/views/quick_entry/new.html.erb`
- Create: `app/views/quick_entry/create.html.erb`
- Modify: `config/routes.rb`

**Step 1: Add routes**

In `config/routes.rb`, add after the `transfers` line:

```ruby
resource :quick_entry, only: [ :new, :create ], controller: "quick_entry"
```

**Step 2: Create controller**

Create `app/controllers/quick_entry_controller.rb`:

```ruby
class QuickEntryController < ApplicationController
  def new
  end

  def create
    if params[:confirm] == "1"
      create_transaction
    else
      parse_and_resolve
    end
  end

  private

  def parse_and_resolve
    parsed = QuickEntryParser.parse(params[:input].to_s)
    if parsed.nil?
      redirect_to new_quick_entry_path, alert: "無法解析輸入，請使用格式：紀錄 {付款人} 支付 {描述} {金額}"
      return
    end

    resolved = QuickEntryResolver.resolve(parsed, Current.household)

    @accounts = Current.household.accounts.active
    @categories = Current.household.category_groups.includes(:categories)
    @account = resolved[:account]
    @category = resolved[:category]
    @memo = resolved[:memo]
    @amount = resolved[:amount].abs
    @date = resolved[:date]
    @payer_keyword = parsed[:payer]
    @description_keyword = parsed[:description]
    @account_matched = resolved[:account].present?
    @category_matched = resolved[:category].present?

    render :create
  end

  def create_transaction
    account = Current.household.accounts.find(params[:account_id])
    category = nil
    if params[:category_id].present?
      category = Category.joins(:category_group)
                         .where(category_groups: { household_id: Current.household.id })
                         .find(params[:category_id])
    end

    transaction = account.transactions.build(
      category: category,
      amount: -params[:amount].to_d.abs,
      date: params[:date],
      memo: params[:memo]
    )

    if transaction.save
      account.recalculate_balance!
      save_mappings_if_requested
      redirect_to new_quick_entry_path, notice: "交易已建立：#{params[:memo]} NT$#{params[:amount]}"
    else
      redirect_to new_quick_entry_path, alert: "建立失敗，請確認所有欄位"
    end
  end

  def save_mappings_if_requested
    if params[:remember_account] == "1" && params[:payer_keyword].present? && params[:account_id].present?
      Current.household.quick_entry_mappings.find_or_create_by(
        keyword: params[:payer_keyword],
        target_type: "Account"
      ) do |m|
        m.target_id = params[:account_id]
      end
    end

    if params[:remember_category] == "1" && params[:description_keyword].present? && params[:category_id].present?
      Current.household.quick_entry_mappings.find_or_create_by(
        keyword: params[:description_keyword],
        target_type: "Category"
      ) do |m|
        m.target_id = params[:category_id]
      end
    end
  end
end
```

**Step 3: Create input view**

Create `app/views/quick_entry/new.html.erb`:

```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-2">快速記帳</h1>
  <p class="text-sm text-slate-500 mb-6">
    輸入格式：紀錄 {付款人} 支付 {描述} {金額}<br>
    或簡短：{描述} {金額}
  </p>

  <%= form_with url: quick_entry_path, method: :post, class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :input, "輸入", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :input, autofocus: true, placeholder: "紀錄 Jerry 支付 家樂福採買 100",
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>

    <div>
      <%= f.submit "解析",
            class: "w-full bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2.5 rounded-lg cursor-pointer transition-colors" %>
    </div>
  <% end %>
</div>
```

**Step 4: Create confirmation view**

Create `app/views/quick_entry/create.html.erb`:

```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-2">確認交易</h1>
  <p class="text-sm text-slate-500 mb-6">請確認以下資訊，或修改後送出</p>

  <%= form_with url: quick_entry_path, method: :post, class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <%= f.hidden_field :confirm, value: "1" %>
    <%= f.hidden_field :payer_keyword, value: @payer_keyword %>
    <%= f.hidden_field :description_keyword, value: @description_keyword %>

    <div>
      <%= f.label :account_id, "帳戶", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.collection_select :account_id, @accounts, :id, :name,
            { prompt: "-- 請選擇帳戶 --", selected: @account&.id },
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% if @payer_keyword.present? && !@account_matched %>
        <label class="flex items-center gap-2 mt-2">
          <%= f.check_box :remember_account, class: "rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" %>
          <span class="text-xs text-slate-500">記住「<%= @payer_keyword %>」對應此帳戶</span>
        </label>
      <% end %>
    </div>

    <div>
      <%= f.label :category_id, "類別", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <select name="category_id" id="category_id"
              class="block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
        <option value="">-- 請選擇類別 --</option>
        <% @categories.each do |group| %>
          <optgroup label="<%= group.name %>">
            <% group.categories.each do |cat| %>
              <option value="<%= cat.id %>" <%= "selected" if @category&.id == cat.id %>><%= cat.name %></option>
            <% end %>
          </optgroup>
        <% end %>
      </select>
      <% unless @category_matched %>
        <label class="flex items-center gap-2 mt-2">
          <%= f.check_box :remember_category, class: "rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" %>
          <span class="text-xs text-slate-500">記住「<%= @description_keyword %>」對應此類別</span>
        </label>
      <% end %>
    </div>

    <div>
      <%= f.label :amount, "金額", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.number_field :amount, value: @amount, step: 0.01, min: 0,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>

    <div>
      <%= f.label :memo, "備註", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :memo, value: @memo,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>

    <div>
      <%= f.label :date, "日期", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.date_field :date, value: @date,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "確認建立",
            class: "flex-1 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2.5 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "重新輸入", new_quick_entry_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 5: Run to verify routes work**

Run: `bin/rails routes | grep quick_entry`
Expected: Shows `new_quick_entry GET /quick_entry/new` and `quick_entry POST /quick_entry`

**Step 6: Commit**

```bash
git add app/controllers/quick_entry_controller.rb app/views/quick_entry/ config/routes.rb
git commit -m "feat: add QuickEntryController with parse and confirm flow"
```

---

### Task 5: Settings::QuickEntryMappingsController (CRUD)

**Files:**
- Create: `app/controllers/settings/quick_entry_mappings_controller.rb`
- Create: `app/views/settings/quick_entry_mappings/index.html.erb`
- Create: `app/views/settings/quick_entry_mappings/new.html.erb`
- Create: `app/views/settings/quick_entry_mappings/edit.html.erb`
- Modify: `config/routes.rb`

**Step 1: Add routes**

In `config/routes.rb`, inside the `namespace :settings` block, add:

```ruby
resources :quick_entry_mappings, only: [ :index, :new, :create, :edit, :update, :destroy ]
```

**Step 2: Create controller**

Create `app/controllers/settings/quick_entry_mappings_controller.rb`:

```ruby
module Settings
  class QuickEntryMappingsController < ApplicationController
    def index
      @mappings = Current.household.quick_entry_mappings.order(:target_type, :keyword)
      @category_mappings = @mappings.select { |m| m.target_type == "Category" }
      @account_mappings = @mappings.select { |m| m.target_type == "Account" }
    end

    def new
      @mapping = Current.household.quick_entry_mappings.build(target_type: params[:target_type] || "Category")
      load_targets
    end

    def create
      @mapping = Current.household.quick_entry_mappings.build(mapping_params)
      validate_target_ownership!
      if @mapping.save
        redirect_to settings_quick_entry_mappings_path, notice: "對應已新增"
      else
        load_targets
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      load_targets
    end

    def update
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      @mapping.assign_attributes(mapping_params)
      validate_target_ownership!
      if @mapping.save
        redirect_to settings_quick_entry_mappings_path, notice: "對應已更新"
      else
        load_targets
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      @mapping.destroy
      redirect_to settings_quick_entry_mappings_path, notice: "對應已刪除"
    end

    private

    def mapping_params
      params.require(:quick_entry_mapping).permit(:keyword, :target_type, :target_id)
    end

    def validate_target_ownership!
      case @mapping.target_type
      when "Category"
        Category.joins(:category_group)
                .where(category_groups: { household_id: Current.household.id })
                .find(@mapping.target_id)
      when "Account"
        Current.household.accounts.find(@mapping.target_id)
      end
    end

    def load_targets
      @categories = Current.household.category_groups.includes(:categories)
      @accounts = Current.household.accounts.active
    end
  end
end
```

**Step 3: Create index view**

Create `app/views/settings/quick_entry_mappings/index.html.erb`:

```erb
<div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-slate-900">快速記帳對應</h1>
    <%= link_to new_settings_quick_entry_mapping_path,
          class: "flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors" do %>
      <%= icon "plus", classes: "w-4 h-4" %>
      新增對應
    <% end %>
  </div>

  <%# Category mappings %>
  <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden mb-4">
    <div class="px-5 py-3 bg-slate-50 border-b border-slate-100">
      <span class="text-sm font-semibold text-slate-700">類別對應</span>
    </div>
    <% if @category_mappings.any? %>
      <div class="divide-y divide-slate-50">
        <% @category_mappings.each do |mapping| %>
          <div class="flex items-center justify-between px-5 py-3">
            <div class="text-sm text-slate-700">
              <span class="font-medium"><%= mapping.keyword %></span>
              <span class="text-slate-400 mx-2">&rarr;</span>
              <span><%= mapping.target.name %></span>
            </div>
            <div class="flex items-center gap-2">
              <%= link_to edit_settings_quick_entry_mapping_path(mapping),
                    class: "text-slate-400 hover:text-indigo-600 transition-colors" do %>
                <%= icon "pencil", classes: "w-4 h-4" %>
              <% end %>
              <%= button_to settings_quick_entry_mapping_path(mapping), method: :delete,
                    data: { turbo_confirm: "確定要刪除「#{mapping.keyword}」的對應嗎？" },
                    class: "text-slate-400 hover:text-red-500 transition-colors" do %>
                <%= icon "trash", classes: "w-4 h-4" %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="px-5 py-4 text-sm text-slate-400">尚無類別對應</div>
    <% end %>
  </div>

  <%# Account mappings %>
  <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
    <div class="px-5 py-3 bg-slate-50 border-b border-slate-100">
      <span class="text-sm font-semibold text-slate-700">帳戶對應</span>
    </div>
    <% if @account_mappings.any? %>
      <div class="divide-y divide-slate-50">
        <% @account_mappings.each do |mapping| %>
          <div class="flex items-center justify-between px-5 py-3">
            <div class="text-sm text-slate-700">
              <span class="font-medium"><%= mapping.keyword %></span>
              <span class="text-slate-400 mx-2">&rarr;</span>
              <span><%= mapping.target.name %></span>
            </div>
            <div class="flex items-center gap-2">
              <%= link_to edit_settings_quick_entry_mapping_path(mapping),
                    class: "text-slate-400 hover:text-indigo-600 transition-colors" do %>
                <%= icon "pencil", classes: "w-4 h-4" %>
              <% end %>
              <%= button_to settings_quick_entry_mapping_path(mapping), method: :delete,
                    data: { turbo_confirm: "確定要刪除「#{mapping.keyword}」的對應嗎？" },
                    class: "text-slate-400 hover:text-red-500 transition-colors" do %>
                <%= icon "trash", classes: "w-4 h-4" %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="px-5 py-4 text-sm text-slate-400">尚無帳戶對應</div>
    <% end %>
  </div>
</div>
```

**Step 4: Create new/edit views**

Create `app/views/settings/quick_entry_mappings/new.html.erb`:

```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">新增對應</h1>
  <%= render "form", mapping: @mapping %>
</div>
```

Create `app/views/settings/quick_entry_mappings/edit.html.erb`:

```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-6">編輯對應</h1>
  <%= render "form", mapping: @mapping %>
</div>
```

Create `app/views/settings/quick_entry_mappings/_form.html.erb`:

```erb
<%= form_with model: [:settings, mapping], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
  <div>
    <%= f.label :keyword, "關鍵字", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <%= f.text_field :keyword, autofocus: true, placeholder: "例：家樂福採買、Jerry",
          class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    <% mapping.errors[:keyword].each do |msg| %>
      <p class="text-xs text-red-500 mt-1"><%= msg %></p>
    <% end %>
  </div>

  <div>
    <%= f.label :target_type, "對應類型", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <%= f.select :target_type, [["類別", "Category"], ["帳戶", "Account"]],
          {},
          class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500",
          data: { action: "change->quick-entry-mapping#toggleTarget", quick_entry_mapping_target: "typeSelect" } %>
  </div>

  <div data-quick-entry-mapping-target="categoryField" class="<%= 'hidden' if mapping.target_type == 'Account' %>">
    <%= f.label :target_id, "類別", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <select name="quick_entry_mapping[target_id]" id="category_target_id"
            class="block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
      <option value="">-- 請選擇 --</option>
      <% @categories.each do |group| %>
        <optgroup label="<%= group.name %>">
          <% group.categories.each do |cat| %>
            <option value="<%= cat.id %>" <%= "selected" if mapping.target_type == "Category" && mapping.target_id == cat.id %>><%= cat.name %></option>
          <% end %>
        </optgroup>
      <% end %>
    </select>
  </div>

  <div data-quick-entry-mapping-target="accountField" class="<%= 'hidden' unless mapping.target_type == 'Account' %>">
    <%= f.label :target_id, "帳戶", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
    <select name="quick_entry_mapping[target_id]" id="account_target_id"
            class="block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
      <option value="">-- 請選擇 --</option>
      <% @accounts.each do |acct| %>
        <option value="<%= acct.id %>" <%= "selected" if mapping.target_type == "Account" && mapping.target_id == acct.id %>><%= acct.name %></option>
      <% end %>
    </select>
  </div>

  <% mapping.errors[:target_type].each do |msg| %>
    <p class="text-xs text-red-500"><%= msg %></p>
  <% end %>

  <div class="flex items-center gap-3 pt-2">
    <%= f.submit mapping.persisted? ? "儲存" : "新增對應",
          class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
    <%= link_to "取消", settings_quick_entry_mappings_path,
          class: "text-sm text-slate-500 hover:text-slate-700" %>
  </div>
<% end %>
```

**Step 5: Create Stimulus controller for toggling target fields**

Create `app/javascript/controllers/quick_entry_mapping_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "categoryField", "accountField"]

  toggleTarget() {
    const type = this.typeSelectTarget.value
    this.categoryFieldTarget.classList.toggle("hidden", type !== "Category")
    this.accountFieldTarget.classList.toggle("hidden", type !== "Account")
  }
}
```

Add `data-controller="quick-entry-mapping"` to the form wrapper in `_form.html.erb` — wrap the form content with:

```erb
<%= form_with model: [:settings, mapping], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4", data: { controller: "quick-entry-mapping" } do |f| %>
```

**Step 6: Commit**

```bash
git add app/controllers/settings/quick_entry_mappings_controller.rb app/views/settings/quick_entry_mappings/ app/javascript/controllers/quick_entry_mapping_controller.js config/routes.rb
git commit -m "feat: add Settings CRUD for QuickEntryMappings"
```

---

### Task 6: Navigation Links

**Files:**
- Modify: `app/views/shared/_nav.html.erb`

**Step 1: Add Quick Entry link to desktop sidebar**

In `app/views/shared/_nav.html.erb`, add after the 報表 link in the desktop sidebar:

```erb
<%= link_to new_quick_entry_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?('/quick_entry') ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
  <%= icon "bolt", classes: "w-5 h-5 shrink-0" %>
  快速記帳
<% end %>
```

**Step 2: Add to mobile bottom tab bar**

Add the same link in the mobile nav section, after 報表:

```erb
<%= link_to new_quick_entry_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs #{request.path.start_with?('/quick_entry') ? 'text-indigo-600' : 'text-slate-500'}" do %>
  <%= icon "bolt", classes: "w-6 h-6" %>
  快速記帳
<% end %>
```

**Step 3: Add Quick Entry Mappings link to Settings sidebar (or to category management page)**

In `app/views/shared/_nav.html.erb`, update the 類別管理 link text to "設定" if desired, or add a sub-link. Alternatively, add a link on the settings category_groups index page pointing to `/settings/quick_entry_mappings`. The simplest approach: add a second nav link under 類別管理:

```erb
<%= link_to settings_quick_entry_mappings_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?('/settings/quick_entry') ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
  <%= icon "key", classes: "w-5 h-5 shrink-0" %>
  記帳對應
<% end %>
```

**Step 4: Commit**

```bash
git add app/views/shared/_nav.html.erb
git commit -m "feat: add quick entry and mapping links to navigation"
```

---

### Task 7: System Tests

**Files:**
- Create: `spec/system/quick_entry_spec.rb`
- Create: `spec/system/quick_entry_mappings_spec.rb`

**Step 1: Write Quick Entry system tests**

Create `spec/system/quick_entry_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "快速記帳", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household, name: "Jerry 現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "生活花費") }

  before { sign_in(user) }

  it "parses input and shows confirmation form" do
    visit new_quick_entry_path
    fill_in "input", with: "停車費 100"
    click_button "解析"

    expect(page).to have_text("確認交易")
    expect(page).to have_field("amount", with: "100")
    expect(page).to have_field("memo", with: "停車費")
  end

  it "creates transaction from confirmation form" do
    visit new_quick_entry_path
    fill_in "input", with: "午餐 350"
    click_button "解析"

    select "Jerry 現金", from: "account_id"
    select "生活花費", from: "category_id"
    click_button "確認建立"

    expect(page).to have_text("交易已建立")
    expect(Transaction.last).to have_attributes(
      amount: -350.to_d,
      memo: "午餐"
    )
  end

  it "pre-fills account and category when mappings exist" do
    create(:quick_entry_mapping, household: household, keyword: "Jerry", target: account)
    create(:quick_entry_mapping, household: household, keyword: "家樂福", target: category)

    visit new_quick_entry_path
    fill_in "input", with: "紀錄 Jerry 支付 家樂福 500"
    click_button "解析"

    expect(page).to have_select("account_id", selected: "Jerry 現金")
    expect(page).to have_select("category_id", selected: "生活花費")
  end

  it "saves new mapping when remember checkbox is checked" do
    visit new_quick_entry_path
    fill_in "input", with: "停車費 100"
    click_button "解析"

    select "Jerry 現金", from: "account_id"
    select "生活花費", from: "category_id"
    check "remember_category"
    click_button "確認建立"

    expect(page).to have_text("交易已建立")
    expect(QuickEntryMapping.find_by(keyword: "停車費", target_type: "Category")).to be_present
  end

  it "shows error for unparseable input" do
    visit new_quick_entry_path
    fill_in "input", with: "hello"
    click_button "解析"

    expect(page).to have_text("無法解析輸入")
  end
end
```

**Step 2: Write Settings mapping system tests**

Create `spec/system/quick_entry_mappings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "快速記帳對應管理", type: :system do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:account) { create(:account, household: household, name: "現金") }
  let!(:category_group) { create(:category_group, household: household, name: "日常") }
  let!(:category) { create(:category, category_group: category_group, name: "飲食") }

  before { sign_in(user) }

  it "creates a new category mapping" do
    visit settings_quick_entry_mappings_path
    click_link "新增對應"

    fill_in "關鍵字", with: "午餐"
    select "類別", from: "對應類型"
    select "飲食", from: "category_target_id"
    click_button "新增對應"

    expect(page).to have_text("對應已新增")
    expect(page).to have_text("午餐")
  end

  it "creates a new account mapping" do
    visit settings_quick_entry_mappings_path
    click_link "新增對應"

    fill_in "關鍵字", with: "Jerry"
    select "帳戶", from: "對應類型"
    select "現金", from: "account_target_id"
    click_button "新增對應"

    expect(page).to have_text("對應已新增")
    expect(page).to have_text("Jerry")
  end

  it "edits an existing mapping" do
    mapping = create(:quick_entry_mapping, household: household, keyword: "舊名", target: category)
    visit settings_quick_entry_mappings_path

    within("div", text: "舊名") do
      find("a[href*='edit']").click
    end

    fill_in "關鍵字", with: "新名"
    click_button "儲存"

    expect(page).to have_text("對應已更新")
    expect(page).to have_text("新名")
    expect(page).not_to have_text("舊名")
  end

  it "deletes a mapping" do
    create(:quick_entry_mapping, household: household, keyword: "要刪除", target: category)
    visit settings_quick_entry_mappings_path

    within("div", text: "要刪除") do
      accept_confirm { find("button[type='submit']").click }
    end

    expect(page).not_to have_text("要刪除")
    expect(page).to have_text("對應已刪除")
  end
end
```

**Step 3: Run all tests**

Run: `bundle exec rspec spec/system/quick_entry_spec.rb spec/system/quick_entry_mappings_spec.rb spec/models/quick_entry_mapping_spec.rb spec/services/`
Expected: All PASS

**Step 4: Commit**

```bash
git add spec/system/quick_entry_spec.rb spec/system/quick_entry_mappings_spec.rb
git commit -m "test: add system tests for quick entry and mapping management"
```

---

### Task 8: Full Test Suite Verification

**Step 1: Run the entire test suite**

Run: `bundle exec rspec`
Expected: All existing tests still pass, no regressions

**Step 2: Fix any failures if needed**

**Step 3: Final commit if any fixes were needed**

```bash
git commit -m "fix: address test failures from quick entry integration"
```
