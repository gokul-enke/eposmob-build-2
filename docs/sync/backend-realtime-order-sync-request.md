# Backend Request — Include Orders in POS Realtime Sync

Hi Backend Team,

The Flutter POS has successfully tested the existing Laravel Reverb flow for
customers, products, and stocks. We would also like **orders** to use the same
realtime notification and catch-up mechanism.

This request does not require sending complete order data through Reverb.
Reverb should remain a small “something changed” notification, while
`/api/v1/sync/changes` remains the authoritative source of changed IDs.

---

## Requested contract

### Channel and event

Please reuse the existing company channel and event:

```text
Channel: private-company.{companyId}.sync
Event:   data.changed
```

When an order changes, broadcast a payload such as:

```json
{
  "entity": "order",
  "action": "updated",
  "id": 1001,
  "company_id": 2,
  "store_id": 5,
  "changed_at": "2026-07-29T08:00:00+00:00"
}
```

Please use the exact entity value:

```text
order
```

Flutter's raw Pusher client receives the literal event name:

```text
data.changed
```

The `.data.changed` notation is only for Laravel Echo listeners.

---

## Include orders in `/sync/changes`

Please extend:

```http
GET /api/v1/sync/changes?since={ISO8601}&store_id={activeStoreId}
X-Tenant: {companyApiKey}
```

Expected response:

```json
{
  "success": true,
  "synced_at": "2026-07-29T08:00:02+00:00",
  "changes": {
    "customers": {
      "upserted": [],
      "deleted": []
    },
    "products": {
      "upserted": [],
      "deleted": []
    },
    "stocks": {
      "upserted": [],
      "deleted": []
    },
    "orders": {
      "upserted": [1001],
      "deleted": []
    }
  }
}
```

Meaning:

- `orders.upserted`: orders created or updated after `since`;
- `orders.deleted`: soft-deleted order IDs after `since`;
- cancelled orders should normally be in `upserted`, because cancellation is a
  status change and Flutter must fetch the latest order state.

Please always return the `orders` object, even when both arrays are empty. This
keeps the API response shape stable.

---

## Changes that should trigger order synchronization

Please broadcast and include the order ID when any POS-relevant order state
changes, including:

- order created;
- order updated;
- order confirmed;
- order cancelled;
- payment status changed;
- fulfillment/order status changed;
- order soft-deleted;
- order restored;
- order item added;
- order item updated;
- order item removed;
- item quantity, price, tax, discount, comment, or status changed;
- customer, table, delivery, payment, or store assignment changed.

If child model changes do not automatically update `orders.updated_at`, please
either:

1. touch the parent order when an order item/payment/status record changes; or
2. observe those child models and emit the parent `order_id`.

The parent order must appear in `orders.upserted` after any relevant child
change.

Please avoid duplicate event storms where possible. Multiple related model
updates inside one transaction may emit one final order notification after the
transaction commits.

---

## Company and store isolation

Order changes must be restricted to the authenticated tenant.

Please ensure:

- `X-Tenant` is mandatory;
- a tenant can only read its own order IDs;
- broadcast auth only permits the matching company channel;
- order pulls are filtered by the active `store_id`;
- the event includes `store_id` when the order belongs to a store.

The channel can remain company-wide. Flutter can ignore an event for another
store when `store_id` is included, but `/sync/changes` and the order-fetch
endpoint must still enforce store filtering.

Expected authorization behavior:

```text
Missing X-Tenant                         -> 401
Invalid X-Tenant                         -> 401
Valid tenant, matching company/store     -> success
Valid tenant, another company's channel  -> 403
Valid tenant, unauthorized store         -> 403 or empty scoped result
```

---

## API for fetching changed orders

`/sync/changes` returns IDs, so Flutter also needs an authoritative way to fetch
the corresponding complete orders.

Preferred option:

```http
GET /api/v1/orders?ids=1001,1002&store_id=5
Authorization: Bearer {accessToken}
X-Tenant: {companyApiKey}
Accept: application/json
```

The response should include all information needed to update the POS order
list, including:

- order ID and order number;
- company and store IDs;
- customer;
- order status;
- payment status and payment information;
- totals, taxes, discounts, delivery charges, paid amount, and balance;
- table/dining/delivery information where applicable;
- timestamps;
- order items and their current statuses.

If a bulk-by-ID endpoint cannot be added now, please confirm which existing
order-list/detail endpoint Flutter should call after `orders.upserted` is
non-empty. Flutter can temporarily refresh the full active-store order list,
but bulk-by-ID fetching is preferred.

---

## Cursor correctness

Please use the same stable server watermark as the existing entities:

```text
since < changed_at <= synced_at
```

Recommended sequence:

1. capture a server-side cutoff;
2. query changes after `since` and at or before the cutoff;
3. return that exact cutoff as `synced_at`.

Flutter will save `synced_at` only after the changed orders have been applied
successfully.

For soft deletes, use `deleted_at` or a durable tombstone/change-log record. If
orders can be hard-deleted, a tombstone is required so offline POS devices can
discover the deletion later.

---

## Transaction and broadcast timing

Please dispatch the realtime event only after the database transaction commits.
This prevents Flutter from receiving `data.changed` and pulling an order before
the final order/items/payment state is committed.

The backend must keep both services running:

```text
php artisan reverb:start
php artisan queue:work
```

Queued broadcast failures should be monitored and retryable. Even if a socket
message is missed, the order must still be discoverable through the next
`/sync/changes` catch-up request.

---

## Acceptance tests

Please verify the following against one company and store:

1. Subscribe to `private-company.{companyId}.sync`.
2. Create an order.
   - Receive `data.changed` with `entity: order`, `action: created`.
   - `/sync/changes` contains the order ID in `orders.upserted`.
3. Update the order.
   - Receive `action: updated`.
   - The order ID is returned in `orders.upserted`.
4. Add/update/remove an order item.
   - The parent order ID is returned in `orders.upserted`.
5. Change order status.
   - The order ID is returned in `orders.upserted`.
6. Change payment status.
   - The order ID is returned in `orders.upserted`.
7. Cancel an order.
   - The order ID is returned in `orders.upserted` with its latest status.
8. Soft-delete an order.
   - The order ID is returned in `orders.deleted`.
9. Disconnect the client, modify several orders, reconnect, and pull from the
   previous `synced_at`.
   - All missed order changes are returned.
10. Make a change in another company/store.
    - It must not appear in the current tenant/store result.

---

## Flutter behavior after backend support

Once `orders` is present in `/sync/changes`, Flutter will:

```text
Receive data.changed
        |
        v
Call /sync/changes using last synced_at
        |
        v
Check whether orders.upserted or orders.deleted is non-empty
        |
        v
Fetch changed orders or refresh the active-store order list
        |
        v
Update the order Provider/UI
        |
        v
Persist the new synced_at after success
```

Flutter will not trust the socket payload as the complete order record.

---

## Summary of backend work

Please add:

- order observation/broadcast through the existing `data.changed` event;
- `orders.upserted` and `orders.deleted` in `/sync/changes`;
- parent-order tracking for order-item/payment/status changes;
- company and store filtering;
- post-transaction event dispatch;
- changed-order fetch support, preferably bulk by ID;
- automated tests for auth, cursor recovery, updates, cancellation, and
  deletion.

Please also confirm the exact existing order endpoint Flutter should use for
fetching the complete changed records.
