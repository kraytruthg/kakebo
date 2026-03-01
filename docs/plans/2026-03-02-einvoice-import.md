# 雲端發票匯入功能實作計畫

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 整合台灣財政部電子發票 API，讓 Household 可設定多組手機條碼，每日自動同步發票至「待確認」列表，使用者確認後建立 Transaction。

**Architecture:** 新增 `InvoiceCarrier`（Household 1-to-many）與 `PendingInvoice`（暫存待確認發票）兩個模型；`InvoiceSyncJob` 由 Solid Queue 每日 6am 排程執行，呼叫財政部 API；使用者在 `/pending_invoices` 頁面逐張確認或略過。

**Tech Stack:** Ruby 3.4.2, Rails 8.1.2, Solid Queue（內建排程）, Net::HTTP（不需額外 gem）, Active Record Encryption（`encrypts`）, RSpec + Capybara

---

> **API 注意事項**
> 財政部電子發票 API 規格請參考官方文件：
> https://www.einvoice.nat.gov.tw/static/ptl/ein_upload/attachments/1693297176294_0.pdf
>
> 開發前需向財政部申請 AppID + APIKey，存入 Rails credentials：
> ```bash
> rails credentials:edit
> # 加入：
> # einvoice:
> #   app_id: YOUR_APP_ID
> #   api_key: YOUR_API_KEY
> ```

---

## Task 1: 建立 invoice_carriers 資料表

**Files:**
- Create: `db/migrate/TIMESTAMP_create_invoice_carriers.rb`

**Step 1: 產生 migration**

```bash
rails generate migration CreateInvoiceCarriers household:references label:string carrier_number:string verification_code:string last_synced_at:datetime
```

**Step 2: 修改 migration 加入 null 限制與索引**

開啟產生的 migration 檔，改為：

```ruby
class CreateInvoiceCarriers < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_carriers do |t|
      t.references :household, null: false, foreign_key: true
      t.string :label, null: false
      t.string :carrier_number, null: false   # e.g. "/ABC1234"
      t.string :verification_code, null: false # encrypted by Active Record Encryption
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :invoice_carriers, [ :household_id, :carrier_number ], unique: true
  end
end
```

**Step 3: 執行 migration**

```bash
rails db:migrate
```

Expected: `== CreateInvoiceCarriers: migrated`

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add invoice_carriers table"
```

---

## Task 2: 建立 pending_invoices 資料表

**Files:**
- Create: `db/migrate/TIMESTAMP_create_pending_invoices.rb`

**Step 1: 產生 migration**

```bash
rails generate migration CreatePendingInvoices invoice_carrier:references invoice_number:string invoice_date:date seller_name:string total_amount:decimal status:string details:jsonb confirmed_category:references
```

**Step 2: 修改 migration**

```ruby
class CreatePendingInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_invoices do |t|
      t.references :invoice_carrier, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.date :invoice_date, null: false
      t.string :seller_name
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string :status, null: false, default: "pending"  # pending / imported / skipped
      t.jsonb :details, default: []                       # [{description:, quantity:, unit_price:, amount:}]
      t.references :confirmed_category, foreign_key: { to_table: :categories }

      t.timestamps
    end

    add_index :pending_invoices, :invoice_number, unique: true
    add_index :pending_invoices, :status
  end
end
```

**Step 3: 執行 migration**

```bash
rails db:migrate
```

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add pending_invoices table"
```

---

## Task 3: InvoiceCarrier 模型

**Files:**
- Create: `app/models/invoice_carrier.rb`
- Modify: `app/models/household.rb`
- Create: `spec/models/invoice_carrier_spec.rb`

**Step 1: 寫失敗測試**

```ruby
# spec/models/invoice_carrier_spec.rb
require "rails_helper"

RSpec.describe InvoiceCarrier, type: :model do
  let(:household) { create(:household) }

  it { should belong_to(:household) }
  it { should have_many(:pending_invoices).dependent(:destroy) }
  it { should validate_presence_of(:label) }
  it { should validate_presence_of(:carrier_number) }
  it { should validate_presence_of(:verification_code) }

  it "validates carrier_number format" do
    carrier = build(:invoice_carrier, household: household, carrier_number: "invalid")
    expect(carrier).not_to be_valid
    expect(carrier.errors[:carrier_number]).to include("格式不正確")
  end

  it "validates carrier_number uniqueness per household" do
    create(:invoice_carrier, household: household, carrier_number: "/ABC1234")
    dup = build(:invoice_carrier, household: household, carrier_number: "/ABC1234")
    expect(dup).not_to be_valid
  end
end
```

