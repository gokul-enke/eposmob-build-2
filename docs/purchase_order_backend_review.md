# Purchase Order API Backend Review

## Purpose

This document explains the backend-only changes made for purchase-order parity between the mobile app and the admin web flow. It is written for review with the backend developer.

This is an engineering review note, not an accounting sign-off. The changes are on a review branch and should not be merged to `staging` until the backend owner validates the calculations and database behavior.

## Current status

- Backend repository: `enkeit/enkepos`
- Review branch: `feature/purchase-order-api-parity-review`
- Commit: `58998f71`
- Files changed: `PurchaseController.php` and `PurchaseRoutes.php`
- Database migrations: none
- `staging`: not changed, merged, or deployed

The branch contains 226 insertions and 26 deletions. No credentials were added to the code or documentation.

## Short answer: was the old backend wrong?

Not everywhere. The old code was a valid older implementation, but it was incomplete and inconsistent with the current admin web purchase flow and with the mobile screen's API contract.

The most important old problems were:

1. The list API returned a purchase-unit label in `purchase_unit_id`. The mobile receive screen needs the numeric `product_sale_units.id` so it can send the ID back for conversion.
2. Retail/sale tax and purchase-cost tax were forced to use the same flag. The admin web supports them independently.
3. On receive, `PurchaseItem.unit_price` stored the entered price while `PurchaseItem.total_price` and stock used a tax-adjusted price. This could make the unit and total disagree.
4. The receive API accepted only `CASH`, `CARD`, and `UPI`, even though the tenant has configurable payment methods.
5. A purchase-order detail endpoint was missing, so a view screen had to depend on the list response containing every item.
6. Per-sale-unit price overrides from the admin flow were not accepted or persisted by the API.
7. A repeated receive request could pass through the old status check and create another accounting/invoice path. The branch now rejects an item already marked received.

These are API-contract and business-consistency issues, not proof that every old purchase record is invalid. Existing data should be tested before any data correction is attempted.

## Endpoints in scope

All routes are inside the `v1` purchase group and use the `auth:sanctum` middleware.

| Method | Endpoint | Purpose | Status |
|---|---|---|---|
| GET | `/api/v1/purchase/list-purchase-order` | Filtered and paginated purchase-order list | Existing endpoint expanded |
| GET | `/api/v1/purchase/purchase-order/{id}` | Full purchase-order detail | New endpoint |
| POST | `/api/v1/purchase/add-purchase-order` | Create an order, optionally receive items immediately | Existing endpoint expanded |
| POST | `/api/v1/purchase/receive-purchase-order/{id}` | Receive pending items and create stock/accounting records | Existing endpoint expanded |

The controller relies on the application's tenant/company scope. The backend developer should still confirm that tenant scoping and permissions are active for API requests, not only for the Filament web request.

## Change 1: purchase-order list API

### Old behavior

The old list query eager-loaded only the item variant, supplier, and store. It used the requested `per_page` value directly and returned this value for the purchase unit:

```php
'purchase_unit_id' => $item->purchase_unit?->unit?->value ?? null,
```

That value is a display string such as `Box` or `NOS`, not the foreign-key ID expected by the receive API.

The response also did not include the current stock pricing, rack, tax flags, or per-unit price overrides needed to prefill the mobile receive form.

### New behavior

The query now eager-loads:

- Product stock records and their per-sale-unit prices
- The purchase unit and its master unit label
- Supplier and store

The endpoint now supports:

- Numeric `per_page`, clamped to a safe range of 1 to 100
- `per_page=all` for an all-record export/view request
- Page summary: `page_discount` and `page_total`
- Full filtered-result summary: `all_discount` and `all_total`
- Product price, MRP, rack, wholesale minimum, tax flags, and `unit_prices`
- Null-safe product and variant names
- Numeric `purchase_unit_id`

### Why this was changed

The admin screen shows discount and total summaries, while the mobile screen needs the same information. The receive screen also needs IDs and pricing fields to submit a valid receive body. Returning a display label in a field named `purchase_unit_id` made the API response look valid while making the next receive request fail or skip conversion.

### Compatibility warning

The type of the existing `purchase_unit_id` response field changed from a label to an integer ID. That is correct for the new mobile client, but it may be breaking for another old client.

The safer long-term contract would be:

