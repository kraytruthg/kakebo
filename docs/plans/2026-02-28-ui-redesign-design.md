# Kakebo UI 全面重設計

**日期**: 2026-02-28
**方向**: 全頁面重寫，含 Stimulus 互動

## 設計目標

從功能性但醜陋的 UI，升級為現代卡片式（Linear 風）的全平台體驗。

## 設計決策

| 項目 | 決定 |
|------|------|
| 裝置 | RWD（手機＋桌機） |
| 風格 | 現代卡片式（Linear 風） |
| Icons | Heroicons（SVG inline） |
| 主色調 | Indigo（藍小鴨藍） |
| 新增交易互動 | Slide-over Drawer（Stimulus） |

## Layout & Navigation

### 桌機
固定左側 sidebar（240px）：
- Logo + 品牌名
- 主導覽：預算 / 帳戶 / 報表（各含 Heroicon）
- 底部：使用者名稱 + 登出按鈕

背景 `bg-slate-50`，內容區 `max-w-5xl` 置中。

### 手機
Sidebar 隱藏，改為底部固定 tab bar：
- 預算 / 帳戶 / 報表（icon + 文字）

### Flash 通知
右上角 toast notification，Stimulus `notification` controller，3 秒後自動消失。

## 各頁面設計

### 登入頁（/sessions/new）
- 全螢幕 `bg-slate-100` 背景
- 白色卡片 `shadow-xl`，置中
- Indigo 品牌標題
- Input 有 Indigo focus ring
- Submit 按鈕：Indigo 漸層

### 預算頁（/budget）
- 月份導航：pill 風格上/下月切換
- Ready to Assign：大型 Indigo 漸層 hero card，數字大而醒目
- 類別群組：分隔 header（CategoryGroup 名稱）
- 類別列：懸浮時 left border highlight（Indigo）
- Budgeted 欄：inline 點擊編輯（Stimulus `inline-edit` + Turbo Stream）

### 帳戶頁（/accounts）
- 預算帳戶 / 追蹤帳戶分區，各為卡片列表
- 每張卡片顯示：名稱、餘額、類型 badge、佔總資產進度條
- 右上「新增帳戶」含 `+` Heroicon

### 帳戶詳情（/accounts/:id）
- Hero 頂部：帳戶名稱、類型 badge、餘額大字
- 「+ 新增交易」按鈕 → 觸發 Slide-over Drawer
- 交易列表：日期 / 類別 / 備註 / 金額
- 刪除：hover 顯示 trash Heroicon（不顯示文字）

### Slide-over Drawer（新增交易）
- 從右側滑入，背景半透明遮罩
- Stimulus `drawer` controller（open/close）
- 表單欄位：日期、類別（grouped select）、金額、備註
- 送出後 Turbo Stream 更新交易列表，Drawer 自動關閉

### 報表頁（/reports）
- 月份切換
- CSS conic-gradient 圓餅圖（無 JS 圖表庫）
- 類別條列（名稱 + 金額 + 佔比）
- 收入 vs 支出 summary cards

## 技術實作要點

- Tailwind CSS v4（已安裝）
- Stimulus（Rails 8 預設）
- Turbo Stream（新增交易後無換頁更新列表）
- Heroicons：SVG 直接 inline 或抽成 partial `_icon.html.erb`
- 無額外 JS 套件

## 不在範圍內

- 深色模式
- 動畫/transition（除 drawer slide-in 外）
- 圖表互動（tooltip 等）
