# Cloudpos Variant Stock — Code-Verified Backend Review

## Purpose

This is a code-verified review of the tester's variant, stock, price, barcode, billing, and return reports. It deliberately separates:

- confirmed defects;
- intentional system behavior;
- already-fixed items;
- conditional risks that occur only in a particular path;
- product decisions that must be documented rather than silently changed.

The review covers the Flutter Cloudpos client and the Laravel `enkepos` backend as currently present in the repository. It does not assume every surprising screen result is a defect.

## Executive verdict

The tester is right about the main variant-stock problem, but not every point is a bug.

| Tester point | Verdict | Main reason |
|---|---|---|
| Quantity entered for a variant does not appear in stock | **Confirmed defect** | It is saved in `product_variants.quantity`, but no variant-scoped `product_stocks` row is created. |
| Cream can display/use White stock | **Confirmed defect** | The Cloudpos product-sync endpoint omits `product_variant_id` from stock rows. Some backend paths also trust `stock_id` without checking its variant. |
| Variant quantities appear combined or stale | **Confirmed defect** | The API exposes a manually stored global variant quantity that is not synchronized with stock movements. |
| Old price batch still exists after changing a price | **Mostly intentional** | The system intentionally keeps stock batches and their prices separately. A catalog price edit does not rewrite historical batches. |
| A 20-unit row and a later 1-unit row both appear | **Usually intentional** | They are separate purchase/stock batches when price, MRP, expiry, batch number, or other grouping fields differ. |
| Price remains visible when stock reaches zero | **Intentional when overselling is enabled** | Cloudpos defaults to allowing oversell for backward compatibility. The stock row remains at zero while the sale may proceed. |
| Product Stock List lacks a Variant column | **Already fixed** | The current admin code and live page include a Variant column. |
| Barcode generator repeats the same barcode for variants | **Confirmed defect / incomplete contract** | The generator does not consider variant barcodes, and unsaved variant rows are not reserved server-side. |
| Product Variant field is missing on Create Product Stock | **Intentional conditional UI, with a settings defect** | It is shown only after selecting a variant product and enabling variants. However, different code paths read two different feature-toggle tables. |
| Billing variant quantity does not refresh | **Confirmed defect** | The stock sync payload lacks variant identity and the variant quantity returned by the API is stale. |
| Return immediately restores stock | **Not expected** | Stock restoration is intentionally deferred until return completion, preventing double restoration. |

## Intended data model

The code clearly intends the following model:

1. `products` stores catalog-level information.
2. `product_variants` stores variant identity, attributes, SKU, barcode, and variant-level catalog prices.
3. `product_stocks` stores physical inventory batches by company, store, product, optional variant, price, expiry, batch number, and quantity.
4. `cart_items` snapshots the chosen product, variant, stock row, sale unit, quantity, and charged price.

For a stock-managed product, physical availability must come from `product_stocks`. The migration comment describes `product_variants.quantity` as “Total across all stores,” but the current application never maintains that total when stock is created, sold, moved, adjusted, or returned. Therefore it cannot safely be used as live availability.

The intended stock identity is:

```text
company_id + store_id + product_id + product_variant_id + stock/batch identity
```

The intended non-variant identity uses `product_variant_id = null`. A variant sale must never borrow from that general bucket or another variant.

---

## Confirmed defects

### C-01 — Variant quantity on product creation is not opening stock

**What the user understands**

The variant editor labels the field `Qty`. A reasonable user interprets Red = 20 and Green = 20 as opening inventory for each variant.

**What the code does**

- `POST /api/v1/product/create-product` accepts `variants.*.quantity`.
- `syncProductVariants()` writes the number only to `product_variants.quantity`.
- It does not create a `product_stocks` row for the newly created variant.
- Separately, the top-level product `quantity` creates a general stock row with `product_variant_id = null`.

This can produce a variant-controlled product with apparent quantity on the variant record and unusable general stock in the stock table.

**Required backend change**

- Treat variant `Qty` as opening stock, or rename/remove it if it is not meant to create stock.
- Because the create request already resolves a store, create one `product_stocks` row per variant with quantity greater than zero.
- Set `product_variant_id`, `store_id`, company, prices, unit, supplier, date, and any initial batch fields.
- Do not create a general `product_variant_id = null` stock row when active variants are supplied.
- Wrap product, variants, attributes, and opening-stock creation in one outer database transaction.
- Prefer an explicit `opening_stock` object over overloading `quantity` long-term.