**Step 2: 執行測試確認失敗**

```bash
bundle exec rspec spec/models/invoice_carrier_spec.rb
```

Expected: FAIL - `uninitialized constant InvoiceCarrier`

**Step 3: 實作模型**

```ruby
# app/models/invoice_carrier.rb
class InvoiceCarrier < ApplicationRecord
  belongs_to :household
  has_many :pending_invoices, dependent: :destroy

  encrypts :verification_code

  validates :label, presence: true
  validates :carrier_number, presence: true,
            format: { with: /\A\/[A-Z0-9+\-.]{7}\z/, message: "格式不正確（應為 /XXXXXXX）" }
  validates :verification_code, presence: true
  validates :carrier_number, uniqueness: { scope: :household_id }
end
```

**Step 4: 更新 Household 模型**

在 `app/models/household.rb` 的 `has_many` 區塊加入：

```ruby
has_many :invoice_carriers, dependent: :destroy
```

**Step 5: 新增 Factory**

```ruby
# spec/factories/invoice_carriers.rb
FactoryBot.define do
  factory :invoice_carrier do
    association :household
    label { "手機載具" }
    carrier_number { "/ABC1234" }
    verification_code { "1234" }
  end
end
```

**Step 6: 執行測試**

```bash
bundle exec rspec spec/models/invoice_carrier_spec.rb
```

Expected: PASS

**Step 7: Commit**

```bash
git add app/models/invoice_carrier.rb app/models/household.rb spec/models/invoice_carrier_spec.rb spec/factories/invoice_carriers.rb
git commit -m "feat: add InvoiceCarrier model"
```

---

## Task 4: PendingInvoice 模型

**Files:**
- Create: `app/models/pending_invoice.rb`
- Create: `spec/models/pending_invoice_spec.rb`
- Create: `spec/factories/pending_invoices.rb`

**Step 1: 寫失敗測試**

```ruby
# spec/models/pending_invoice_spec.rb
require "rails_helper"

RSpec.describe PendingInvoice, type: :model do
  it { should belong_to(:invoice_carrier) }
  it { should belong_to(:confirmed_category).class_name("Category").optional }
  it { should validate_presence_of(:invoice_number) }
  it { should validate_presence_of(:invoice_date) }
  it { should validate_presence_of(:total_amount) }

  describe "status scopes" do
    let(:carrier) { create(:invoice_carrier) }

    it "pending scope returns only pending invoices" do
      p1 = create(:pending_invoice, invoice_carrier: carrier, status: "pending")
      create(:pending_invoice, invoice_carrier: carrier, status: "imported", invoice_number: "AB12345678")
      expect(PendingInvoice.pending).to eq([ p1 ])
    end
  end

  describe "suggested_category" do
    it "returns last confirmed category for same seller" do
      carrier = create(:invoice_carrier)
      category = create(:category, category_group: create(:category_group, household: carrier.household))
      create(:pending_invoice, invoice_carrier: carrier, seller_name: "7-11", status: "imported", confirmed_category: category)
      new_invoice = create(:pending_invoice, invoice_carrier: carrier, seller_name: "7-11", invoice_number: "CD99999999")
      expect(new_invoice.suggested_category).to eq(category)
    end
  end
end
```

**Step 2: 執行確認失敗**

```bash
bundle exec rspec spec/models/pending_invoice_spec.rb
```

**Step 3: 實作模型**

```ruby
# app/models/pending_invoice.rb
class PendingInvoice < ApplicationRecord
  belongs_to :invoice_carrier
  belongs_to :confirmed_category, class_name: "Category", optional: true

  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_date, presence: true
  validates :total_amount, presence: true
  validates :status, inclusion: { in: %w[pending imported skipped] }

  scope :pending, -> { where(status: "pending") }
  scope :imported, -> { where(status: "imported") }
  scope :recent_first, -> { order(invoice_date: :desc) }

  delegate :household, to: :invoice_carrier

  def suggested_category
    PendingInvoice
      .joins(:invoice_carrier)
      .where(invoice_carriers: { household_id: invoice_carrier.household_id })
      .where(seller_name: seller_name, status: "imported")
      .where.not(confirmed_category_id: nil)
      .order(updated_at: :desc)
      .first
      &.confirmed_category
  end
end
```

**Step 4: 新增 Factory**

