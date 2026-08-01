# Production QA scenarios and release blockers

This document records the practical QA pass for the POS application. The live
Windows debug build is exercised through Marionette Flutter MCP; automated
tests are used as regression evidence, not as a substitute for UI testing.

## Acceptance matrix

| Area | Scenario | Expected result | Status |
|---|---|---|---|
| Authentication | Valid login, invalid login, logout, session restore | Clear validation, no stale session, safe return to login | Live valid-login path verified; invalid/logout pending |
| Store/day | Select store, bootstrap, previous-day pending dialog | Store loads; user can explicitly defer/close day | Store bootstrap and defer path verified |
| Billing | Add product, price selection, stock selection, quantity, tax totals | Correct cart identity, stock, totals, and no build-phase errors | Verified with live sale |
| Payment | Cash/card/UPI/credit validation and exact paid amount | No under/overpayment unless explicitly allowed; correct method payload | Cash path verified; other methods pending |
| Order lifecycle | Save, resume, confirm, print, cancel | State transitions are idempotent and recoverable | Confirmed order verified; save/resume/print pending |
| Returns | Search sale, select lines, partial return, refund | Quantities and refund breakdown cannot exceed original sale | Automated coverage exists; live scenario pending |
| Inventory | Product/category/stock/variant create-edit-disable | Validation, stock integrity, and sync errors are visible | Not fully live-verified |
| Customers | Create/edit/select/customer credit | No duplicate or stale customer context | Customer selection exercised; CRUD pending |
| Reports | Sales, stock, customer/supplier, export/print | Filters, totals, pagination and empty states work | Not fully live-verified |
| Restaurant | Tables, menu, kitchen/order status | State changes persist and recover after refresh | Not fully live-verified |
| Offline/sync | Offline mutation, reconnect, retry | No duplicate sale; queued work is visible and replay-safe | Automated coverage exists; live network toggle pending |

## Live findings during this pass

- Billing and Sales navigation rendered successfully through Marionette. The
  Sales screen showed confirmed test orders, filters, pagination fields, and
  order rows.
- Navigating to Dashboard caused the Marionette widget-tree/screenshot request
  to stall. The app required a hot restart to recover and returned to login.
  This needs investigation with a dashboard-specific test account/data set
  before release.
- Dashboard API requests now have bounded 15-second timeouts so a slow or
  unavailable endpoint cannot leave the screen waiting forever. The live
  dashboard flow still needs a post-fix verification with a logged-in test
  session.
- A `ListTile` visibility assertion was reproduced in the expandable drawer
  and fixed by adding transparent `Material` hosts around decorated tiles.
- Dashboard also exposed a Flutter `DropdownButton` assertion: its
  `selectedItemBuilder` returned one widget for three menu items. The custom
  builder was removed so Flutter uses the correctly sized default selection
  list.
- After a full restart, Dashboard rendered live KPI content through Marionette.
  The MCP error stream still showed the pre-fix dropdown event until restart;
  this must be rechecked from a clean session before release.
- Sales Return live navigation exposed a 14-pixel status-chip `RenderFlex`
  overflow; the chip label now ellipsizes within a flexible region.
- Sales Return also exposed remaining decorated drawer tiles without a Material
  host; the expandable parent tile and sub-item variants were wrapped to remove
  the Flutter visibility assertion.
- Confirmed Orders rendered a valid empty state and a `Sync with Database`
  action, but the live test account had no confirmed orders after sync. This
  needs backend/data verification because Sales already showed confirmed test
  orders; the two screens may be using different endpoints or filters.

## Reproducible implementation issues found/fixed

1. Provider notifications during widget build in store selection and billing
   customer hydration. Initialization is deferred to a post-frame callback.
2. Selected side-menu `ListTile` lacked a Material ancestor, causing a Flutter
   assertion about invisible ink/background rendering.

## Release blockers requiring backend/business confirmation

The following code paths contain explicit placeholder/TODO behavior and cannot
be made production-correct by UI changes alone:

- `lib/providers/restaurant/order_provider.dart`: restaurant orders are marked
  for API integration.
- `lib/providers/restaurant/menu_provider.dart`: restaurant menu loading is
  marked for API integration.
- `lib/screens/customer_profile/widgets/customer_chat_widget.dart`: chat uses
  a placeholder API call.
- `lib/screens/billing/mobile_screen/widgets/billing_widget.dart`: coupon
  modal is not implemented.
- `lib/screens/transactions/company_accounts/add_company_account.dart`:
  company account lists and create action are placeholders.
- `lib/screens/print/preview.dart`: actual printing is not implemented.

Before release, confirm whether each feature is intentionally disabled, or
provide the production API contract and expected user-visible behavior. A
feature that is visible in navigation but silently uses mock/placeholder data
must be hidden or completed before shipping.

## Required live test data

- A non-production store with permissioned test user.
- One sellable product with multiple stock lots and a variant.
- One customer eligible for credit and one walk-in customer.
- A completed sale suitable for partial return.
- Configured test cash, card, and UPI payment methods.
- Printer/cash-drawer test configuration, or explicit acceptance of simulation.

## Release exit criteria

- No new Flutter exceptions during each live scenario.
- `flutter analyze` has no errors.
- Full test suite completes without hanging or reporter failures.
- Every visible navigation item either passes its scenario or is disabled with
  a clear “not available” state.
- Backend confirms idempotency for sale, payment, sync, and return endpoints.

## Latest regression evidence

- Sales-return calculation, refund-breakdown, and stock-report tests passed
  (`flutter test` targeted run: 6 tests).
- Targeted analysis of the dashboard, drawer, and sales-return responsive files
  reported no analyzer errors; only two existing unused-method warnings remain
  in the dashboard.
- Windows release build passed: `flutter build windows --release` produced
  `build/windows/x64/runner/Release/cloudpos.exe`. CMake emitted a non-fatal
  `webview_windows` developer-policy warning.
- Mobile order widgets/actions and payment-summary regression tests passed
  (targeted run: 9 tests).
