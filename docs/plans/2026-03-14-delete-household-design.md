# Delete Household Design

## Summary

Allow household owners to permanently delete a household and all its associated data. The delete action requires typing the household name to confirm, and users cannot delete their last remaining household.

## Scope

- **In scope:** Owner-only household deletion, name confirmation, cascade delete, session switching after delete
- **Out of scope:** Leave household (member exit), member management, household renaming

## Route & Controller

### Route Change

```ruby
namespace :settings do
  resources :households, only: [ :new, :create, :show, :destroy ]
end
```

### `Settings::HouseholdsController`

**`show` action:**
- Find household, verify current user is owner (redirect otherwise)
- Display household info: name, created_at, account count, transaction count, budget entry count, member count
- Bottom section: danger zone with name-confirmation delete form

**`destroy` action flow:**
1. Find household, verify current user is owner
2. Check user has more than 1 household, otherwise reject with flash error
3. Compare `params[:household_name]` with `household.name`, reject if mismatch
4. Delete in safe order (wrapped in transaction):
   a. `household.update_columns(default_account_id: nil)` — prevent Account `clear_default_account` callback issues
   b. `Transaction.where(account_id: household.account_ids).delete_all` — skip callbacks to avoid enqueuing useless recalculation jobs
   c. `household.destroy!` — Category `before_destroy` won't block since transactions are already gone
5. Set `session[:current_household_id]` to user's next available household
6. Redirect to settings path with flash success message

## UI Design

### Household Detail Page (`settings/households/show.html.erb`)

**Info section:**
- Household name as page title
- Stats: account count, transaction count, budget entry count, member count

**Danger zone (bottom, red border):**
- Title: "刪除帳本"
- Description: "刪除後所有帳戶、交易、預算資料將永久刪除，無法復原。"
- Input field: placeholder shows household name, label says "請輸入帳本名稱以確認"
- Delete button: disabled by default, enabled only when input matches household name exactly
- If last household: hide input and button, show message "這是你唯一的帳本，無法刪除"

**Stimulus controller (`confirm-delete`):**
- Listen to input event on the text field
- Compare input value with `data-expected-name` attribute
- Enable/disable the submit button accordingly

### Entry Point

- Settings page: add a "管理" link next to the household switcher area (only visible to owners)
- Links to `settings/households/:id`

## Cascade Delete Strategy

The controller explicitly deletes in safe order to avoid callback conflicts:

1. **Nullify `default_account_id`** — prevents `Account#clear_default_account` from updating a household mid-destroy
2. **`delete_all` transactions** — bypasses `Transaction#after_commit` (avoids enqueuing hundreds of `BudgetEntryRecalculationJob`s) and clears the data that would trigger `Category#before_destroy` abort
3. **`household.destroy!`** — remaining cascade via `dependent: :destroy` works cleanly:

```
Household
├── household_memberships (all member associations)
├── accounts (transactions already deleted)
├── category_groups → categories → budget_entries
└── quick_entry_mappings
```

## Other Members Handling

When a household is deleted, other members lose access. Two scenarios:

1. **Member has other households:** `ApplicationController#set_current_household` already falls back to `households.first` when `current_household_id` is invalid — no extra work needed.
2. **Member loses their last household:** The `User#before_create` callback only fires on creation. For existing users who lose their last household, the controller must create a new default household for each affected member before destroying the target household.

## Permission Rules

- Only users with `role: "owner"` in `household_memberships` can access show and destroy
- Non-owners do not see the "管理" link on settings page
- Attempting to access show/destroy as non-owner redirects to settings with error flash

## Test Plan

### Model Tests (`spec/models/household_spec.rb`)
- Cascade delete: destroying household deletes accounts, transactions, category_groups, categories, budget_entries, memberships
- Cascade works even when categories have transactions (the main edge case)

### Request Tests (`spec/requests/settings/households_spec.rb`)
- Owner can delete household (success path)
- Member cannot delete (redirect with error)
- Last household cannot be deleted (redirect with error)
- Name mismatch rejects deletion (redirect with error)
- After deletion, session switches to another household
- Other members who lose their last household get a new default household created

### System Tests (`spec/system/household_delete_spec.rb`)
- Desktop: navigate to household detail → type name → button enables → click delete → redirected to settings
- Mobile: same flow from mobile settings page
- Wrong name input keeps button disabled
- Last household shows "無法刪除" message