```ruby
# spec/factories/pending_invoices.rb
FactoryBot.define do
  factory :pending_invoice do
    association :invoice_carrier
    sequence(:invoice_number) { |n| "AB#{n.to_s.rjust(8, '0')}" }
    invoice_date { Date.today }
    seller_name { "測試商店" }
    total_amount { 100.0 }
    status { "pending" }
    details { [] }
  end
end
```

**Step 5: 執行測試**

```bash
bundle exec rspec spec/models/pending_invoice_spec.rb
```

Expected: PASS

**Step 6: Commit**

```bash
git add app/models/pending_invoice.rb spec/models/pending_invoice_spec.rb spec/factories/pending_invoices.rb
git commit -m "feat: add PendingInvoice model"
```

---

## Task 5: EinvoiceApiService

**Files:**
- Create: `app/services/einvoice_api_service.rb`
- Create: `spec/services/einvoice_api_service_spec.rb`

> **重要**: 以下 API 端點與參數請對照官方規格文件 v1.9 確認。
> `cardEncrypt` 的加密方式需查閱文件確認（常見實作為 AES-128-CBC）。

**Step 1: 寫測試（使用 stub 避免真實 API 呼叫）**

```ruby
# spec/services/einvoice_api_service_spec.rb
require "rails_helper"

RSpec.describe EinvoiceApiService do
  let(:carrier) { build(:invoice_carrier, carrier_number: "/ABC1234", verification_code: "1234") }
  let(:service) { described_class.new(carrier) }

  describe "#fetch_invoices" do
    it "returns array of invoice hashes" do
      stub_response = {
        "v" => "0.5",
        "code" => 200,
        "details" => [
          {
            "rowNum" => 1,
            "invNum" => "AB12345678",
            "cardType" => "3J0002",
            "cardNo" => "/ABC1234",
            "sellerName" => "全家便利商店",
            "invStatus" => "N",
            "invDonatable" => false,
            "amount" => "150",
            "invPeriod" => "11402",
            "donateMark" => 0
          }
        ]
      }

      allow(service).to receive(:api_get).with(action: "carrierInvChk", anything_else: anything).and_return(stub_response)

      result = service.fetch_invoices
      expect(result).to be_an(Array)
      expect(result.first[:invoice_number]).to eq("AB12345678")
      expect(result.first[:seller_name]).to eq("全家便利商店")
      expect(result.first[:total_amount]).to eq(150.0)
    end
  end

  describe "#fetch_invoice_details" do
    it "returns array of item hashes" do
      stub_response = {
        "v" => "0.5",
        "code" => 200,
        "details" => [
          { "rowNum" => 1, "description" => "咖啡", "quantity" => "1", "unitPrice" => "50", "amount" => "50" }
        ]
      }

      allow(service).to receive(:api_get).and_return(stub_response)

      result = service.fetch_invoice_details("AB12345678", Date.new(2025, 2, 1))
      expect(result).to be_an(Array)
      expect(result.first[:description]).to eq("咖啡")
      expect(result.first[:amount]).to eq(50.0)
    end
  end
end
```

**Step 2: 執行確認失敗**

```bash
bundle exec rspec spec/services/einvoice_api_service_spec.rb
```

**Step 3: 實作 Service**

