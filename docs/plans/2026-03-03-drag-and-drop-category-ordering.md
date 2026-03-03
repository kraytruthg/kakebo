# Drag-and-Drop Category Ordering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add drag-and-drop reordering for CategoryGroups and Categories in the Settings page, plus a dropdown to move Categories between groups.

**Architecture:** SortableJS via importmap + a reusable Stimulus `sortable_controller.js`. Two new `reorder` collection routes handle batch position updates in a transaction. Category edit form gets a `category_group_id` select for group reassignment.

**Tech Stack:** SortableJS, Stimulus, Rails 8.1, importmap, RSpec + Capybara

---

### Task 1: Install SortableJS via importmap

**Files:**
- Modify: `config/importmap.rb`

**Step 1: Pin sortablejs**

Run: `bin/importmap pin sortablejs`

This should add a line like:
```
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@...
```

**Step 2: Verify pin works**

Run: `bin/rails runner "puts Rails.application.importmap.to_json" | grep sortablejs`

Expected: output contains `"sortablejs"` entry

**Step 3: Commit**

```bash
git add config/importmap.rb vendor/javascript/
git commit -m "chore: pin sortablejs via importmap"
```

---

### Task 2: Add drag-handle icon to IconHelper

**Files:**
- Modify: `app/helpers/icon_helper.rb`

**Step 1: Add the "bars-3" icon SVG path**

Add to the `ICONS` hash in `app/helpers/icon_helper.rb`, after the `"arrows-right-left"` entry:

```ruby
"bars-3" => '<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
```

This is the Heroicons "bars-3" (hamburger menu / grip) icon, consistent with the project's existing Heroicons usage.

**Step 2: Verify icon renders**

Run: `bin/rails runner "include IconHelper; puts icon('bars-3')"`

Expected: outputs an `<svg>` tag

**Step 3: Commit**

```bash
git add app/helpers/icon_helper.rb
git commit -m "feat: add bars-3 icon for drag handle"
```

---

### Task 3: Add reorder routes

**Files:**
- Modify: `config/routes.rb`
- Test: `spec/requests/settings/category_groups_spec.rb` (later tasks)

**Step 1: Add collection reorder routes**

In `config/routes.rb`, replace the settings namespace block:

```ruby
namespace :settings do
  resources :category_groups, only: [ :new, :create, :edit, :update, :destroy ] do
    collection do
      patch :reorder
    end
    resources :categories, only: [ :new, :create, :edit, :update, :destroy ] do
      collection do
        patch :reorder
      end
    end
  end
end
```

**Step 2: Verify routes exist**

Run: `bin/rails routes -g reorder`

