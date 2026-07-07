# Task 298 - Day Close Improve
**Project**: eposmob (CloudPOS)  
**Date**: July 7, 2026  
**Author**: Mubashir  

## Overview
On login, if COMPULSORY_DAY_CLOSE_REGISTER company 
prop is enabled, the app checks if the sales executive 
has a pending day close via a dedicated backend API. 
If pending, a dialog prompts them to close before 
proceeding to the dashboard.

## Final Flow
1. Sales executive logs in and selects a store
2. bootstrapStore() completes (loads all settings)
3. App reads COMPULSORY_DAY_CLOSE_REGISTER from AppSettings
4. If flag is OFF → proceed to MainScreen silently
5. If flag is ON → call pending-status API
6. If pending_day_close = false → proceed to MainScreen silently
7. If pending_day_close = true → show dialog:
   "You did not close your last day sales for [date].
    Do you want to close it now?"
   
   [ Yes ] → DayCloseModal opens on store selection screen
             → On submit → navigate to MainScreen
             → On cancel without submit → navigate to MainScreen
             (user never stuck on store selection screen)
   
   [ No ]  → navigate to MainScreen immediately

## Files Changed

### 1. lib/models/get_app_settings.dart
- Added `compulsoryDayCloseRegister` boolean field
- Parsed from COMPULSORY_DAY_CLOSE_REGISTER company prop
- Default value: false
- Follows existing _readSettingStatus() pattern

### 2. lib/models/day_close_pending_status.dart (NEW)
- New model for pending-status API response
- Fields: pendingDayClose, canOpenShift, 
  requiresConfirmation, businessDate, message,
  confirmationMessage, openingTransactionId,
  closingTransactionId, openingDate, openingTime,
  closingDate, closingTime

### 3. lib/resources/app_url.dart
- Added dailySalesClosePendingStatus endpoint:
  GET /api/v1/daily-sales-close/pending-status

### 4. lib/providers/sales_provider.dart
- Added fetchDayClosePendingStatus() method
- Calls pending-status API with store_id param
- Includes X-Tenant header for multi-tenant routing
- Returns DayClosePendingStatus? model

### 5. lib/screens/login/store_selection_screen.dart
- After bootstrapStore(), check compulsoryDayCloseRegister
- If enabled, call fetchDayClosePendingStatus()
- If pending → show AlertDialog with API message
- Yes → open DayCloseModal with dayCloseSubmitted flag
  to prevent double navigation
- No → navigate to MainScreen immediately
- shouldNavigateToMainScreen flag ensures correct
  navigation in all scenarios

### 6. lib/screens/sales/daily_sales_close_list.dart
- Modified `DayCloseModal` denomination dropdown building flow
- Passed parent controllers array and current index down to row and dropdown builders
- Added a `.where()` filter on the dropdown items mapping to exclude values selected in other rows

## Backend Setup
- Company Prop created in ERP:
  - Property Name: Compulsory Day Close Register
  - Property Code: COMPULSORY_DAY_CLOSE_REGISTER
  - Type: boolean
  - Category: Pos
  - Status: Active (toggle on/off from admin)

## APIs Used
1. GET /api/v1/daily-sales-close/pending-status
   ?store_id=X
   → Returns pending status and message for dialog

2. POST /api/v1/daily-sales-close/create
   { store_id, business_date }
   → Used internally by DayCloseModal on submit
   (existing endpoint, not modified)

## Known Limitations / Future Improvements
- "No" allows bypassing the check — consider making 
  it mandatory in future if senior decides
- DayCloseModal opens with current session summary —
  business_date from pending-status API is not 
  explicitly passed to DayCloseModal yet (uses 
  its own fetchDailySalesCloseSummary internally)
- If multiple days are missed, only the oldest 
  pending date is shown (backend handles this logic)
- summary API available for future use:
  GET /api/v1/daily-sales-close/summary
  ?store_id=X&business_date=YYYY-MM-DD

## Development History
- Initial implementation used list API with 
  yesterday date filter (temporary approach)
- Updated to fetch latest record and compare 
  businessDate against yesterday
- Final implementation replaced with Athul's 
  dedicated pending-status API (cleaner, 
  purpose-built, backend handles all logic)
- Denomination Selection Fix: Updated dropdown rows in `DayCloseModal` to dynamically filter out options selected in other rows to prevent duplicate cash breakdown entries.

---
*Task 298 complete and tested on Windows. 
Popup appears correctly on login when flag is 
enabled and day close is pending. Cash breakdown duplicate options filtered out.*
