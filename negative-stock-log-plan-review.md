# Negative Stock Log & Report — Backend Review

## Summary

The proposed plan has the right business behavior and a sensible storage
direction:

- Allow the sale when physical stock exists but was not fully registered.
- Deduct all eligible recorded stock down to zero.
- Record only the unfulfilled quantity as a shortage.
- Make the shortage traceable by company, store, salesman, product, and order.
- Provide a dedicated Negative Stock Report.

However, the plan should not be implemented exactly as written. The current
proposal misses the main mobile/executive-sales path, does not actually fix
multi-batch deduction for normal POS cart lines, and is vulnerable to concurrent
sales reading the same stock.

The recommended approach is to centralize sale deductions in a transactional
service and reuse it from every order-entry path.

## Priority findings

### 1. Mobile/executive sales are not covered

This is the most important gap.

Executive orders intentionally skip normal stock validation and use
`OrderController::adjustStockForExecutive()` instead of
`Helper::adjustStock()`:

- `app/Http/Controllers/Api/V1/OrderController.php:448`
- `app/Http/Controllers/Api/V1/OrderController.php:469`

`adjustStockForExecutive()` already deducts from the preferred stock row and
then other compatible rows, but any final `$remainingToDeduct` is silently
discarded.

Changing only `Helper::adjustStock()` and `CreateOrderPage` would therefore not
record shortages for executive/mobile salesman orders, which appears to be the
primary scenario for this feature.

The same deduction service should be used by:

- Filament POS order creation
- Normal API order creation
- Executive/mobile order creation
- Order imports
- Order edits that increase the sold quantity

### 2. The proposed multi-batch loop does not fix the main POS flow

The POS normally stores a specific `product_stock_id` on each cart item and
passes it to `Helper::adjustStock()`:

- `app/Filament/Tenant/Resources/OrderResource/Pages/CreateOrderPage.php:1436`

When `product_stock_id` is present, the helper builds a collection containing
only that one stock row:

- `app/Helper/Helper.php:245`

Therefore, wrapping the current collection in a deduction loop does not make
other batches available. For example, a request for 3 against a selected batch
of 2 and another eligible batch of 2 would deduct 2 and incorrectly report a
shortage of 1.

The business rule must explicitly choose one of these behaviors:

1. **Strict batch:** deduct only the selected batch and report any remainder as
   shortage.
2. **Preferred batch:** deduct the selected batch first, then spill into other
   compatible batches in the same company, store, product, and variant.

The existing executive implementation already follows preferred-batch
behavior, so that is likely the most consistent option. Before adopting it,
confirm how batch-specific purchase cost, retail price, tax, and expiry should
be handled.

### 3. Stock rows must be locked during deduction

The proposed read-modify-save loop is vulnerable to concurrent sales:

1. Sale A reads quantity 2.
2. Sale B reads quantity 2.
3. Both deduct 2.
4. Both conclude there was no shortage.

Eligible stock rows should be selected using `lockForUpdate()` inside a database
transaction. Use a deterministic order:

```php
->orderBy('created_at')
->orderBy('id')
->lockForUpdate()
```

Although Filament order creation already has an outer transaction, the shared
stock service should protect itself because it is called from multiple entry
points.

### 4. The proposed `notes` value will not currently be mass assigned

The `product_stock_logs` table has a `notes` column, but `notes` is missing from
the model's `$fillable` array:

- `app/Models/ProductStockLog.php:12`

Depending on Laravel configuration, the proposed payload may be silently
discarded or cause a mass-assignment exception.

Add `notes` to `$fillable` and preferably cast it to an array:

```php
protected $casts = [
    'old_values' => 'array',
    'new_values' => 'array',
    'changed_fields' => 'array',
    'notes' => 'array',
    'created_at' => 'datetime',
    'updated_at' => 'datetime',
];
```

Then pass an array rather than manually calling `json_encode()`:

```php
'notes' => [
    'requested' => $requested,
    'eligible_available' => $available,
    'deducted' => $deducted,
    'shortage' => $shortage,
    'product_variant_id' => $productVariantId,
    'cart_item_id' => $cartItemId,
],
```

`eligible_available` is clearer than `available`, because stock in another
store or variant may exist but must not be consumed.

