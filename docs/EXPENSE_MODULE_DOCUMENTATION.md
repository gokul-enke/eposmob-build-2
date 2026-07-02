# Expense Transaction Module Documentation

This document describes the current implementation of the **Expense / General Payment** flow in the EPOS application. It reflects the code as it exists now, including the final data-source split, request payload behavior, view-screen mapping fixes, list-screen behavior, and the current known limitations.

---

## 1. File Paths & Locations

### New Expense Module Files
1. **Model:** `lib/models/expense.dart`
   - Stores expense row data from the API.
   - Preserves both display labels and backing IDs where available (`categoryId`, `debitAccountId`, `creditAccountId`, `paymentMethodId`).
2. **Provider:** `lib/providers/expense_provider.dart`
   - Handles list loading, create submission, filter state, pagination, and option normalization.
3. **List Screen:** `lib/screens/transactions/expense_list_screen.dart`
   - Displays paginated expense rows, reusable filters, pagination, and keyboard-friendly focus traversal.
4. **Create Screen:** `lib/screens/transactions/create_expense_screen.dart`
   - Builds the create form and loads options from both expense APIs and master data.
5. **View Screen:** `lib/screens/transactions/view_expense_screen.dart`
   - Shows a readable detail page using name-resolution helpers.

### Existing Files Modified
1. **Endpoint Registry:** `lib/resources/app_url.dart`
   - Contains the expense/general-payment endpoints.
2. **Main Provider Registration:** `lib/main.dart`
   - Registers `ExpenseProvider` globally.
3. **Navigation / Sidebar:** `lib/controllers/sidebar_controller.dart`, `lib/widgets/side_menu.dart`
   - Adds routing into the expense list/create/view screens.

---

## 2. Authentication & Tenant Context

Every expense request uses tenant-aware authenticated headers.

### Headers and Context Used
- `Authorization: Bearer <token>`
- `X-Tenant: <api_key>`
- `store_id` from `SharedPreferences` when available

### Token Source
```dart
final token = Provider.of<AuthModel>(context, listen: false).token;
```

### Shared Preferences Values Used
- `api_key`
- `active_store_id`

---

## 3. Backend Endpoints Currently Used

The current expense implementation uses three backend endpoints.

### A. List General Payments
- **Endpoint:** `{{server}}/api/v1/general-payment/list-general-payments`
- **Method:** `GET`
- **Query Parameters:**
  - `type=EXPENSE`
  - `store_id` when available

### B. General Payment Account Options
- **Endpoint:** `{{server}}/api/v1/general-payment/account-options`
- **Method:** `GET`
- **Used For:**
  - Expense Account (Debit)
  - Paid From / Source (Credit)
- **Important:**
  - This endpoint is **not** the source of truth for `Payment Method` anymore.
  - We intentionally stopped using it for `paymentMethodOptions` because it could mix ledger account names into the payment-method dropdown.

### C. Create General Payment
- **Endpoint:** `{{server}}/api/v1/general-payment/create-general-payment`
- **Method:** `POST`
- **Current Payload Shape:**
```json
{
  "entry_type": "EXPENSE",
  "payment_date": "2026-06-29",
  "category": "8193",
  "description": "Office rent",
  "amount": 80.0,
  "payment_method": "7970",
  "expense_account_id": "20",
  "payment_account_id": "11",
  "status": "SUCC",
  "notes": "",
  "store_id": 2
}
```

---

## 4. Final Data-Source Split

This is the final behavior implemented in the create form.

### Expense Category
- Loaded from **master data** through `MasterDataProvider.fetchMasterData(...)`
- Current code tries these master-data codes in order:
  1. `EXPENSE_CATEGORY`
  2. `EXPENSE_CATEGORIES`
- If one returns records, the screen maps them into `ExpenseProvider.categoryOptions`

### Expense Account (Debit)
- Loaded from `general-payment/account-options`
- Stored in `ExpenseProvider.debitAccountOptions`

### Paid From / Source (Credit)
- Loaded from `general-payment/account-options`
- Stored in `ExpenseProvider.creditAccountOptions`

