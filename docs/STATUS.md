# Kakebo 系統開發狀態

最後更新：2026-03-01

## 已完成

- 認證：登入 / 登出 / 註冊（REGISTRATION_OPEN 開關）
- 帳戶管理：新增 / 編輯（預算帳戶 / 追蹤帳戶）
- 預算分配：BudgetEntry 編輯、Ready to Assign、複製上月
- 月份切換：URL 參數 ?year=&month=，邊界保護
- 自動結轉：首次瀏覽某月自動從上月 available 建立 carried_over
- 交易記錄：從帳戶頁新增 / 刪除 / 編輯
- 類別管理：CategoryGroup / Category CRUD，刪除保護
- Onboarding：新用戶首次登入引導建立第一個帳戶

## 進行中

- 類別交易明細頁：從預算頁進入某類別的跨帳戶月份交易列表（feature/category-transactions）

## 待開發

### 預算功能

#### 目標設定（Goals）
每個 Category 可設定儲蓄或支出目標，預算頁每行顯示進度條與達成率。
- **月度目標（Monthly Target）**：每月需分配到指定金額。適合固定開銷（餐費、交通）。進度 = 本月已預算 / 目標金額。
- **存到指定日期（Savings by Date）**：在某年月前累積到指定總額。系統自動計算每月應存金額 = （目標 − 已累積）/ 剩餘月數。
- 資料模型建議：在 `categories` 加 `goal_type`（enum）、`goal_amount`（decimal）、`goal_target_date`（date）。
- UI：預算頁類別行內嵌進度條，綠＝達標、黃＝部分、紅＝未達標；點擊展開 Turbo Frame 顯示詳情與設定表單。

#### Auto-Assign
一鍵將 Ready to Assign 依各類別目標自動分配，省去逐一輸入的麻煩。
- 邏輯：依目標計算每個類別本月尚缺金額，由 RTA 依序填入（不超過 RTA 餘額）。
- 入口：預算頁頂部「自動分配」按鈕，觸發 PATCH 到 `budgets#auto_assign`，以 Turbo Stream 更新各行。

#### 預算範本（Budget Template）
儲存當前月份的預算配置作為範本，之後可一鍵套用，適合收入穩定的用戶。
- 與「複製上月」的差別：範本是手動命名儲存、隨時可套用；複製上月是直接抄上月實際數字。
- 資料模型：`BudgetTemplate`（name）→ `BudgetTemplateEntry`（category_id, amount）。

---

### 交易功能

#### 帳戶間轉帳（Transfer）
在兩個帳戶之間建立一筆轉帳，自動在來源帳戶產生支出交易、目標帳戶產生收入交易，兩筆互相關聯。
- 資料模型：`Transaction` 加 `transfer_id`（self-referential），或獨立 `Transfer` model 關聯兩筆 Transaction。
- 重點：轉帳不影響預算（不屬於任何 Category），僅在追蹤帳戶與預算帳戶之間搬移餘額。

#### 分割交易（Split Transaction）
單筆消費拆分到多個類別（如一張超市收據同時含餐費和日用品）。
- 資料模型：主 Transaction 有多個 `TransactionSplit`，各自有 category_id 與 amount，合計須等於主交易金額。
- UI：交易表單內可動態新增分割行（Stimulus controller）。

#### 定期交易（Recurring Transactions）
設定每月/每週固定收支規則（如薪水、房租），系統在指定日期自動建立交易。
- 資料模型：`RecurringTransaction`（frequency, amount, category_id, account_id, next_due_date）；以 cron job（Solid Queue）每日檢查到期項目並建立交易。
- 使用者可提前確認或跳過當期。

#### 收款方管理（Payee）
記錄常用商家名稱，輸入交易時自動補全並預填上次使用的類別。
- 資料模型：`Payee`（household_id, name）；Transaction 加 `payee_id`。
- 記憶邏輯：新增交易時，選定 payee 後自動帶入該 payee 最近一次使用的 category。

---

### 帳戶功能

#### CSV 交易匯入
從銀行網站下載 CSV 後上傳，系統解析並批次建立交易，支援欄位對應設定。
- 需處理：日期格式、正負號（支出 vs 收入）、重複交易偵測（相同日期 + 金額 + 帳戶則跳過）。
- UI：上傳頁顯示預覽表格，讓使用者確認欄位對應後再匯入。

#### 帳戶對帳（Reconciliation）
將帳戶帳面餘額與銀行實際餘額核對，逐筆確認後鎖定已對帳交易。
- 交易狀態：`uncleared`（未清算）→ `cleared`（已清算，使用者確認）→ `reconciled`（已對帳，不可再修改）。
- 流程：輸入銀行當前餘額 → 系統列出未對帳交易 → 逐一勾選 → 差額歸零後完成對帳，建立一筆「對帳調整」交易補差額。

#### 信用卡特殊處理（Credit Card）
信用卡帳戶刷卡時，自動將對應金額從消費類別預算移至「信用卡付款」類別，確保還款時不會重複扣預算。
- YNAB 核心設計：信用卡是負債帳戶，刷卡 = 支出類別 − 預算 + 信用卡付款類別 + 預算；還款時扣「信用卡付款」類別，餘額歸零。
- 需判斷帳戶是否為信用卡類型（`account_type: :credit_card`）並在 Transaction after_commit 觸發自動轉移邏輯。

---

### 報表功能

#### 支出報表
月度各類別支出金額，以長條圖或圓餅圖呈現，快速看出花最多錢的類別。
- 資料來源：該月所有 budget 帳戶的負向交易，按 category 分組加總。
- 可篩選月份範圍（最近 3/6/12 個月）。

#### 收入 vs 支出
月度收入與支出加總對比，折線圖顯示趨勢，判斷是否入不敷出。
- 收入 = 該月正向交易加總（income category 或無 category）；支出 = 負向交易加總。

#### 淨資產走勢（Net Worth）
所有帳戶餘額加總（資產 − 負債），以折線圖呈現每月底淨資產變化。
- 需每月底快照帳戶餘額，或即時從交易計算歷史餘額。

#### 類別趨勢
單一類別的跨月支出折線圖，用來觀察特定開銷是否逐月攀升。
- 入口：從類別交易明細頁（進行中功能）新增「查看趨勢」連結。

---

### 其他

#### 老錢指標（Age of Money）
顯示你「花出去的錢」平均在帳戶裡待了幾天。天數越大代表財務越健康（不再月光）。
- 計算方式（YNAB 官方邏輯）：取最近 10 筆支出，追蹤每筆錢對應的收入日期，計算平均天數差。
- 作為儀表板首頁的健康指標之一。

#### 貸款計算機（Loan Tracker）
設定貸款金額、利率、期數，系統計算每月應還金額，並追蹤已還進度。
- 可連結一個追蹤帳戶（Tracking Account），以帳戶餘額反映剩餘負債。
- 優先度較低，屬進階功能。

## 維護說明

完成功能開發或重要修正後，AI Agent 提議更新此文件，由開發者確認後 commit。