```json
{
  "purchase_unit_id": 8,
  "purchase_unit": "Box"
}
```

The backend developer should decide whether to keep a legacy label under a separate key before merging.

### Performance warning

`per_page=all` loads all matching vouchers and their related product-stock data into memory. It is useful for a controlled export, but it should not be used for an unbounded large dataset. The backend owner should consider an export job or a maximum record limit if the table grows significantly.

## Change 2: purchase-order detail endpoint

### Old behavior

There was no dedicated mobile detail route. The list response happened to include item data, but that is fragile because list results are paginated and list payloads are normally optimized for rows.

### New behavior

The route below now returns one complete voucher:

```text
GET /api/v1/purchase/purchase-order/{id}
```

It returns the voucher ID, voucher number, date, amount, discount, supplier, store, status, and detailed items. Each item includes product identity, variant, quantity, unit price, total price, purchase unit, stock pricing, tax flags, rack, expiry, batch, and unit-price overrides.

Both `items` and `purchase_items` are included as aliases because the existing clients use different names. The backend developer can later standardize this response after checking all clients.

### Why this was changed

The mobile view screen can now request one order directly instead of depending on the current page of the list. A missing ID returns HTTP 404 with `Purchase order not found.`

## Change 3: purchase tax calculation

### The two tax flags

The API now supports two independent choices:

| Field | Meaning |
|---|---|
| `tax_include` | Whether retail and wholesale prices already include tax |
| `tax_include_purchase` | Whether the purchase cost already includes tax |

The admin web has a separate purchase-tax toggle. The old API reused `tax_include` for purchase cost, which is incorrect when, for example, retail price is entered tax-inclusive but the supplier purchase price is entered tax-exclusive.

### Calculation used by the branch

The existing `CartHelper::calculateTax()` is used to determine the product/category tax rate.

If `tax_include_purchase` is `true`:

```text
entered purchase rate = tax-inclusive rate
stored purchase rate = entered rate
tax amount = extracted tax portion
```

If `tax_include_purchase` is `false`:

```text
entered purchase rate = tax-exclusive rate
stored purchase rate = entered rate + tax
tax amount = entered rate * tax rate
```

The stored purchase rate is the inclusive cost used by stock and accounting records. Supplier invoice lines then derive the exclusive amount by subtracting the stored purchase tax.

### Backward compatibility decision

When an old client omits `tax_include_purchase`, the branch falls back to the old `tax_include` value:

```php
$taxIncludePurchase = array_key_exists('tax_include_purchase', $row)
    ? (bool) $row['tax_include_purchase']
    : $taxInclude;
```

This preserves the old client behavior while allowing the new app and web flow to send the separate flag.

### Why the old calculation could be wrong

Example with an 18% tax rate and an entered purchase price of 100:

| Input meaning | Correct inclusive stock cost | Correct tax |
|---|---:|---:|
| 100 is tax-exclusive | 118.00 | 18.00 |
| 100 is tax-inclusive | 100.00 | 15.25 |

If retail tax mode was used for both cases, the backend could store 118 when the supplier price already included tax, or store 100 when tax still needed to be added. That affects stock valuation, supplier invoice lines, and accounting totals.

### Review point: rounding

The receive stock path rounds purchase tax to three decimal places. The initial purchase-item calculation is performed before that stock-path rounding. The backend developer should standardize rounding at the agreed currency precision and verify that voucher, stock, invoice, and ledger totals reconcile exactly.

## Change 4: purchase-unit IDs and quantity conversion

The branch does not introduce a new conversion algorithm. The existing conversion is used:

```text
base quantity = purchase quantity * ProductSaleUnit.conversion_rate
```

The branch makes the existing behavior usable by returning the numeric purchase-unit ID in the list/detail response and accepting the same ID in create/receive bodies.

Example:

```text
purchase_unit_id = 8
purchase_qty = 2
conversion_rate for unit 8 = 12
stored base quantity = 24
```

The API checks that the selected sale unit belongs to the product when performing conversion. The backend developer should consider making a mismatched product/unit combination an explicit validation error rather than silently leaving the original quantity unchanged.

## Change 5: per-sale-unit price overrides

The admin web can store a price for a particular sale unit on a particular stock batch. The API now accepts:

