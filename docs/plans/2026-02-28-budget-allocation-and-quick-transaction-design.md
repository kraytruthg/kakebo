# 預算分配 & 快速新增交易 設計文件

**日期：** 2026-02-28
**狀態：** 已確認，待實作

## 問題陳述

1. 預算頁面只能顯示，無法編輯各類別的「已分配」金額（`BudgetEntry#budgeted`）
2. 預算頁面沒有快速新增交易的入口，必須跳轉到帳戶頁才能記帳

## 解決方案：方案 A（Turbo Frame + Stimulus + Drawer）

### 功能一：Inline 預算分配

#### 後端

- 新建 `BudgetEntriesController`，提供：
  - `GET /budget_entries/:id/edit` → 回傳 inline input 的 Turbo Frame HTML
  - `POST /budget_entries` / `PATCH /budget_entries/:id` → upsert 後回傳 Turbo Stream
- 統一用 `BudgetEntry.find_or_initialize_by(category_id:, year:, month:)` 處理 create/update

- Turbo Stream 回應：replace 對應 `budget-entry-CATEGORY_ID` frame，同時 replace `available-CATEGORY_ID` span

#### 前端

- 「已分配」欄位包在 `<turbo-frame id="budget-entry-CATEGORY_ID">`
- 預設顯示格式化金額，整格可點擊（cursor: pointer）
- 點擊後：Turbo 發 GET，frame 換成 `<input type="number">` + hidden submit
- 互動規則：
  - Enter → 送出
  - Escape → 取消，恢復顯示
  - Blur → 不自動送出

### 功能二：Row 旁快速新增交易

#### 後端

- 沿用現有 `POST /accounts/:account_id/transactions` route，不新增 route
- Transaction create 成功後，Turbo Stream **額外** replace：
  - `activity-CATEGORY_ID` span（本月支出）
  - `available-CATEGORY_ID` span（可用金額）
- 計算方式沿用現有 `@monthly_activities` 邏輯，但改為 per-category 查詢後回傳

#### 前端

- 每個 category row 最右側加「操作」欄，hover 時出現 `+` 按鈕
- 複用 accounts/show 現有 `drawer` Stimulus controller
- 新增 `data-action="budget#openWithCategory"` 傳遞 `data-category-id` / `data-category-name`
- Drawer 內表單欄位：
  - 帳戶（budget 帳戶下拉，預設第一張）→ 切換時 Stimulus 更新 form action
  - 金額（必填）
  - 備註
  - 日期（預設今天）
  - 類別（唯讀顯示 + hidden input 傳值）
- 送出成功：Turbo Stream 更新 activity/available，Drawer 關閉

## 受影響檔案

| 檔案 | 操作 |
|------|------|
| `config/routes.rb` | 新增 `resources :budget_entries, only: [:edit, :create, :update]` |
| `app/controllers/budget_entries_controller.rb` | 新建 |
| `app/views/budget_entries/edit.html.erb` | 新建（inline input frame）|
| `app/views/budget_entries/update.turbo_stream.erb` | 新建 |
| `app/views/budget/index.html.erb` | 加 turbo-frame、id span、drawer、+ 按鈕 |
| `app/views/transactions/create.turbo_stream.erb` | 擴充：條件式更新 budget row |
| `app/javascript/controllers/budget_controller.js` | 新建（openWithCategory、form action 切換）|
| `app/controllers/transactions_controller.rb` | 擴充：budget 頁呼叫時回傳 category activity |

## 不在本次範圍

- 刪除或重新排序 BudgetEntry
- 月份間的 rollover 邏輯調整
- 類別管理（新增 / 刪除類別）
