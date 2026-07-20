# Fast Confirm Order + Reliable Background Sync Plan

> **Goal:** Reduce the cashier's perceived Confirm Order time from approximately 10 seconds to less than 1 second, while ensuring that temporary API failures do not lose orders.
>
> **Scope:** This is the first practical phase. It does **not** attempt to solve complete multi-terminal offline inventory coordination yet.

## 1. Project Manager Overview

### 1.1 The problem in simple terms

Today, the cashier presses **Confirm Order**, and the application waits for the complete backend operation before clearing the billing screen. The backend currently performs several expensive operations before returning a response. If any network or server error occurs, the cashier sees a failure even when some server-side work may already have completed.

This causes two business problems:

1. The cashier waits around 10 seconds for a normal order.
2. During development or temporary network problems, the order can appear to fail and the cashier may not know whether it was actually created.

### 1.2 Recommended business behavior

The cashier should receive an immediate local acknowledgement:

```text
Order saved locally
Sync pending
```

The application then sends the order to the backend in the background.

The order will have these statuses:

| Status | Meaning |
|---|---|
| `pending_sync` | Saved safely on the POS, waiting for the backend |
| `syncing` | Currently being sent |
| `synced` | Backend accepted the order |
| `retry` | Temporary failure; will be sent again |
| `failed` | Permanent validation/business failure; needs attention |
| `conflict` | Backend detected a duplicate or stock/business conflict |

The admin panel may see an order slightly later. This is acceptable for this phase, but the POS must never silently lose the local order.

### 1.3 The new user experience

```text
Cashier presses Confirm
        |
        |-- Local validation
        |-- Save complete order payload locally
        |-- Save pending-sync record locally
        |-- Clear billing screen immediately
        |-- Print from local order snapshot if required
        |
        `-- Background sync sends the order to the backend
                 |
                 |-- Success: mark synced and store server order number
                 |-- Timeout/500: retry automatically
                 |-- 400/422: mark failed and show the reason
