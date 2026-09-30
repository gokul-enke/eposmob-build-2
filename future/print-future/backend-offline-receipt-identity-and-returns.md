# Backend change request: stable offline receipt identity and returns

## Why this change is required

The POS now confirms and prints a sale locally before the API request finishes.
The customer must therefore receive a receipt reference that exists **before**
the backend creates its normal order number.

The old local values such as `CONF-9` are not safe across multiple counters:
two devices can independently create the same value. They are also not useful
in the backend Sales search after the sale syncs.

The app now creates two permanent identifiers at confirmation time:

- `client_sale_id`: UUIDv7, for idempotency and exact machine lookup. This is
  not intended to be typed by a cashier.
- `receipt_number`: short customer-facing reference, for example
  `2-03-260916-0001`.

The receipt format is:

```text
storeId-counterNumber-YYMMDD-dailySequence
2-03-260916-0001
```

This is deliberately much shorter than a UUID. The app prints this reference
on the first offline receipt and must continue to show the same reference in
Sales, order details, reprints, returns and refunds. The backend may still
generate its existing order number such as `ORD-004645`; both values are kept.

## Request sent by the POS

The existing endpoints remain the same:

- `POST /api/v1/order/add-to-order`
- `POST /api/v1/order/update-order` for the existing restaurant/attender flow

Five additional fields are now included in the existing JSON body:

```json
{
  "client_sale_id": "01995643-7f83-7a21-9a4b-b8c26d9c7b61",
  "receipt_number": "2-03-260916-0001",
  "issued_at": "2026-09-16T04:14:00.000Z",
  "pos_device_id": "8f9ab152-e97a-46a8-83ab-4ea64b1261a1",
  "counter_number": 3,
  "items": [
    {
      "product_id": 123,
      "quantity": 1,
      "price": 5
    }
  ],
  "phone": "0011001100",
  "customer_id": 45,
  "transaction_number": "",
  "payment_method": ["CASH", "CREDIT"],
  "paid_methods": [
    {"method": "CASH", "amount": 3},
    {"method": "CREDIT", "amount": 2}
  ],
  "source_type": "executive",
  "balance": "2.0",
  "status": "confirmed",
  "delivery_charge": 0,
  "store_id": 2
}
```

The rest of the order body is unchanged. The item keys shown above are only an
example; the backend must continue accepting the current full item contract.

The shared identity contract is already used by desktop billing, mobile
billing, restaurant counter billing and attender confirmation. The repository's
current kiosk pages are presentation-only and do not yet submit production
orders; when kiosk checkout orchestration is enabled, it must call the same
local-first coordinator and identity service rather than creating a separate
numbering implementation.

## Required database fields and constraints

Add nullable fields to the orders table so old orders remain valid:

```text
client_sale_id   UUID/string nullable
receipt_number  string nullable
issued_at       UTC datetime nullable
pos_device_id   UUID/string nullable
counter_number  integer nullable
```

Required uniqueness:

```text
UNIQUE (company_id, client_sale_id)
UNIQUE (company_id, receipt_number)
```

If orders are tenant-isolated into separate databases, equivalent tenant-local
unique constraints are acceptable. Do not scope either constraint only by
store: a receipt must never resolve to two orders inside the same tenant.

Store `issued_at` as the immutable sale instant supplied by the device. Keep
the server creation time separately for audit and sync diagnostics.

## Idempotent add-to-order behaviour

`client_sale_id` must be the idempotency key for the sale.

1. On the first request, create the order normally and save all five fields.
2. If the same tenant sends the same `client_sale_id` again, do **not** create
   a second order and do **not** reapply stock, customer balance, payment,
   points or accounting effects.
3. Return HTTP 200 with the already-created order as a successful idempotent
   replay.
4. If the same `client_sale_id` arrives with a materially different payload,
   return HTTP 409 and log an audit event instead of mutating the first order.
5. Perform the idempotency lookup and order creation inside one database
   transaction protected by the unique constraint.

Apply the same replay protection to `update-order`: repeating the same
`client_sale_id` for the same existing order must return the already-confirmed
result without posting payment, stock, customer balance or ledger effects a
second time.

Recommended success response for both first submission and replay:

```json
{
  "status": "success",
  "data": {
    "orders_id": 6220,
    "order_number": "ORD-004645",
    "client_sale_id": "01995643-7f83-7a21-9a4b-b8c26d9c7b61",
    "receipt_number": "2-03-260916-0001",
    "issued_at": "2026-09-16T04:14:00.000Z"
  },
  "idempotent_replay": false
}
```

## Counter registration and validation

The current app stores a counter number per physical device and per store in
Settings. It also preserves the counter configuration and daily sequence when
the operator clears cached local data.

For a single counter, default counter `01` works. For multiple counters, each
device must be configured with a different number in the same store.

The durable production design should let the backend own this assignment. A
suggested endpoint is:

```text
PUT /api/v1/pos-devices/{pos_device_id}/counter
{
  "store_id": 2,
  "counter_number": 3
}
```

Enforce:

```text
UNIQUE (company_id, store_id, counter_number)
UNIQUE (company_id, pos_device_id, store_id)
```

The order endpoint should verify that `pos_device_id`, `store_id` and
`counter_number` match the registered assignment when registration is enabled.
Until that endpoint is available, accept these fields and use the order-level
unique constraints as the final collision protection.

Never reuse an old counter number without an audit trail. If a device is
replaced, retire the old device assignment and explicitly assign the number to
the replacement.

## Sales list and search

Current frontend request:

```text
GET /api/v1/order/executive/list-orders?number=<search text>&store_id=<id>
```

