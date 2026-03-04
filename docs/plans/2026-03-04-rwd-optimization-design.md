# RWD 優化設計：iPhone 15 Pro 適配

**日期：** 2026-03-04
**目標：** 全面優化手機版佈局，以 iPhone 15 Pro (393pt) 為主要目標，採用原生 App 風格
**方案：** 漸進式 Tailwind 優化（逐頁調整，不引入新依賴）

## 全域基礎設施

### Safe Area 適配
- viewport meta 加入 `viewport-fit=cover`
- 底部 tab bar 加入 `pb-[env(safe-area-inset-bottom)]`
- 頂部通知區域考慮 Dynamic Island

### 底部導航重構（6-7 → 5 個 tab）
**保留：** 預算、帳戶、報表、記帳
**新增：** 設定（整合類別管理、對應管理、管理員功能）

規格：
- 圖示 `w-6 h-6`
- 文字 `text-[10px]`
- 點擊區域至少 44x44pt
- active 狀態用 indigo 色

### 統一頁面容器
手機全寬，桌面維持 max-width：
```
px-4 py-4 lg:max-w-4xl lg:mx-auto lg:px-6 lg:py-8
```

## 各頁面設計

### 預算頁（Budget Index）
- **手機：** 表格改為卡片列表
  - 群組標題保持
  - 每個類別一張卡片：名稱、預算/剩餘金額、進度條
  - 點擊卡片 → 類別交易明細
- **桌面：** 保持原表格
- 切換方式：`hidden lg:block` / `lg:hidden`
- 摘要卡片保持 `grid-cols-2`

### 帳戶列表（Accounts Index）
- 取消 max-width，改全寬容器
- 帳戶卡片字體稍微加大
- 其餘保持（已是卡片式）

### 帳戶詳情（Accounts Show）
- **標題區：** 改為垂直排列（帳戶名 → 餘額 → 按鈕列）
- **交易列表：** 手機版表格改為卡片列表
  - 每張卡片：日期+備註（第一行）、類別（第二行灰字）、金額靠右
  - 點擊展開編輯/刪除操作
- **桌面版保持原表格**

### 報表頁（Reports）
- 已有 `lg:grid-cols-2` 響應式
- 圓餅圖 `w-48 h-48` → `w-40 h-40`（手機稍縮小）

### 類別交易明細（Category Transactions）
- 交易表格手機版改卡片列表（同帳戶詳情）
- 篩選晶片保持 `flex flex-wrap`

### 快速記帳（Quick Entry）
- 取消 max-width，改全寬 + padding

### 設定頁（新增）
- 新增 Settings 首頁（`/settings`）
- 列表入口：類別管理、快速記帳對應管理、使用者管理（admin）
- 各入口為帶箭頭的大卡片

### 類別管理（Settings > Categories）
- 保持現有佈局，取消 max-width

### 登入頁
- 已響應式，不調整

### 抽屜面板
- 已有 `w-full sm:w-96`
- 加入 safe area bottom padding

## 技術要點

- 使用 `hidden lg:block` / `lg:hidden` 切換表格/卡片（兩套 markup）
- Safe area 用 CSS `env(safe-area-inset-*)` 原生支援
- 所有可點擊元素最小 44x44pt
- 不引入新依賴，純 Tailwind 類別調整