```ruby
# app/services/einvoice_api_service.rb
require "net/http"
require "openssl"
require "base64"

class EinvoiceApiService
  BASE_URL = "https://www.einvoice.nat.gov.tw"
  API_PATH = "/PB2CAPIVAN/invapp/InvApp"

  def initialize(carrier)
    @carrier = carrier
    @app_id  = Rails.application.credentials.einvoice[:app_id]
    @api_key = Rails.application.credentials.einvoice[:api_key]
  end

  # 取得載具發票列表
  # 回傳 [{invoice_number:, invoice_date:, seller_name:, total_amount:}]
  def fetch_invoices(start_date: 3.months.ago.to_date, end_date: Date.today)
    timestamp = Time.now.to_i
    response = api_get(
      action: "carrierInvChk",
      timeStamp: timestamp,
      cardType: "3J0002",
      cardNo: @carrier.carrier_number,
      cardEncrypt: encrypted_verification_code(timestamp),
      onlyWinningInv: "N",
      startDate: start_date.strftime("%Y/%m/%d"),
      endDate: end_date.strftime("%Y/%m/%d"),
      numPerPage: 20,
      pageNo: 1
    )

    return [] unless response["code"] == 200

    (response["details"] || []).map do |item|
      {
        invoice_number: item["invNum"],
        invoice_date: parse_inv_period(item["invPeriod"]),
        seller_name: item["sellerName"],
        total_amount: item["amount"].to_f
      }
    end
  end

  # 取得單張發票明細
  # 回傳 [{description:, quantity:, unit_price:, amount:}]
  def fetch_invoice_details(invoice_number, invoice_date)
    timestamp = Time.now.to_i
    response = api_get(
      action: "carrierInvDetail",
      timeStamp: timestamp,
      cardType: "3J0002",
      cardNo: @carrier.carrier_number,
      cardEncrypt: encrypted_verification_code(timestamp),
      invNum: invoice_number,
      invDate: invoice_date.strftime("%Y/%m/%d")
    )

    return [] unless response["code"] == 200

    (response["details"] || []).map do |item|
      {
        description: item["description"],
        quantity: item["quantity"].to_f,
        unit_price: item["unitPrice"].to_f,
        amount: item["amount"].to_f
      }
    end
  end

  private

  def api_get(params)
    uri = URI("#{BASE_URL}#{API_PATH}")
    uri.query = URI.encode_www_form({ version: "0.5", type: "Carrier", appID: @app_id, UIID: @carrier.carrier_number }.merge(params))

    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error("EinvoiceApiService error: #{e.message}")
    {}
  end

  # AES-128-CBC 加密驗證碼
  # 注意：實際加密方式請對照官方 API 文件確認
  def encrypted_verification_code(timestamp)
    cipher = OpenSSL::Cipher.new("AES-128-CBC")
    cipher.encrypt
    cipher.key = @api_key.byteslice(0, 16).ljust(16, "\0")
    cipher.iv  = timestamp.to_s.ljust(16, "\0").byteslice(0, 16)
    encrypted = cipher.update(@carrier.verification_code) + cipher.final
    Base64.strict_encode64(encrypted)
  end

  # 將發票期別（e.g. "11402" = 民國114年2月）轉換為 Date
  def parse_inv_period(period)
    return Date.today unless period&.length == 5
    year  = period[0..2].to_i + 1911
    month = period[3..4].to_i
    Date.new(year, month, 1)
  rescue
    Date.today
  end
end
```

**Step 4: 執行測試**

```bash
bundle exec rspec spec/services/einvoice_api_service_spec.rb
```

Expected: PASS

**Step 5: Commit**

```bash
git add app/services/einvoice_api_service.rb spec/services/einvoice_api_service_spec.rb
git commit -m "feat: add EinvoiceApiService"
```

---

## Task 6: InvoiceSyncJob

**Files:**
- Create: `app/jobs/invoice_sync_job.rb`
- Create: `spec/jobs/invoice_sync_job_spec.rb`

**Step 1: 寫失敗測試**

```ruby
# spec/jobs/invoice_sync_job_spec.rb
require "rails_helper"

RSpec.describe InvoiceSyncJob, type: :job do
  let(:household) { create(:household) }
  let!(:carrier) { create(:invoice_carrier, household: household) }

  let(:fake_invoices) do
    [
      { invoice_number: "AB12345678", invoice_date: Date.today, seller_name: "7-11", total_amount: 150.0 },
      { invoice_number: "CD87654321", invoice_date: Date.today, seller_name: "全家", total_amount: 200.0 }
    ]
  end

  let(:fake_details) { [ { description: "咖啡", quantity: 1.0, unit_price: 50.0, amount: 50.0 } ] }

  before do
    api = instance_double(EinvoiceApiService,
      fetch_invoices: fake_invoices,
      fetch_invoice_details: fake_details
    )
    allow(EinvoiceApiService).to receive(:new).with(carrier).and_return(api)
  end

  it "建立 PendingInvoice 紀錄" do
    expect { described_class.perform_now }.to change(PendingInvoice, :count).by(2)
  end

  it "不重複匯入相同 invoice_number" do
    create(:pending_invoice, invoice_carrier: carrier, invoice_number: "AB12345678")
    expect { described_class.perform_now }.to change(PendingInvoice, :count).by(1)
  end

  it "更新 last_synced_at" do
    described_class.perform_now
    expect(carrier.reload.last_synced_at).to be_present
  end
end
```

**Step 2: 執行確認失敗**

```bash
bundle exec rspec spec/jobs/invoice_sync_job_spec.rb
```

**Step 3: 實作 Job**

