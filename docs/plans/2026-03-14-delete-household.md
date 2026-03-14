# Delete Household Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow household owners to permanently delete a household with name-confirmation, safe cascade delete, and orphaned member handling.

**Architecture:** Add `show` and `destroy` actions to `Settings::HouseholdsController`. The destroy action manually deletes data in safe order (transactions → budget_entries → categories → category_groups) via `delete_all` to bypass model callbacks, then calls `household.destroy!` for the remaining clean associations. A new Stimulus controller enables the delete button only when the typed name matches.

**Tech Stack:** Rails 8.1, Stimulus, Tailwind CSS v4, RSpec + Capybara

**Spec:** `docs/plans/2026-03-14-delete-household-design.md`

---

## Chunk 1: Safe Delete Logic & Request Tests

### Task 1: Route + Controller Skeleton

**Files:**
- Modify: `config/routes.rb:38`
- Modify: `app/controllers/settings/households_controller.rb`

- [ ] **Step 1: Update routes**

In `config/routes.rb`, change line 38 from:
```ruby
resources :households, only: [ :new, :create ]
```
to:
```ruby
resources :households, only: [ :new, :create, :show, :destroy ]
```

- [ ] **Step 2: Add show and destroy stubs to controller**

In `app/controllers/settings/households_controller.rb`, add:
```ruby
class Settings::HouseholdsController < ApplicationController
  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)
    if @household.save
      Current.user.household_memberships.create!(household: @household, role: "owner")
      session[:current_household_id] = @household.id
      redirect_to root_path, notice: "帳本已建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @household = find_owned_household
    return unless @household

    @transaction_count = Transaction.where(account_id: @household.account_ids).count
    @budget_entry_count = BudgetEntry.joins(category: :category_group)
                                     .where(category_groups: { household_id: @household.id }).count
  end

  def destroy
    @household = find_owned_household
    return unless @household

    if Current.user.households.count <= 1
      redirect_to settings_root_path, alert: "無法刪除唯一的帳本"
      return
    end

    if params[:household_name] != @household.name
      redirect_to settings_household_path(@household), alert: "帳本名稱不正確"
      return
    end

    safe_destroy_household(@household)
    session[:current_household_id] = Current.user.households.where.not(id: @household.id).first&.id
    redirect_to settings_root_path, notice: "帳本「#{@household.name}」已刪除"
  end

  private

  def household_params
    params.require(:household).permit(:name)
  end

  def find_owned_household
    household = Current.user.households.find_by(id: params[:id])
    membership = Current.user.household_memberships.find_by(household: household)

    unless household && membership&.role == "owner"
      redirect_to settings_root_path, alert: "權限不足"
      return nil
    end

    household
  end

  def safe_destroy_household(household)
    ActiveRecord::Base.transaction do
      # Create default households for orphaned members
      other_members = household.users.where.not(id: Current.user.id)
      orphaned = other_members.select { |u| u.households.count == 1 }
      orphaned.each do |user|
        new_hh = Household.create!(name: "#{user.name} 的家")
        HouseholdMembership.create!(user: user, household: new_hh, role: "owner")
      end

      # Safe delete order to bypass model callbacks
      household.update_columns(default_account_id: nil)
      Transaction.where(account_id: household.account_ids).delete_all
      BudgetEntry.joins(category: :category_group)
                 .where(category_groups: { household_id: household.id })
                 .delete_all
      Category.where(category_group_id: household.category_group_ids).delete_all
      household.category_groups.delete_all
      household.destroy!
    end
  end
end
```

- [ ] **Step 3: Verify routes compile**

