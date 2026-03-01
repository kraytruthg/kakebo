# 雲端發票匯入功能設計

## 背景

整合台灣財政部電子發票（雲端載具）API，讓使用者可自動同步發票紀錄並匯入為 Kakebo 交易。

## 需求摘要

- Household 可設定多組手機條碼（1-to-many）
- 每日自動由背景 job 同步發票至待確認列表
- 使用者確認發票明細、指定 Category 後才建立 Transaction
- 同一賣方自動帶入上次使用的 Category（記憶功能）

---

## 資料模型

### `invoice_carriers`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `household_id` | integer | 所屬家庭（FK） |
| `label` | string | 顯示名稱，例如「Jerry 的手機」 |
| `carrier_number` | string | 手機條碼，例如 `/ABC1234` |
| `verification_code` | string | 驗證碼（加密儲存） |
| `last_synced_at` | datetime | 上次同步時間 |

關聯：`Household has_many :invoice_carriers`

### `pending_invoices`

| 欄位 | 型別 | 說明 |
|------|------|------|
| `invoice_carrier_id` | integer | 來源載具（FK） |
| `invoice_number` | string | 發票號碼（unique，防重複） |
| `invoice_date` | date | 發票日期 |
| `seller_name` | string | 賣方名稱 |
| `total_amount` | decimal | 發票總金額 |
| `details` | jsonb | 商品明細陣列 |
| `status` | string | `pending` / `imported` / `skipped` |
| `confirmed_category_id` | integer | 確認時選的 Category（用於自動建議） |

---

## 背景同步機制

**`InvoiceSyncJob`**（Solid Queue 排程）

排程設定（`config/recurring.yml`）：
```yaml
invoice_sync:
  class: InvoiceSyncJob
  schedule: every day at 6am
```

流程：
1. 撈出所有 Household 的 `InvoiceCarrier`
2. 逐一呼叫財政部 API（AppID + APIKey 存 credentials，加上載具號碼 + 驗證碼）
3. 新發票寫入 `PendingInvoice`，以 `invoice_number` 防重複
4. 更新 `last_synced_at`
5. API 失敗時記錄錯誤並跳過，繼續處理下一個載具

---

## UI 流程

### 設定頁面 - 載具管理

- 路由：`/settings/invoice_carriers`
- Controller：`Settings::InvoiceCarriersController`
- 功能：列出、新增、編輯、刪除載具

### 待確認發票頁面

- 路由：`/pending_invoices`
- Controller：`PendingInvoicesController`
- 顯示所有 `status: pending` 發票，依日期排序
- 每筆顯示：賣方名稱、日期、金額、Category 下拉（自動帶入同賣方上次 category）
- 可展開查看商品明細（jsonb）
- 操作：**確認匯入** 或 **略過**

### 確認匯入流程

1. 使用者選好 Category，點「確認」
2. 建立 `Transaction`：
   - `date` = invoice_date
   - `amount` = total_amount
   - `memo` = seller_name
   - `category` = 使用者選擇的 category
3. `PendingInvoice` 標記為 `imported`，儲存 `confirmed_category_id`

### 導覽列 badge

顯示目前 `pending` 筆數，提醒使用者有待確認的發票。

---

## 安全考量

- `verification_code` 使用 Rails `encrypts` 加密儲存
- AppID + APIKey 存放於 Rails credentials，不進 git
- `invoice_carrier` 與 `pending_invoice` 的存取皆需驗證 household 歸屬