Expected output includes:
```
reorder_settings_category_groups  PATCH  /settings/category_groups/reorder
reorder_settings_category_group_categories  PATCH  /settings/category_groups/:category_group_id/categories/reorder
```

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add reorder routes for category groups and categories"
```

---

### Task 4: Implement CategoryGroups#reorder with request spec (TDD)

**Files:**
- Test: `spec/requests/settings/category_groups_spec.rb`
- Modify: `app/controllers/settings/category_groups_controller.rb`

**Step 1: Write the failing request spec**

Add to `spec/requests/settings/category_groups_spec.rb`, inside the main `describe` block:

```ruby
describe "PATCH /settings/category_groups/reorder" do
  it "updates positions for all groups" do
    g1 = create(:category_group, household: household, position: 0)
    g2 = create(:category_group, household: household, position: 1)
    g3 = create(:category_group, household: household, position: 2)

    patch reorder_settings_category_groups_path,
          params: { positions: [ { id: g3.id, position: 0 }, { id: g1.id, position: 1 }, { id: g2.id, position: 2 } ] },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(g3.reload.position).to eq(0)
    expect(g1.reload.position).to eq(1)
    expect(g2.reload.position).to eq(2)
  end

  it "rejects reordering groups from another household" do
    other_group = create(:category_group, position: 0)

    expect {
      patch reorder_settings_category_groups_path,
            params: { positions: [ { id: other_group.id, position: 0 } ] },
            as: :json
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/settings/category_groups_spec.rb -e "reorder"`

Expected: FAIL (routing error or action not found)

**Step 3: Implement reorder action**

Add to `app/controllers/settings/category_groups_controller.rb`:

```ruby
def reorder
  positions = params.require(:positions)
  ApplicationRecord.transaction do
    positions.each do |pos|
      Current.household.category_groups.find(pos[:id]).update!(position: pos[:position])
    end
  end
  head :ok
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/settings/category_groups_spec.rb -e "reorder"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/settings/category_groups_spec.rb app/controllers/settings/category_groups_controller.rb
git commit -m "feat: add CategoryGroups#reorder action with request spec"
```

---

### Task 5: Implement Categories#reorder with request spec (TDD)

**Files:**
- Test: `spec/requests/settings/categories_spec.rb`
- Modify: `app/controllers/settings/categories_controller.rb`

**Step 1: Write the failing request spec**

Add to `spec/requests/settings/categories_spec.rb`, inside the main `describe` block:

```ruby
describe "PATCH /settings/category_groups/:id/categories/reorder" do
  it "updates positions for categories within the group" do
    c1 = create(:category, category_group: group, position: 0)
    c2 = create(:category, category_group: group, position: 1)
    c3 = create(:category, category_group: group, position: 2)

    patch reorder_settings_category_group_categories_path(group),
          params: { positions: [ { id: c3.id, position: 0 }, { id: c1.id, position: 1 }, { id: c2.id, position: 2 } ] },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(c3.reload.position).to eq(0)
    expect(c1.reload.position).to eq(1)
    expect(c2.reload.position).to eq(2)
  end

  it "rejects reordering categories from another group" do
    other_group = create(:category_group)
    other_cat = create(:category, category_group: other_group, position: 0)

    expect {
      patch reorder_settings_category_group_categories_path(group),
            params: { positions: [ { id: other_cat.id, position: 0 } ] },
            as: :json
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/settings/categories_spec.rb -e "reorder"`

Expected: FAIL

**Step 3: Implement reorder action**

Add to `app/controllers/settings/categories_controller.rb`:

```ruby
def reorder
  positions = params.require(:positions)
  ApplicationRecord.transaction do
    positions.each do |pos|
      @category_group.categories.find(pos[:id]).update!(position: pos[:position])
    end
  end
  head :ok
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/settings/categories_spec.rb -e "reorder"`

Expected: PASS

**Step 5: Commit**

```bash
git add spec/requests/settings/categories_spec.rb app/controllers/settings/categories_controller.rb
git commit -m "feat: add Categories#reorder action with request spec"
```

---

### Task 6: Create Stimulus sortable_controller.js

**Files:**
- Create: `app/javascript/controllers/sortable_controller.js`

**Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/sortable_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    handle: { type: String, default: ".drag-handle" }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: this.handleValue,
      animation: 150,
      ghostClass: "opacity-30",
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async onEnd() {
    const items = this.element.querySelectorAll("[data-sortable-id]")
    const positions = Array.from(items).map((item, index) => ({
      id: parseInt(item.dataset.sortableId),
      position: index
    }))

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ positions })
      })

      if (!response.ok) {
        this.sortable.sort(this._previousOrder)
      }
    } catch {
      this.sortable.sort(this._previousOrder)
    }
  }
}
```

**Step 2: Verify controller auto-registers**

The importmap `pin_all_from "app/javascript/controllers"` auto-registers any `*_controller.js` files. No manual registration needed.

**Step 3: Commit**

```bash
git add app/javascript/controllers/sortable_controller.js
git commit -m "feat: add Stimulus sortable controller wrapping SortableJS"
```

---

### Task 7: Update category_groups/index.html.erb with drag-and-drop UI

**Files:**
- Modify: `app/views/settings/category_groups/index.html.erb`

**Step 1: Add sortable data attributes and drag handles**

Replace the full content of `app/views/settings/category_groups/index.html.erb` with:

```erb
<div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-slate-900">類別管理</h1>
    <%= link_to new_settings_category_group_path,
          class: "flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors" do %>
      <%= icon "plus", classes: "w-4 h-4" %>
      新增群組
    <% end %>
  </div>

  <div class="space-y-4" data-controller="sortable" data-sortable-url-value="<%= reorder_settings_category_groups_path %>">
    <% @category_groups.each do |group| %>
      <div class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden" data-sortable-id="<%= group.id %>">
        <%# Group header %>
        <div class="flex items-center justify-between px-5 py-3 bg-slate-50 border-b border-slate-100">
          <div class="flex items-center gap-2">
            <span class="drag-handle cursor-grab text-slate-300 hover:text-slate-500">
              <%= icon "bars-3", classes: "w-4 h-4" %>
            </span>
            <span class="text-sm font-semibold text-slate-700"><%= group.name %></span>
          </div>
          <div class="flex items-center gap-2">
            <%= link_to edit_settings_category_group_path(group),
                  class: "text-xs text-slate-500 hover:text-indigo-600 transition-colors" do %>
              <%= icon "pencil", classes: "w-4 h-4" %>
            <% end %>
            <%= button_to settings_category_group_path(group), method: :delete,
                  data: { turbo_confirm: "確定要刪除「#{group.name}」群組嗎？" },
                  class: "text-xs text-slate-400 hover:text-red-500 transition-colors" do %>
              <%= icon "trash", classes: "w-4 h-4" %>
            <% end %>
          </div>
        </div>

        <%# Categories %>
        <div class="divide-y divide-slate-50" data-controller="sortable" data-sortable-url-value="<%= reorder_settings_category_group_categories_path(group) %>">
          <% group.categories.each do |category| %>
            <div class="flex items-center justify-between px-5 py-2.5" data-sortable-id="<%= category.id %>">
              <div class="flex items-center gap-2">
                <span class="drag-handle cursor-grab text-slate-300 hover:text-slate-500">
                  <%= icon "bars-3", classes: "w-3.5 h-3.5" %>
                </span>
                <span class="text-sm text-slate-700"><%= category.name %></span>
              </div>
              <div class="flex items-center gap-2">
                <%= link_to edit_settings_category_group_category_path(group, category),
                      class: "text-slate-400 hover:text-indigo-600 transition-colors" do %>
                  <%= icon "pencil", classes: "w-4 h-4" %>
                <% end %>
                <%= button_to settings_category_group_category_path(group, category), method: :delete,
                      data: { turbo_confirm: "確定要刪除「#{category.name}」嗎？" },
                      class: "text-slate-400 hover:text-red-500 transition-colors" do %>
                  <%= icon "trash", classes: "w-4 h-4" %>
                <% end %>
              </div>
            </div>
          <% end %>

          <%# Add category link %>
          <div class="px-5 py-2.5">
            <%= link_to new_settings_category_group_category_path(group),
                  class: "flex items-center gap-1.5 text-xs text-indigo-500 hover:text-indigo-700 transition-colors" do %>
              <%= icon "plus", classes: "w-3.5 h-3.5" %>
              新增類別
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <% if @category_groups.empty? %>
      <div class="text-center py-12 text-slate-400 text-sm">
        尚無類別群組，請先新增群組
      </div>
    <% end %>
  </div>
</div>
```

Key changes from original:
- Outer `<div class="space-y-4">` gets `data-controller="sortable"` with group reorder URL
- Each group card gets `data-sortable-id="<%= group.id %>"`
- Group header: name wrapped in flex div with drag handle icon before it
- Each category `<div class="divide-y">` gets `data-controller="sortable"` with category reorder URL
- Each category row gets `data-sortable-id="<%= category.id %>"`
- Category row: name wrapped in flex div with drag handle icon before it

**Step 2: Manually test in browser**

Visit `http://localhost:3000/settings/categories` and verify:
- Drag handles (≡) appear on both groups and categories
- Dragging a group card reorders groups (check Network tab for PATCH request)
- Dragging a category row reorders categories within its group

**Step 3: Commit**

```bash
git add app/views/settings/category_groups/index.html.erb
git commit -m "feat: add drag-and-drop UI to category management page"
```

---

### Task 8: Add Category group reassignment (TDD)

**Files:**
- Test: `spec/requests/settings/categories_spec.rb`
- Modify: `app/controllers/settings/categories_controller.rb`
- Modify: `app/views/settings/categories/edit.html.erb`

**Step 1: Write the failing request spec**

Add to `spec/requests/settings/categories_spec.rb`:

```ruby
describe "PATCH /settings/category_groups/:id/categories/:id (change group)" do
  it "moves category to another group" do
    category = create(:category, category_group: group, name: "搬家類別", position: 0)
    target_group = create(:category_group, household: household, name: "目標群組")

    patch settings_category_group_category_path(group, category),
          params: { category: { name: "搬家類別", category_group_id: target_group.id } }

    expect(category.reload.category_group).to eq(target_group)
    expect(response).to redirect_to(settings_categories_path)
  end

  it "rejects moving to a group from another household" do
    category = create(:category, category_group: group, name: "不動類別")
    other_household_group = create(:category_group)

    patch settings_category_group_category_path(group, category),
          params: { category: { name: "不動類別", category_group_id: other_household_group.id } }

    expect(category.reload.category_group).to eq(group)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/settings/categories_spec.rb -e "change group"`

Expected: FAIL (category_group_id not permitted)

**Step 3: Update controller to permit category_group_id and validate household**

In `app/controllers/settings/categories_controller.rb`:

1. Update `category_params`:
```ruby
def category_params
  params.require(:category).permit(:name, :category_group_id)
end
```

2. Update the `update` action to validate group belongs to household and set position:
```ruby
def update
  @category = @category_group.categories.find(params[:id])
  if category_params[:category_group_id].present?
    target_group = Current.household.category_groups.find_by(id: category_params[:category_group_id])
    unless target_group
      redirect_to settings_categories_path, alert: "無效的目標群組"
      return
    end
  end

  if @category.update(category_params)
    if @category.saved_change_to_category_group_id?
      @category.update_column(:position, @category.category_group.categories.maximum(:position).to_i + 1)
    end
    redirect_to settings_categories_path, notice: "類別已更新"
  else
    render :edit, status: :unprocessable_entity
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/settings/categories_spec.rb -e "change group"`

Expected: PASS

**Step 5: Update the edit form to include group dropdown**

Modify `app/views/settings/categories/edit.html.erb`:

```erb
<div class="max-w-lg mx-auto px-4 sm:px-6 py-8">
  <h1 class="text-xl font-bold text-slate-900 mb-1">編輯類別</h1>
  <p class="text-sm text-slate-500 mb-6">群組：<%= @category_group.name %></p>

  <%= form_with model: [:settings, @category_group, @category], class: "bg-white rounded-2xl shadow-sm border border-slate-100 p-6 space-y-4" do |f| %>
    <div>
      <%= f.label :name, "類別名稱", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.text_field :name, autofocus: true,
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
      <% @category.errors[:name].each do |msg| %>
        <p class="text-xs text-red-500 mt-1"><%= msg %></p>
      <% end %>
    </div>

    <div>
      <%= f.label :category_group_id, "所屬群組", class: "block text-sm font-medium text-slate-700 mb-1.5" %>
      <%= f.collection_select :category_group_id,
            Current.household.category_groups.order(:position), :id, :name,
            {},
            class: "block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" %>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= f.submit "儲存",
            class: "bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium px-5 py-2 rounded-lg cursor-pointer transition-colors" %>
      <%= link_to "取消", settings_categories_path,
            class: "text-sm text-slate-500 hover:text-slate-700" %>
    </div>
  <% end %>
</div>
```

**Step 6: Commit**

```bash
git add spec/requests/settings/categories_spec.rb app/controllers/settings/categories_controller.rb app/views/settings/categories/edit.html.erb
git commit -m "feat: allow moving category to different group via edit form"
```

---

### Task 9: System tests for drag-and-drop ordering

**Files:**
- Test: `spec/system/categories_spec.rb`

**Step 1: Add system tests for reordering and group change**

Add to `spec/system/categories_spec.rb`, inside the main `describe` block:

```ruby
it "拖曳調整 CategoryGroup 順序" do
  group2 = create(:category_group, household: user.household, name: "娛樂", position: 2)
  visit settings_categories_path

  # Verify initial order
  groups = all("[data-sortable-id]").select { |el| el.matches_css?(".space-y-4 > [data-sortable-id]") }
  expect(groups.first).to have_text("日常開銷")

  # Drag second group above first
  source = find("[data-sortable-id='#{group2.id}'] .drag-handle")
  target = find("[data-sortable-id='#{group.id}'] .drag-handle")
  source.drag_to(target)

  # Verify positions updated in DB
  sleep 0.5 # wait for async PATCH
  expect(group2.reload.position).to be < group.reload.position
end

it "拖曳調整 Category 順序" do
  cat1 = create(:category, category_group: group, name: "食物", position: 0)
  cat2 = create(:category, category_group: group, name: "交通", position: 1)
  visit settings_categories_path

  source = find("[data-sortable-id='#{cat2.id}'] .drag-handle")
  target = find("[data-sortable-id='#{cat1.id}'] .drag-handle")
  source.drag_to(target)

  sleep 0.5
  expect(cat2.reload.position).to be < cat1.reload.position
end

it "編輯時將 Category 換到其他群組" do
  group2 = create(:category_group, household: user.household, name: "娛樂")
  cat = create(:category, category_group: group, name: "電影")
  visit settings_categories_path

  within("[data-sortable-id='#{cat.id}']") { click_link "編輯" }
  select "娛樂", from: "所屬群組"
  click_button "儲存"

  expect(page).to have_text("類別已更新")
  expect(cat.reload.category_group).to eq(group2)
end
```

Note: Capybara's `drag_to` works with Selenium Chrome driver. The `sleep 0.5` accounts for the async fetch call. If tests are flaky, increase to `sleep 1` or use a `have_css` wait assertion.

**Step 2: Run system tests**

Run: `bundle exec rspec spec/system/categories_spec.rb`

Expected: all tests PASS (including existing tests)

**Step 3: Commit**

```bash
git add spec/system/categories_spec.rb
git commit -m "test: add system tests for drag-and-drop ordering and group change"
```

---

### Task 10: Run full test suite and verify

**Step 1: Run all specs**

Run: `bundle exec rspec`

Expected: all specs pass, 0 failures

**Step 2: Fix any failures**

If any tests fail, investigate and fix before proceeding.

**Step 3: Final commit (if any fixes)**

```bash
git add -A
git commit -m "fix: address test failures from drag-and-drop feature"
```
