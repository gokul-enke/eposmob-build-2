# Offline-first sales architecture

## Product rule

`Confirm Order` means the sale is durable on this device. It does not mean the
server has replied.

Every live final-sale surface follows this order:

1. Validate the checkout state.
2. Save an immutable confirmed-order snapshot to Hive.
3. Flush the confirmed order to disk.
4. Save the exact API request in the durable sale outbox and flush it.
5. Clear/advance the local cart workspace.
6. Print from the local confirmed-order snapshot when printing was requested.
7. Start one API attempt through the app-scoped outbox.
8. Show the result in **Sales → Confirmed Orders**.

The screen that started step 7 does not own the request. Navigating to another
page or tab cannot cancel it. Closing the process during a queued or sending
state changes that record to `needs_review` on the next start; it is not sent a
second time automatically.

There is intentionally no automatic retry. The API does not yet accept an
idempotency key, so a timeout or lost response is ambiguous and retrying could
create a duplicate sale. A `needs_review` sale can be retried once from
Confirmed Orders only after the operator confirms ("I verified — Retry") that
it is absent from the backend.

When Offline Mode is on or the device has no internet, the offline-first path
saves the sale and marks it `needs_review` without sending it.

## Online-first mode (`OFFLINE_FIRST_SALES` app setting)

The tenant app setting `OFFLINE_FIRST_SALES` selects the mode, read through
`AppSettingsProvider.saleConfirmationMode`:

| Setting | Mode |
| --- | --- |
| row missing, status true, or settings not loaded | offline-first (described above) |
| status false | online-first |

Online-first uses the same coordinator, snapshot and outbox, but the confirm
button waits (with its loading state) for the one API attempt:

1. No internet, Offline Mode or no login → error; nothing is saved and the
   cart is unchanged.
2. Save the snapshot and outbox record exactly as offline-first does, so a
   crash mid-request is still recovered as `needs_review` on restart.
3. Send the request and wait for it.
4. `synced` → clear the cart, refresh post-sync caches, then print.
5. `rejected` (400/422) → discard the outbox record and the local snapshot;
   show the server message; the cart is unchanged so the cashier can fix it.
6. Ambiguous (timeout, 5xx, unreadable response) → clear the cart so it cannot
   be confirmed twice, do **not** print, and keep the sale as `needs_review`
   in Confirmed Orders.

## Shared code versus surface adapters

| Layer | Location | Responsibility |
| --- | --- | --- |
| Canonical request | `lib/models/order_submission_payload.dart` | One create/update API field mapping for every surface |
| Transaction boundary | `lib/services/local_first_sale_coordinator.dart` | Enforces persist → outbox → clear → print → one background attempt |
| Durable outbox | `lib/services/local_sale_sync_service.dart` | App-scoped request ownership, Hive state and result classification |
| Local sale repository | `LocalProductProvider` confirmed orders | Durable receipt/review snapshot and local stock/cart hand-off |
| Surface adapter | Desktop, mobile or restaurant page/controller | Reads that UI's state, validates it, saves its snapshot and supplies its print callback |
| Status UI | `lib/screens/sales/confirmed_orders.dart` | Shows queued, sending, synced, rejected or needs-review beside each local sale |

A new billing surface must write only a thin adapter around
`LocalFirstSaleCoordinator`. It must not reimplement HTTP timing, outbox state,
retry policy or sync-result classification.

## Live surface status

| Surface | Final-sale path | Status |
| --- | --- | --- |
| Supermarket desktop | `features/billing/presentation/pages/billing_page.dart` | Uses shared local-first coordinator |
| Responsive/mobile billing | `services/checkout_service.dart` | Uses shared local-first coordinator |
| Restaurant counter billing | `screens/billing/restaurant/widgets/order_panel.dart` | Uses shared local-first coordinator |
| Attender existing-order confirmation | same `OrderPanel`, attender route configuration | Uses shared local-first coordinator and existing update-order API |
| Kiosk | `screens/kiosk/*` | Development-only; its cart is still server-backed, so it is not declared offline-capable |

`Send to Kitchen` remains a kitchen-order operation, not a confirmed sale. It
must not appear as completed revenue or deduct a customer's final balance. A
future offline KOT outbox can reuse the outbox mechanics but needs separate KOT
conflict and table-order rules.

The old `billing_page_restaurant.dart` is not the live responsive/sidebar
restaurant route. The live route uses `RestaurantPage` and `OrderPanel`.

## Field contract

The canonical create request preserves:

- product, quantity, price, MRP, stock, variant and item comment data;
- customer ID and phone;
- transaction number;
- single or multiple payment methods and amounts;
- balance and allocate-to-customer-credit intent;
- coupon, flat discount, percentage discount and calculated discount;
- order comment and status;
- delivery method, date, time, car number and delivery charge;
- delivery address, saved address ID and pincode;
- table ID;
- quotation ID;
- active store ID and source type.

The local confirmed-order snapshot additionally preserves receipt/customer
metadata that is not part of the current create-order API: customer name/type,
alternate phone, VAT number, CR number and quotation number.

For an attender/restaurant order that already exists on the server, the shared
model emits the exact existing `update-order` body. Address ID/pincode and items
remain in the local audit/receipt snapshot, but are not added to that request
because the current update API does not accept them. This keeps the migration
API-compatible.

## Post-sale side effects

The local cart and stock reservation are committed before network sync so the
cashier can continue billing immediately. Server-authoritative customer
balance, credit ledger, loyalty, server stock and reporting are refreshed only
after a verified successful sync. They are not applied optimistically a second
time in a page widget.

The receipt may show the predicted old/current customer balance calculated from
the immutable local sale. The API payload remains the source of truth for the
actual credit/balance mutation.

## Status meanings

| State | Meaning |
| --- | --- |
| `queued` | Durable locally; the first attempt has not started |
| `sending` | The one API attempt is in progress |
| `synced` | A verifiable success response was received |
| `rejected` | The server clearly rejected the request (for example 400/422) |
| `needs_review` | The outcome is ambiguous, credentials were unavailable, or the app stopped before verification |

Unsynced/rejected/needs-review local sales cannot be deleted from Confirmed
Orders. This preserves the audit trail.

## Legacy Orders to review page

No newly migrated sale writes to `OrderSubmissionCoordinator`. The existing
**Orders to review** page is retained only so installations with historical
ambiguous records from older builds do not lose their audit/reconciliation
screen. It can be removed after a release migration proves that the legacy
`order_submissions` box has no unresolved records. New sync status belongs in
**Confirmed Orders**.

## Verification

Contract and lifecycle coverage lives in:

- `test/order_submission_payload_test.dart`
- `test/local_first_sale_coordinator_test.dart`
- `test/local_sale_sync_service_test.dart`
- `test/local_product_provider_hive_persistence_test.dart`

The tests cover every request field, create versus update contracts, disk-first
ordering, print failure, outbox write rollback, one-attempt behavior, process
restart classification and background completion independent of the initiating
adapter.