```ruby
# app/jobs/invoice_sync_job.rb
class InvoiceSyncJob < ApplicationJob
  queue_as :default

  def perform
    InvoiceCarrier.find_each do |carrier|
      sync_carrier(carrier)
    rescue => e
      Rails.logger.error("InvoiceSyncJob: carrier #{carrier.id} failed - #{e.message}")
    end
  end

  private

  def sync_carrier(carrier)
    api = EinvoiceApiService.new(carrier)
    invoices = api.fetch_invoices

    invoices.each do |inv|
      next if PendingInvoice.exists?(invoice_number: inv[:invoice_number])

      details = api.fetch_invoice_details(inv[:invoice_number], inv[:invoice_date])

      carrier.pending_invoices.create!(
        invoice_number: inv[:invoice_number],
        invoice_date:   inv[:invoice_date],
        seller_name:    inv[:seller_name],
        total_amount:   inv[:total_amount],
        details:        details,
        status:         "pending"
      )
    end

    carrier.update_column(:last_synced_at, Time.current)
  end
end
```

**Step 4: 執行測試**

```bash
bundle exec rspec spec/jobs/invoice_sync_job_spec.rb
```

Expected: PASS

**Step 5: Commit**

```bash
git add app/jobs/invoice_sync_job.rb spec/jobs/invoice_sync_job_spec.rb
git commit -m "feat: add InvoiceSyncJob"
```

---

## Task 7: 排程設定

**Files:**
- Modify: `config/recurring.yml`

**Step 1: 加入排程**

在 `config/recurring.yml` 的 `production:` 區塊加入：

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  invoice_sync:
    class: InvoiceSyncJob
    schedule: every day at 6am
```

**Step 2: Commit**

```bash
git add config/recurring.yml
git commit -m "feat: schedule InvoiceSyncJob daily at 6am"
```

---

## Task 8: Settings - 載具管理 CRUD

**Files:**
- Create: `app/controllers/settings/invoice_carriers_controller.rb`
- Create: `app/views/settings/invoice_carriers/index.html.erb`
- Create: `app/views/settings/invoice_carriers/new.html.erb`
- Create: `app/views/settings/invoice_carriers/edit.html.erb`
- Create: `app/views/settings/invoice_carriers/_form.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/system/invoice_carriers_spec.rb`

**Step 1: 寫 system spec**

```ruby
# spec/system/invoice_carriers_spec.rb
require "rails_helper"

RSpec.describe "載具管理", type: :system do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "新增載具" do
    visit settings_invoice_carriers_path
    click_link "新增載具"
    fill_in "顯示名稱", with: "我的手機"
    fill_in "手機條碼", with: "/ABC1234"
    fill_in "驗證碼", with: "1234"
    click_button "儲存"
    expect(page).to have_text("我的手機")
    expect(page).to have_text("/ABC1234")
  end

  it "格式錯誤時顯示錯誤訊息" do
    visit new_settings_invoice_carrier_path
    fill_in "顯示名稱", with: "手機"
    fill_in "手機條碼", with: "invalid"
    fill_in "驗證碼", with: "1234"
    click_button "儲存"
    expect(page).to have_text("格式不正確")
  end

  it "刪除載具" do
    create(:invoice_carrier, household: user.household, label: "舊手機")
    visit settings_invoice_carriers_path
    click_button "刪除"
    expect(page).not_to have_text("舊手機")
  end
end
```

**Step 2: 新增路由**

在 `config/routes.rb` 的 `namespace :settings` 區塊加入：

```ruby
namespace :settings do
  resources :category_groups, only: [:new, :create, :edit, :update, :destroy] do
    resources :categories, only: [:new, :create, :edit, :update, :destroy]
  end
  resources :invoice_carriers, only: [:index, :new, :create, :edit, :update, :destroy]
end
```

**Step 3: 實作 Controller**

```ruby
# app/controllers/settings/invoice_carriers_controller.rb
module Settings
  class InvoiceCarriersController < ApplicationController
    before_action :set_carrier, only: [:edit, :update, :destroy]

    def index
      @carriers = Current.household.invoice_carriers.order(:created_at)
    end

    def new
      @carrier = Current.household.invoice_carriers.build
    end

    def create
      @carrier = Current.household.invoice_carriers.build(carrier_params)
      if @carrier.save
        redirect_to settings_invoice_carriers_path, notice: "載具已新增"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @carrier.update(carrier_params)
        redirect_to settings_invoice_carriers_path, notice: "載具已更新"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @carrier.destroy
      redirect_to settings_invoice_carriers_path, notice: "載具已刪除"
    end

    private

    def set_carrier
      @carrier = Current.household.invoice_carriers.find(params[:id])
    end

    def carrier_params
      params.require(:invoice_carrier).permit(:label, :carrier_number, :verification_code)
    end
  end