```

The target is that local persistence and screen reset complete in under one second. The backend request is no longer part of the cashier's critical UI path.

### 1.4 What will change

#### Backend

- Return a small order acknowledgement instead of building the full order-details response inside the create-order request.
- Add a unique `client_order_id` and idempotency protection.
- Ensure retries cannot create duplicate orders.
- Move non-critical invoice, receipt, notification, and detailed response work out of the critical request path where safe.
- Improve stock updates so concurrent requests cannot silently oversell.

#### Frontend

- Add a durable local pending-order/outbox record.
- Save the exact API payload before clearing the UI.
- Send pending orders from a background sync service.
- Retry temporary failures with backoff.
- Preserve permanent failures for manual review instead of deleting them.
- Print from the local order snapshot instead of waiting for a second order-details API call.
- Route desktop, mobile, and restaurant checkout through one submission service.

### 1.5 What is deliberately not included now

This phase will not implement:

- A local shop server/hub.
- Fully shared offline inventory between multiple terminals.
- Unlimited offline customer credit.
- Offline card/UPI payment processing unless the payment terminal explicitly supports it.

If multiple terminals are disconnected from the backend at the same time, exact stock consistency still requires a later stock-lease or local-shop-authority design. The immediate objective is fast confirmation and lossless retry.

### 1.6 Delivery phases

#### Phase A — Measure and reduce normal online latency

- Add timing logs around the mobile request, backend transaction, receipt creation, and order-details building.
- Remove the expensive order-details payload from the create-order response.
- Return only `order_id`, `order_number`, `client_order_id`, and status.
- Move local printing and UI reset away from the backend response.

#### Phase B — Add safe retry identity

- Generate a unique `client_order_id` on the POS.
- Persist it with the order payload.
- Add backend uniqueness and idempotency handling.
- Verify that repeating the same request returns the original order.

#### Phase C — Add local outbox

- Persist the order and pending-sync record locally before clearing the screen.
- Start background synchronization immediately after the local commit.
- Add retry, failure, and pending-order visibility.

#### Phase D — Later multi-terminal inventory decision

After observing real shop usage, choose either server-online inventory, stock leases, or a local shop hub. This should be a separate project decision and should not delay the fast-confirm work.

### 1.7 Success criteria

The implementation is successful when:

- The billing screen resets in less than one second after Confirm.
- A timeout after a successful server commit does not create a duplicate order.
- Restarting the application does not lose pending orders.
- Temporary failures retry automatically.
- Validation failures remain visible with an actionable reason.
- The admin panel eventually receives every valid order.
- The cashier can identify whether an order is pending, synced, failed, or conflicted.

## 2. Backend Developer Implementation

### 2.1 Existing backend path and request flow

Backend repository:

```text
C:\Users\gokul\Desktop\Projects\Enke\eposmob\enkepos
```

Current route:

```text
routes/api/OrderRoutes.php:8
POST /api/v1/order/add-to-order
App\Http\Controllers\Api\V1\OrderController@add_to_order
```

Current controller flow is in:

```text
app/Http/Controllers/Api/V1/OrderController.php:198
```

The current request does approximately the following:

1. Starts a database transaction.
2. Gets or creates the customer.
3. Calls `CartService::addMultipleToCart()`.
4. Retrieves the active cart.
5. Validates payment/coupon data.
6. Creates or updates the order.
7. Adjusts stock.
8. Stores order properties.
9. Handles quotation conversion if applicable.
10. Commits the transaction.
11. Creates receipts after commit.
12. Calls `getOrderDetails()`.
13. Returns a large nested response containing products, attachments, category, customer, transactions, loyalty data, returns, payment information, and invoice data.

The expensive final step is especially important:

```text
OrderController.php:2837 - getOrderDetails()
```

It loads many nested relationships and also performs additional lookups while mapping every cart item. The mobile application then fetches order details again for the print flow, so the current path can perform duplicate work.

### 2.2 Immediate latency fix

Change the successful `add_to_order` response to a small acknowledgement:

```json
{
  "status": "accepted",
  "order_id": 12345,
  "order_number": "INV-2026-000123",
  "client_order_id": "01HT...",
  "sync_status": "synced"
}
```

Do not include `order_details` in this response.

Keep the existing order-details endpoint for screens that explicitly need full details:

```text
GET /api/v1/order/executive/order-details/{order_number}
```

The order creation endpoint should acknowledge the committed order as soon as the required order, stock, and financial records are complete.

### 2.3 Profile before moving work

Add structured timing logs using the `client_order_id` or a request ID:

```text
order_request_total_ms
customer_ms
cart_items_ms
stock_ms
order_create_ms
invoice_observer_ms
receipt_ms
order_details_ms
```

The likely latency sources are:

- `CartService::addMultipleToCart()` performs product, stock, tax, unit, and cart-item work for every line.
- `OrderObserver::created()` calls `OrderHelper::handleOrderCreated()` synchronously for confirmed orders.
- `OrderController::add_to_order()` creates receipts before responding.
- `getOrderDetails()` loads a large relationship graph and builds a very large response.
- The response is JSON-encoded and transmitted even though Confirm only needs the order ID and number.

Do not guess which step is slow. Measure it in development and production-like data.

### 2.4 Idempotency and duplicate protection

The frontend will retry requests after timeouts. A timeout does not prove that the server rolled back; the server may have committed successfully before the response was lost.

Add these request fields:

```json
{
  "client_order_id": "stable-unique-id-generated-by-the-device",
  "device_id": "stable-installation-id",
  "client_created_at": "2026-03-08T10:42:12Z",
  "payload_version": 1
}
```

Also accept:

```http
Idempotency-Key: <client_order_id>
```

Recommended first migration:

```text
orders.client_order_id      nullable string
orders.device_id            nullable string
orders.client_created_at    nullable timestamp
orders.client_payload_hash  nullable string
```

Add a unique index scoped to the tenant/company:

```text
unique(company_id, client_order_id)
```

A dedicated `order_idempotency_keys` table is preferable later if request lifecycle tracking is needed, but order columns are sufficient for the first implementation.

#### Important ordering requirement

The idempotency lookup must happen **before** `CartService::addMultipleToCart()`.

Currently `CartService::createOrRetrieveCart()` can reuse an active cart for the same customer/store/source. If a background retry adds the same items before duplicate detection, quantities can be merged into the cart again.

Required behavior:

1. Read `client_order_id`.
2. Find an existing order before mutating any cart.
3. If found and the payload hash matches, return the original result.
4. If found and the payload hash differs, return `409 Conflict`.
5. If not found, create an isolated cart/order flow.

For queued orders, do not reuse the normal active cart. Add `client_order_id` to the cart or create a dedicated cart for that client order. This prevents multiple pending orders from the same customer and terminal from merging into one server cart.

### 2.5 Response and error contract

Use clear HTTP behavior:

| Situation | HTTP status | Frontend behavior |
|---|---:|---|
| New order committed | `201` | Mark synced |
| Same idempotency key, same payload | `200` | Mark synced with original order |
| Same key, different payload | `409` | Mark conflict; do not retry automatically |
| Validation/business error | `422` | Mark failed; show message |
| Authentication error | `401/403` | Pause sync and request login |
| Temporary server/database error | `500/503` | Retry with backoff |
| Network timeout | No response | Retry with same key |

Return structured errors:

```json
{
  "status": "failed",
  "code": "INSUFFICIENT_STOCK",
  "message": "Insufficient stock for Product A",
  "retryable": false,
  "client_order_id": "01HT..."
}
```

The current controller catches exceptions and returns a generic `500`. Preserve a safe user-facing message and a machine-readable error code.

### 2.6 Move non-critical work out of the response path

The following work should be evaluated for an after-commit job:

- Full order-details building.
- Admin notification creation.
- Track-order/event side effects.
- Invoice generation if business rules allow it to be eventually completed.
- Receipt creation if the order can safely be shown as payment-pending until the receipt job completes.

`app/Observers/OrderObserver.php` currently performs confirmed-order side effects synchronously from the `created()` event. If these are moved to a job, make the job idempotent as well:

```text
OrderSideEffectsJob(order_id)
```

The job must check whether the invoice/receipt already exists before creating it. It must use `afterCommit()` or equivalent behavior so it cannot run against a transaction that later rolls back.

Do not move required financial correctness out of the transaction without explicitly changing the order status model. If invoice creation must remain synchronous, keep it in the transaction but remove `getOrderDetails()` and measure again first.

### 2.7 Stock correctness

Current executive stock adjustment is in:

```text
OrderController.php:458 - adjustStockForExecutive()
```

It reads quantities and updates stock rows without `lockForUpdate()`. It clamps quantities to zero instead of returning a clear insufficient-stock failure. `Helper::adjustStock()` has similar read-then-save behavior in:

```text
app/Helper/Helper.php:243
```

For the immediate fast-sync phase:

- Preserve current behavior only if the business accepts temporary oversell risk.
- Add timing and stock logs.
- Add a separate task to make stock deduction atomic.

The correct later implementation should:

1. Lock all relevant stock rows in a stable order.
2. Recalculate availability inside the transaction.
3. Reject the order with `409` if stock is insufficient, or apply an explicitly approved oversell policy.
4. Write stock movement/ledger records linked to `order_id` and `client_order_id`.
5. Make the stock adjustment idempotent.

### 2.8 Backend tests

Add feature tests for:

1. Successful order returns a small response without `order_details`.
2. Same `client_order_id` submitted twice creates one order only.
3. Same key with a different payload returns `409`.
4. Idempotency check happens before cart mutation.
5. Two pending orders do not share the same active cart.
6. A temporary `500` can be retried safely.
7. A validation failure returns `422` and a stable error code.
8. Concurrent sales cannot reduce stock below the approved policy.
9. Invoice/receipt jobs are not duplicated.
10. The endpoint's p95 response time meets the agreed target, preferably below one second for normal order sizes.

## 3. Frontend Developer Implementation

### 3.1 Current frontend paths to cover

The main desktop flow is:

```text
lib/features/billing/presentation/pages/billing_page.dart:6824
_confirmOrder()
```

The API method is:

```text
lib/providers/cart_provider.dart:860
addToOrderAPI()
```

The current local Hive provider is:

```text
lib/providers/local_product_provider.dart
```

The existing general `SyncProvider` is:

```text
lib/providers/sync_provider.dart
```

It currently synchronizes catalog/reference data and does not upload pending orders.

Also audit these flows so they do not bypass the new service:

```text
lib/services/checkout_service.dart
lib/screens/billing/billing_page_restaurant.dart
lib/screens/billing/restaurant/widgets/order_panel.dart
lib/features/billing/presentation/pages/billing_page_mobile.dart
```

All Confirm, Confirm & Print, mobile, desktop, and restaurant paths should eventually use one order-submission service.

### 3.2 Add a local pending-order record

Use Hive for the first implementation because the application already initializes Hive and has local order models. Do not introduce a large database migration in the first speed fix unless Hive proves insufficient.

Create a dedicated pending-order/outbox model rather than mixing it with user drafts:

```text
PendingOrderRecord