### Payment Method
- Loaded only from `MasterDataProvider.fetchPaymentMethods()`
- Stored in `ExpenseProvider.paymentMethodOptions`
- This list should contain only real payment-method values such as:
  - `BANK`
  - `CARD`
  - `CASH`
  - `COD`
  - `ONLINE`
  - `CHEQUE`
  - `UPI`

### Why This Split Exists
During integration we found that using `general-payment/account-options` for all dropdowns could produce an incorrect `Payment Method` dropdown that mixed account names with payment methods, for example:
- `Purchase Account`
- `Indirect Expense Account`
- `Direct Expense Account`
- `BANK`
- `cash`

That is not valid UI behavior, so `paymentMethodOptions` now comes only from master data.

---

## 5. Provider Responsibilities

### `ExpenseProvider`
Current responsibilities:
- load expense list rows
- normalize account-options payloads
- hold list/filter/pagination state
- create new expense entries
- resolve readable labels for the view screen
- expose dynamic status options from fetched expense rows

### Key Fields
- `categoryOptions`
- `debitAccountOptions`
- `creditAccountOptions`
- `paymentMethodOptions`
- `_allExpenses`
- `_filteredExpenses`

### Important Methods
- `fetchGeneralPayments(...)`
  - loads expense rows from the list API
- `fetchAccountOptions(...)`
  - loads debit and credit account options
  - still normalizes category-shaped keys if returned
  - intentionally does **not** populate `paymentMethodOptions` from account-options
- `createGeneralPayment(...)`
  - posts the create payload
  - refreshes the list on success
- `resolveOptionLabel(...)`
  - used by the view screen to map stored IDs back to readable names
- `setCategoryOptionsFromMasterData(...)`
  - converts master data records into create-form category options
- `setPaymentMethodOptionsFromMasterData(...)`
  - converts master data records into create-form payment-method options
- `availableStatuses`
  - returns `All` plus unique status values found in `_allExpenses`

---

## 6. Create Screen Flow

### Initialization Sequence
In `CreateExpenseScreen.initState()` the screen currently does:
1. fetch account options from `general-payment/account-options`
2. fetch expense-category master data
3. fetch payment methods from master data

### Current Form Field Mapping
- `selectedCategory`
  - submits `selectedCategory['id']`
- `selectedDebitAccount`
  - submits `selectedDebitAccount['id']`
- `selectedCreditAccount`
  - submits `selectedCreditAccount['id']`
- `selectedPaymentMethod`
  - submits `selectedPaymentMethod['id']`

### Current Submission Rules
Before submit, the screen requires:
- Expense Category selected
- Debit Account selected
- Credit Account selected
- Payment Method selected
- Amount > 0
- Auth token present

---

## 7. View Screen Mapping Fixes

The view screen originally showed numeric/raw values in some cases, for example category/payment-method IDs instead of human-readable labels.

### Fix Applied
`Expense` now preserves IDs separately from the visible label fields, and `ViewExpenseScreen` uses `ExpenseProvider.resolveOptionLabel(...)` to display:
- category name
- payment method label
- debit account name
- credit account name

### Result
The view page now prefers readable labels such as:
- `Utilities`
- `UPI`
- `Direct Expense Account`
- `Bank Account`

instead of raw IDs like `8190` or `8188` when option lists are available.

---

## 8. Expense List Screen Behavior

The expense list screen was simplified to match the current backend capability and improve keyboard usability.

### Current List Actions
- `View` is available for each row.
- `Delete` has been removed from the UI.
- bulk selection/delete has also been removed.

### Why Delete Was Removed
The previous delete action only removed rows from in-memory provider state and did not call a backend delete endpoint. That caused records to disappear temporarily and then come back after the next reload.

Because there is currently no confirmed expense delete API wired in the app, removing the delete action is less misleading than keeping a fake local delete.

### Current Filter Sources
The list filters now use provider-backed values instead of old hardcoded placeholder sets.

- `Category` filter -> `ExpenseProvider.categoryOptions`
- `Debit Account` filter -> `ExpenseProvider.debitAccountOptions`
- `Status` filter -> `ExpenseProvider.availableStatuses`
- `Reference No` filter -> text search using `ExpenseProvider.setReference(...)`

### Status Filter Behavior
The status filter is now dynamic.

That means the dropdown is built from the actual statuses returned in fetched expense rows, for example:
- `All`
- `SUCC`
- `FAILED`
- `PENDING`
- `DRAFT`