end
```

**Step 4: 建立 Views**

```erb
<%# app/views/settings/invoice_carriers/index.html.erb %>
<div class="max-w-2xl mx-auto px-4 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-semibold text-slate-800">載具管理</h1>
    <%= link_to "新增載具", new_settings_invoice_carrier_path,
          class: "px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700" %>
  </div>

  <div class="space-y-3">
    <% @carriers.each do |carrier| %>
      <div class="bg-white rounded-xl border border-slate-200 px-4 py-3 flex items-center justify-between">
        <div>
          <p class="font-medium text-slate-800"><%= carrier.label %></p>
          <p class="text-sm text-slate-500"><%= carrier.carrier_number %></p>
          <% if carrier.last_synced_at %>
            <p class="text-xs text-slate-400">上次同步：<%= carrier.last_synced_at.strftime("%Y/%m/%d %H:%M") %></p>
          <% else %>
            <p class="text-xs text-slate-400">尚未同步</p>
          <% end %>
        </div>
        <div class="flex gap-2">
          <%= link_to "編輯", edit_settings_invoice_carrier_path(carrier),
                class: "text-sm text-slate-600 hover:text-indigo-600" %>
          <%= button_to "刪除", settings_invoice_carrier_path(carrier), method: :delete,
                class: "text-sm text-red-500 hover:text-red-700",
                data: { turbo_confirm: "確定刪除？" } %>
        </div>
      </div>
    <% end %>

    <% if @carriers.empty? %>
      <p class="text-slate-500 text-sm text-center py-8">尚未設定載具</p>
    <% end %>
  </div>
</div>
```

```erb
<%# app/views/settings/invoice_carriers/_form.html.erb %>
<%= form_with model: [:settings, carrier], class: "space-y-4" do |f| %>
  <% if carrier.errors.any? %>
    <div class="bg-red-50 border border-red-200 rounded-lg px-4 py-3">
      <ul class="text-sm text-red-600 space-y-1">
        <% carrier.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :label, "顯示名稱", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :label, class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500", placeholder: "例：Jerry 的手機" %>
  </div>

  <div>
    <%= f.label :carrier_number, "手機條碼", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.text_field :carrier_number, class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500", placeholder: "/XXXXXXX" %>
    <p class="mt-1 text-xs text-slate-400">格式為 /XXXXXXX，共 8 碼（斜線 + 7 個字元）</p>
  </div>

  <div>
    <%= f.label :verification_code, "驗證碼", class: "block text-sm font-medium text-slate-700 mb-1" %>
    <%= f.password_field :verification_code, class: "w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
  </div>

  <div class="flex gap-3 pt-2">
    <%= f.submit "儲存", class: "px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 cursor-pointer" %>
    <%= link_to "取消", settings_invoice_carriers_path, class: "px-4 py-2 text-sm text-slate-600 hover:text-slate-800" %>
  </div>
<% end %>
```

```erb
<%# app/views/settings/invoice_carriers/new.html.erb %>
<div class="max-w-lg mx-auto px-4 py-8">
  <h1 class="text-xl font-semibold text-slate-800 mb-6">新增載具</h1>
  <%= render "form", carrier: @carrier %>
</div>
```

```erb
<%# app/views/settings/invoice_carriers/edit.html.erb %>
<div class="max-w-lg mx-auto px-4 py-8">
  <h1 class="text-xl font-semibold text-slate-800 mb-6">編輯載具</h1>
  <%= render "form", carrier: @carrier %>
</div>
```

**Step 5: 執行 system spec**

```bash
bundle exec rspec spec/system/invoice_carriers_spec.rb
```

Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/settings/invoice_carriers_controller.rb app/views/settings/invoice_carriers/ config/routes.rb spec/system/invoice_carriers_spec.rb
git commit -m "feat: add invoice carriers settings UI"
```

---

## Task 9: 待確認發票頁面

**Files:**
- Create: `app/controllers/pending_invoices_controller.rb`
- Create: `app/views/pending_invoices/index.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/system/pending_invoices_spec.rb`

**Step 1: 寫 system spec**