```json
"unit_prices": [
  {
    "sale_unit_id": 8,
    "price": 300
  }
]
```

For a received stock record, the branch uses `updateOrCreate()` keyed by:

```text
product_stock_id + product_sale_unit_id
```

### Why this was changed

Without this field, the mobile app could display or edit the unit price but the backend would discard it. The next sale would then use the old/default price instead of the batch-specific value.

### Review point

The `unit_prices.*.sale_unit_id` rule checks that the ID exists. The backend should also validate that every supplied sale unit belongs to the same product as the purchase item, and that the price is valid for the tenant/store rules.

## Change 6: receive validation and duplicate protection

### Dynamic payment methods

The old receive endpoint hardcoded:

```text
CASH, CARD, UPI
```

The branch loads the tenant's configured `PAYMENT_METHOD` values and builds validation rules from them. This makes receive behavior consistent with the existing create endpoint and tenant configuration.

### Already-received item guard

The branch rejects an item whose status is already `Y`:

```text
Item {id} has already been received.
```

This prevents a simple retry from creating another stock/invoice/payment flow for the same purchase item.

The existing cross-order guard was retained: an item must belong to the voucher ID in the URL.

### Important concurrency review

The new status check is useful, but it is not a complete concurrency lock. Two requests arriving at the same time could both read status `N` before either update commits. The backend developer should consider `lockForUpdate()`, an idempotency key, or a database constraint/transaction strategy before production use.

The current behavior returns a validation-style error for a repeated receive. The backend owner should decide whether a retry should instead be idempotently treated as success or return HTTP 409 Conflict.

## What the create endpoint now stores

For each item, the create path now:

1. Resolves and validates the product variant.
2. Converts purchase-unit quantity to base quantity when supplied.
3. Calculates the purchase tax using `tax_include_purchase`.
4. Stores the calculated inclusive purchase rate in `PurchaseItem.unit_price`.
5. Calculates `PurchaseItem.total_price` from the same stored rate.
6. When `receive=true`, creates stock using the same purchase tax mode and stores `tax_include_purchase`.
7. Persists the supplied per-sale-unit overrides on the created stock.

The purpose is to keep the purchase item, voucher amount, stock valuation, and supplier accounting on the same price basis.

## What the receive endpoint now stores

For each received item, the receive path now:

1. Confirms the purchase item belongs to the requested voucher.
2. Rejects an item already marked received.
3. Converts purchase-unit quantity when supplied.
4. Calculates retail, wholesale, and purchase tax separately.
5. Stores the calculated inclusive purchase rate in the purchase item and stock.
6. Recalculates the line total and voucher total from that same rate.
7. Stores `tax_include_purchase` and per-sale-unit overrides on stock.
8. Creates the supplier invoice and payment records using the received stock totals.

The key business rule is that the same inclusive purchase rate should flow through stock valuation, supplier invoice totals, and the creditor/inventory transaction.

## Request examples

### Create purchase order

The following is illustrative; IDs and prices are examples only.

```json
{
  "purchase_date": "2026-08-01",
  "supplier_id": 12,
  "store_id": 3,
  "voucher_number": "PO-1001",
  "invoice_ref": "SUP-INV-77",
  "discount": 10,
  "items": [
    {
      "product_id": 55,
      "product_variant_id": null,
      "quantity": 24,
      "purchase_unit_id": 8,
      "purchase_qty": 2,
      "unit_price": 100,
      "tax_include": false,
      "tax_include_purchase": false,
      "retail_price": 150,
      "wholesale_price": 130,
      "mrp": 160,
      "rack": "A1",
      "wholesale_min_unit": 10,
      "receive": false,
      "unit_prices": [
        {"sale_unit_id": 8, "price": 300}
      ]
    }
  ],
  "payment_methods": ["CASH"],
  "paid_amounts": {"CASH": 0}
}
```

`unit_price` is the entered purchase price. The server decides the stored inclusive rate using `tax_include_purchase`.

### Receive purchase order