Change the existing `number` filter to search all of the following:

1. existing `order_number`, such as `ORD-004645`;
2. new `receipt_number`, such as `2-03-260916-0001`;
3. exact `client_sale_id` for support/debugging.

For `receipt_number`, accept exact and partial matching and normalize harmless
typing differences such as spaces and letter case. Hyphens should remain the
canonical displayed form. A document template may visually prepend its
configured invoice prefix (for example `PREFIX2-03-260916-0001`); when the
typed query begins with the tenant's configured prefix, strip that prefix and
match the remaining `receipt_number`. Apply the existing tenant and store
authorization before matching.

Each Sales list item must return:

```json
{
  "id": 6220,
  "order_number": "ORD-004645",
  "client_sale_id": "01995643-7f83-7a21-9a4b-b8c26d9c7b61",
  "receipt_number": "2-03-260916-0001",
  "issued_at": "2026-09-16T04:14:00.000Z"
}
```

The POS now labels the search box **Order or receipt number**, shows both the
backend order number and receipt reference in Sales, and copies the customer
receipt reference when available.

### Current integration validation (16 September 2026)

The Windows POS was tested against the current demo backend. A request carrying
the new identity fields was accepted and became backend order `ORD-004646`, but
the Sales list still displayed only that backend order number. It did not
surface the submitted customer receipt reference. The frontend model and UI do
display `receipt_number` when the list/detail response includes it, so the
backend team should verify that all five identity fields are persisted and
returned by both list-orders and order-details.

A separate manual-offline test produced receipt `2-01-260916-0002`. The sale
survived an application restart in the POS Sync attention queue and no API
request was started while Offline Mode was enabled. Searching the current
backend Sales list for this reference correctly returned no result because that
sale has not been submitted. After an operator-approved retry, the same search
must resolve the backend order; this is the required acceptance test for the
backend change.

## Sale order details and reprinting

Current frontend request:

```text
GET /api/v1/order/executive/order-details/{order_number}?store_id=<id>
```

The response must include `client_sale_id`, `receipt_number` and `issued_at` at
the top level of `data`, in addition to the existing `order_number`.

For compatibility, keep accepting the backend `order_number` in the path. It
is also useful to allow `receipt_number` in the same path, but Sales search can
first resolve the receipt to the backend order if changing this route is not
immediately possible.

The app uses `receipt_number` as the visible invoice number on online reprints
when it is present. This ensures the first offline print and a later Sales
reprint identify the same customer receipt. Old orders without the new field
continue to print `order_number`.

## Return and refund flow

The current cashier journey is:

1. Open **Sales**.
2. Type the number printed on the customer's bill into the search bar.
3. Open the matching sale order details.
4. Choose **Return Order** (or the relevant cancel/refund action).
5. The frontend then uses the resolved backend order ID and cart item IDs for
   the existing return APIs.

Current return endpoints used by the app:

```text
GET  /api/v1/order/list-return-order-items?order_number=<value>&store_id=<id>
POST /api/v1/order/sales-return
POST /api/v1/order/complete-return-order
POST /api/v1/order/cancel-order
```

Required behaviour:

- `list-return-order-items` should resolve `order_number`, `receipt_number` or
  exact `client_sale_id` in its existing `order_number` parameter.
- After lookup, returns/refunds must continue using the canonical backend
  `orders.id` and `cart_item_id`; do not create returns against a local string.
- Return records should retain `original_order_id` and, for audit/reporting,
  expose the original `receipt_number` and `client_sale_id` through the order
  relation or snapshot fields.
- Cancel/refund, stock restoration, customer balance reversal, payment
  reversal and tax/credit-note generation must execute only once, inside the
  existing transaction boundary.
- The order details response should include return state so another counter
  cannot return the same quantity twice.

## Important offline limitation

A number identifies a sale; it does not copy the sale to every device.

If the original sale has not reached the backend and the customer visits a
different counter that is also offline, that counter cannot safely perform a
return because it does not have the original items, payments, tax totals or
return state. The correct behaviour is to show **Sale not yet synchronized**
and wait for reconciliation. Do not invent a return from only the printed
number.

Supporting truly offline cross-counter returns later would require a shared
store LAN database or peer-to-peer replication with conflict handling. That is
a separate feature.

## Acceptance tests

1. Counter 01 and counter 02 create sales offline at the same time; receipt
   references differ and both sync.
2. Re-send the exact first request; only one order, stock movement, payment,
   customer balance movement and ledger entry exist.
3. Re-send the same `client_sale_id` with changed totals; API returns 409.
4. Search Sales using `ORD-004645`; the order is found.
5. Search Sales using `2-03-260916-0001`; the same order is found.
6. Open order details; both identifiers and the original `issued_at` are
   returned.
7. Reprint after sync; the printed receipt reference remains
   `2-03-260916-0001`.
8. Start a return by the receipt reference; the API resolves order 6220 and
   returns its canonical cart item IDs.
9. Complete a partial return, then search from another counter; returned and
   remaining quantities are correct.
10. Old orders with null new fields still search, print and return by their
    existing order number.
11. Two devices are assigned the same counter number in one store; counter
    registration rejects the second assignment.
12. A sale times out after reaching the server; a verified retry with the same
    `client_sale_id` returns the existing order instead of making a duplicate.

## Deployment order

1. Add nullable columns and indexes.
2. Deploy idempotent order creation and return the new fields.
3. Expand Sales/order-details/return lookup.
4. Deploy the POS build.
5. Configure a unique counter number on every physical device in
   **Settings → POS Counter Identity**.
6. Add backend counter registration when ready; the receipt and idempotency
   contract does not need to change again.