### 5. Validate the preferred stock row against the full context

The current `ProductStock::find($productStockId)` lookup does not verify that
the selected row belongs to the supplied:

- company
- product
- store
- product variant

A stale or invalid stock ID could therefore deduct from an unrelated stock row.
The preferred-row query and fallback-row query must use the same tenant, store,
product, and variant constraints.

For a product without a variant, explicitly use
`whereNull('product_variant_id')`. A variant sale must never consume general
product stock or stock belonging to another variant.

### 6. A boolean return value is no longer sufficient

The proposed behavior returns different values for equivalent shortages:

- No stock rows: log the full shortage and return `false`.
- Partial deduction: log the remaining shortage and return `true`.

Both cases mean that the allowed sale was handled but recorded stock was
insufficient.

Return a structured result instead:

```php
final readonly class StockDeductionResult
{
    public function __construct(
        public float $requested,
        public float $deducted,
        public float $shortage,
    ) {}

    public function isComplete(): bool
    {
        return $this->shortage <= 0;
    }
}
```

The caller can then apply the company's allow-or-block policy without losing
information.

If the method must retain a boolean temporarily, define `true` as "the
operation was handled, including a recorded shortage." Reserve `false` for
invalid input or a system failure.

### 7. Order context must be passed from every sale path

Passing the order reference only from `CreateOrderPage` produces an incomplete
report. Context must also be provided by API, executive, import, and edit flows.

Prefer a context object or named array rather than continuing to append
positional parameters:

```php
new StockDeductionContext(
    companyId: $order->company_id,
    storeId: $cart->store_id,
    userId: auth()->id(),
    orderId: $order->id,
    cartItemId: $cartItem->id,
    productVariantId: $cartItem->product_variant_id,
    preferredStockId: $cartItem->product_stock_id,
    channel: 'executive',
)
```

Including the cart-item ID makes an individual shortage easier to trace and
helps prevent duplicate records for the same order line.

### 8. Stock updates already create audit rows in `product_stock_logs`

Every saved `ProductStock` update triggers the model observer and writes an
`action = updated` row to `product_stock_logs`:

- `app/Models/ProductStock.php:150`

The `StockAdjusted` event also writes an `adjust_stock` row to `stock_logs`.
After this feature, an allowed shortage may therefore produce:

- One or more `product_stock_logs.action = updated` rows from the model observer
- One or more `stock_logs.type = adjust_stock` rows from the event listener
- One `product_stock_logs.action = negative_stock` shortage row

This is acceptable, but it should be documented. The shortage row represents
the unmet portion of the sale; it is not the only audit record for the stock
movement.

The current decrement event also uses the reason `purchase` for a sale. This
should be corrected to `sale`.

### 9. Add an index for the report query

No new table is required, but the report will primarily filter by company,
action, and date. The existing table does not have a matching composite index.

Add a small migration:

```php
Schema::table('product_stock_logs', function (Blueprint $table) {
    $table->index(
        ['company_id', 'action', 'created_at'],
        'product_stock_logs_company_action_created_index'
    );
});
```

Storing shortage inside `notes` is acceptable for an initial version, but
sorting a large report by a JSON value stored in a text column will be
expensive. If shortage reporting becomes high-volume or feeds summaries, add a
dedicated decimal `shortage_quantity` column later.

### 10. Blocking sales requires an atomic policy

The optional plan to "log, then return false" is not sufficient. A caller may
ignore the return value, as it does today, or accidentally commit part of the
order.

For blocking behavior:

1. Lock and calculate eligible availability.
2. Apply the block policy before committing deductions.
3. Throw a domain exception so the entire order transaction rolls back.
4. Decide separately whether blocked attempts need an audit log.

If a blocked-attempt log is written inside the rejected order transaction, the
log will be rolled back too. Persisting blocked attempts requires an intentional
logging strategy outside that transaction.

## Recommended implementation design

### Step 1 — Introduce a dedicated deduction service

Create a service such as:

```text
app/Services/StockDeductionService.php
```

Keep `Helper::adjustStock()` temporarily as a compatibility wrapper if needed,
but do not duplicate sale-deduction logic between the helper and the executive
controller.

