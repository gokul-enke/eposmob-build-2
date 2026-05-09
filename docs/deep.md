# Billing System Deep Review

## Scope

Reviewed and aligned the following sales flows:

- `confirm order`
- `confirm order and print`
- `save order`
- `save order and print`
- `clear cart`
- `sync offline confirmed order`
- `restore saved order`
- `saved/confirmed order print`

Primary files reviewed:

- `lib/screens/billing/billing_page.dart`
- `lib/providers/local_product_provider.dart`
- `lib/screens/sales/confirmed_orders.dart`
- `lib/screens/sales/widgets/confirmed_order_detail_modal.dart`
- `lib/providers/cart_provider.dart`
- `lib/helpers/payment_helper.dart`
- `lib/services/print_service.dart`
- `lib/services/checkout_service.dart`
- `lib/providers/billing_provider.dart`
- `lib/screens/billing/billing_page_desktop.dart`
- `lib/screens/billing/billing_page_mobile.dart`
- `lib/screens/billing/billing_page_restaurant.dart`
- `lib/screens/billing/restaurant/order_panel.dart`

## Final Verdict

The main billing flow, offline sync flow, and saved-order print flow are now structurally aligned.

Before this work, the system had real inconsistencies:

- the same sale could produce different `payment_method` / `paid_methods` bodies depending on which button was used
- offline sync could rebuild payment payloads differently from online order creation
- transport-layer code was mutating `paid_methods` a second time
- desktop/mobile provider flow was not treating `COD` and `ONLINE` consistently
- some confirmed-sale paths were clearing cart with stock restoration instead of confirmed-sale stock retention
- saved-order print rendering existed in multiple copies with different discount logic
- restoring saved orders did not consistently understand stored payment method IDs

Those issues are now corrected in the active paths.

## What Was Fixed

### 1. Payment payload normalization is centralized

Shared helpers now live in:

- `lib/helpers/payment_helper.dart`

Important helpers:

- `normalizePaidMethodsForApi(...)`
- `buildApiPaymentPayloadFromLocal(...)`

These now handle:

- converting stored payment names or IDs into API-safe method IDs
- excluding credit-only pseudo methods like `DEBIT` / `BALANCE` from paid-method submission
- subtracting change/balance exactly once from the first cash/COD bucket
- rebuilding offline payment JSON into the same API structure used online

### 2. `CartProvider` no longer rewrites payment data

In:

- `lib/providers/cart_provider.dart`

`addToOrderAPI`, `updateOrderAPI`, and `addToOrderConfirmAPI` now trust the caller’s normalized `paid_methods`.

This removes the previous double-adjustment risk where:

- UI layer already reduced cash/COD by change
- API transport layer reduced it again

Also corrected:

- `updateOrderAPI` multi-payment body now uses `paid_methods`
- confirm/update/create multi-payment structure is consistent

### 3. Main billing page now stores and submits payment data consistently

In:

- `lib/screens/billing/billing_page.dart`

Current behavior:

- online confirm and confirm+print send `payment_method` as a method-ID array
- `paid_methods` uses method IDs with normalized amounts
- local save uses structured multi-payment JSON even for single-method cases
- save+print promotes to confirmed order with the same stored payment structure

### 4. Desktop/mobile provider flow is now aligned with the main billing flow

In:

- `lib/providers/billing_provider.dart`
- `lib/services/checkout_service.dart`
- `lib/screens/billing/billing_page_desktop.dart`
- `lib/screens/billing/billing_page_mobile.dart`

Changes:

- added `getSelectedPaymentMethodsForApi()`
- `getPaidMethods()` now emits method IDs, not just human-readable names
- `getTotalPaidAmount()` now includes `COD`
- local save payload from `createOrderData()` now stores IDs for `CASH/CARD/UPI/COD`, keeps `ONLINE`, and keeps `DEBIT` only as storage metadata
- restore logic on desktop/mobile now understands both stored names and stored IDs
- `COD` and `ONLINE` are no longer lost in desktop/mobile save/restore

### 5. Confirmed-sale cart clearing now preserves stock reduction

Confirmed sale paths must not restore stock.

Correct behavior now uses:

- `LocalProductProvider.clearCartAfterOrder()`

This is now used in confirmed-sale flows, including the shared checkout service:

- online confirm
- online confirm+print
- offline save-and-confirm/print

Draft-save paths still use normal `clearCart()`, which correctly restores draft-reserved stock.

### 6. Offline sync now uses the same payment semantics as online order creation

In:

- `lib/screens/sales/confirmed_orders.dart`

Active sync path now:

- builds item payload from `LocalProductProvider.buildOrderItemsPayloadFrom(order.items)`
- rebuilds payment payload through `PaymentHelper.buildApiPaymentPayloadFromLocal(...)`
- sends through the same `CartProvider.addToOrderAPI(...)`
- sends `status: "confirmed"`
- no longer invents a fake `transactionId`
- no longer forces a fake default `deliveryMethodId`

