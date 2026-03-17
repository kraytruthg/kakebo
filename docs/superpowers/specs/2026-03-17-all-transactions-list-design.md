# All Transactions List

A global transaction list page and unified transaction display across the app.

## Problem

Transactions can only be viewed per-account (limited to 50, no pagination) or per-category-per-month. There is no way to see all transactions across accounts in one place, and the account detail page lacks pagination and filtering.

## Solution

Add a global transaction list page at `/transactions` with full filtering, and upgrade the account detail page to use the same shared components with pagination and filtering.

## Architecture

### Prerequisites

Add `has_many :transactions, through: :accounts` to `Household` model. This association does not currently exist.

### Route & Controller

```ruby
# config/routes.rb
resources :transaction_lists, only: [:index], path: "transactions"
```

The route uses `transaction_lists` (not `transactions`) to avoid conflict with the existing nested `resources :transactions` under `accounts`.

`TransactionListsController#index`:
- Base scope: `Current.household.transactions` (all transactions across accounts via the new through association)
- Accepts filter params: `account_id`, `category_id`, `date_from`, `date_to`, `query`
- Pagy pagination (30 per page, matching existing config)
- Includes: `category`, `account`, `transfer_pair: :account`
- Default order: `date DESC, created_at DESC` (existing `.recent` scope)

### Account Detail Page Changes

`AccountsController#show`:
- Replace `@account.transactions.recent.limit(50)` with Pagy pagination
- Add same filtering support (category, date range, memo search) — account filter hidden since already scoped
- Reuse shared partials for consistent UI

### Shared Partials

```
app/views/shared/
  _transaction_filters.html.erb  # Filter bar (account, category, date range, search)
  _transaction_table.html.erb    # Desktop table
  _transaction_cards.html.erb    # Mobile card list
```

Partial parameters control differences between contexts:

| Parameter | Global list | Account page |
|-----------|------------|--------------|
| `show_account_column` | true | false |
| `show_account_filter` | true | false |
| `show_category_column` | true | true |
| `filter_url` | `transaction_lists_path` | `account_path(@account)` |

### Filtering Implementation

GET parameters with standard form submission (no Turbo Frame). URLs are shareable/bookmarkable.

```
GET /transactions?account_id=1&category_id=3&date_from=2026-03-01&date_to=2026-03-17&query=lunch
```

Controller scope composition:
```ruby
scope = base_scope.includes(:category, :account, transfer_pair: :account).recent
scope = scope.where(account_id: params[:account_id]) if params[:account_id].present?
scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
scope = scope.where("category_id IS NULL") if params[:category_id] == "income"
scope = scope.where("date >= ?", params[:date_from]) if params[:date_from].present?
scope = scope.where("date <= ?", params[:date_to]) if params[:date_to].present?
if params[:query].present?
  sanitized = ActiveRecord::Base.sanitize_sql_like(params[:query])
  scope = scope.where("memo ILIKE ?", "%#{sanitized}%")
end
@pagy, @transactions = pagy(scope)
```

Date range filtering handles partial input: only `date_from`, only `date_to`, or both. ILIKE wildcards in user input are escaped via `sanitize_sql_like`.

UI details:
- Account and category: `<select>` dropdowns (desktop), pill buttons (mobile)
- Date range: native `<input type="date">` (no extra JS library)
- Memo search: text input with form submit
- Mobile "search" pill expands to show input field when tapped

### Navigation

**Desktop sidebar** — add "transactions" between "accounts" and "reports":

```
Budget
Accounts
Transactions  ← NEW (icon: list-bullet)
Reports
Quick Entry
...
```

**Mobile bottom tab** — no changes. The bottom tab bar stays at 5 items (budget, accounts, reports, quick entry, settings). Access the global transaction list from the accounts index page via a "All Transactions" link/button displayed above the account list.

### UI Layout

**Desktop (global list)**:
- Page title "transactions" + total count
- Filter bar: account dropdown, category dropdown, date range inputs, memo search (horizontal row)
- Transaction table: date, memo, category, account, amount, actions (edit/delete on hover)
- Edit links: `edit_account_transaction_path(transaction.account, transaction)` (uses nested route)
- Delete buttons: `account_transaction_path(transaction.account, transaction)` with DELETE method
- Transfer rows: light purple background, no edit/delete (matching existing behavior)
- Income rows: category shows "income" in italic
- Empty state: "No transactions found" when filter returns no results, "No transactions yet" when no transactions exist
- Pagy pagination at bottom

**Mobile (global list)**:
- Page title + total count
- Filter pills: horizontal scrollable row (account, category, date, search)
- Transaction cards: date + memo on first line, "category · account" on second line, amount on right
- Transfer cards: light purple background
- Pagy pagination at bottom

**Account detail page**:
- Existing header (balance, buttons, drawer) unchanged
- Transaction list replaced with shared partials (table/cards + filters + pagination)
- Account filter hidden, category/date/search filters available

### Data Considerations

- Memo search uses PostgreSQL `ILIKE` — sufficient for the expected transaction volume, no full-text search needed
- Household isolation enforced at controller level via `Current.household`
- Category filter shows category groups with nested categories (matching existing category select pattern)
- Category filter includes a special "income" option to filter transactions with `category_id IS NULL` and non-transfer

## Testing

### Request Specs (`spec/requests/transaction_lists_spec.rb`)

- Unauthenticated access redirects to login
- Index returns success, shows only current household transactions
- Each filter param correctly narrows results (account_id, category_id, date range, query)
- Multiple filters applied simultaneously return correct intersection
- Income filter (`category_id=income`) returns only income transactions
- Partial date range (only date_from or only date_to) works correctly
- ILIKE special characters in query are escaped (searching "100%" doesn't break)
- Pagination works correctly
- Cannot see other household's transactions

### Account Page Request Specs Update

- Account show page has pagination (replaces limit 50)
- Filter params work on account show page

### System Specs (`spec/system/transaction_lists_spec.rb`)

Desktop:
- Click "transactions" in sidebar, see transaction list
- Apply filters (account, category, date range, search), verify results update
- Pagination navigation works
- Edit and delete transactions from the list

Mobile (375x812):
- Navigate from accounts page to global transaction list
- Filters work in mobile UI
- Card layout displays correctly
- Pagination works

Account page:
- Pagination replaces old limit-50 behavior
- Filters work on account detail page (desktop + mobile)