The service should accept:

- company ID
- store ID
- product ID
- product variant ID
- preferred product-stock ID
- requested quantity in base units
- user ID
- order ID
- cart-item ID
- source channel

It should return requested, deducted, and shortage quantities.

### Step 2 — Select and lock eligible stock

Within a database transaction:

1. Reject a requested quantity less than or equal to zero.
2. Query only rows matching company, store, product, and variant.
3. Lock the rows with `lockForUpdate()`.
4. Process the preferred row first if it is valid.
5. Process remaining compatible rows by FIFO.
6. Use `created_at, id` for stable ordering.
7. Deduct no more than each row's current positive quantity.

All quantity calculations should respect the database precision of three
decimal places.

### Step 3 — Record the shortage atomically

If the sale is allowed and the remaining quantity is greater than zero, create
one `negative_stock` log in the same transaction as the order and stock
deductions.

Suggested row:

| Column | Value |
|---|---|
| `product_id` | Sold product |
| `store_id` | Order/cart store |
| `user_id` | Authenticated salesman/user |
| `type` | `automatic` |
| `action` | `negative_stock` |
| `old_values` | Aggregate eligible balance before deduction |
| `new_values` | Aggregate eligible balance after deduction, normally zero |
| `changed_fields` | `["quantity"]` |
| `reason` | Human-readable shortage reason |
| `notes` | Structured shortage details |
| `reference_type` | `App\Models\Order` |
| `reference_id` | Order ID |
| `company_id` | Explicit company ID from the context |

Suggested `notes` payload:

```json
{
  "requested": 3,
  "eligible_available": 2,
  "deducted": 2,
  "shortage": 1,
  "product_variant_id": null,
  "cart_item_id": 123,
  "channel": "executive"
}
```

Do not rely on `Helper::tenantId()` or `auth()` deep inside the service when the
caller can provide explicit company and user context. This also makes imports,
queues, and tests more reliable.

### Step 4 — Wire all entry points to the service

Replace or delegate the deduction logic in:

- `app/Filament/Tenant/Resources/OrderResource/Pages/CreateOrderPage.php`
- `app/Http/Controllers/Api/V1/OrderController.php`
- `app/Imports/OrderImport.php`
- `app/Filament/Tenant/Resources/OrderResource/Pages/EditOrderPage.php`

Review all remaining `Helper::adjustStock(..., false, ...)` calls with `rg` so
no sale-decrement path is missed.

Increment/restock paths such as sales returns should remain separate and must
never create shortage rows.

### Step 5 — Build the Negative Stock Report

The report proposed in the original plan is suitable, with these adjustments:

- Always filter explicitly by the current company.
- Default to newest shortages first.
- Default the date range to the current month, but show a clear active-filter
  indicator so older shortages are not mistaken for missing data.
- Scope store, product, category, and salesman filter options to the current
  company.
- Users belong to companies through a pivot, so do not assume the `users` table
  has a direct `company_id` column.
- Link invoices with `OrderResource::getUrl('view', ['record' => $orderId])`.
- Gracefully handle deleted/null stores, users, and references.
- Decode legacy string JSON defensively if `notes` is cast after old data
  already exists.

`HasPageShield` should be added, and the new page permission must actually be
generated/synchronized and assigned to the appropriate roles. Adding the trait
alone does not grant existing roles access.

### Step 6 — Add the report index

Create the composite `company_id, action, created_at` index described above.
This is recommended even though no new business-data table is needed.

## Acceptance tests

### Core behavior

1. Stock 5, sale 3, sale 3: final stock 0 and one shortage log for 1.
2. No stock row, sale 3: one shortage log for 3 and no stock row created.
3. Batches 2 + 2, sale 3: deduct 2 then 1, with no shortage.
4. Exact stock 3, sale 3: final stock 0, with no shortage.
5. Stock 5, sale 3: final stock 2, with no shortage.
6. Increment/return paths never write a negative-stock log.

### Scope and batch behavior

7. Preferred batch 2 plus compatible batch 2, sale 3: use both according to the
   approved batch policy.
