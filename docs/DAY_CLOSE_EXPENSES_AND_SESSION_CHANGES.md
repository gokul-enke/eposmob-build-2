# Day Close Expenses Breakdown & Session Changes

**Date:** 2026-07-15  
**Branch:** mubashir-dev  
**Scope:** Day Close feature enhancements, print service fix, stock screen responsive UI

---

## Feature Overview

The Day Close workflow in eposmob follows the sequence: **Open Shift → Record Sales → Day Close → Submit**. The Day Close modal and detail screen now display a session-scoped **Expenses Breakdown** (Cash Expenses, Bank Expenses, Total Expense) inside the Transaction Overview section, giving operators a clear view of expenses recorded during that specific shift.

---

## Files Changed

### 1. `lib/models/daily_sales_close.dart`

**Role:** Data models for the Day Close feature — `DailySalesCloseData` (detail API response) and `DailySalesCloseSummary` (summary API response).

**Changes:**

- **`DailySalesCloseData`** — Added three new fields:
  - `String? totalExpenses` (from JSON key `total_expenses`)
  - `String? cashExpenses` (from JSON key `cash_expenses`)
  - `String? bankExpenses` (from JSON key `bank_expenses`)
  - Added to constructor, parsed in `fromJson()` with `?.toString()` to handle both string and numeric API values.

- **`DailySalesCloseSummary`** — Added two new fields:
  - `num? bankExpenses` (from JSON key `bank_expenses`)
  - `num? totalExpenses` (from JSON key `total_expenses`)
  - `cashExpenses` already existed. Added new fields to constructor and `fromJson()` using `_numValue()`.

**Why:** Both APIs already return these fields, but they were not mapped in the Flutter models, so the UI could not display them.

---

### 2. `lib/providers/expense_provider.dart`

**Role:** Provider for expense/general-payment data, used by the Expense List screen and shared helpers.

**Changes:**

- Added `getExpenseBreakdownForDate()` method (~57 lines):
  - Accepts `accessToken`, `storeId`, `businessDate`
  - Calls `listGeneralPayments` API with `type=EXPENSE` and `store_id`
  - Parses response with `Expense.fromJson()`, filters by matching `paymentDate` to `businessDate`
  - Splits expenses by `creditAccount` name containing "cash" or "bank"
  - Returns `Map<String, double>` with keys `cash`, `bank`, `total`
  - Returns all zeros on any error — does not throw
  - Stateless: does not mutate `_allExpenses` or call `notifyListeners()`

**Why:** Initially created as a shared helper for both the modal and detail screen. The modal no longer uses it (switched to summary API), but the method remains available for other callers.

**Known limitation:** This method fetches **all expenses for the store on that date**, not scoped to a specific Day Close session. If multiple sessions exist on the same business date, values will be inflated. This is why the modal was switched to use the summary API instead.

---

### 3. `lib/screens/sales/daily_sales_close_list.dart`

**Role:** Day Close list screen and the Day Close modal (`DayCloseModal` widget).

**Changes:**

- **Import added:** `expense_provider.dart`
- **State variables added:** `_expenseCash`, `_expenseBank`, `_expenseTotal` (all `double`, default `0.0`)
- **`_fetchSummary()` updated:** After setting `_businessDateController.text`, the three expense state variables are now populated directly from the summary API response:
  ```dart
  _expenseCash = (result?.cashExpenses ?? 0).toDouble();
  _expenseBank = (result?.bankExpenses ?? 0).toDouble();
  _expenseTotal = (result?.totalExpenses ?? 0).toDouble();
  ```
- **`_fetchExpenses()` method kept but not called:** Remains in the file as a fallback/utility. It uses `getExpenseBreakdownForDate()` via `ExpenseProvider`.
- **UI added in Transaction Overview:** After the CREDIT AMOUNT / CREDIT COLLECTED row:
  - `_buildSmallSummaryRow('CASH EXPENSES', ..., 'BANK EXPENSES', ...)`
  - `_buildSmallSummaryItem('TOTAL EXPENSE', ..., color: Colors.red.shade700)`
  - Read-only display, matches existing card styles exactly

**Why:** Displays session-scoped expenses from the summary API in the Transaction Overview section.

---

### 4. `lib/screens/sales/daily_sales_close_detail.dart`

**Role:** Read-only detail screen for a completed Day Close record.

**Changes:**

- **UI section added:** "Expenses Breakdown" section placed between Sales Summary and Cash Summary:
  - Uses `_buildSectionHeader('Expenses Breakdown', Icons.receipt_long_outlined)`
  - Uses `_buildCard()` wrapper (same `CustomBoxShadowContainer` as all other sections)
  - Three-column `Row` with `_buildDetailItem` for Cash Expenses, Bank Expenses, Total Expense
  - All values in red; Total Expense is bold
- **Data source:** Reads directly from `data.cashExpenses`, `data.bankExpenses`, `data.totalExpenses` — fields from the `/view/$id` API response already fetched by `_fetchDetails()`
- **No separate API call** — no `ExpenseProvider` import needed

**Why:** The detail API (`/view/$id`) already returns session-scoped expense fields. No additional fetch required.

---

### 5. `lib/services/print_service.dart`

**Role:** Handles receipt/invoice printing and PDF generation.

**Changes:**

- **Payment total calculation fix:** When computing `paidAmount` from `paymentBreakdown`, the code now excludes keys `DEBIT`, `CREDIT`, and `BALANCE` from the sum:
  ```dart
  const excludedKeys = {'DEBIT', 'CREDIT', 'BALANCE'};
  final totalPaid = paymentBreakdown.entries
      .where((e) => !excludedKeys.contains(e.key.trim().toUpperCase()))
      .fold<double>(0.0, (sum, e) { ... });
  ```

