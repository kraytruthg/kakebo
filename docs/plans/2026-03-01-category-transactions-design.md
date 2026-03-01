# 類別交易明細頁設計

日期：2026-03-01

## 背景

目前帳戶頁（`/accounts/:id`）只顯示單一帳戶的最近 50 筆交易，無法跨帳戶查看。
用戶需要能從預算頁點擊類別，查看該類別該月所有帳戶的交易明細，並能編輯、刪除交易。

## 目標

- 從預算頁連結進入特定類別 + 月份的跨帳戶交易明細
- 可依帳戶篩選
- 可編輯（修改日期、備註、類別、金額）與刪除交易

## 路由

```
GET /budget/:year/:month/categories/:category_id/transactions
    ?account_id=   # 可選，篩選特定帳戶
```

新增 routes：
```ruby
get "budget/:year/:month/categories/:category_id/transactions",
    to: "budget/category_transactions#index",
    as: :budget_category_transactions
```

同時為現有 `transactions` nested routes 加上 `update`：
```ruby
resources :transactions, only: [:create, :update, :destroy]
```

## Controller

`Budget::CategoryTransactionsController#index`

- 驗證 category 屬於當前 household，否則 404
- 載入該類別 + 月份的所有交易（跨帳戶）
- 若 `account_id` 有值且屬於 household，加入帳戶篩選

`TransactionsController#update`（新增）

- 驗證 transaction 屬於 account，account 屬於 household
- 更新成功後 redirect 回 referer（保持篩選狀態）

## 頁面設計

### 標題區
- 類別名稱 + 年月（例：「食費 — 2026年3月」）
- 返回預算頁的連結（含同一年月）

### 帳戶篩選
- 一排 chip：「全部」+ 各帳戶名稱
- 點擊切換 `?account_id=` 全頁重整

### 交易列表
- 欄位：日期 / 備註 / 帳戶名稱 / 金額
- 按日期降序排列
- 每筆右側：編輯 icon（開啟 drawer）、刪除按鈕
- 空狀態：「本月沒有此類別的交易紀錄」

### 編輯 Drawer
- 複用現有 `drawer` Stimulus controller
- 表單欄位：日期、備註、類別（下拉）、金額
- 儲存後 redirect 回當前頁面（保持年月 + 類別 + 帳戶篩選）
- 驗證失敗 → turbo stream 回傳錯誤訊息

### 底部合計
- 顯示篩選後交易的金額合計

## 資料查詢

```ruby
Transaction
  .joins(:account, category: :category_group)
  .where(category_id: @category.id)
  .where(category_groups: { household_id: Current.household.id })
  .for_month(@year, @month)
  .then { |q| @account ? q.where(account_id: @account.id) : q }
  .recent
```

## 錯誤處理

- 類別不屬於 household → 404
- `account_id` 不屬於 household → 忽略，顯示全部
- 交易驗證失敗 → drawer 內顯示錯誤

## 測試（System Spec）

- 從預算頁點擊類別連結進入明細頁
- 顯示跨帳戶的交易紀錄
- 帳戶 chip 篩選有效
- 編輯交易後資料更新
- 刪除交易後消失