Run: `bin/rails routes | grep settings_household`
Expected: routes for `show` and `destroy` appear alongside `new` and `create`.

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/settings/households_controller.rb
git commit -m "feat: add show and destroy actions for household management"
```

### Task 2: Request Tests for Destroy

**Files:**
- Create: `spec/requests/settings/households_spec.rb`

- [ ] **Step 1: Write request specs**

Create `spec/requests/settings/households_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Settings::Households", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:other_user) { create(:user, password: "password123") }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "DELETE /settings/households/:id" do
    context "when owner with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end
      let(:target) { user.households.first }

      it "deletes household when name matches" do
        account = create(:account, household: target)
        create(:transaction, account: account, amount: -100, date: Date.today)

        expect {
          delete settings_household_path(target), params: { household_name: target.name }
        }.to change(Household, :count).by(-1)
          .and change(Account, :count).by(-1)
          .and change(Transaction, :count).by(-1)

        expect(response).to redirect_to(settings_root_path)
        follow_redirect!
        expect(response.body).to include("已刪除")
      end

      it "rejects when name does not match" do
        expect {
          delete settings_household_path(target), params: { household_name: "wrong" }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_household_path(target))
      end

      it "deletes household with categories that have transactions" do
        account = create(:account, household: target)
        cg = create(:category_group, household: target)
        cat = create(:category, category_group: cg)
        create(:budget_entry, category: cat, year: 2026, month: 1)
        create(:transaction, account: account, category: cat, amount: -50, date: Date.today)

        expect {
          delete settings_household_path(target), params: { household_name: target.name }
        }.to change(Household, :count).by(-1)
          .and change(CategoryGroup, :count).by(-1)
          .and change(Category, :count).by(-1)
          .and change(BudgetEntry, :count).by(-1)

        expect(response).to redirect_to(settings_root_path)
      end

      it "switches session to another household after deletion" do
        delete settings_household_path(target), params: { household_name: target.name }
        follow_redirect!

        # Verify user can still access the app (session points to valid household)
        get budget_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when owner with only one household" do
      it "rejects deletion" do
        household = user.households.first

        expect {
          delete settings_household_path(household), params: { household_name: household.name }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_root_path)
        follow_redirect!
        expect(response.body).to include("唯一")
      end
    end

    context "when member (not owner)" do
      it "rejects deletion" do
        household = user.households.first
        HouseholdMembership.create!(user: other_user, household: household, role: "member")

        # Sign in as other_user (member)
        delete session_path
        post session_path, params: { email: other_user.email, password: "password123" }

        # other_user needs a second household so the "last household" guard doesn't trigger
        second = Household.create!(name: "Other")
        HouseholdMembership.create!(user: other_user, household: second, role: "owner")

        expect {
          delete settings_household_path(household), params: { household_name: household.name }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_root_path)
      end
    end

    context "orphaned members" do
      it "creates default household for members who lose their last household" do
        household = user.households.first
        HouseholdMembership.create!(user: other_user, household: household, role: "member")

        # other_user only has this one household (their auto-created one was replaced)
        other_user.household_memberships.where.not(household: household).destroy_all
        other_user.households.where.not(id: household.id).destroy_all

        second = Household.create!(name: "Keep")
        HouseholdMembership.create!(user: user, household: second, role: "owner")

        expect {
          delete settings_household_path(household), params: { household_name: household.name }
        }.to change { other_user.reload.households.count }.from(1).to(1)
        # Count stays at 1: lost the deleted one, gained a new default

        new_hh = other_user.households.first
        expect(new_hh.name).to include(other_user.name)
      end
    end
  end

  describe "GET /settings/households/:id" do
    it "shows household details for owner" do
      household = user.households.first

      get settings_household_path(household)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(household.name)
    end

    it "redirects non-owner" do
      other_household = Household.create!(name: "Other")
      HouseholdMembership.create!(user: other_user, household: other_household, role: "owner")

      get settings_household_path(other_household)
      expect(response).to redirect_to(settings_root_path)
    end
  end
end
```

- [ ] **Step 2: Run request tests**

Run: `bundle exec rspec spec/requests/settings/households_spec.rb`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/settings/households_spec.rb
git commit -m "test: add request specs for household deletion"
```

## Chunk 2: UI — Show Page, Stimulus Controller, Settings Link

### Task 3: Stimulus Confirm-Delete Controller