**Suggested payload**

```json
{
  "name": "Himalaya Soap",
  "store_id": 1,
  "variants": [
    {
      "client_key": "red",
      "sku": "SOAP-RED",
      "barcode": "111000341",
      "price": 35,
      "attributes": [{"product_prop_id": 1, "value": "Red"}],
      "opening_stock": {
        "quantity": 20,
        "retail_price": 35,
        "purchase_rate": 25,
        "mrp": 40
      }
    }
  ]
}
```

**Acceptance test**

Create Red = 20 and Green = 20. The stock table must contain two rows with the correct variant IDs and no general stock row. Billing must show 20 for each variant.

### C-02 — Cloudpos stock-sync rows omit `product_variant_id`

**Why this is the direct cause of the tester's billing mapping report**

Cloudpos downloads products from:

```text
GET /api/v1/product/executive/list-products
```

The backend maps stock rows with ID, product, store, quantity, and price, but does not include `product_variant_id`. The Flutter `Stock.fromJson()` model supports the field, and its variant filter deliberately accepts only exact `stock.productVariantId == selectedVariantId` matches.

The backend has the required value in the database but drops it from the response. It also returns the product SKU instead of the variant SKU for each stock row.

**Required backend change**

Every stock object returned by the executive product endpoint must include at least:

```json
{
  "id": 901,
  "product_id": 50,
  "product_variant_id": 101,
  "store_id": 1,
  "quantity": 20,
  "price": "35.000",
  "sku": "SOAP-RED"
}
```

Also add a contract test proving two variants of one product return distinct stock IDs and variant IDs.

### C-03 — Variant availability returned by the API is stale

**What the code does**

`ProductVariantResource` returns `product_variants.quantity`. Stock creation, purchase receiving, sale, adjustment, transfer, withdrawal, expiry clearing, and return update `product_stocks.quantity`; none synchronizes the variant field. `StockAdjusted` listeners only write logs.

This confirms that `product_variants.quantity` is currently a stale cache, despite the original migration describing it as a total across all stores.

**Required backend change**

Preferred design: stop treating `product_variants.quantity` as authoritative. Compute and return store-scoped availability from stock rows:

```json
{
  "id": 101,
  "quantity": 40,
  "available_quantity": 20,
  "availability_scope": {"store_id": 1}
}
```

- `available_quantity`: sum for the requested store.
- If legacy `quantity` must remain, define it explicitly as company-wide total and compute it rather than trusting the stored column.
- Include stock changes in incremental product synchronization. Product stock updates are already included in the updated-at filter; the response must carry correct variant identity and availability.

The Flutter client already prefers `available_quantity` over legacy `quantity`.

### C-04 — A supplied `stock_id` is not consistently validated against product, variant, store, and company

Several code paths use `ProductStock::find(stock_id)` and then validate or change that row without proving that it belongs to the submitted cart line. `Helper::adjustStock()` has this behavior. The single-item cart path also validates only the quantity of the supplied stock row.

This permits an internally inconsistent line such as:

```text
product = Jasmine
variant = Cream
stock_id = White Jasmine stock
```

**Required backend change**

Before pricing, validation, deduction, or restoration, resolve stock through one shared service that enforces:

```text
stock.company_id == current tenant
stock.store_id == cart/order store
stock.product_id == submitted product
stock.product_variant_id == submitted variant
```

For a non-variant line, require `stock.product_variant_id IS NULL`. Return `422` on mismatch and change no stock.

Do not rely only on the Flutter client being correct. The backend must protect the invariant.

### C-05 — The executive product endpoint is store-scoped, but several validation and fallback queries are not

The product download correctly filters loaded stock rows by requested store. However:

- variant stock validation can sum all stores;
- `OrderHelper::validateStock()` does not receive a store ID;
- `Helper::adjustStock()` does not receive or filter a store when no stock ID is present;
- fallback price queries can choose the first stock without variant or store scoping.

This can display stock from Store A but validate or deduct a row from Store B.

**Required backend change**

Make `store_id` mandatory for stock-managed cart/order operations and pass it through every stock lookup. A stock query without tenant, store, product, and variant scope should be treated as invalid in these flows.

### C-06 — Variant barcode generation and uniqueness are incomplete

**What is working**

The Flutter save validation catches duplicate barcodes between variant rows, which explains the red error in the screenshot.

**What is broken**