8. Stock in another store is not consumed.
9. Stock belonging to another variant is not consumed.
10. A general-product sale does not consume variant stock.
11. A preferred stock ID belonging to another product or company is rejected.
12. FIFO ordering is stable when two rows have the same `created_at` value.

### Entry points and references

13. Filament POS shortage contains the order and cart-item reference.
14. Executive/mobile shortage contains the order and salesman reference.
15. Normal API shortage follows the configured allow/block policy.
16. Imported order shortage contains the imported order reference.
17. Increasing an existing order quantity records a linked shortage when
    necessary.

### Transactions and concurrency

18. Two simultaneous sales competing for the same stock cannot both consume
    the same quantity.
19. An order failure after deduction rolls back stock updates and the shortage
    log.
20. A duplicate/retried order request does not create duplicate shortage logs
    for the same cart item.

### Reporting and tenancy

21. Company A cannot see company B's shortage logs.
22. Store, product, category, and salesman filters are tenant scoped.
23. Requested, eligible available, deducted, and shortage quantities display
    correctly for decimal base-unit quantities.
24. Invoice links open the correct tenant order.
25. Exported report values match the filtered table values.

## Suggested delivery order

1. Confirm strict-batch versus preferred-batch behavior.
2. Implement and test the transactional deduction service.
3. Wire Filament and all API/executive order paths.
4. Add the model changes and report index migration.
5. Add order/cart-item context to shortage logs.
6. Build the report and permissions.
7. Add import and edit-order coverage.
8. Add concurrency and rollback tests before production release.

## App-to-backend stock payload contract

### What the app currently does

The Flutter checkout builds order lines in:

- `lib/providers/local_product_provider.dart:1484`

For quantities that can be covered by known stock rows, it emits one payload
line per local stock reservation. If the requested quantity is greater than all
locally available stock, it emits an additional line whose `stock_id` is null.

The final order body is assembled in:

- `lib/providers/cart_provider.dart:861`

The endpoint is:

```http
POST /api/v1/order/add-to-order
```

The app sends `stock_id` on an item. The backend's `CartService` maps that value
to the cart item's `product_stock_id`. For the current endpoint contract, the
app should use `stock_id`, not `product_stock_id`, inside `items[]`.

The backend receives and validates the lines in:

- `app/Services/CartService.php:27`
- `app/Services/CartService.php:245`
- `app/Services/CartService.php:401`

### Example: Stock 1 = 10, Stock 2 = 20, sale = 40

Assume:

- Product ID: `501`
- Stock 1 ID: `1001`, quantity `10`
- Stock 2 ID: `1002`, quantity `20`
- Both rows belong to the same company, store, product, and variant bucket.
- The sale quantity `40` is already expressed in the product's base unit.

The app can reserve only 30 units. The remaining 10 units are unreserved and
represent the shortage candidate.

The current backend-compatible payload should contain three item lines:

```json
{
  "items": [
    {
      "product_id": 501,
      "quantity": 10,
      "price": 100,
      "mrp": 120,
      "stock_id": 1001,
      "warranty_enabled": false
    },
    {
      "product_id": 501,
      "quantity": 20,
      "price": 100,
      "mrp": 120,
      "stock_id": 1002,
      "warranty_enabled": false
    },
    {
      "product_id": 501,
      "quantity": 10,
      "price": 100,
      "mrp": 120,
      "stock_id": null,
      "warranty_enabled": false
    }
  ],
  "store_id": 7,
  "source_type": "executive",
  "customer_id": 55,
  "transaction_number": "",
  "payment_method": [101],
  "paid_methods": [
    {
      "method": 101,
      "amount": 4000
    }
  ],
  "delivery_charge": 0
}
```

Payment and customer values above are examples only. The important stock fields
are `items[].product_id`, `items[].quantity`, `items[].stock_id`, the optional
variant/sale-unit fields, and the top-level `store_id`.

The expected backend result is:

| Result | Quantity |
|---|---:|
| Requested | 40 |
| Deducted from Stock 1 | 10 |
| Deducted from Stock 2 | 20 |
| Total deducted | 30 |
| Shortage | 10 |
| Final Stock 1 | 0 |
| Final Stock 2 | 0 |

Exactly one shortage record should be created for this product/order context:

