# Quick Entry（快速記帳）設計文件

## 概述

讓使用者透過自然語言文字輸入快速記帳，系統自動解析並匹配類別與帳戶。未來可擴展為語音輸入。

## 使用者流程

```
輸入文字 → Regex 解析 → Mapping 查詢 → 確認/補充 → 建立 Transaction
```

### 範例

1. 輸入：`紀錄 Jerry 支付 家樂福採買 100`
2. Regex 解析：payer=Jerry, description=家樂福採買, amount=100
3. 查 Mapping：Jerry → Account「Jerry 現金」, 家樂福採買 → Category「生活花費」
4. 顯示確認畫面（所有欄位 pre-filled）
5. 用戶確認 → 建立 Transaction（category=生活花費, account=Jerry現金, memo=家樂福採買, amount=-100, date=今天）

### 匹配失敗時

- 找不到對應 → 確認畫面中該欄位空白，使用者手動選擇
- 確認畫面有「記住這個對應」勾選框 → 勾選後自動建立 mapping

## 資料模型

### QuickEntryMapping（多態）

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | bigint | PK |
| household_id | FK | 所屬家戶 |
| keyword | string | 關鍵字（如「家樂福採買」「Jerry」） |
| target_type | string | "Category" 或 "Account" |
| target_id | bigint | 對應的 category_id 或 account_id |
| created_at | datetime | |
| updated_at | datetime | |

**驗證：**
- keyword 必填
- keyword 在同一 household + target_type 下唯一
- target_type 限定為 "Category" 或 "Account"

**關聯：**
- `belongs_to :household`
- `belongs_to :target, polymorphic: true`

## 輸入格式（Regex 規則）

支援的格式（由完整到簡短）：

1. `紀錄 {payer} 支付 {description} {amount}` — 完整格式
2. `{payer} {description} {amount}` — 省略動詞
3. `{description} {amount}` — 省略 payer，帳戶需手動選或用預設

金額支援整數和小數（如 `100`、`99.5`）。

## 核心 Service

### QuickEntryParser

負責 regex 解析文字輸入。

```ruby
QuickEntryParser.parse("紀錄 Jerry 支付 家樂福採買 100")
# => { payer: "Jerry", description: "家樂福採買", amount: 100 }

QuickEntryParser.parse("停車費 50")
# => { payer: nil, description: "停車費", amount: 50 }
```

### QuickEntryResolver

負責用 mapping 表將解析結果轉換為具體的 Account/Category。

```ruby
QuickEntryResolver.resolve(parsed_result, household)
# => {
#      account: #<Account>,       # 或 nil（未匹配）
#      category: #<Category>,     # 或 nil（未匹配）
#      memo: "家樂福採買",
#      amount: -100,
#      date: Date.today
#    }
```

## 頁面與路由

### 1. Quick Entry 頁面（`/quick_entry`）

- **輸入階段**：一個文字輸入框 + 送出按鈕
- **確認階段**：顯示解析結果的表單
  - 帳戶下拉（pre-filled 或空白）
  - 類別下拉（pre-filled 或空白）
  - 金額（pre-filled）
  - Memo（pre-filled = description）
  - 日期（預設今天）
  - 「記住帳戶對應」勾選框（payer 有值且未匹配時顯示）
  - 「記住類別對應」勾選框（description 未匹配時顯示）
- 確認送出後建立 Transaction + 可選的 mapping

### 2. Settings 管理頁面

- `Settings::QuickEntryMappingsController` — CRUD
- 頁面上用 target_type 分組顯示（類別對應 / 帳戶對應）
- 路由：`/settings/quick_entry_mappings`

## 路由規劃

```ruby
resource :quick_entry, only: [:new, :create], controller: "quick_entry"

namespace :settings do
  resources :quick_entry_mappings
end
```

## 未來擴展

- **語音輸入**：加上 Web Speech API 或外部 STT 服務，將語音轉文字後餵入同一套解析邏輯
- **LLM fallback**：匹配失敗時可選擇用 LLM 推測類別
- **iOS Shortcut / LINE Bot**：透過 API endpoint 接入其他入口