**Why:** Previously, the fold summed all values in the `paymentBreakdown` map, including accounting entries like DEBIT, CREDIT, and BALANCE that are not actual payments. This inflated the printed "Paid Amount" on receipts.

---

### 6. `lib/screens/product/widgets/add_product_stock.dart`

**Role:** Add/manage product stock screen (purchase order entry).

**Changes (1376 insertions, 392 deletions):**

- **Import added:** `stock_responsive.dart` for shared responsive helpers
- **Mobile-responsive layouts throughout**, gated by `stockIsPhone(context)` (breakpoint: `< 600px`):
  - **Header section:** Stacks date, store dropdown, and supplier field vertically on mobile (horizontal `Row` on desktop)
  - **Stock table header:** Hidden on mobile (`SizedBox.shrink()`) — card layout replaces it
  - **Stock item rows:** Compact card layout on mobile with:
    - Product name + index badge + edit/delete icons in header row
    - Barcode and unit info row
    - 2x2 grid for editable fields (Qty, Cost Price, Selling Price, Tax %)
    - Total amount displayed at bottom of card
  - **Summary section:** Single-column layout on mobile, two-column on desktop
  - **Action buttons (Finish/Cancel):** Full-width `Expanded` buttons on mobile, fixed-width on desktop
- **Inline editable fields:** `_InlineEditableField` widget for direct in-card editing on mobile
- **Purchase order completion flow:** Restructured to find `purchaseId` from successful batch items and complete the purchase order

---

### 7. `lib/screens/product/widgets/stock_responsive.dart`

**Role:** New file — shared responsive helpers for stock screens.

**Contents:**
- `kStockPhoneBreakpoint` constant (`600`)
- `stockIsPhone(BuildContext)` — returns `true` if screen width < 600
- `stockHorizontalPadding(double width)` — adaptive padding
- `StockContentCard` — Shopify-style card with border and shadow
- `StockIconAction` — icon button with >= 44px tap target
- `StockInfoChip` — label + value display for mobile cards
- `StockPaginationBar` — pagination that wraps on narrow screens

---

### 8. `pubspec.lock`

**Changes:** Transitive dependency version bumps:
- `characters` 1.4.0 → 1.4.1
- `matcher` 0.12.17 → 0.12.19
- `material_color_utilities` 0.11.1 → 0.13.0
- `test_api` 0.7.7 → 0.7.10

---

## Bugs Fixed

### Bug 1: Expenses Breakdown showed 0.00 (Race Condition)

**Root cause:** `initState()` fired `_fetchSummary()` and `_fetchExpenses()` concurrently. When opened from the Day Close button, `widget.pendingBusinessDate` was `null` and `_businessDateController.text` was empty. `_fetchExpenses()` ran with an empty `businessDate`, so no expenses matched.

**Fix:** Removed `_fetchExpenses()` from `initState()`. Expense values are now set directly from the summary API response inside `_fetchSummary()`, which already returns session-scoped `cash_expenses`, `bank_expenses`, and `total_expenses`.

### Bug 2: Expenses Breakdown showed inflated values (Scope Issue)

**Root cause:** `getExpenseBreakdownForDate()` fetched all expenses for the store on a given date and filtered client-side. If multiple Day Close sessions existed on the same business date, all sessions' expenses were summed together.

**Fix:** Switched the modal to use session-scoped values from the summary API (`DailySalesCloseSummary.cashExpenses`, `.bankExpenses`, `.totalExpenses`) instead of calling `getExpenseBreakdownForDate()`.

### Bug 3: Print service inflated paid amount

**Root cause:** `paymentBreakdown` map included accounting keys (DEBIT, CREDIT, BALANCE) that were summed into the paid total.

**Fix:** Excluded these keys from the fold calculation in `print_service.dart`.

---

## Correct Day Close Workflow

1. **Open Shift** — operator opens a new shift via the Open Shift modal, setting shift name and opening cash
2. **Record Sales** — sales are processed throughout the shift
3. **Record Expenses** — expenses are recorded via the Expense module (cash or bank)
4. **Day Close** — operator opens the Day Close modal:
   - Summary API is called with `store_id` and `businessDate`
   - Transaction Overview shows: Total Orders, Total Sales, Payment Received, Collected On Sale, Cash/Online Sales, Credit Amount/Collected, and **Expenses Breakdown (Cash / Bank / Total)**
   - Cash In Hand, Returns & Refunds, Cash Breakdown sections are filled
5. **Submit** — payload is sent to close the shift; the `_cashExpensesController` value (editable field) is included in the submission, but the Expenses Breakdown display is read-only

---

## Known Limitations

1. **`_fetchExpenses()` method retained but unused:** The method exists in `daily_sales_close_list.dart` but is not called. Flutter analyzer reports it as `unused_element`. It can be removed in a future cleanup if `getExpenseBreakdownForDate()` is not needed elsewhere.

2. **`getExpenseBreakdownForDate()` is not session-scoped:** The method in `expense_provider.dart` sums all expenses for a store on a date, across all sessions. It should only be used when session scoping is not required.

3. **Summary API must return `bank_expenses` and `total_expenses`:** The modal relies on these fields being present in the summary API response. If the backend does not return them, the values will default to 0.

4. **Detail API fields parsed as `String?`:** In `DailySalesCloseData`, `cashExpenses`, `bankExpenses`, and `totalExpenses` are stored as `String?` (using `?.toString()`), while in `DailySalesCloseSummary` the same fields are `num?`. This matches each model's existing parsing conventions but means consumers need to handle the type difference.