This is the most important correctness fix for offline sync.

### 7. Saved/confirmed print is unified

In:

- `lib/services/print_service.dart`
- `lib/screens/billing/billing_page.dart`
- `lib/screens/sales/confirmed_orders.dart`
- `lib/screens/sales/widgets/confirmed_order_detail_modal.dart`

Saved-order printing now routes through one shared service:

- `PrintService.printSavedOrder(...)`

This removed duplicated print-building logic and aligned:

- `you saved` calculation
- `netExcTax`
- subtotal-based discount calculation
- payment method display/breakdown rendering
- VAT / CR rendering

### 8. Saved-order updates no longer drop VAT / CR fields

In:

- `lib/providers/local_product_provider.dart`

`updateSavedOrder(...)` now preserves:

- `customerVatNumber`
- `customerCrNumber`

This prevents edited saved orders from silently losing receipt/print data.

## Flow-by-Flow Review

### Confirm Order

Main page:

- `billing_page.dart` calls `CartProvider.addToOrderAPI(...)`
- sends method-ID array from `_getSelectedPaymentMethods()`
- sends normalized `paid_methods` from `_getPaidMethods()`

Provider/desktop/mobile path:

- `checkout_service.dart` now calls `billingProvider.getSelectedPaymentMethodsForApi()`
- `billingProvider.getPaidMethods()` now emits the same ID-based format

Result:

- both active online confirm paths now submit the same payment-body shape

### Confirm Order And Print

Online confirm+print still:

- creates order online
- fetches server order details
- prints from server-confirmed response

This is correct, because server response is authoritative for receipt printing after an online sale.

The request body used before printing is now aligned with normal confirm order.

### Save Order

Draft-save behavior is now consistent:

- saved order stores structured payment JSON
- JSON carries method IDs / `ONLINE` / `DEBIT`
- draft save clears cart with stock restoration

This is correct because a draft is not a confirmed sale.

### Save Order And Print

Offline save+print behavior is now consistent:

- order becomes a confirmed local order
- confirmed local print uses `PrintService.printSavedOrder(...)`
- confirmed local save clears via `clearCartAfterOrder()`

This fixes the previous stock-restoration risk in the shared checkout flow.

### Clear Cart

There are now two correct meanings:

- `clearCart()` = abandon draft cart, restore reserved stock
- `clearCartAfterOrder()` = confirmed sale, do not restore stock

That distinction is important and is now preserved across flows.

### Sync Offline Confirmed Order

Current sync behavior is correct:

- item payload expansion matches online order item submission
- payment payload is rebuilt by the shared helper
- status is always forced to `confirmed`
- synced order is removed from local confirmed storage only after API success

This is now the closest match to the online confirm-order body.

### Restore Saved Order

Restore behavior now correctly handles:

- payment names
- payment method IDs
- `COD`
- `ONLINE`
- `DEBIT`

Stock behavior in `loadOrderForEditing(...)` is also sound:

- previous draft reservations are released
- incoming saved-order reservations are reapplied

That prevents stock drift when switching between drafts.

## Request-Body Consistency Summary

For the same sale, the target structure is now:

- `payment_method`: list of method IDs for multi-payment API submission
- `paid_methods`: list of `{method, amount}` using the same IDs
- `balance`: explicit string/number from UI state
- `to_customer_credit`: separate boolean/flag, not encoded as a paid method

For local storage, the target structure is now:

- JSON with:
  - `methods`
  - `amounts`
  - `isMultiPayment: true`

Stored payment JSON now works as the source of truth for:

- restore
- local print
- offline sync

## Remaining Notes / Residual Risk

### 1. Restaurant-screen warnings

Analyzer still shows pre-existing warnings in:

- `billing_page_restaurant.dart`
- `restaurant/order_panel.dart`

The filtered warnings left there are mostly unrelated style/unused items, not compile errors.

### 2. Desktop/mobile provider path still depends on provider-held fields

The shared provider flow now preserves address and aligned payment data.

If later you want desktop/mobile saved orders to also carry additional billing-page-only fields like advanced delivery-charge state or extra KYC data, those values need to exist in `BillingProvider` first. That is not a current request-body bug, but it is a completeness boundary.

## Validation

Validation run:

- `flutter analyze` on the touched billing/payment/sync/print files

Result:

- no analyzer `error -` lines in the touched flow files
- remaining warnings are mostly pre-existing style/unused issues outside the corrected request-body logic

## Bottom Line

For the reviewed order lifecycle, the active paths are now consistent in the places that matter most:

- payment request body shape
- change/balance handling
- confirmed-sale stock handling
- offline sync request reconstruction
- saved-order restore semantics
- saved/confirmed order printing

The offline sync process and save/restore cases were the highest-risk areas, and those are now materially safer and structurally aligned with the online order flow.