- `generateUniqueBarcode()` checks product and sale-unit tables, not `product_variants`.
- The create/edit API rules do not apply `distinct` to `variants.*.barcode`.
- The API does not check a variant barcode against existing product, sale-unit, and variant barcodes.
- The database has no unique variant barcode constraint.
- Repeated generator calls before saving are stateless and can return the same value.
- The Flutter generator's in-form collision set currently includes product and sale-unit controllers but omits variant controllers.

**Required backend change**

- Create one company-wide barcode namespace covering products, sale units, and variants. A central `barcode_registry` with a unique `(company_id, barcode)` key is the strongest design.
- At minimum, validate all three tables in one transaction and add `distinct` for submitted variant rows.
- Add `POST /api/v1/product/generate-barcodes` with `count`, or provide reservation tokens with expiry, so one request can safely allocate multiple unsaved barcodes.
- Include variants when calculating the next generated number.

The Flutter form should also include all variant barcode controllers in `_collectCurrentFormBarcodes()`.

### C-07 — Variant enablement has two sources of truth

Some code reads `settings.value` for `PRODUCT_VARIANT_ENABLED`; other code reads `company_props.active` through `Helper::productVariantEnabled()`.

Consequences can include:

- Manage Variants appears but Create Product Stock hides the variant selector;
- the UI allows variant stock while the API does not require a variant;
- one tenant receives different behavior between admin, purchase, and API paths.

**Required backend change**

Choose one feature-toggle source and use one helper everywhere. Migrate existing tenant values, remove or mirror the duplicate, and add a test covering admin visibility plus API validation.

### C-08 — Stock movement drops variant and batch identity

`StockService::moveStock()` creates/finds the destination row using only product, destination store, and company. It does not include `product_variant_id` and does not preserve the full batch identity.

Moving Red stock can therefore merge it into a general product row at the destination. This is a confirmed related defect even though it was not explicitly named by the tester.

**Required backend change**

Destination identity must preserve variant, batch number, expiry, prices, unit, purchase source, tax fields, and other configured batch keys. Never merge different variants.

### C-09 — Stock deduction is not atomic and the non-executive allocator cannot consume multiple batches correctly

Order creation runs inside a transaction, but stock reads and writes do not use row locks or conditional atomic updates. Two tills can validate the same last unit before either writes.

Additionally, `Helper::adjustStock()` checks each stock row for the full requested quantity. If 20 units are available as 10 + 10 across two rows, it does not split the deduction across both. Its boolean result is often ignored, so an order can succeed without complete stock deduction.

**Required backend change**

Implement one allocator service that:

1. locks eligible rows with `lockForUpdate()` inside the order transaction;
2. filters tenant, store, product, and variant;
3. validates any requested stock IDs;
4. consumes the selected group or FEFO/FIFO rows across multiple batches;
5. records allocations per cart/order line;
6. fails the whole order if strict stock mode cannot allocate the full quantity;
7. records an explicit unallocated quantity when overselling is allowed.

### C-10 — The legacy single-item cart endpoint can deduct twice

`POST /api/v1/cart/add-to-cart` immediately subtracts from a supplied stock row. `POST /api/v1/order/add-to-order` later deducts cart stock again. Removing or clearing the cart does not restore the first subtraction.

The newer bulk cart path does not deduct at add-to-cart time, so the two endpoints follow conflicting reservation rules.

**Required backend change**

Choose one model:

- recommended: do not mutate physical stock until order confirmation; or
- implement explicit stock reservations with reserve/release/consume states.

Do not silently subtract physical stock in only one cart endpoint. Deprecate the legacy path if current clients no longer need it.

---

## Intentional or conditional behavior

### I-01 — Old and new stock prices can coexist

This is intentional batch pricing, not automatically a stock-mapping bug.

The system supports:

- product catalog price;
- variant catalog price;
- stock-batch retail price;
- sale-unit master price;
- stock-batch sale-unit override;
- a historical cart/order line price.

Changing a product or variant from 35 to 33 should not rewrite completed orders. It also does not necessarily rewrite an older stock batch's retail price. Decrementing an old physical batch while charging the current variant price can be valid because stock identity and selling-price identity are separate.

A defect exists only if one of these occurs:

- Cream uses White's stock row;
- the screen shows 33 but the finalized order charges 35 without an authorized override;
- the server recalculates a price differently from the confirmed cart line;
- an unavailable batch is selected while another policy should be used.

**Product decision required**

