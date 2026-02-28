# 類別群組管理 & 預算 Copy 設計文件

**日期：** 2026-02-28
**狀態：** 已確認，待實作

## 問題陳述

1. 類別與群組只能透過 seed/資料庫直接操作，無 UI 可管理
2. 每月初需手動逐一填入預算金額，缺少從上月複製的快速入口

## 解決方案：方案 A（極簡 CRUD + 全頁重整）

### 功能一：設定頁類別群組管理

#### 路由

```ruby
namespace :settings do
  resources :category_groups, only: [:new, :create, :edit, :update, :destroy] do
    resources :categories, only: [:new, :create, :edit, :update, :destroy]
  end
end
get "settings/categories", to: "settings/category_groups#index", as: :settings_categories
```

#### Controllers

- `Settings::CategoryGroupsController`：index, new, create, edit, update, destroy
- `Settings::CategoriesController`：new, create, edit, update, destroy

#### 頁面結構（`/settings/categories`）

```
⚙️ 設定 > 類別管理                          [+ 新增群組]

┌─────────────────────────────────────────┐
│ 飲食                          [編輯] [刪除] │
│   餐廳                        [編輯] [刪除] │
│   超市                        [編輯] [刪除] │
│   [+ 新增類別]                            │
├─────────────────────────────────────────┤
│ 交通                          [編輯] [刪除] │
│   加油                        [編輯] [刪除] │
│   [+ 新增類別]                            │
└─────────────────────────────────────────┘
```

#### 互動規則

- 全頁重整（無 Turbo Stream）
- **新增群組**：頁面頂部 `<details>` 展開 inline form，POST 後 redirect 回設定頁
- **新增類別**：群組底部小 form，POST 後 redirect 回設定頁
- **編輯名稱**：導向 edit 頁，存檔後 redirect 回設定頁
- **刪除群組**：需該群組無任何類別，否則顯示錯誤提示
- **刪除類別**：需該類別無任何交易記錄，否則顯示錯誤提示
- **排序**：本次不做，新建的群組/類別 position 設為 max + 1

#### 導覽變更

- 桌機 sidebar 底部加 ⚙️ 設定連結
- 手機底部 tab bar 加第四個設定 icon

#### 安全

- 所有 controller 透過 `Current.household` scope，確保只能操作自己的資料

---

### 功能二：預算 Copy（複製上月）

#### 路由

```ruby
post "budget/copy_from_previous", to: "budget#copy_from_previous", as: :budget_copy_from_previous
```

#### 邏輯

- `BudgetController#copy_from_previous`，接收 `year` / `month` params
- 計算上個月（跨年正確處理：1 月 → 去年 12 月）
- 對 household 所有 category，若上月有 `BudgetEntry#budgeted > 0`，且本月 budgeted == 0（或尚無記錄），則複製
- 已手動設定過的類別（budgeted != 0）不覆蓋
- 完成後 redirect 回 `budget_path(year:, month:)`

#### Flash 訊息

| 情況 | 訊息 |
|------|------|
| 成功複製 N 個類別 | 「已從 X 月複製 N 個類別的預算」 |
| 上月無預算可複製 | 「上月無預算可複製」 |

#### UI 位置

月份導覽列右側加「複製上月」按鈕：

```
← 上個月    2026 年 2 月    下個月 →    [複製上月]
```

---

## 受影響檔案

| 檔案 | 操作 |
|------|------|
| `config/routes.rb` | 新增 settings namespace 路由、copy_from_previous |
| `app/controllers/settings/category_groups_controller.rb` | 新建 |
| `app/controllers/settings/categories_controller.rb` | 新建 |
| `app/views/settings/category_groups/index.html.erb` | 新建 |
| `app/views/settings/category_groups/new.html.erb` | 新建 |
| `app/views/settings/category_groups/edit.html.erb` | 新建 |
| `app/views/settings/categories/new.html.erb` | 新建 |
| `app/views/settings/categories/edit.html.erb` | 新建 |
| `app/views/layouts/application.html.erb` | 加設定導覽連結 |
| `app/controllers/budget_controller.rb` | 新增 copy_from_previous action |
| `app/views/budget/index.html.erb` | 加「複製上月」按鈕 |

## 不在本次範圍

- 類別排序（拖拉或上下移動）
- 帳戶管理設定
- 預算目標（Goal）設定
- 使用者帳號設定
