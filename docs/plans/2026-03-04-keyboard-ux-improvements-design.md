# Keyboard & UX Improvements Design

## Overview

Improve keyboard navigation and interaction consistency across the Kakebo app, focusing on budget page inline editing and Drawer behavior.

## Current State

- **Drawer Controller** (`drawer_controller.js`): Used on Account show page. Has ESC close, backdrop click, body scroll lock.
- **Budget Controller** (`budget_controller.js`): Used on Budget page. Has its own Drawer logic but **missing** ESC close and body scroll lock. Duplicates Drawer open/close/backdrop logic.
- **Budget inline edit** (`budget_entries/edit.html.erb`): Turbo Frame with autofocus input. No ESC cancel, no click-outside cancel, no focus trap.

## Changes

### 1. Refactor: Unified Drawer Controller

Extract all Drawer behavior into a single `drawer_controller.js`:

**Responsibilities:**
- Open/close animation (`translate-x-full` toggle)
- Backdrop show/hide (opacity + pointer-events)
- ESC key close (keydown listener on document)
- Backdrop click close
- Body scroll lock (`overflow-hidden` on body)
- Focus trap (Tab cycles within panel only)

**Targets:** `panel`, `backdrop`

**Focus trap logic:**
- On open: query all focusable elements (`input, button, select, textarea, a[href], [tabindex]`) in panel
- Save `document.activeElement` before open, restore on close
- Intercept Tab/Shift+Tab to cycle within panel boundaries

### 2. Simplify: Budget Controller

Remove all Drawer open/close/backdrop/animation logic from `budget_controller.js`.

**Keep:** `openWithCategory`, `outflowInput`, `inflowInput`, `accountChanged`, `updateFormAction`

**Communication with Drawer:** Use Stimulus Outlets.

```javascript
static outlets = ["drawer"]

openWithCategory(event) {
  // Set category...
  this.drawerOutlet.open()
  this.outflowTarget.focus()
}
```

**View change:** Budget index wraps Drawer elements with `data-controller="drawer"` and connects via `data-budget-drawer-outlet`.

### 3. New: InlineEdit Controller

New Stimulus controller for budget inline editing.

**Behavior:**
- **Esc** → cancel edit, restore display state
- **Click outside (focusout)** → cancel edit
- **Mutual exclusion** → clicking another category triggers focusout on current, auto-cancels

**Cancel mechanism:**
- New `BudgetEntriesController#show` action returns a single category's display turbo-frame
- InlineEdit controller stores the show URL as a Stimulus value
- On cancel: set `turbo-frame.src` to show URL, triggering Turbo reload

**Controller structure:**
```javascript
// inline_edit_controller.js
static values = { restoreUrl: String }

connect()    — focus input
keydown(e)   — if Escape, cancel()
focusout(e)  — rAF delay, check if activeElement left frame, cancel()
cancel()     — set frame src to restoreUrl value
```

**View (edit.html.erb):**
```erb
<turbo-frame id="budget-entry-<%= @category.id %>"
             data-controller="inline-edit"
             data-inline-edit-restore-url-value="<%= budget_entry_path(...) %>">
```

### 4. Account Show Page

Update `accounts/show.html.erb` to use the refactored `drawer_controller.js` (already uses it, just verify feature parity after refactor).

## Files to Change

| File | Action |
|------|--------|
| `app/javascript/controllers/drawer_controller.js` | Refactor: add focus trap, ensure ESC/body lock |
| `app/javascript/controllers/budget_controller.js` | Simplify: remove Drawer logic, add outlet |
| `app/javascript/controllers/inline_edit_controller.js` | New: ESC cancel, focusout cancel |
| `app/views/budget/index.html.erb` | Update: separate Drawer controller, outlet wiring |
| `app/views/budget_entries/edit.html.erb` | Update: add inline-edit controller + restore URL |
| `app/views/budget_entries/show.html.erb` | New: single category display turbo-frame partial |
| `app/controllers/budget_entries_controller.rb` | Add: `show` action |
| `config/routes.rb` | Add: budget_entries show route |
| `app/views/accounts/show.html.erb` | Verify: works with refactored drawer controller |
| `spec/system/` | Add: system tests for keyboard interactions |

## Out of Scope

- Keyboard shortcuts guide/help overlay
- Notification click-to-dismiss
- Tab-to-next-category continuous editing mode
- Global keyboard shortcuts (e.g., `n` to create new transaction)