Document one price precedence. Current Flutter precedence is roughly sale-unit override/master, then variant price, wholesale qualification, selected stock retail price, then product price. The bulk backend trusts an explicit client price first. These should be aligned, while preserving authorized cashier overrides and historical snapshots.

### I-02 — Multiple rows such as 20 and 1 are not necessarily duplicates

The stock-add API intentionally merges only when product, variant, retail price, MRP, company, store, expiry, and batch number match. A changed price or batch creates another row. The stock grouping configuration also intentionally groups by selected fields, with selling price enabled by default.

The admin should show an aggregated summary plus expandable batches so non-technical users understand `Total 21 = Batch A 20 + Batch B 1`. Do not consolidate physical batches if doing so would destroy price, expiry, supplier, or cost history.

### I-03 — Zero-stock price visibility and overselling

Cloudpos has an `ALLOW_OVERSELL` policy. The client defaults to allowing overselling for backward compatibility when the setting is absent. In oversell mode:

- an out-of-stock variant remains selectable;
- its catalog/variant price remains usable;
- physical stock remains zero rather than becoming negative;
- the sale can proceed without a stock allocation.

That behavior matches the tester's “price 33 remains but stock no longer decreases” report and is not a defect when overselling is enabled.

There is still a backend contract gap: the Laravel code does not read `ALLOW_OVERSELL`, and executive-source stock validation is skipped unconditionally. Strict mode is therefore enforced mainly by the client and can be bypassed through the API.

**Required improvement**

- Enforce the same setting server-side.
- Return `stock_status: in_stock | out_of_stock | oversold` and `allocated_quantity`/`unallocated_quantity` on order lines.
- Show “Oversold — no stock deducted” rather than making it look like inventory failed silently.

### I-04 — Product Variant field on Create Product Stock is conditional

The field is intentionally visible only when:

1. a product has been selected;
2. variant functionality is enabled; and
3. the selected product has active variants.

Therefore its absence on the initial blank Create Product Stock screen is correct. It becomes a bug only if it remains hidden after selecting a variant product while the unified feature toggle is enabled.

### I-05 — Return stock is restored at completion, not draft creation

The current flow intentionally avoids restoring inventory in `salesReturn()` and restores it in `completeReturnOrder()`. This prevents double counting and is correct.

The remaining conditional defect is fallback restoration: if a variant cart line has no `product_stock_id`, completion does not pass `product_variant_id`, and a product-only fallback can select the wrong row or fail. COGS fallback is also not variant/store scoped.

**Required improvement**

- Preserve original stock allocations on the order line.
- Restore those exact allocations at completion.
- If legacy data lacks stock IDs, require product + variant + store fallback, not product alone.
- Keep completion idempotent.

---

## Already fixed or not reproducible as a current defect

### F-01 — Product Stock List Variant column

The current `ProductStocks` admin page defines a `Variant` column and the live page shows it. No new backend task is needed for this tester point.

### F-02 — Flutter variant identity in normal cart/order payloads

The current Flutter paths preserve `product_variant_id` in local cart identity and checkout payloads. Strict local filtering does not deliberately fall back to another variant or general stock. Older documentation claiming all Flutter paths drop the variant is stale.

### F-03 — Return draft no longer restores stock twice

The code intentionally removed draft-stage restoration. Do not reintroduce it as a response to the tester report.

---

## Endpoint change checklist

### `GET /api/v1/product/executive/list-products` — highest priority

- Add `product_variant_id` to every stock row.
- Return variant SKU/barcode where applicable.
- Add store-scoped `available_quantity` for every variant.
- Keep company-wide total separate and clearly named if needed.
- Ensure the incremental sync changes whenever related stock or variant data changes.

### `POST /api/v1/product/create-product`

- Use one transaction for the full operation.
- Convert variant opening quantities into variant-scoped stock rows.
- Never create general stock for an active variant product.
- Validate variant barcodes across the complete company namespace.
- Return created stock rows with product, variant, store, quantity, and price.

### `POST /api/v1/product/edit-product/{id}`

- Do not use product + store alone to update stock for a variant product.
- Separate catalog edits from physical stock adjustments.
- Do not treat `variants[].quantity` as an arbitrary writable live total.
- Require explicit variant/store/stock identity for an inventory adjustment.

### `POST /api/v1/product/add-stock` and bulk stock

- Keep the existing belongs-to-product validation.
- Use the unified variant feature toggle.
- Return the updated store-scoped variant availability.
- Add tests for same product with two variants, prices, and stores.