```json
{
  "items": [
    {
      "purchase_item_id": 91,
      "quantity": 24,
      "purchase_unit_id": 8,
      "purchase_qty": 2,
      "unit_price": 100,
      "tax_include": false,
      "tax_include_purchase": false,
      "retail_price": 150,
      "wholesale_price": 130,
      "mrp": 160,
      "rack": "A1",
      "wholesale_min_unit": 10,
      "unit_prices": [
        {"sale_unit_id": 8, "price": 300}
      ]
    }
  ],
  "payment_methods": ["CASH"],
  "paid_amounts": {"CASH": 2360},
  "invoice_ref": "SUP-INV-77",
  "discount": 10
}
```

The receive route should be tested with a partial receive, a full receive, a repeated receive, and an item ID from another voucher.

## Business-impact review checklist

The backend developer should verify these before merging:

- [ ] `tax_include_purchase=true` extracts tax from an inclusive entered rate.
- [ ] `tax_include_purchase=false` adds tax to an exclusive entered rate.
- [ ] Retail/wholesale tax behavior remains controlled by `tax_include`.
- [ ] `PurchaseItem.total_price`, `PurchaseVoucher.amount_total`, stock value, supplier invoice amount, and ledger amount reconcile.
- [ ] A discount cannot make any total negative and is applied at the intended level.
- [ ] Purchase-unit quantity is converted only when the unit belongs to the product.
- [ ] Every `unit_prices.sale_unit_id` belongs to the product and tenant.
- [ ] Old clients that omit `tax_include_purchase` retain expected behavior.
- [ ] Existing clients are not broken by the `purchase_unit_id` response type change.
- [ ] A repeated receive cannot create duplicate stock, supplier invoices, vouchers, or transactions.
- [ ] Concurrent receive requests are serialized or made idempotent.
- [ ] Configured payment methods and paid amounts use the same canonical method keys.
- [ ] `per_page=all` is safe for the expected maximum dataset size.
- [ ] Latest stock pricing is selected for the correct company, store, variant, and batch. The current list/detail mapping uses the newest stock for the product and should be reviewed for multi-store or multi-variant products.
- [ ] Pending purchase items do not lose the intended purchase-tax mode merely because no stock row exists yet. The current response reads that flag from the latest stock.

## Suggested API test matrix

| Area | Test cases |
|---|---|
| List | Filters, page size 1/15/100, invalid page size, `all`, page summary, all-result summary |
| Detail | Existing ID, missing ID, tenant isolation, item aliases |
| Create | Pending item, immediate receive, multiple items, variant product, discount, old body without new fields |
| Tax | Sale inclusive/purchase inclusive, sale inclusive/purchase exclusive, both exclusive, tax disabled |
| Units | Base unit, valid purchase unit, wrong-product unit, decimal conversion, unit price override |
| Receive | Partial receive, full receive, wrong voucher item, already received, concurrent retry |
| Payments | Tenant-configured method, unknown method, multiple methods, paid total and invoice total reconciliation |
| Accounting | Stock valuation, supplier invoice, supplier voucher, creditor/inventory transaction, tax split |

## Recommended merge order

1. Backend developer reviews this branch and either approves the API contract or requests changes.
2. Run backend tests against a staging-like database with real tax, unit, stock, supplier, and payment configuration.
3. Merge the backend branch to `staging` only after the API contract is accepted.
4. Test the mobile app against that backend branch/staging deployment.
5. Merge the Flutter branch after list, detail, create, receive, tax, unit conversion, payments, and retry cases pass.

If the backend developer does not approve the backend changes, do not merge the Flutter branch unchanged because the app now expects the detail route and the expanded response/body fields. Adjust the app to the approved API contract first.

## Source map

Backend review branch files:

- `enkepos/routes/api/PurchaseRoutes.php`
- `enkepos/app/Http/Controllers/Api/V1/PurchaseController.php`

Reference implementation used for comparison:

- `enkepos/app/Filament/Tenant/Pages/PurchaseVouchers.php`
- `enkepos/app/Filament/Tenant/Pages/ReceivePurchase.php`
- `enkepos/app/Helper/CartHelper.php`
- `enkepos/app/Models/ProductSaleUnit.php`
- `enkepos/app/Models/ProductStock.php`

## Final conclusion

The branch is safe from a source-control perspective because it is isolated and reviewable. It is not yet safe to call business-production-ready without backend testing. The largest decisions for the backend developer are the response compatibility of `purchase_unit_id`, the exact tax/rounding policy, concurrency protection for receive, and the reconciliation of all stock, invoice, payment, and ledger totals.