id
clientOrderId
deviceId
storeId
payloadJson
payloadHash
localReceiptNumber
status
attemptCount
nextAttemptAt
lastError
createdAt
syncedAt
serverOrderId
serverOrderNumber
```

Use a dedicated box, for example:

```text
pending_order_outbox
```

The record must contain the exact payload that will be sent to the backend. It must not depend on the current cart after the cashier has started the next order.

### 3.3 Local confirm algorithm

Implement a service such as:

```text
lib/features/billing/data/order_outbox_repository.dart
lib/features/billing/services/order_sync_service.dart
lib/features/billing/services/local_order_submission_service.dart
```

The local confirm operation should be:

```text
1. Prevent duplicate button taps.
2. Validate cart and payment locally.
3. Build the final API payload.
4. Generate clientOrderId.
5. Persist PendingOrderRecord and payload.
6. Wait for the local write to complete.
7. Clear the cart/reset the billing workspace.
8. Show "Order saved locally; sync pending".
9. Print from the local snapshot if requested.
10. Start sync without awaiting it.
```

The screen must not be cleared before step 5 succeeds.

The local persistence write must be awaited. Existing cart persistence uses an asynchronous queue in `LocalProductProvider`, but the new pending-order write must expose a `Future` so the application knows that the order is durable before showing success.

### 3.4 Background sync behavior

Create one sync worker for pending orders. Do not add order uploading into the existing catalog-only `SyncProvider` unless the responsibilities are deliberately separated. A dedicated `OrderSyncProvider` or `OrderSyncService` is clearer.

Sync triggers:

- Immediately after enqueue.
- Application startup.
- App foreground/resume.
- Connectivity restored.
- A short timer while the application is active.
- Manual Retry button.

Only one worker may process a given record at a time.

Recommended retry policy:

```text
attempt 1: immediately
attempt 2: 2 seconds
attempt 3: 5 seconds
attempt 4: 15 seconds
then: exponential backoff with a maximum delay
```

Use the same `client_order_id` and request payload on every retry.

### 3.5 Classify responses correctly

The API client should stop returning untyped generic maps for order submission. Introduce a typed result such as:

```dart
class OrderSyncResult {
  final bool accepted;
  final bool retryable;
  final String? code;
  final String? message;
  final int? serverOrderId;
  final String? serverOrderNumber;
}
```

Behavior:

- `201/200`: mark `synced`.
- Timeout/socket error/`500/503`: keep `retry`.
- `401/403`: pause the worker until authentication is restored.
- `422`: mark `failed`; preserve the payload and show the backend reason.
- `409`: mark `conflict`; do not blindly retry.

Never delete a pending record on an exception.

### 3.6 Make Confirm & Print fast

Current desktop `billing_page.dart:6474` performs an order-details fetch after order creation before printing. The new flow should print from the local order snapshot:

```text
Local cart/order snapshot -> receipt printer
```

The server order-details request can happen later for reconciliation or history. It must not block the cashier from starting the next order.

If printing fails, the order must remain synced/pending independently from the print retry state. Do not resend the order just because printing failed.

### 3.7 UI status and recovery

Add a small pending-sync indicator to the billing/offline data area:

```text
Pending orders: 3
Last sync: 10:42:15
```

For each pending order show:

- Temporary receipt number.
- Local creation time.
- Current sync state.
- Last error.
- Retry action.
- Server order number after successful sync.

The cashier should see different messages:

```text
Order saved locally. Sync will retry automatically.
Order synced successfully.
Order needs attention: insufficient stock.
Login required to synchronize this order.
```

Do not show “Order failed” when the actual problem is only a temporary network timeout.

### 3.8 Device identity and local IDs

Generate and persist a stable `device_id` once per installation. Generate a new unique `client_order_id` for every confirmed order. Do not use local sequential numbers such as `CONF-1`, because two devices can generate the same number.

Use a temporary local receipt number for printing, then replace/map it to the backend `order_number` after synchronization.

### 3.9 Avoid stale cart and customer state

The pending payload must be built from a snapshot at the time of Confirm. It must include:

- Items and quantities.
- Product/stock/variant IDs.
- Prices and discounts.
- Customer ID and phone snapshot.
- Payment method and amounts.
- Delivery details.
- Store ID.
- Operator/device ID.
- Client order ID.

Do not rebuild the payload later from `LocalProductProvider.cartItems`, because the cashier may already be working on another order.

### 3.10 Frontend tests

Add tests for:

1. Confirm creates one pending record.
2. Duplicate taps create one pending record.
3. The billing screen clears only after the pending record is durable.
4. The exact payload is restored after application restart.
5. A network timeout keeps the order pending.
6. A later retry marks the order synced.
7. Repeated successful responses do not create local duplicates.
8. A `422` response becomes a visible failed/conflict record.
9. Confirm & Print does not call order-details before printing.
10. Printing failure does not resend the order.
11. Desktop, mobile, and restaurant Confirm paths use the same submission service.
12. Pending orders are not lost when Hive boxes are closed or the app exits.

Run at minimum:

```text
flutter analyze
flutter test
php artisan test
```

### 3.11 Frontend implementation order

Implement in this order:

1. Add `client_order_id` to the payload and logging.
2. Add backend idempotency support.
3. Add the pending-order Hive model and repository.
4. Refactor one desktop Confirm path to use the repository.
5. Add background sync and retry UI.
6. Refactor mobile and restaurant paths to the same service.
7. Replace server-details printing with local snapshot printing.
8. Add restart, timeout, duplicate, and failure tests.

The first production-safe milestone is reached when one desktop Confirm path is lossless and fast. Other billing paths should then be migrated to the same service rather than implementing separate retry logic.