```ruby
# spec/system/pending_invoices_spec.rb
require "rails_helper"

RSpec.describe "待確認發票", type: :system do
  let(:user) { create(:user) }
  let!(:carrier) { create(:invoice_carrier, household: user.household) }
  let!(:group) { create(:category_group, household: user.household, name: "食物") }
  let!(:category) { create(:category, category_group: group, name: "餐飲") }
  let!(:account) { create(:account, household: user.household, account_type: "budget") }
  let!(:invoice) do
    create(:pending_invoice,
      invoice_carrier: carrier,
      seller_name: "7-11",
      total_amount: 150,
      invoice_date: Date.today,
      details: [{ description: "咖啡", quantity: 1, unit_price: 50, amount: 50 }]
    )
  end

  before { sign_in(user) }

  it "顯示待確認發票清單" do
    visit pending_invoices_path
    expect(page).to have_text("7-11")
    expect(page).to have_text("$150")
  end

  it "展開發票可看到商品明細" do
    visit pending_invoices_path
    click_button "查看明細"
    expect(page).to have_text("咖啡")
  end

  it "確認匯入發票後建立 Transaction" do
    visit pending_invoices_path
    select "餐飲", from: "類別"
    select account.name, from: "帳戶"
    click_button "確認匯入"
    expect(page).not_to have_text("7-11")
    expect(Transaction.count).to eq(1)
    expect(Transaction.last.memo).to eq("7-11")
  end

  it "略過發票後不再顯示" do
    visit pending_invoices_path
    click_button "略過"
    expect(page).not_to have_text("7-11")
    expect(invoice.reload.status).to eq("skipped")
  end
end
```

**Step 2: 新增路由**

在 `config/routes.rb` 加入：

```ruby
resources :pending_invoices, only: [:index] do
  member do
    post :import
    post :skip
  end
end
```

**Step 3: 實作 Controller**

```ruby
# app/controllers/pending_invoices_controller.rb
class PendingInvoicesController < ApplicationController
  def index
    @pending_invoices = Current.household.invoice_carriers
                                .flat_map { |c| c.pending_invoices.pending.recent_first.to_a }
                                .sort_by(&:invoice_date).reverse
    @categories = Current.household.category_groups
                          .includes(:categories).flat_map(&:categories)
    @accounts   = Current.household.accounts.active
  end

  def import
    invoice  = find_pending_invoice
    category = Current.household.category_groups
                      .flat_map(&:categories).find { |c| c.id == params[:category_id].to_i }
    account  = Current.household.accounts.find(params[:account_id])

    Transaction.create!(
      account:  account,
      category: category,
      amount:   -invoice.total_amount,
      date:     invoice.invoice_date,
      memo:     invoice.seller_name
    )

    invoice.update!(status: "imported", confirmed_category: category)
    redirect_to pending_invoices_path, notice: "#{invoice.seller_name} 已匯入"
  end

  def skip
    find_pending_invoice.update!(status: "skipped")
    redirect_to pending_invoices_path, notice: "已略過"
  end

  private

  def find_pending_invoice
    PendingInvoice.joins(:invoice_carrier)
                  .where(invoice_carriers: { household_id: Current.household.id })
                  .find(params[:id])
  end
end
```

**Step 4: 建立 View**

