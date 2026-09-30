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

There is intentionally no automatic retry. Every request carries a
`client_sale_id` (see [Sale identity](#sale-identity)), and `add-to-order`
returns the existing order when it sees that ID again, so a repeated send does
not create a duplicate. Retries still stay manual: an operator decides, from
**Sales → Confirmed Orders**, whether and when a sale is sent again (see
[Operator actions](#operator-actions-in-confirmed-orders)).

When Offline Mode is on or the device has no internet, the offline-first path
saves the sale and marks it `needs_review` without sending it.

## Online-first mode (`POS_OFFLINE_SALES` app setting)

The tenant app setting `POS_OFFLINE_SALES` selects the mode, read through
`AppSettingsProvider.saleConfirmationMode`:

| Setting | Mode |
| --- | --- |
| row missing, status true, or settings not loaded | offline-first (described above) |
| status false | online-first |

Online-first uses the same coordinator, snapshot and outbox, but the confirm
button waits (with its loading state) for the one API attempt:

1. No internet or Offline Mode → the sale falls back to offline-first (saved,
   cart cleared, printed, `needs_review`), so the till keeps selling. No login
   while online → error; nothing is saved, the cart is unchanged and the
   already-issued bill number is skipped.
2. Save the snapshot and outbox record exactly as offline-first does, so a
   crash mid-request is still recovered as `needs_review` on restart.
3. Send the request and wait for it.
4. `synced` → clear the cart, refresh post-sync caches, then print. The
   receipt shows the backend order number (`order_number` from the response)
   instead of the local bill number; if the response has none, the bill
   number is printed. Offline-first receipts always show the bill number,
   because they print before the server answers.
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
| Sale identity | `lib/services/receipt_identity_service.dart` | Issues the bill number and `client_sale_id` before the sale is saved |
| Status UI | `lib/screens/sales/confirmed_orders.dart` | Lists sales that still need attention, with Retry, Log and Remove |
| Attempt log UI | `lib/screens/sales/widgets/local_sale_sync_log_dialog.dart` | Shows each attempt's exact request and response |

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

Going offline does not change the buttons' path: mobile shows the same Confirm
actions, and the restaurant's offline button and F2/F5/F6/F10 shortcuts open
the same confirm checkout (offline, a table or delivery order can also be
confirmed from the counter panel). The old **Save & Print** was removed from
every live surface: it put a `CONF-…` sale in Confirmed Orders with no request,
so it could never sync. **Save Order** (F8) still parks a draft; desktop F9 now
only points the cashier to Confirm & Print.

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
- active store ID and source type;
- sale identity: `client_sale_id`, `receipt_number` (the bill number),
  `issued_at`, `pos_device_id` and `counter_number`.

The local confirmed-order snapshot additionally preserves receipt/customer
metadata that is not part of the current create-order API: customer name/type,
alternate phone, VAT number, CR number and quotation number.

For an attender/restaurant order that already exists on the server, the shared
model emits the exact existing `update-order` body. Address ID/pincode and items
remain in the local audit/receipt snapshot, but are not added to that request
because the current update API does not accept them. This keeps the migration
API-compatible.

## Sale identity

Before the sale is saved, `ReceiptIdentityService` issues two values:

| Value | Example | Purpose |
| --- | --- | --- |
| Bill number (`receipt_number`) | `2-01-260929-0002` | For people: printed on the bill, shown as **Bill No.**, searchable |
| `client_sale_id` | UUIDv7 | For the system: the backend's duplicate-protection key |

The bill number format is `store-counter-YYMMDD-dailySequence`:

- **store:** the active store's backend ID.
- **counter:** set per store in **Settings** (defaults to `01`). Every device
  in the same store must use a different counter number, otherwise two devices
  issue the same bill number and the backend rejects the second with 409.
- **date:** in the configured business time zone.
- **sequence:** starts at `0001` each day for each store and counter. It is
  saved before use, so a number is never issued twice, but gaps are expected
  (a failed or rejected confirmation skips a number).

The sequence lives only on the device. A reinstall or cleared app data restarts
it at `0001`, which clashes with bills already sold that day (the backend
answers 409). To resume, open **Settings → POS Counter Identity**, look up the
counter's last bill today in the admin panel and enter its last digits in
**Last bill sold today**. The dialog shows the last bill this device issued
today and the next bill number. The sequence can only be raised, never
lowered, so this cannot cause duplicates.

The API field is `receipt_number`. It is unrelated to the Receipts (payment
voucher) module's `receipt_number`; the UI calls it **Bill No.** to avoid that
confusion. The backend order number (`ORD-…`) is kept separately and shown as
**Order No.**

On the backend, `add-to-order` locks on `client_sale_id` before doing any work:

- the same ID with the same payload returns the original order
  (`idempotent_replay: true`);
- the same ID with a different payload is refused with 409;
- a unique index per company guards against two sends racing.

## Operator actions in Confirmed Orders

**Sales → Confirmed Orders** lists only sales that are not `synced` and not
removed. Each card has:

| Action | Available for | What it does |
| --- | --- | --- |
| **Review & retry** | `needs_review` | After the operator confirms "I verified — Retry" that the sale is absent from the backend, sends the stored request once more |
| **Retry** | `rejected` | Sends the same stored request once more. The cause (for example stock) must be fixed on the backend first, or it is rejected again |
| **Log (N)** | every sale with a sync record | Opens the attempt log |
| **Remove** (bin icon) | `needs_review`, `rejected` | Hides the sale after the operator ticks a confirmation (for example "this order is already in the admin panel"). Nothing is deleted and the sale is never sent again |

A retry sends the stored request body unchanged. Its endpoint follows the
sale's operation, not the page:

| Operation | Endpoint |
| --- | --- |
| New sale (desktop, mobile, restaurant counter) | `POST /api/v1/order/add-to-order` |
| Attender confirming an existing order | `POST /api/v1/order/update-order` |

A removed sale keeps its state and log, plus `dismissed_at` and
`dismiss_note`. There is no screen that lists removed sales yet.

## Attempt log

Every server attempt is appended to the sale's outbox record (`attempts`) and
kept across restarts. Earlier attempts are never replaced.

| Field | Meaning |
| --- | --- |
| `number` | Attempt count, starting at 1 |
| `started_at`, `finished_at` | UTC times |
| `endpoint` | The URL that was called |
| `request_body` | The exact JSON body sent; stored before the request so a crash still keeps it |
| `http_status` | Response status, when a response arrived |
| `response_body` | Raw response body, cut at 100,000 characters |
| `error` | Why no response arrived: timeout, connection error, or the app closed mid-request |
| `outcome` | `synced`, `rejected` or `needs_review` |

The `Authorization` token and `X-Tenant` key are never stored. The log dialog
pretty-prints JSON and can copy each body or the whole record.

A successful (`synced`) attempt keeps only the first 2,000 characters of its
response; rejections and failures keep up to 100,000.

Each attempt also prints to the console (`[LocalSaleSync]` lines): the URL,
bill number and attempt number, the request body, then the status, time,
outcome and response. Bodies are cut at 1,000 characters.

## Retention

On app start, synced sales last updated more than 30 days ago
(`LocalSaleSyncService.syncedRetention`) are deleted: both the outbox record
with its attempt log and the local confirmed-order snapshot. `needs_review`,
`rejected`, removed, `queued` and `sending` sales are never deleted. The
cleanup runs after the leftover-cart check and never blocks startup. Lower the
retention to 7 days once production is stable.

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

Unsynced local sales are never deleted from Confirmed Orders. A `needs_review`
or `rejected` sale can only be **removed**, which hides it but keeps the sale,
its state and its attempt log on the device for audit. `queued` and `sending`
sales cannot be removed.

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
- `test/sale_confirmation_mode_setting_test.dart`
- `test/receipt_identity_service_test.dart`
- `test/sales_receipt_identity_model_test.dart`
- `test/sales_return_receipt_number_test.dart`

The tests cover every request field, create versus update contracts, disk-first
ordering, print failure, outbox write rollback, one-attempt behavior, process
restart classification, background completion independent of the initiating
adapter, online-first outcomes, the `POS_OFFLINE_SALES` setting, bill number
issuing, the attempt log, retrying rejected sales, removing sales, the
update-order endpoint on retry, and Bill No. on Sales Return.