**Files:**
- Create: `app/javascript/controllers/confirm_delete_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/confirm_delete_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]
  static values = { expected: String }

  validate() {
    this.buttonTarget.disabled = this.inputTarget.value !== this.expectedValue
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/confirm_delete_controller.js
git commit -m "feat: add confirm-delete Stimulus controller"
```

### Task 4: Household Show Page

**Files:**
- Create: `app/views/settings/households/show.html.erb`

- [ ] **Step 1: Create the show template**

Create `app/views/settings/households/show.html.erb`:
```erb
<div class="px-4 py-6 lg:max-w-2xl lg:mx-auto lg:px-6 lg:py-8">
  <div class="mb-6">
    <%= link_to "← 設定", settings_root_path, class: "text-sm text-slate-500 hover:text-slate-700" %>
  </div>

  <h1 class="text-xl font-bold text-slate-900 mb-6"><%= @household.name %></h1>

  <div class="bg-white rounded-xl border border-slate-100 p-5 mb-8">
    <h2 class="text-sm font-medium text-slate-500 mb-4">帳本資訊</h2>
    <dl class="grid grid-cols-2 gap-4">
      <div>
        <dt class="text-xs text-slate-400">建立日期</dt>
        <dd class="text-lg font-semibold text-slate-900"><%= @household.created_at.strftime("%Y-%m-%d") %></dd>
      </div>
      <div>
        <dt class="text-xs text-slate-400">帳戶數</dt>
        <dd class="text-lg font-semibold text-slate-900" data-testid="account-count"><%= @household.accounts.count %></dd>
      </div>
      <div>
        <dt class="text-xs text-slate-400">交易數</dt>
        <dd class="text-lg font-semibold text-slate-900" data-testid="transaction-count"><%= @transaction_count %></dd>
      </div>
      <div>
        <dt class="text-xs text-slate-400">預算項目</dt>
        <dd class="text-lg font-semibold text-slate-900" data-testid="budget-entry-count"><%= @budget_entry_count %></dd>
      </div>
      <div>
        <dt class="text-xs text-slate-400">成員數</dt>
        <dd class="text-lg font-semibold text-slate-900" data-testid="member-count"><%= @household.users.count %></dd>
      </div>
    </dl>
  </div>

  <div class="bg-white rounded-xl border-2 border-red-200 p-5">
    <h2 class="text-base font-bold text-red-700 mb-2">刪除帳本</h2>

    <% if Current.user.households.count <= 1 %>
      <p class="text-sm text-slate-500" data-testid="cannot-delete-message">這是你唯一的帳本，無法刪除。</p>
    <% else %>
      <p class="text-sm text-slate-500 mb-4">刪除後所有帳戶、交易、預算資料將永久刪除，無法復原。</p>

      <%= form_with url: settings_household_path(@household), method: :delete, class: "space-y-4",
            data: { controller: "confirm-delete", confirm_delete_expected_value: @household.name } do |f| %>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">
            請輸入「<span class="font-bold text-red-600"><%= @household.name %></span>」以確認
          </label>
          <%= f.text_field :household_name, placeholder: @household.name,
                class: "w-full rounded-lg border-slate-300 text-sm focus:ring-red-500 focus:border-red-500",
                data: { confirm_delete_target: "input", action: "input->confirm-delete#validate" },
                autocomplete: "off" %>
        </div>
        <button type="submit" disabled
                class="w-full bg-red-600 text-white text-sm font-medium rounded-lg px-4 py-2.5 hover:bg-red-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                data-confirm-delete-target="button"
                data-testid="delete-household-button">
          永久刪除此帳本
        </button>
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Verify show page renders**

Run: `bin/rails routes | grep settings_household`
Then start server and manually verify, or run the request spec:
Run: `bundle exec rspec spec/requests/settings/households_spec.rb`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/settings/households/show.html.erb
git commit -m "feat: add household show page with delete confirmation UI"
```

### Task 5: Add "管理" Link to Settings Page