```erb
<%# app/views/pending_invoices/index.html.erb %>
<div class="max-w-2xl mx-auto px-4 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-semibold text-slate-800">待確認發票</h1>
    <span class="text-sm text-slate-500"><%= @pending_invoices.size %> 筆待確認</span>
  </div>

  <% if @pending_invoices.empty? %>
    <div class="text-center py-16 text-slate-400">
      <p class="text-lg">沒有待確認的發票</p>
      <p class="text-sm mt-2">每日 06:00 自動同步</p>
    </div>
  <% else %>
    <div class="space-y-4">
      <% @pending_invoices.each do |invoice| %>
        <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div class="px-4 py-3">
            <div class="flex items-start justify-between">
              <div>
                <p class="font-medium text-slate-800"><%= invoice.seller_name %></p>
                <p class="text-sm text-slate-500"><%= invoice.invoice_date.strftime("%Y/%m/%d") %> · <%= invoice.invoice_number %></p>
              </div>
              <p class="text-lg font-semibold text-slate-800">$<%= number_with_delimiter(invoice.total_amount.to_i) %></p>
            </div>

            <%# 商品明細（可展開） %>
            <% if invoice.details.present? %>
              <details class="mt-2">
                <summary class="text-xs text-indigo-600 cursor-pointer hover:text-indigo-800">查看明細（<%= invoice.details.size %> 項）</summary>
                <div class="mt-2 space-y-1">
                  <% invoice.details.each do |item| %>
                    <div class="flex justify-between text-xs text-slate-600">
                      <span><%= item["description"] || item[:description] %></span>
                      <span>$<%= (item["amount"] || item[:amount]).to_i %></span>
                    </div>
                  <% end %>
                </div>
              </details>
            <% end %>
          </div>

          <%# 確認表單 %>
          <%= form_with url: import_pending_invoice_path(invoice), method: :post, class: "border-t border-slate-100 px-4 py-3 bg-slate-50 flex flex-wrap items-center gap-3" do |f| %>
            <div class="flex-1 min-w-36">
              <%= label_tag :category_id, "類別", class: "block text-xs text-slate-500 mb-1" %>
              <%= select_tag :category_id,
                    options_for_select(
                      @categories.map { |c| [c.name, c.id] },
                      invoice.suggested_category&.id
                    ),
                    include_blank: "-- 選擇類別 --",
                    class: "w-full border border-slate-300 rounded-lg px-2 py-1 text-sm" %>
            </div>
            <div class="flex-1 min-w-36">
              <%= label_tag :account_id, "帳戶", class: "block text-xs text-slate-500 mb-1" %>
              <%= select_tag :account_id,
                    options_for_select(@accounts.map { |a| [a.name, a.id] }),
                    class: "w-full border border-slate-300 rounded-lg px-2 py-1 text-sm" %>
            </div>
            <div class="flex gap-2 self-end">
              <%= f.submit "確認匯入", class: "px-3 py-1.5 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 cursor-pointer" %>
            </div>
          <% end %>

          <%# 略過按鈕 %>
          <%= button_to "略過", skip_pending_invoice_path(invoice), method: :post,
                class: "w-full text-xs text-slate-400 hover:text-slate-600 py-2 border-t border-slate-100" %>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

**Step 5: 執行 system spec**

```bash
bundle exec rspec spec/system/pending_invoices_spec.rb
```

Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/pending_invoices_controller.rb app/views/pending_invoices/ config/routes.rb spec/system/pending_invoices_spec.rb
git commit -m "feat: add pending invoices review UI"
```

---

## Task 10: 導覽列 badge 與設定連結

**Files:**
- Modify: `app/views/shared/_nav.html.erb`

**Step 1: 更新導覽列**

在 `app/views/shared/_nav.html.erb` 的 desktop sidebar 與 mobile tab bar 中，加入發票與設定的連結。

Desktop sidebar 的 `<nav>` 區塊加入：

```erb
<%= link_to pending_invoices_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path == pending_invoices_path ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
  <%= icon "document-text", classes: "w-5 h-5 shrink-0" %>
  <span class="flex-1">發票</span>
  <% pending_count = Current.household.invoice_carriers.flat_map { |c| c.pending_invoices.pending }.size %>
  <% if pending_count > 0 %>
    <span class="inline-flex items-center justify-center w-5 h-5 bg-indigo-600 text-white text-xs font-bold rounded-full"><%= pending_count %></span>
  <% end %>
<% end %>

<%= link_to settings_invoice_carriers_path, class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium #{request.path.start_with?(settings_invoice_carriers_path) ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}" do %>
  <%= icon "cog-6-tooth", classes: "w-5 h-5 shrink-0" %>
  載具設定
<% end %>
```

Mobile tab bar 加入（注意手機版空間有限，可考慮只加 badge 到現有項目）：

```erb
<%= link_to pending_invoices_path, class: "flex-1 flex flex-col items-center py-3 gap-1 text-xs relative #{request.path == pending_invoices_path ? 'text-indigo-600' : 'text-slate-500'}" do %>
  <%= icon "document-text", classes: "w-6 h-6" %>
  <% pending_count = Current.household.invoice_carriers.flat_map { |c| c.pending_invoices.pending }.size %>
  <% if pending_count > 0 %>
    <span class="absolute top-2 right-1/4 w-4 h-4 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center"><%= pending_count %></span>
  <% end %>
  發票
<% end %>
```

**Step 2: 執行所有測試確認沒有 regression**

```bash
bundle exec rspec
```

Expected: All examples passing

**Step 3: Commit**

```bash
git add app/views/shared/_nav.html.erb
git commit -m "feat: add pending invoices badge to nav"
```

---

## 完成後確認清單

- [ ] `bundle exec rspec` 全部通過
- [ ] 手動測試：設定頁可新增 / 編輯 / 刪除載具
- [ ] 手動測試：待確認頁面顯示發票、確認後建立 Transaction、略過後消失
- [ ] 導覽列 badge 正確顯示待確認筆數
- [ ] `docs/STATUS.md` 更新功能清單
