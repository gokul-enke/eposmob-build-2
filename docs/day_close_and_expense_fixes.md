# Day Close Modal Fixes & Create Expense Payment Method Filter

**Date:** 2026-07-17
**Branch:** mubashir-dev

---

## Part 1 — Day Close Modal Fixes

**File:** `lib/screens/sales/daily_sales_close_list.dart`

---

### Fix 1 — Opening Time Validation Removed

#### What was wrong
`_submitDayClose()` contained a validation block that blocked form submission if the opening time was empty or did not match the store's configured working start time. This caused submit failures on legitimate day closes where the opening time differed from the store setting (e.g., late opens, manual overrides).

#### Why it was wrong
The validation was overly strict and did not account for valid operational scenarios where the actual shift opening time differed from the store's configured default. The backend already validates required fields, making the client-side block redundant and obstructive.

#### What was changed
The opening time validation block inside `_submitDayClose()` was removed entirely. The opening time is still included in the submission payload (line 1262–1264) — it is just no longer validated client-side before submitting.

```dart
// Payload still sends the opening time correctly:
openingTime: _openingTimeController.text.trim().isEmpty
    ? summary?.openingTime
    : _openingTimeController.text.trim(),
```

#### How to verify
Open the Day Close modal, clear or modify the Opening Time field, and tap Submit. The form should submit without showing a validation error related to opening time.

---

### Fix 2 — Closing Time Pre-fill Always Empty

#### What was wrong
In `_fetchSummary()`, `_closingTimeController` was pre-filled from the summary API response:

```dart
// Before (wrong):
_closingTimeController.text = result?.closingTime ?? '';
```

This populated the Closing Time field with the **previous session's closing time** from the API — even when no current shift had been closed. Operators were seeing a pre-filled time they had not entered, leading to confusion and incorrect close records.

#### Why it was wrong
The summary API returns data from the most recently recorded session. Its `closingTime` reflects a past close, not the current session being closed. The closing time must always be entered by the operator at the time of closing.

#### What was changed
`_closingTimeController` is now always set to an empty string in `_fetchSummary()` (line 1125):

```dart
// After (correct):
_closingTimeController.text = '';
```

#### How to verify
Open the Day Close modal. The Closing Time field should be blank regardless of what the summary API returns. The operator must manually select the closing time.

---

### Fix 3 — Opening Time Conditional Pre-fill

#### What was wrong
The opening time pre-fill in `_fetchSummary()` unconditionally used `result?.openingTime` from the summary API, which reflects the **previous session's opening time** when no shift is currently open. This caused the Opening Time field to show an incorrect, stale time when the modal was opened with no active shift.

#### Why it was wrong
The summary API is not scoped to the currently open shift. When no shift is open, `result?.openingTime` is the opening time of the last completed session — not a useful default for a new close operation.

#### What was changed
The pre-fill logic in `_fetchSummary()` (lines 1114–1123) was made conditional on whether a shift is currently active (`widget.openDraft != null`):

```dart
if (_openingTimeController.text.isEmpty) {
  final storeOpenTime = storeSession.activeStore?.storeOpenTime;
  final fallbackTime = storeOpenTime ?? '08:00:00';
  final hasActiveShift = widget.openDraft != null;
  _openingTimeController.text =
      (hasActiveShift &&
       result?.openingTime != null &&
       result!.openingTime!.isNotEmpty)
          ? result.openingTime!
          : fallbackTime;
}
```

| Condition | Opening Time pre-filled with |
|---|---|
| Active shift exists (`widget.openDraft != null`) | API `openingTime` (the actual shift start) |
| No active shift | Store's configured `storeOpenTime`, or `08:00:00` as last resort |

#### How to verify
1. **With an open shift:** Open the Day Close modal — Opening Time should reflect the actual shift start time from the summary API.
2. **Without an open shift:** Open the Day Close modal — Opening Time should show the store's configured open time (or `08:00:00`), not a stale value from a previous session.

---

### Fix 4 — Shift Name Field Made Always Editable

#### What was wrong
The Shift Name field used `enabled: !_openingPrefilled`. Once `_prefillFromOpenDraft()` ran (which fires when `widget.openDraft != null`), `_openingPrefilled` was set to `true`, rendering the Shift Name field **disabled and non-editable** for every open shift.

#### Why it was wrong
There is no functional reason to lock the Shift Name — operators may need to correct or rename a shift at close time. The lock was a side effect of reusing the `_openingPrefilled` guard, which was designed to prevent the summary API from overwriting data already loaded from the open draft, not to restrict user input.

#### What was changed
The `enabled` property on the Shift Name `_buildAmountField` (line 2270) was changed from conditional to always `true`:

```dart
// Before:
_buildAmountField(
  label: 'Shift Name',
  controller: _shiftNameController,
  enabled: !_openingPrefilled,   // locked when shift is open
),

// After:
_buildAmountField(
  label: 'Shift Name',
  controller: _shiftNameController,
  enabled: true,                 // always editable
),
```

No other field's `enabled` property was changed.

#### How to verify
Open the Day Close modal with an active shift. The Shift Name field should be tappable and editable. Type a new name and submit — the new name should appear in the submitted payload.

---

### Fix 5 — Cash Expenses Editable Field Removed