**Files:**
- Modify: `app/views/settings/index.html.erb`

- [ ] **Step 1: Add the manage link**

In `app/views/settings/index.html.erb`, add a "管理帳本" link **inside** the `<div class="space-y-3">` block (before the existing "類別管理" link, around line 28). This link must be **outside** the `if households.size > 1` block so single-household owners can also reach the show page.

```erb
    <% current_membership = Current.user.household_memberships.find_by(household: Current.household) %>
    <% if current_membership&.role == "owner" %>
      <%= link_to settings_household_path(Current.household),
            class: "flex items-center justify-between bg-white rounded-xl border border-slate-100 px-5 py-4 hover:border-indigo-200 hover:shadow-sm transition-all",
            data: { testid: "manage-household-link" } do %>
        <div class="flex items-center gap-3">
          <%= icon "home", classes: "w-5 h-5 text-slate-400" %>
          <span class="text-sm font-medium text-slate-800">管理帳本</span>
        </div>
        <%= icon "chevron-right", classes: "w-4 h-4 text-slate-400" %>
      <% end %>
    <% end %>
```

Insert this right after `<div class="space-y-3">` on line 27, before the "類別管理" link.

- [ ] **Step 2: Commit**

```bash
git add app/views/settings/index.html.erb
git commit -m "feat: add manage household link to settings page"
```

## Chunk 3: System Tests

### Task 6: Desktop System Tests

**Files:**
- Create: `spec/system/household_delete_spec.rb`

- [ ] **Step 1: Write desktop system tests**

Create `spec/system/household_delete_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Household deletion", type: :system do
  before do
    driven_by :selenium, using: :headless_chrome
  end

  let(:user) { create(:user, password: "password123") }

  describe "desktop" do
    context "with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end

      it "deletes household after typing name confirmation" do
        target = user.households.first
        account = create(:account, household: target)
        create(:transaction, account: account, amount: -100, date: Date.today)

        sign_in user
        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text(target.name)
        expect(page).to have_text("帳戶數")
        expect(page).to have_button("永久刪除此帳本", disabled: true)

        fill_in "household_name", with: target.name
        expect(page).to have_button("永久刪除此帳本", disabled: false)

        click_button "永久刪除此帳本"

        expect(page).to have_text("已刪除")
        expect(page).to have_current_path(settings_root_path)
        expect(Household.find_by(id: target.id)).to be_nil
      end

      it "keeps delete button disabled when name does not match" do
        target = user.households.first
        sign_in user
        visit settings_household_path(target)

        fill_in "household_name", with: "wrong name"
        expect(page).to have_button("永久刪除此帳本", disabled: true)
      end
    end

    context "with only one household" do
      it "shows cannot-delete message" do
        sign_in user
        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text("唯一的帳本，無法刪除")
        expect(page).not_to have_button("永久刪除此帳本")
      end
    end
  end

  describe "mobile" do
    context "with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end

      it "deletes household from mobile settings" do
        target = user.households.first
        sign_in user
        Capybara.current_session.resize_to(375, 812)

        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text(target.name)

        fill_in "household_name", with: target.name
        click_button "永久刪除此帳本"

        expect(page).to have_text("已刪除")
      end
    end

    context "with only one household" do
      it "shows cannot-delete message on mobile" do
        sign_in user
        Capybara.current_session.resize_to(375, 812)

        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text("唯一的帳本，無法刪除")
      end
    end
  end
end
```

- [ ] **Step 2: Run system tests**

Run: `bundle exec rspec spec/system/household_delete_spec.rb`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add spec/system/household_delete_spec.rb
git commit -m "test: add system tests for household deletion (desktop + mobile)"
```

### Task 7: Final Verification

- [ ] **Step 1: Run rubocop**

Run: `bin/rubocop`
Expected: No offenses. Fix any issues.

- [ ] **Step 2: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass, no regressions.

- [ ] **Step 3: Commit any fixes**

If rubocop or tests required changes, commit them.