### `POST /api/v1/product/update-stock/{id}`

- Validate tenant, store, product, and variant ownership of the target row.
- Do not silently update product or variant catalog price unless the request explicitly asks to do so.
- Return authoritative stock identity and quantity.

### `GET /api/v1/product/generate-barcode`

- Include variant barcodes in uniqueness calculation.
- Add a multi-barcode/reservation API for unsaved rows.
- Back it with a company-wide uniqueness mechanism.

### `POST /api/v1/cart/add-to-cart` and `/add-to-cart-bulk`

- Apply the same reservation/deduction policy in both endpoints.
- Validate `stock_id` against tenant, store, product, and variant.
- Align price precedence with the documented business rule.
- Enforce strict/oversell policy server-side.
- Return allocation and oversell status.

### `POST /api/v1/order/add-to-order` and confirmation endpoints

- Lock and allocate stock atomically.
- Deduct across valid selected/FIFO/FEFO batches when necessary.
- Fail strict-mode orders if allocation is incomplete.
- Never ignore a failed stock adjustment.
- Snapshot final charged price and stock allocations.

### `POST /api/v1/order/sales-return` and `/complete-return-order`

- Keep draft creation non-mutating.
- Restore exact original allocations only at completion.
- Pass variant and store in legacy fallback logic.
- Make completion idempotent.

### `POST /api/v1/stocks/move/{id}`

- Preserve `product_variant_id` and complete batch identity at the destination.
- Lock source and destination rows during transfer.

---

## Data repair required after code fixes

The existing database may already contain inconsistent records. Run an audit before migration:

1. Variant products with general stock rows (`product_variant_id IS NULL`).
2. Variant records whose stored `quantity` differs from summed stock.
3. Cart/order lines where stock product/variant/store does not match the line.
4. Duplicate barcodes across products, sale units, and variants.
5. Variant stock moved into a general destination row.
6. Variant order/return lines missing `product_stock_id`.

Do not automatically assign ambiguous general stock to a variant. Export those rows for manual mapping. After repair, either remove the cached `product_variants.quantity` column or rebuild it as a clearly documented derived cache.

## Recommended implementation order

### Priority 0 — fixes that explain the tester's current billing failures

1. Add `product_variant_id` to executive product stock payloads.
2. Return store-scoped `available_quantity` per variant.
3. Create variant-scoped opening stock during product creation.
4. Validate stock/product/variant/store/company identity on cart and order APIs.
5. Unify the variant feature toggle.

### Priority 1 — inventory correctness

1. Add atomic stock allocation and multi-batch deduction.
2. Fix stock transfer identity.
3. Align strict versus oversell behavior on the backend.
4. Fix legacy single-cart double deduction or deprecate the endpoint.
5. Make return fallback variant/store aware.

### Priority 2 — clarity and data quality

1. Implement company-wide barcode uniqueness and multi-generation.
2. Document catalog price versus batch price versus charged price.
3. Show stock totals with expandable batch rows.
4. Audit and repair existing inconsistent data.

## Minimum end-to-end acceptance scenario

1. Create one product with Red = 20 and Green = 20.
2. Confirm two variant-scoped stock rows and no general row.
3. Sync Cloudpos for Store 1; verify every stock row contains its variant ID.
4. Select Red; verify only Red stock is displayed and allocated.
5. Sell one Red; verify Red = 19 and Green = 20 after fresh sync.
6. Attempt Red with Green's stock ID; verify `422` and no mutation.
7. Add another Red batch of 1 at a new price; verify total Red = 20 with two visible batches.
8. Change the Red catalog price; verify old completed sales remain unchanged and the new sale follows the documented precedence.
9. Sell through zero in strict mode; verify rejection.
10. Repeat in oversell mode; verify explicit oversold status and no false deduction.
11. Complete a Red return; verify only the original Red allocation is restored once.
12. Move Red stock to another store; verify it remains Red at the destination.
13. Generate five variant barcodes; verify all are unique and globally validated.

## Final conclusion

The variant feature is structurally present in both applications, and many Flutter paths now carry variant identity correctly. The system is not “almost fully correct” yet because the main Cloudpos product-sync response drops stock-to-variant identity, opening variant quantity does not create physical inventory, and the backend does not consistently enforce stock identity or atomic allocation.

At the same time, batch rows, historical prices, conditional variant selectors, delayed return restoration, and configured overselling are intentional concepts. They should be explained and made visible in the UI, not removed as if they were all defects.