#### What was wrong
The Day Close modal had an editable **Cash Expenses** field that allowed operators to manually override the cash expenses figure. The Transaction Overview section of the same modal already displays the session-scoped cash expenses value from the summary API, making the editable field redundant and a source of potential data inconsistency.

#### Why it was wrong
Having both a read-only display (Transaction Overview) and an editable input for the same value with different scoping created confusion. If an operator manually edited the field and submitted, their override could conflict with the actual expense records stored in the system.

#### What was changed

**1. UI — Cash Expenses field removed (lines 2484–2495):**
The two-column row containing Cash Refunds (left) and Cash Expenses (right) was replaced with a single full-width Cash Refunds field. Cash Refunds remains fully editable and unchanged.

```dart
// Before:
_buildTwoColumnRow(
  isNarrow: isNarrow,
  left: _buildAmountField(label: 'Cash Refunds', controller: _cashRefundsController),
  right: _buildAmountField(label: 'Cash Expenses', controller: _cashExpensesController),
),

// After:
_buildAmountField(
  label: 'Cash Refunds',
  controller: _cashRefundsController,
),
```

**2. Payload — now reads directly from summary API (line 1271):**

```dart
// Before:
cashExpenses: num.tryParse(_cashExpensesController.text.trim()) ?? summary?.cashExpenses,

// After:
cashExpenses: summary?.cashExpenses,
```

**3. Dead code removed:**
- Declaration: `_cashExpensesController` (was line 919) — removed
- `dispose()` call (was line 1061) — removed
- `_fetchSummary()` pre-fill assignment (was line 1130) — removed
- Debug print referencing controller (was line 1239) — removed

#### How to verify
Open the Day Close modal. The Cash Expenses field should no longer appear in the form. Only Cash Refunds should be visible in that section. Submit a day close and confirm the `cash_expenses` value in the API payload matches the figure shown in the Transaction Overview.

---

## Part 2 — Create Expense Payment Method Filter

**File:** `lib/screens/transactions/create_expense_screen.dart`

---

### What was wrong
The **Payment Method** dropdown in the Create Expense screen showed all available payment methods regardless of which credit account (Paid From / Source) was selected. This allowed operators to select a payment method not supported by the chosen account, which would be rejected by the backend or create invalid records.

### Why it was wrong
Each company account in the system has a `payment_method` array that lists the payment method codes it supports. The UI was not using this data to constrain the dropdown options — it always showed the full list from the master data.

### What was changed

**1. Company accounts loaded on init (lines 69–73):**
In `initState()`, after fetching expense account options, `CompanyAccountProvider.listCompanyAccounts()` is called with `loadAll: true` to ensure all company account records (including their `paymentMethod` arrays) are available in memory:

```dart
final companyAccountProvider =
    Provider.of<CompanyAccountProvider>(context, listen: false);
await companyAccountProvider.listCompanyAccounts(
    accessToken: token, loadAll: true);
```

**2. State variable to hold allowed methods (line 44):**

```dart
List<String> _allowedPaymentMethods = [];
```

**3. Credit account `onChanged` populates allowed methods (lines 368–386):**
When the operator selects a credit account, the matching `CompanyAccount` is looked up by name and its `paymentMethod` list is stored. If the currently selected payment method is no longer in the allowed list, it is automatically cleared:

```dart
onChanged: (val) {
  setState(() {
    selectedCreditAccount = val;
    final companyAccountProvider =
        Provider.of<CompanyAccountProvider>(context, listen: false);
    final selectedAccountName = val?['name']?.toString();
    final matchedAccount = companyAccountProvider
        .getCompanyAccountsList?.firstWhereOrNull(
          (account) => account.name == selectedAccountName);
    _allowedPaymentMethods = matchedAccount?.paymentMethod ?? [];
    if (selectedPaymentMethod != null) {
      final currentName = selectedPaymentMethod!['name']
          ?.toString().toUpperCase();
      final stillValid = _allowedPaymentMethods.any(
          (m) => m.toUpperCase() == currentName);
      if (!stillValid) selectedPaymentMethod = null;
    }
  });
},
```

**4. `_getFilteredPaymentMethods()` filters the dropdown (lines 235–245):**
The Payment Method dropdown's `items:` is sourced from this function instead of directly from the provider:

```dart
List<Map<String, dynamic>> _getFilteredPaymentMethods(ExpenseProvider provider) {
  if (selectedCreditAccount == null || _allowedPaymentMethods.isEmpty) {
    return provider.paymentMethodOptions; // no filter — show all
  }
  return provider.paymentMethodOptions.where((method) {
    final name = method['name']?.toString().toUpperCase();
    return _allowedPaymentMethods.any(
        (allowed) => allowed.toUpperCase() == name);
  }).toList();
}
```

| State | Payment Methods shown |
|---|---|
| No credit account selected | All available methods (unfiltered) |
| Credit account selected | Only methods in that account's `paymentMethod` array |
| Credit account changed to one where current method is invalid | Current payment method selection is automatically cleared |

### How to verify
1. Open Create Expense.
2. Leave Paid From blank — Payment Method should show all options.
3. Select a Paid From account with a restricted `payment_method` array (e.g., only `CASH`) — Payment Method dropdown should show only `Cash`.
4. Select a payment method, then change Paid From to an account that does not support it — Payment Method should auto-clear.
