# 拖曳排序 + Category 換組 設計文件

## 概要

在 Settings 類別管理頁面加入拖曳排序功能，允許使用者：
1. 拖曳調整 CategoryGroup 之間的順序
2. 拖曳調整同一 Group 內 Category 的順序
3. 在編輯 Category 時透過下拉選單將 Category 移到其他 Group

## 技術選型

**SortableJS + Stimulus Controller**

- SortableJS：成熟的拖曳排序庫，~10KB gzip，無依賴，支援巢狀排序和觸控裝置
- 透過 importmap `pin "sortablejs"` 引入
- Stimulus controller 包裝 SortableJS，拖曳放開後即時發送 PATCH 請求儲存

## 前端設計

### Stimulus Controller: `sortable_controller.js`

```javascript
// data-controller="sortable"
// data-sortable-url-value="/settings/category_groups/reorder"
// data-sortable-handle-value=".drag-handle"
```

- 在 `connect()` 初始化 SortableJS 實例
- `onEnd` callback 收集新順序，POST 到 `url` value
- 失敗時 revert（利用 SortableJS 內建功能）

### UI 變更（`settings/category_groups/index.html.erb`）

**Group 層級：**
- 外層 `<div class="space-y-4">` 加上 `data-controller="sortable"` 和 reorder URL
- 每個 Group 卡片左側 header 加入拖曳把手 `≡`（`drag-handle` class）
- Group 卡片加上 `data-id` attribute

**Category 層級：**
- 每個 Group 內的 `<div class="divide-y">` 加上 `data-controller="sortable"` 和對應的 reorder URL
- 每個 Category 行左側加入拖曳把手 `≡`
- Category 行加上 `data-id` attribute

### 拖曳把手樣式

```html
<span class="drag-handle cursor-grab text-slate-300 hover:text-slate-500">
  ≡
</span>
```

## 後端設計

### 新增路由

```ruby
namespace :settings do
  resources :category_groups, only: [...] do
    collection do
      patch :reorder
    end
    resources :categories, only: [...] do
      collection do
        patch :reorder
      end
    end
  end
end
```

### CategoryGroupsController#reorder

```ruby
def reorder
  positions = params.require(:positions)
  ApplicationRecord.transaction do
    positions.each do |pos|
      Current.household.category_groups.find(pos[:id]).update!(position: pos[:position])
    end
  end
  head :ok
rescue ActiveRecord::RecordNotFound
  head :not_found
end
```

### CategoriesController#reorder

```ruby
def reorder
  positions = params.require(:positions)
  ApplicationRecord.transaction do
    positions.each do |pos|
      @category_group.categories.find(pos[:id]).update!(position: pos[:position])
    end
  end
  head :ok
rescue ActiveRecord::RecordNotFound
  head :not_found
end
```

## Category 換組功能

### 編輯表單變更

在 `settings/categories/edit.html.erb` 的名稱欄位下方加入 CategoryGroup 下拉選單：

```erb
<%= f.label :category_group_id, "所屬群組" %>
<%= f.collection_select :category_group_id,
      Current.household.category_groups, :id, :name %>
```

### Controller 變更

- `Settings::CategoriesController#category_params` 允許 `:category_group_id`
- `update` action 需要處理 category_group_id 變更（更新後 position 設為目標 group 的 max + 1）

## 安全性

- **Household scoping**：reorder 端點只操作 `Current.household` 的資料
- **Position 驗證**：只接受 `id` + `position` 組合
- **CSRF**：fetch 請求帶 `X-CSRF-Token` header
- **換組驗證**：確認目標 `category_group_id` 屬於 `Current.household`

## 測試策略

- **System test**：用 Capybara `drag_to` 測試拖曳排序 UI，以及 Category 換組的表單操作
- **Request spec**：測試 reorder endpoint 的權限檢查和原子性
