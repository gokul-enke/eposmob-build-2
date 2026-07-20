# Open Shift & Day Close Feature — Implementation Reference

> **Generated from actual codebase on 2026-07-10.**
> Every detail below is derived from the implemented code. Nothing speculative or pending is included.

---

## Table of Contents

1. [Business Flow Overview](#1-business-flow-overview)
2. [API Endpoints](#2-api-endpoints)
3. [Models](#3-models)
4. [Files Modified / Created](#4-files-modified--created)
5. [UX Behaviours](#5-ux-behaviours)
6. [Testing Checklist](#6-testing-checklist)

---

## 1. Business Flow Overview

### 1.1 Login → Store Selection → Day Close Check

```
User logs in
  → StoreSelectionScreen displays available stores
  → User taps a store
  → _handleStoreSelection() fires
  → Reads compulsoryDayCloseRegister from AppSettings
  → IF compulsoryDayCloseRegister == true:
      → Calls salesProvider.fetchDayClosePendingStatus(storeId, userId)
      → IF response.pendingDayClose == true:
          → Shows "Day Close Pending" AlertDialog (barrierDismissible: false)
          → "Yes" → Dismisses alert → Opens DayCloseModal (passes openDraft)
              → On DayCloseModal success → navigates to MainScreen
              → On DayCloseModal dismissed without submit → navigates to MainScreen anyway
          → "No" → Dismisses alert → navigates to MainScreen
      → ELSE: navigates to MainScreen
  → IF compulsoryDayCloseRegister == false:
      → Skips entire pending check → navigates to MainScreen
```

### 1.2 Billing Page → Open Shift Check

```
User enters BillingPage
  → initState() → postFrameCallback fires
  → _checkOpenShiftRequired() always called (no compulsoryDayCloseRegister gate)
  → Calls salesProvider.fetchDayClosePendingStatus(storeId, userId)
  → IF response.canOpenShift == true (no open shift exists):
      → Shows "Shift Not Opened" AlertDialog (barrierDismissible: false)
      → "Open Shift" → Dismisses alert → Opens OpenShiftModal
          → On OpenShiftModal success → onSuccess: () {} (no-op, stays on billing)
      → "Go Back" → Dismisses alert → pops billing page (Navigator.pop)
  → IF canOpenShift == false (shift already open):
      → No alert shown, user proceeds with billing
```

### 1.3 Day Close (Manual from Sales List)

```
User opens DailySalesCloseList screen
  → Taps "Day Close" button on a record
  → Opens DayCloseModal (openDraft may be null)
  → Modal fetches summary from backend via fetchDailySalesCloseSummary()
  → IF openDraft was provided → prefills opening fields from draft
  → User fills/edits fields → taps "Close Day"
  → _submitDayClose() fires → validates opening time against working hours
  → Calls createDailySalesClose() → on success pops modal + shows snackbar
```

---

## 2. API Endpoints

All endpoints are defined in `lib/resources/app_url.dart`.

### 2.1 Open Shift — `POST /api/v1/daily-sales-close/open`

**Constant:** `APPUrl.openShift`
**Provider method:** `SalesProvider.openShiftApi()` (line 1131)

**Request headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
X-Tenant: {apiKey}
```

**Request body:**
```json
{
  "store_id": 1,
  "shift_name": "Shift",
  "business_date": "2026-07-10",
  "opening_date": "2026-07-10",
  "opening_time": "09:30:00",
  "opening_cash_in_hand": 500.0,
  "opening_cash_breakdown": [
    { "denomination": "100", "count": 5 }
  ],
  "notes": ""
}
```

**Response:** `200` or `201` → returns `true`. Any other status → returns `false`.

---

### 2.2 Day Close Pending Status — `GET /api/v1/daily-sales-close/pending-status`

**Constant:** `APPUrl.dailySalesClosePendingStatus`
**Provider method:** `SalesProvider.fetchDayClosePendingStatus()` (line 1183)

**Query parameters:** `?store_id={storeId}&user_id={userId}`

**Request headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
X-Tenant: {apiKey}
```

**Response (parsed fields):**
```json
{
  "success": true,
  "data": {
    "pending_day_close": true,
    "can_open_shift": false,
    "requires_confirmation": false,
    "business_date": "2026-07-09",
    "message": "...",
    "confirmation_message": "...",
    "opening_transaction_id": 123,
    "closing_transaction_id": null,
    "opening_date": "2026-07-09",
    "opening_time": "09:00:00",
    "closing_date": "2026-07-09",
    "closing_time": "21:00:00",
    "open_draft": {
      "id": 45,
      "shift_name": "Shift",
      "opening_time": "09:00:00",
      "cash_summary": {
        "opening_cash_in_hand": "500",
        "opening_cash_breakdown": [
          { "denomination": "100", "count": 5 }
        ]
      }
    }
  }
}
```

---

### 2.3 Day Close Summary — `GET /api/v1/daily-sales-close/summary`

**Constant:** `APPUrl.dailySalesCloseSummary`
**Provider method:** `SalesProvider.fetchDailySalesCloseSummary()` (line 973)

**Query parameters:** `?store_id={storeId}`

**Request headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
X-Tenant: {apiKey}
```

**Response (parsed into `DailySalesCloseSummary`):**
```json
{
  "user_name": "John",
  "store_id": 1,
  "shift_name": "Shift",
  "business_date": "2026-07-10",
  "opening_date": "2026-07-10",
  "opening_time": "09:00:00",
  "closing_date": "2026-07-10",
  "closing_time": "21:00:00",
  "cash_refunds": 0,
  "cash_expenses": 0,
  "cash_drop_amount": 0,
  "opening_cash_in_hand": 500,
  "opening_cash_breakdown": [...],
  "closing_cash_in_hand": 0,
  "closing_cash_breakdown": [...],
  "notes": "",
  "total_orders": 15,
  "total_sales": "5000.00",
  "payment_received": "4500.00",
  "collected_on_sale": "4000.00",
  "cash_sales": "3000.00",
  "online_sales": "1000.00",
  "credit_amount": "500.00",
  "credit_collected": "200.00",
  "total_returns": "100.00",
  "total_refunds": "50.00"
}
```

---

### 2.4 Day Close Create — `POST /api/v1/daily-sales-close/create`

**Constant:** `APPUrl.dailySalesCloseCreate`
**Provider method:** `SalesProvider.createDailySalesClose()` (line 1022)

**Query parameters:** `?store_id={storeId}`

**Request headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
X-Tenant: {apiKey}
```

**Request body:**
```json
{
  "shift_name": "Shift",
  "business_date": "2026-07-10",
  "opening_date": "2026-07-10",
  "opening_time": "09:00:00",
  "closing_date": "2026-07-10",
  "closing_time": "21:00:00",
  "cash_refunds": 0,
  "cash_expenses": 0,
  "cash_drop_amount": 0,
  "opening_cash_in_hand": 500,
  "opening_cash_breakdown": [
    { "denomination": "100", "count": 5 }
  ],
  "closing_cash_in_hand": 1200,
  "closing_cash_breakdown": [
    { "denomination": "500", "count": 2 },
    { "denomination": "100", "count": 2 }
  ],
  "notes": ""
}
```

**Response:**
- `200`/`201` → `{ "success": true, "message": "..." }`
- Other → `{ "success": false, "message": "..." }`

---

### 2.5 Day Close List — `GET /api/v1/daily-sales-close/list`

**Constant:** `APPUrl.listDailySalesClose`

### 2.6 Day Close View — `GET /api/v1/daily-sales-close/view/{id}`

**Constant:** `APPUrl.viewDailySalesClose(id)`

---

## 3. Models

### 3.1 `DayClosePendingStatus` — `lib/models/day_close_pending_status.dart`

| Field | Type | JSON Key | Default |
|---|---|---|---|
| `pendingDayClose` | `bool` | `pending_day_close` | `false` |
| `canOpenShift` | `bool` | `can_open_shift` | `true` |
| `requiresConfirmation` | `bool` | `requires_confirmation` | `false` |
| `businessDate` | `String` | `business_date` | `''` |
| `message` | `String` | `message` | `''` |
| `confirmationMessage` | `String` | `confirmation_message` | `''` |
| `openingTransactionId` | `int?` | `opening_transaction_id` | `null` |
| `closingTransactionId` | `int?` | `closing_transaction_id` | `null` |
| `openingDate` | `String?` | `opening_date` | `null` |
| `openingTime` | `String?` | `opening_time` | `null` |
| `closingDate` | `String?` | `closing_date` | `null` |
| `closingTime` | `String?` | `closing_time` | `null` |
| `openDraft` | `OpenDraftModel?` | `open_draft` | `null` |

### 3.2 `OpenDraftModel` — `lib/models/day_close_pending_status.dart`

| Field | Type | JSON Key |
|---|---|---|
| `id` | `int?` | `id` |
| `shiftName` | `String?` | `shift_name` |
| `cashSummary` | `OpenDraftCashSummary?` | `cash_summary` |
| `openingTime` | `String?` | `opening_time` |

### 3.3 `OpenDraftCashSummary` — `lib/models/day_close_pending_status.dart`

| Field | Type | JSON Key |
|---|---|---|
| `openingCashInHand` | `String?` | `opening_cash_in_hand` |
| `openingCashBreakdown` | `List<dynamic>?` | `opening_cash_breakdown` |

### 3.4 `DailySalesCloseSummary` — `lib/models/daily_sales_close.dart`

| Field | Type | JSON Key |
|---|---|---|
| `userName` | `String?` | `user_name` |
| `storeId` | `int?` | `store_id` |
| `shiftName` | `String?` | `shift_name` |
| `businessDate` | `String?` | `business_date` |
| `openingDate` | `String?` | `opening_date` |
| `openingTime` | `String?` | `opening_time` |
| `closingDate` | `String?` | `closing_date` |
| `closingTime` | `String?` | `closing_time` |
| `cashRefunds` | `num?` | `cash_refunds` |
| `cashExpenses` | `num?` | `cash_expenses` |
| `cashDropAmount` | `num?` | `cash_drop_amount` |
| `openingCashInHand` | `num?` | `opening_cash_in_hand` |
| `openingCashBreakdown` | `List<dynamic>?` | `opening_cash_breakdown` |
| `closingCashInHand` | `num?` | `closing_cash_in_hand` |
| `closingCashBreakdown` | `List<dynamic>?` | `closing_cash_breakdown` |
| `notes` | `String?` | `notes` |
| `totalOrders` | `int?` | `total_orders` |
| `totalSales` | `String?` | `total_sales` |
| `paymentReceived` | `String?` | `payment_received` |
| `collectedOnSale` | `String?` | `collected_on_sales` / `collected_on_sale` |
| `cashSales` | `String?` | `cash_sales` |
| `onlineSales` | `String?` | `online_sales` |
| `creditAmount` | `String?` | `credit_amount` |
| `creditCollected` | `String?` | `credit_collected` |
| `totalReturns` | `String?` | `total_returns` |
| `totalRefunds` | `String?` | `total_refunds` |

### 3.5 `AppSettings.compulsoryDayCloseRegister` — `lib/models/get_app_settings.dart`

- Type: `bool`, default `false`
- Parsed from app settings via `_readSettingStatus()`
- Gates the Day Close pending check at login in `store_selection_screen.dart`
- Does **NOT** gate the Open Shift check on `billing_page.dart`

---

## 4. Files Modified / Created

### 4.1 `lib/screens/sales/open_shift_modal.dart` (948 lines)

**Purpose:** Full-screen modal dialog for opening a new shift before billing.

**Class:** `OpenShiftModal` (StatefulWidget)
- Constructor parameter: `VoidCallback onSuccess` (required)

**State:** `_OpenShiftModalState`

**Controllers (all disposed in `dispose()`):**
| Controller | Initial Value | Purpose |
|---|---|---|
| `_shiftNameController` | `"Shift"` | Prefilled default shift name |
| `_businessDateController` | Today (`yyyy-MM-dd`) | Auto-set to today's date |
| `_openingTimeController` | Now (`HH:mm:00`) | Auto-set to current time |
| `_openingCashInHandController` | `""` | Auto-calculated from breakdown |
| `_notesController` | `""` | Optional notes |
| `_scrollController` | — | Auto-scroll on row add |
| `_denominationControllers[]` | — | One per breakdown row |
| `_countControllers[]` | — | One per breakdown row |

**Key methods:**

| Method | Line | Purpose |
|---|---|---|
| `initState()` | 48 | Sets store info, today's date, current time; calls `_fetchDenominations()` and `_ensureBreakdownRows()` |
| `_fetchDenominations()` | 79 | Loads cash denomination master data from `MasterDataProvider` |
| `_ensureBreakdownRows()` | 98 | Adds one empty breakdown row if list is empty |
| `_addBreakdownRow()` | 104 | Creates denomination + count controller pair |
| `_recalculateOpeningCash()` | 109 | Sums `denomination × count` for all rows; sets `_openingCashInHandController.text` |
| `_saveOpeningDraft()` | 141 | Validates opening time required; builds breakdown payload; calls `salesProvider.openShiftApi()`; on success shows snackbar, pops modal, calls `onSuccess()` |
| `_buildBreakdownSection()` | 627 | Renders denomination dropdown + count field rows with Add Row / Remove Row |
| `_buildDenominationDropdown()` | 792 | Dropdown of `_cashDenominations` filtered to exclude already-selected values in other rows |

**Form field order in build():**
1. Store (disabled)
2. Shift Name + Business Date (two-column)
3. Opening Time* + Opening Cash Balance (two-column)
4. Opening Cash Breakdown (dynamic rows)
5. Notes

**Payload sent to `openShiftApi()`:**
```
store_id, shift_name, business_date, opening_date (= business_date),
opening_time, opening_cash_in_hand, opening_cash_breakdown, notes
```

---

### 4.2 `lib/screens/sales/daily_sales_close_list.dart` (2606 lines)

**Purpose:** Contains both the Day Close listing screen and the Day Close modal.

#### DayCloseModal (line 759)

**Class:** `DayCloseModal` (StatefulWidget)
- Constructor parameters:
  - `VoidCallback onSuccess` (required)
  - `OpenDraftModel? openDraft` (optional)

**State:** `_DayCloseModalState`

**Controllers (all disposed in `dispose()`):**
| Controller | Purpose |
|---|---|
| `_businessDateController` | Business date from summary |
| `_shiftNameController` | Shift name (prefilled from openDraft or summary) |
| `_openingTimeController` | Opening time (prefilled from openDraft or summary) |
| `_closingTimeController` | Closing time from summary |
| `_notesController` | Notes |
| `_cashRefundsController` | Cash refunds |
| `_cashExpensesController` | Cash expenses |
| `_cashDropAmountController` | Cash drop amount |
| `_openingCashInHandController` | Opening cash in hand |
| `_closingCashInHandController` | Closing cash in hand |
| `_openingDenominationControllers[]` | Opening breakdown denomination per row |
| `_openingCountControllers[]` | Opening breakdown count per row |
| `_closingDenominationControllers[]` | Closing breakdown denomination per row |
| `_closingCountControllers[]` | Closing breakdown count per row |
| `_scrollController` | Auto-scroll on breakdown row add |

**State flags:**
| Flag | Purpose |
|---|---|
| `_openingPrefilled` | `true` when opening fields were populated from `openDraft` — locks opening fields as read-only |
| `_openingTimeReadOnly` | `true` when `openingTime` was provided by summary — locks opening time field |

**Key methods:**

| Method | Line | Purpose |
|---|---|---|
| `initState()` | 803 | Calls `_fetchSummary()`, `_fetchDenominations()`, `_ensureBreakdownRows()`; if `openDraft != null`, calls `_prefillFromOpenDraft()` |
| `_prefillFromOpenDraft()` | 843 | Fills shift name, opening time, opening cash in hand, and opening cash breakdown from `OpenDraftModel`; sets `_openingPrefilled = true` |
| `_fetchSummary()` | 929 | Calls `salesProvider.fetchDailySalesCloseSummary(storeId)` → populates all controllers from response. Respects `_openingPrefilled` to not overwrite draft-provided opening values |
| `_fetchDenominations()` | 814 | Loads cash denomination master data from `MasterDataProvider` |
| `_ensureBreakdownRows()` | 834 | Adds one empty row each for opening and closing breakdown if lists are empty |
| `_buildBreakdownPayload()` | 882 | Loops through denomination/count controllers, builds `[{denomination, count}]` array, skips empty rows |
| `_submitDayClose()` | 995 | Validates opening time against `AppSettings.workingTime`; calls `salesProvider.createDailySalesClose()` with all field values; shows success/error snackbar |
| `_extractWorkingStartTime()` | 1434 | Regex-extracts start time from "HH:mm - HH:mm" working time string |
| `_parseTimeOfDay()` | 1440 | Parses "HH:mm" string to `TimeOfDay` |
| `_isTimeBefore()` | 1449 | Compares two `TimeOfDay` values |

**Form field order in build() (after reorder):**
1. Session Information (User, Opening date/time, Closing date/time)
2. Business Date + Shift Name (two-column)
3. Opening Time + Closing Time (two-column)
4. Transaction Overview (Total Orders, Total Sales, Payment Received, Collected on Sale, Cash Sales, Online Sales, Credit Amount, Credit Collected)
5. Cash In Hand (Opening Cash In Hand, Closing Cash In Hand)
6. Returns & Refunds (Total Returns, Total Refunds)
7. Opening Cash Breakdown (dynamic rows with auto-scroll)
8. Closing Cash Breakdown (dynamic rows with auto-scroll)
9. Cash Refunds + Cash Expenses (two-column)
10. Cash Drop Amount
11. Notes

**Payload sent to `createDailySalesClose()`:**
```
store_id (query param), shift_name, business_date, opening_date,
opening_time, closing_date, closing_time, cash_refunds, cash_expenses,
cash_drop_amount, opening_cash_in_hand, opening_cash_breakdown,
closing_cash_in_hand, closing_cash_breakdown, notes
```

**Validation before submit:**
- Reads `AppSettings.workingTime` (e.g. "09:00 - 21:00")
- Extracts the start time via regex
- If opening time < working start time → blocks submit with error snackbar

---

### 4.3 `lib/screens/login/store_selection_screen.dart` (510 lines)

**Purpose:** Store selection after login. Contains the compulsory Day Close pending check.

**Key method:** `_handleStoreSelection()` (line ~370)

**Logic flow:**
1. Saves selected store to `StoreSessionProvider`
2. Reads `compulsoryDayCloseRegister` from `AppSettingsProvider`
3. If `true`:
   - Calls `salesProvider.fetchDayClosePendingStatus(storeId, userId)`
   - Prints diagnostics (storeId, userId, pendingDayClose, openDraft, requiresConfirmation)
   - If `pendingStatus.pendingDayClose == true`:
     - Shows `AlertDialog` with title "Day Close Pending"
     - Content uses priority chain: `confirmationMessage` → `message` → fallback text with `businessDate`
     - "Yes" button → opens `DayCloseModal(openDraft: pendingStatus?.openDraft)`
       - `onSuccess` → sets flag + navigates to `MainScreen`
       - `.then()` → if dismissed without submit → navigates to `MainScreen` anyway
     - "No" button → navigates to `MainScreen`
4. If `false` or no pending status → navigates directly to `MainScreen`

**Imports added:**
- `package:pos_machine/providers/app_settings_provider.dart`
- `package:pos_machine/providers/auth_model.dart`
- `package:pos_machine/providers/sales_provider.dart`
- `package:pos_machine/screens/sales/daily_sales_close_list.dart`
- `package:pos_machine/models/day_close_pending_status.dart`

---

### 4.4 `lib/features/billing/presentation/pages/billing_page.dart` (9705 lines)

**Purpose:** Main billing/POS screen. Contains the Open Shift check on page entry.

**Key methods:**

| Method | Line | Purpose |
|---|---|---|
| `_checkOpenShiftRequired()` | 9639 | Creates a fresh `SalesProvider()`, calls `fetchDayClosePendingStatus()`. If `canOpenShift == true` → calls `_showOpenShiftRequiredAlert()` |
| `_showOpenShiftRequiredAlert()` | 9667 | Shows `AlertDialog` (barrierDismissible: false) with "Shift Not Opened" title |

**Alert dialog actions:**
- **"Open Shift"** → Pops alert → Opens `OpenShiftModal(onSuccess: () {})` (no-op callback; user stays on billing page)
- **"Go Back"** → Pops alert → Pops billing page (`Navigator.of(context).pop()` if `canPop()`)

**Trigger:** Called unconditionally from `initState()` → `postFrameCallback` (line 358). No `compulsoryDayCloseRegister` gate.

**Import added:** `package:pos_machine/screens/sales/open_shift_modal.dart` (line 58)

---

### 4.5 `lib/providers/sales_provider.dart` (1221 lines)

**Methods added/modified:**

| Method | Line | HTTP | Endpoint |
|---|---|---|---|
| `fetchDailySalesCloseSummary()` | 973 | `GET` | `dailySalesCloseSummary?store_id=X` |
| `createDailySalesClose()` | 1022 | `POST` | `dailySalesCloseCreate?store_id=X` |
| `openShiftApi()` | 1131 | `POST` | `openShift` |
| `fetchDayClosePendingStatus()` | 1183 | `GET` | `dailySalesClosePendingStatus?store_id=X&user_id=Y` |

**All methods include:**
- `SharedPreferences` API key lookup
- `Bearer` token + `X-Tenant` headers
- Debug logging of request/response

---

### 4.6 `lib/models/day_close_pending_status.dart` (94 lines)

**New file.** Contains three model classes:
- `OpenDraftCashSummary` — opening cash in hand + breakdown
- `OpenDraftModel` — id, shift name, opening time, cash summary
- `DayClosePendingStatus` — full pending status response model

---

### 4.7 `lib/resources/app_url.dart`

**Endpoints added:**

| Constant | URL Path |
|---|---|
| `dailySalesClosePendingStatus` | `/api/v1/daily-sales-close/pending-status` |
| `dailySalesCloseSummary` | `/api/v1/daily-sales-close/summary` |
| `dailySalesCloseCreate` | `/api/v1/daily-sales-close/create` |
| `openShift` | `/api/v1/daily-sales-close/open` |
| `listDailySalesClose` | `/api/v1/daily-sales-close/list` |
| `viewDailySalesClose(id)` | `/api/v1/daily-sales-close/view/{id}` |

---

## 5. UX Behaviours

### 5.1 Open Shift Modal

| Behaviour | Detail |
|---|---|
| **Shift Name prefill** | Initialized to `"Shift"` (editable) |
| **Business Date prefill** | Auto-set to today's date (`yyyy-MM-dd`) |
| **Opening Time prefill** | Auto-set to current time (`HH:mm:00`) |
| **Opening Cash auto-calculate** | `_recalculateOpeningCash()` sums `denomination × count` for all breakdown rows. Triggered on denomination dropdown change and count field `onChanged`. Result written to Opening Cash Balance field |
| **Opening Cash editable** | Field remains manually editable even after auto-calculation |
| **Denomination dropdown filtering** | Each dropdown excludes denominations already selected in other rows |
| **Breakdown row management** | "Add Row" adds a new empty row. Remove button (red circle icon) removes a row (disabled when only 1 row remains) |
| **Auto-scroll on Add Row** | After adding a row, `_scrollController.animateTo(maxScrollExtent)` with 300ms `easeOut` animation |
| **Auto-focus on Add Row** | After adding a new breakdown row, the Count field of the new row is auto-focused via FocusNode + postFrameCallback so user can type immediately without tapping. |
| **Store field** | Disabled/read-only, shows active store name |
| **Time picker** | Uses `TimePickerTableCell` component |
| **Date picker** | Uses `CalendarPickerTableCell` component |
| **Validation** | Opening Time is required. Shows inline error message if empty |
| **Loading state** | Save button shows `CircularProgressIndicator` while submitting. Cancel and Close buttons disabled during loading |
| **Responsive layout** | Two-column layout on desktop (>= 420px), single column on narrow screens. Modal width: 760px desktop, 98% screen width mobile |

### 5.2 Day Close Modal

| Behaviour | Detail |
|---|---|
| **OpenDraft prefill** | If `openDraft` provided: prefills shift name, opening time, opening cash in hand, and opening cash breakdown rows. Sets `_openingPrefilled = true` which locks those fields as read-only |
| **Null openDraft handling** | When DayCloseModal receives openDraft: null (e.g. pending day close exists but no formal shift was opened), prefill is skipped entirely and _fetchSummary() populates all fields instead. No crash occurs. |
| **Summary fetch** | On init, fetches summary from backend. Populates all fields. If `_openingPrefilled` is already true, skips overwriting opening fields |
| **Opening Time lock** | If summary provides `openingTime`, sets `_openingTimeReadOnly = true` (renders as disabled TextFormField instead of TimePicker) |
| **Working hours validation** | Before submit, checks if opening time < working start time from `AppSettings.workingTime`. Blocks with error snackbar if violated |
| **Closing Cash auto-calculate** | `_recalculateClosingCash()` sums `denomination × count` for all closing breakdown rows. Triggered on denomination dropdown change, count field `onChanged`, and when a row is removed. Result written to Closing Cash In Hand field. |
| **Closing Cash editable** | Closing Cash In Hand field remains manually editable even after auto-calculation. |
| **Auto-scroll on Add Row** | Both Opening and Closing breakdown sections scroll to bottom after adding a row (same 300ms easeOut animation) |
| **Breakdown row management** | Separate opening and closing breakdown rows. Each has Add Row / Remove Row controls |
| **Denomination dropdowns** | Loaded from `MasterDataProvider.fetchCashDenominations()` |
| **Fallback values** | On submit, if controller text is empty, falls back to summary values |
| **Loading states** | Summary loading shows spinner. Submit shows loading indicator on Close Day button |
| **Error display** | Fetch errors show error message with Retry button. Submit errors show snackbar |

### 5.3 Day Close Pending Alert (Login)

| Behaviour | Detail |
|---|---|
| **Gate** | Only shown when `compulsoryDayCloseRegister == true` in AppSettings |
| **Barrier** | `barrierDismissible: false` — user must choose Yes or No |
| **Message priority** | `confirmationMessage` → `message` → fallback: "You did not close your last day sales for {businessDate}. Do you want to close it now?" |
| **Yes action** | Opens DayCloseModal with `openDraft` from pending status |
| **No action** | Navigates to MainScreen without day close |
| **Dismiss without submit** | If DayCloseModal is dismissed (e.g. X button) without submitting, user still navigates to MainScreen |

### 5.4 Open Shift Required Alert (Billing)

| Behaviour | Detail |
|---|---|
| **Gate** | Always checked (no AppSettings gate) |
| **Trigger** | `canOpenShift == true` from pending status API |
| **Barrier** | `barrierDismissible: false` |
| **Open Shift action** | Opens OpenShiftModal. After success, user stays on billing page |
| **Go Back action** | Pops billing page, returning to previous screen |

---

## 6. Testing Checklist

### 6.1 Open Shift Modal

- [ ] Modal opens from billing page alert "Open Shift" button
- [ ] Shift Name is prefilled with "Shift" and is editable
- [ ] Business Date is prefilled with today's date
- [ ] Opening Time is prefilled with current time
- [ ] Store field shows active store name and is disabled
- [ ] Adding denomination breakdown rows works
- [ ] Removing a breakdown row works (disabled when only 1 row)
- [ ] Selecting a denomination in one row removes it from other dropdowns
- [ ] Changing denomination or count recalculates Opening Cash Balance
- [ ] Opening Cash Balance remains manually editable
- [ ] Adding a new breakdown row auto-scrolls to bottom
- [ ] Submit with empty Opening Time shows validation error
- [ ] Successful submit shows "Shift opened successfully" snackbar
- [ ] Successful submit closes modal
- [ ] Failed submit shows error message in modal
- [ ] Cancel button closes modal without submitting
- [ ] Loading spinner shows on Save button during submit
- [ ] Responsive layout: narrow screens show single-column layout

### 6.2 Day Close Modal

- [ ] Modal opens from sales list "Day Close" button
- [ ] Modal opens from login pending alert "Yes" button
- [ ] Summary is fetched and all fields are populated
- [ ] With `openDraft` provided: shift name, opening time, opening cash in hand, opening breakdown are prefilled and locked
- [ ] Without `openDraft`: all opening fields are editable
- [ ] With openDraft null: all opening fields editable, summary fetched and fields populated normally
- [ ] Opening Time is read-only when summary provides it
- [ ] Closing Time is editable
- [ ] Transaction Overview cards show correct values from summary
- [ ] Cash In Hand fields are populated from summary
- [ ] Opening and Closing breakdown rows work (add/remove)
- [ ] Changing denomination or count in Closing Cash Breakdown recalculates Closing Cash In Hand
- [ ] Closing Cash In Hand remains manually editable
- [ ] Adding a breakdown row auto-scrolls to bottom (both sections)
- [ ] Cash Refunds, Cash Expenses, Cash Drop Amount, Notes are editable
- [ ] Submit validates opening time against working hours
- [ ] Submit with opening time before working start shows error snackbar
- [ ] Successful submit shows success snackbar and closes modal
- [ ] Failed submit shows error snackbar
- [ ] Loading state shows spinner on Close Day button
- [ ] Fetch error shows error message with Retry button
- [ ] Form field order matches: Session Info → Business Date/Shift → Times → Overview → Cash In Hand → Returns → Breakdowns → Refunds/Expenses → Cash Drop → Notes

### 6.3 Login Day Close Pending Check

- [ ] With `compulsoryDayCloseRegister = true` and `pendingDayClose = true`: alert shown
- [ ] With `compulsoryDayCloseRegister = true` and `pendingDayClose = false`: no alert, navigates to MainScreen
- [ ] With `compulsoryDayCloseRegister = false`: no API call, navigates directly to MainScreen
- [ ] Alert message uses `confirmationMessage` when available
- [ ] Alert message falls back to `message` when `confirmationMessage` is empty
- [ ] Alert message falls back to default text with `businessDate` when both are empty
- [ ] "Yes" opens DayCloseModal with `openDraft`
- [ ] "No" navigates to MainScreen
- [ ] With openDraft null and pendingDayClose true: DayCloseModal opens without prefill, fetches summary
- [ ] Dismissing DayCloseModal without submitting still navigates to MainScreen
- [ ] Cannot tap outside alert to dismiss it

### 6.4 Billing Page Open Shift Check

- [ ] On billing page entry, `fetchDayClosePendingStatus` is called
- [ ] With `canOpenShift = true`: "Shift Not Opened" alert shown
- [ ] With `canOpenShift = false`: no alert, billing proceeds normally
- [ ] "Open Shift" opens OpenShiftModal
- [ ] After successful shift open, user stays on billing page
- [ ] "Go Back" pops billing page
- [ ] Cannot tap outside alert to dismiss it
- [ ] Check runs regardless of `compulsoryDayCloseRegister` setting

### 6.5 API Integration

- [ ] `openShiftApi` sends correct payload to `/api/v1/daily-sales-close/open`
- [ ] `createDailySalesClose` sends correct payload to `/api/v1/daily-sales-close/create`
- [ ] `fetchDayClosePendingStatus` sends correct query params to `/api/v1/daily-sales-close/pending-status`
- [ ] `fetchDailySalesCloseSummary` sends correct query params to `/api/v1/daily-sales-close/summary`
- [ ] All API calls include `Authorization`, `Content-Type`, and `X-Tenant` headers
- [ ] Network errors are caught and surfaced to the user

---

*End of document.*