```json
{
  "requested": 40,
  "eligible_available": 30,
  "deducted": 30,
  "shortage": 10,
  "product_variant_id": null,
  "channel": "executive"
}
```

The shortage log should be created by the backend. The app must not be trusted
as the authority for `eligible_available`, `deducted`, or `shortage`, because
its local stock snapshot may be stale.

### Important ordering issue in the current app

`CartProvider.addToOrderAPI()` currently sends:

```dart
"items": items?.reversed.toList(),
```

That can turn the example into this received order:

1. Unreserved 10 (`stock_id = null`)
2. Stock 2 reservation of 20
3. Stock 1 reservation of 10

If the backend processes each line independently in that order, the unreserved
line may consume Stock 1 before the explicit Stock 1 line is processed. The
overall stock may still reach zero, but the batch allocation, COGS association,
and shortage line can become incorrect.

The safe fixes are, in order of preference:

1. The backend aggregates the complete order requirement by compatible
   company/store/product/variant bucket and performs one locked deduction.
2. If it must process split lines, it processes all non-null `stock_id` lines
   first and null-stock lines last, regardless of request order.
3. Remove the unconditional `reversed` behavior from the app when it is not
   needed for the API contract.

The backend must never depend on the client array order for stock correctness.

### Sale-unit quantities

The app stores cart quantities internally in base units. When a reservation is
exactly representable in the selected sale unit, the payload builder converts
the quantity to display/sale units and sends both:

```json
{
  "quantity": 2,
  "sale_unit_id": 90,
  "product_sale_unit_id": 90
}
```

If sale unit `90` has a conversion rate of 12, the backend must calculate:

```text
requested base quantity = 2 × 12 = 24
```

Stock deductions, reservation allocation, and shortage logs must always use the
base quantity. The report may additionally display the sold unit for user
clarity, but its numeric shortage must have one consistent unit.

For a split where a remaining base quantity cannot be represented exactly in
the sale unit, the app intentionally emits that portion as a base-unit line
without `sale_unit_id`.

### Variants and stores

For a variant product, every split line must carry the same
`product_variant_id`:

```json
{
  "product_id": 501,
  "product_variant_id": 9001,
  "quantity": 10,
  "stock_id": 1001
}
```

The backend must verify that each supplied stock ID belongs to:

- the authenticated tenant/company
- the top-level `store_id`
- the line's `product_id`
- the line's `product_variant_id`, or null for a general product

Stock from another store or variant must not count toward
`eligible_available`.

### Recommended version-2 payload

The split-line payload is compatible with the current backend, but it mixes
commercial order lines with physical stock allocation. A cleaner future
contract sends one commercial line plus allocation hints:

```json
{
  "items": [
    {
      "client_line_id": "8fe956c2-f138-46dd-bec7-6d310d92f2be",
      "product_id": 501,
      "quantity": 40,
      "price": 100,
      "mrp": 120,
      "product_variant_id": null,
      "stock_allocations": [
        {
          "stock_id": 1001,
          "base_quantity": 10
        },
        {
          "stock_id": 1002,
          "base_quantity": 20
        }
      ]
    }
  ],
  "store_id": 7,
  "source_type": "executive"
}
```

In this version:

- `quantity` is the actual quantity being sold.
- `stock_allocations` are client hints, not authoritative deductions.
- The missing 10 does not need to be sent as a fabricated stock row.
- The backend reloads and locks eligible rows, recalculates availability, and
  derives the shortage itself.
- `client_line_id` provides an idempotency/deduplication key for retries.

This version requires coordinated app and backend changes. Until then, retain
the current split-line shape, fix ordering independence on the backend, and log
one aggregate shortage for the full compatible product bucket.

## Final recommendation

Proceed with the feature, but centralize deduction before building the report.
If each caller keeps its own stock-decrement implementation, shortage behavior
will differ between POS, mobile executives, API orders, imports, and edits.

The minimum safe production version should include:

- Coverage of executive/mobile sales
- Explicit preferred/strict batch behavior
- Tenant/store/product/variant validation
- `lockForUpdate()` within a transaction
- A structured deduction result
- `notes` fillable/cast support
- Order and cart-item references
- A composite report index
- Concurrency and rollback tests