whatever values are actually present in `_allExpenses`.

### Keyboard / Tab Flow
The filter row now supports ordered keyboard traversal without needing to click each field first.

Current traversal order:
1. Category filter
2. Reference search
3. Debit Account filter
4. Status filter
5. Reset button

This is implemented using:
- `FocusNode`
- `FocusTraversalGroup`
- `FocusTraversalOrder`
- existing `CustomDropDownWithSearch`

No new filter component was introduced; the existing reusable dropdown component is reused.

---

## 9. Frontend Account & Payment Method Compatibility Validation

To prevent the backend from throwing validation errors (like `422 Validation failed` when pairing incompatible payment accounts and methods, e.g., using "Online Payment" with "Cash Account"), we implemented a frontend compatibility validation layer:

### A. Dynamic Input Filtering
* **Filtering Logic:** The `Payment Method` dropdown options are dynamically filtered based on the chosen value in the `Paid From / Source (Credit)` dropdown.
  * **Cash Account Selected:** The payment methods list is restricted to show only options containing "cash" (case-insensitive).
  * **Bank/other Account Selected:** The payment methods list is restricted to exclude cash-based options.
* **Auto-Reset Selection:** If a user modifies the selected Credit Account, and the currently selected payment method is no longer compatible, the payment method dropdown selection is automatically reset to `null` to prevent submission of invalid data.

### B. Submit-Time Validation Safeguard
Before posting the POST payload to the server, `_submitForm()` double-validates the compatibility pairing:
* **Cash Mismatch:** Displays a warning SnackBar (`"For Cash Account, only Cash payment method is allowed."`) and halts execution if there is an incompatibility.
* **Bank Mismatch:** Displays a warning SnackBar (`"For Bank/other Account, Cash payment method is not allowed."`) and halts execution if there is an incompatibility.

---

## 10. Known Limitations

### No Confirmed Backend Delete Integration Yet
There is currently no confirmed expense delete endpoint wired in `APPUrl`.

### Category Master-Data Code Still Needs Confirmation
The code currently tries:
- `EXPENSE_CATEGORY`
- `EXPENSE_CATEGORIES`

If the backend uses a different exact master-data code, both implementation and documentation should be updated together.

---

## 11. Important Corrections from the Original Integration Assumptions

The first documentation draft no longer matched the final code in a few places.

### Corrected Points
1. **Payment Method is not loaded from `general-payment/account-options` anymore**
   - it now comes only from `MasterDataProvider`
2. **Expense Category is no longer guaranteed to come from account-options**
   - in the create screen it now prefers master data
3. **The create form can still fail with `422 Validation failed` even when all fields are filled**
   - because backend account/method compatibility rules exist
4. **Delete is no longer shown in the expense list UI**
   - because there is no real backend delete call wired
5. **Expense list filters are now provider-backed and keyboard-traversable**
   - rather than old static placeholder filter lists
6. **Status filter is now dynamic from fetched API rows**
   - it is no longer restricted to a hardcoded `SUCC / FAILED` list
7. **Currency indicators are dynamic**
   - no longer hardcoded as "SAR". Retrieved from `AppSettingsProvider` in create, list, and view screens.

---

## 12. Recommended Next Improvements

1. Confirm the final master-data code for expense category with the backend team if `EXPENSE_CATEGORY` / `EXPENSE_CATEGORIES` are only provisional aliases.
2. Add a real backend expense delete endpoint only after the exact backend route and request contract are confirmed.
3. If backend later exposes allowed payment methods per account directly, use that instead of only backend-side validation errors.

---

## 13. Summary

The expense module is now implemented with a mixed-source strategy that matches the observed web behavior more closely:
- expense list and create submission use `ExpenseProvider`
- debit and credit accounts come from `general-payment/account-options`
- expense category comes from master data in the create form
- payment method comes from payment-method master data only
- view screen resolves names more reliably than before
- expense list no longer exposes misleading local-only delete actions
- expense filters are keyboard-friendly and use reusable dropdown UI
- status filter now follows the statuses actually returned by the expense list API
- UI pre-filters payment methods and validates compatibility dynamically to prevent 422 errors

The main known gaps still remaining are:
- final confirmation of the exact expense-category master-data code
