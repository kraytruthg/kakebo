# Kakebo — 家庭記帳 App 設計文件

**日期：** 2026-02-27
**專案：** kakebo
**技術棧：** Rails 8.1 / Ruby 3.4 / PostgreSQL / Hotwire (Turbo + Stimulus) / Tailwind CSS
**部署：** Render

---

## 目標

給兩人家庭（夫妻）使用的預算先決記帳 App，實作完整 YNAB 邏輯：
- Ready to Assign（RTA）
- 月份間餘額滾入（Rollover）
- Budget account / Tracking account 分類
- 零基預算（Zero-based budgeting）

---

## 使用者範圍

- 單一 Household，兩個 User 帳號
- 共享同一組帳戶、類別、預算、交易
- 認證：Rails 8 內建 `has_secure_password`，Session-based

---

## 資料模型

```
Household
├── User (has_secure_password)
├── Account
│   ├── account_type: enum [budget, tracking]
│   ├── name, balance, starting_balance
│   └── active: boolean
├── CategoryGroup
│   ├── name, position
│   └── Category
│       ├── name, position
│       └── BudgetEntry (year × month × category)
│           ├── budgeted: decimal     ← 使用者手動分配
│           ├── carried_over: decimal ← 上月 available（系統計算後存起來）
│           └── available = carried_over + budgeted + activity（即時計算）
└── Transaction
    ├── account_id
    ├── category_id (nil = income，直接增加 RTA)
    ├── amount: decimal
    ├── date
    ├── memo: string
    └── transfer_pair_id (帳戶轉帳時兩筆互相對應)
```

### 核心計算邏輯

**Ready to Assign（RTA）**
```
RTA = 所有 budget account 餘額總和 - 所有 category available 總和
```

**Category Available**
```
available = carried_over + budgeted + activity
activity  = 該月該 category 的所有 transactions 加總（即時查詢）
```

**Rollover（月份滾入）**
- `carried_over` 存在 `budget_entries` 資料表
- 當過去的 transaction 被修改時，觸發 `BudgetEntryRecalculationJob`
  從修改月份往後 cascade 更新所有 `carried_over`

---

## 頁面規劃

### 1. 預算頁（Budget）— 主介面
- 月份切換導航（Turbo Frame 局部更新）
- Ready to Assign 顯示在最上方
- 左欄：CategoryGroup + Category 清單
- 右側三欄：Budgeted / Activity / Available
- 點擊 Budgeted 欄位輸入金額
  - Stimulus 即時預覽 RTA 變動
  - 送出後 Turbo Stream 更新 RTA 和該列數字

### 2. 帳戶頁（Accounts）
- 左側：帳戶清單（budget / tracking 分組）
- 右側：該帳戶交易清單
- 新增 / 編輯 / 刪除交易
- 帳戶間轉帳

### 3. 新增交易表單
- 欄位：帳戶、類別、金額、日期、備註
- 轉帳模式：選擇來源和目標帳戶

### 4. 報表頁（Reports）
- 月度支出圓餅圖（各類別佔比）
- 六個月收支趨勢折線圖

---

## Hotwire 使用策略

| 互動 | 技術 |
|------|------|
| 月份切換 | Turbo Frame |
| 輸入 Budgeted → 更新 RTA | Turbo Stream |
| 新增交易 → 更新帳戶餘額和交易清單 | Turbo Stream |
| Budgeted 欄位即時預覽 | Stimulus controller |
| 交易表單切換轉帳模式 | Stimulus controller |

---

## 認證設計

- `has_secure_password` + `generates_token_for :session`
- Session cookie based
- Controller 層：`before_action :require_login`
- `Current.household` 提供當前家庭 scope，確保資料隔離

---

## 背景工作

- **BudgetEntryRecalculationJob**：Transaction 修改後，重算受影響月份之後的所有 `carried_over`
- 使用 Rails 8 內建 Solid Queue

---

## 測試策略

- Model spec：BudgetEntry 計算邏輯、cascade 更新
- System spec（Capybara）：預算頁輸入金額 → RTA 更新完整流程
- Request spec：取代 controller spec

---

## v1 不做（之後再加）

| 功能 | 原因 |
|------|------|
| Split Transaction | 增加複雜度，手動分兩筆可替代 |
| Payee 自動完成 | 兩人使用規模不需要 |
| Age of Money | 錦上添花，v1 先跑起來 |
| 手機 App | 先用 PWA / 手機瀏覽器 |

---

## 部署（Render）

- Web Service：Rails + Puma
- Database：Render 託管 PostgreSQL
- 環境變數：`DATABASE_URL`、`RAILS_MASTER_KEY`
- `bin/render-build.sh`：`bundle install && rails assets:precompile && rails db:migrate`
