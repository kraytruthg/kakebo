# 帳戶間轉帳（Transfer）設計文件

日期：2026-03-01

## 功能概述

在兩個帳戶之間建立轉帳，自動在來源帳戶產生支出交易、目標帳戶產生收入交易，兩筆互相關聯。轉帳不影響預算（category_id 為 nil）。

## 決策摘要

- **入口**：帳戶頁頂部獨立「轉帳」按鈕，導向獨立表單頁
- **顯示**：類別欄顯示「轉出 → 帳戶B」/ 「轉入 ← 帳戶A」標籤，不顯示編輯按鈕
- **刪除**：刪除任一筆，兩筆同時刪除，兩帳戶餘額同步更新
- **編輯**：不支援，只能刪除後重建
- **帳戶限制**：任意兩帳戶皆可轉，排除自身

## 資料模型

Schema 已有 `transfer_pair_id integer` 欄位與索引，**不需要新 migration**。

```ruby
# Transaction model 補充
belongs_to :transfer_pair, class_name: "Transaction", optional: true
has_one    :transfer_counterpart, class_name: "Transaction", foreign_key: :transfer_pair_id
```

建立規則：
- 來源帳戶：`amount = -N`，`category_id = nil`
- 目標帳戶：`amount = +N`，`category_id = nil`
- 兩筆 `transfer_pair_id` 互相指向對方

驗證：
- 來源帳戶 ≠ 目標帳戶
- 兩帳戶都屬於同一 household
- amount 必須為正數（form 填正數，model 自動處理正負）

## 路由與 Controller

```ruby
resources :transfers, only: [:new, :create, :destroy]
```

### TransfersController

- `new`：render 轉帳表單，接受 `?from_account_id=` query param 預設來源帳戶
- `create`：在 DB transaction 內建立兩筆，失敗整體 rollback，render new with errors
- `destroy`：找到 transfer_pair，兩筆同時刪除，兩帳戶各 recalculate_balance!

```ruby
# create 核心邏輯
ActiveRecord::Base.transaction do
  outgoing = from_account.transactions.create!(amount: -amount, date:, memo:, category_id: nil)
  incoming = to_account.transactions.create!(amount: +amount, date:, memo:, category_id: nil, transfer_pair_id: outgoing.id)
  outgoing.update!(transfer_pair_id: incoming.id)
end

# destroy 核心邏輯
pair = @transaction.transfer_pair
@transaction.destroy
pair&.destroy
from_account.recalculate_balance!
to_account.recalculate_balance!
```

## UI 設計

### 帳戶頁按鈕區

```
[編輯]  [轉帳]  [新增交易]
```

「轉帳」連結：`/transfers/new?from_account_id=<id>`

### 轉帳表單頁（transfers/new）

獨立頁面（非 Drawer），欄位：
- 來源帳戶（下拉，預設帶入 query param，排除目標選項）
- 目標帳戶（下拉，排除來源帳戶）
- 金額（正整數）
- 日期（date picker，預設今天）
- 備註（選填）
- [取消] [確認轉帳]

### 交易列表 row

- 類別欄：`轉出 → 帳戶B` 或 `轉入 ← 帳戶A`
- 編輯連結：轉帳交易不顯示
- 刪除按鈕：保留，confirm 後連動刪除兩筆

## 錯誤處理

| 情境 | 處理 |
|------|------|
| 來源 = 目標帳戶 | model validation，render new with error |
| 帳戶不屬於 household | `Current.household.accounts.find` → 404 |
| amount ≤ 0 | model validation，render new with error |
| DB 中途失敗 | transaction rollback，render new with error |

## 測試策略

### System spec（`spec/system/transfers_spec.rb`）

- Happy path：點「轉帳」→ 填表 → 送出 → 兩帳戶各出現轉帳紀錄、餘額正確
- 刪除：刪除任一筆 → 兩筆同時消失、兩帳戶餘額還原
- Error path：選同一帳戶送出 → 顯示錯誤訊息

### Model spec

- `transfer?` 回傳正確值
- `income?` 排除 transfer 情境
