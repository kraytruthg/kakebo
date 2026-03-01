# MVP 設計文件

**日期：** 2026-03-01
**範圍：** 補齊 Kakebo 成為可部署單人記帳 MVP 所需的功能

---

## 背景

現有系統已實作認證、帳戶管理、預算分配、交易記錄、月度報表。本次 MVP 補齊以下缺口，使系統可部署至雲端供個人實際使用。

---

## 功能範圍（方案 B）

| # | 功能 | 說明 |
|---|------|------|
| 1 | **用戶註冊** | 填寫 email / 密碼 / 姓名完成註冊，同時建立專屬 Household；以環境變數 `REGISTRATION_OPEN` 控制是否開放公開註冊 |
| 2 | **月份切換** | 預算頁與報表頁加上 ← / → 導覽，URL 帶 `?year=&month=` 參數，任意月份皆可瀏覽與編輯 |
| 3 | **自動結轉** | 首次瀏覽某月預算時，若 BudgetEntry 不存在，自動從上個月的 `available` 建立本月 `carried_over`；上個月無資料則 `carried_over = 0` |
| 4 | **類別管理** | CategoryGroup / Category 的 CRUD 介面；預設 seed 提供基本分類（食物、交通、娛樂、住宅、醫療）；刪除前檢查是否有關聯交易 |
| 5 | **交易編輯** | 在帳戶頁交易列表加上編輯入口，支援修改金額、日期、備忘、類別；以 Turbo Stream 更新列表與預算 |
| 6 | **Onboarding 引導** | 新用戶首次登入若無帳戶，導向三步驟引導：① 建立第一個帳戶 → ② 確認預設類別（可略過）→ ③ 進入預算頁 |

---

## 架構

### Routes 新增

```
GET  /signup                                    → users#new
POST /users                                     → users#create

resources :category_groups do
  resources :categories
end

PATCH /accounts/:account_id/transactions/:id    → transactions#update

GET  /onboarding                                → onboarding#index
```

### Model 變動

| Model | 變動 |
|-------|------|
| **User** | 新增 `before_create :create_household` callback，建立同名 Household |
| **BudgetEntry** | 新增 `BudgetEntry.initialize_month!(household, year, month)`：從上個月各類別的 `available` 建立本月 `carried_over`，以 DB transaction 保證一致性 |
| **Transaction** | 新增 `update` action；after_commit 已有重新計算邏輯，不需額外修改 |
| **Category** | 新增刪除保護：有關聯交易時拒絕刪除並顯示提示 |
| **CategoryGroup** | 新增刪除保護：含有 Category 時拒絕刪除並顯示提示 |

### 環境變數

```
REGISTRATION_OPEN=false   # 預設關閉公開註冊（個人部署用）
```

---

## 月份切換設計

- URL 參數：`?year=2026&month=3`
- 合法範圍：year 2000–2099，month 1–12
- 超界或非數字 → redirect 到當月
- 邊界按鈕（2000/01 的上一月、2099/12 的下一月）設為 disabled

```ruby
def at_upper_bound?
  @year == 2099 && @month == 12
end

def at_lower_bound?
  @year == 2000 && @month == 1
end
```

---

## 自動結轉邏輯

**觸發時機：** `BudgetController#index` 呼叫時，若該月任一 BudgetEntry 不存在。

**結轉來源：** 僅看上個月（immediate previous）。

- 上個月有資料 → 各類別 `carried_over = 上月 available`
- 上個月無資料 → `carried_over = 0`
- 用戶跳月（中間有空月）→ 跳過的月份 `carried_over = 0`，行為符合預期

---

## Edge Cases 與錯誤處理

| 情境 | 處理方式 |
|------|---------|
| URL 帶非數字參數（`year=abc`） | redirect 到當月 |
| 年月超出合法範圍 | redirect 到當月 |
| 2000/01 按上一個月 | 按鈕 disabled |
| 2099/12 按下一個月 | 按鈕 disabled |
| 瀏覽某月但上個月無資料 | `carried_over = 0` |
| 刪除有交易的 Category | 拒絕，顯示「此分類有 N 筆交易，請先移除」 |
| 刪除有 Category 的 CategoryGroup | 拒絕並提示 |
| 新用戶無帳戶 | 登入後導向 onboarding |
| 公開註冊關閉時訪問 `/signup` | 顯示「目前不開放註冊」 |

---

## 測試策略

每個功能搭配 system test，涵蓋主要 happy path 與關鍵 error path：

| 功能 | 涵蓋範圍 |
|------|---------|
| 用戶註冊 | 成功、email 重複、註冊關閉 |
| 月份切換 | ← / → 導覽、邊界 disabled、非法 URL redirect |
| 自動結轉 | 首次瀏覽建立 entry、有上月資料帶入、無資料為 0 |
| 類別管理 | 新增 / 重新命名 / 刪除空分類 / 刪除有交易分類 |
| 交易編輯 | 修改金額後預算更新、修改類別後雙方 available 更新 |
| Onboarding | 新用戶導向引導、已有帳戶不觸發 |

Unit / Request test 補 model 方法與 controller 邊界驗證，不重複 system test 已涵蓋的流程。
