# Backend Variant System: Production Remediation and Implementation Handoff

> Requested filename uses `varient`; this document uses the correct term **variant** internally.

## Document status

- Repository: `enkepos/` Laravel backend inside the Flutter workspace.
- Review date: 2026-07-10.
- Purpose: give another implementation agent enough verified context to repair the backend variant system without repeating the full audit.
- This document supersedes the older `backend-varient.md`, whose conclusions describe an earlier code state.
- This is an implementation handoff, not evidence that the changes below have already been made.

### Coordination update — 2026-07-10

The project owner confirmed that the current order backend accepts quantities above available stock. Earlier statements in this document saying checkout necessarily rejects every oversell are superseded by that confirmation. The frontend now uses `ALLOW_OVERSELL` (default `true`) and can restore strict client blocking with status `false`. The backend should expose that app-setting code for tenants that require strict behavior. Authorization, audit reasons and concurrency behavior still require backend verification even when overselling is intentionally allowed.

## Executive verdict

The backend has a useful variant data model and carries variant identity through many order paths, but it is **not production-ready for stock-managed variant sales**.

The most important release blockers are:

1. The Flutter app previously fell back from missing variant stock to general product stock. The frontend has now removed that fallback; backend validation should remain aligned with exact variant identity.
2. New product creation creates general stock, not variant-scoped stock, so a newly created variant product can be added locally and rejected at checkout.
3. `product_variants.quantity` and `product_stocks.quantity` are separate, unsynchronized sources of truth.
4. Stock validation and deduction are not protected by row locks or atomic conditional updates.
5. The return workflow can restore physical stock twice.
6. Product/variant/stock/sale-unit relationships are not sufficiently validated as one coherent graph.
7. Explicit client prices are trusted before server-side product, variant, stock, or sale-unit pricing.
8. Variant barcode uniqueness is not enforced across the full tenant barcode namespace.

Until these are fixed, production use can produce rejected sales, stale availability, overselling under concurrency, incorrect return stock, or unauthorized prices.

---

## 1. Scope and important files

### Data model and schema

- `enkepos/app/Models/Product.php`
- `enkepos/app/Models/ProductVariant.php`
- `enkepos/app/Models/ProductVariantAttribute.php`
- `enkepos/app/Models/ProductStock.php`
- `enkepos/app/Models/ProductAttachment.php`
- `enkepos/app/Models/CartItem.php`
- `enkepos/database/migrations/2026_02_10_172553_create_product_variants_table.php`
- `enkepos/database/migrations/2026_02_10_172554_create_product_variant_attributes_table.php`
- `enkepos/database/migrations/2026_02_10_182443_add_variant_columns_to_cart_items_table.php`
- `enkepos/database/migrations/2026_02_13_162225_add_product_variant_id_to_product_stocks_table.php`
- `enkepos/database/migrations/2026_02_18_120608_add_product_variant_id_to_product_attachments_table.php`

### Catalog API

- `enkepos/app/Http/Controllers/Api/V1/ProductController.php`
- `enkepos/app/Http/Controllers/Api/V1/Resources/ProductResource.php`
- `enkepos/app/Http/Controllers/Api/V1/Resources/ProductCollection.php`
- `enkepos/app/Http/Controllers/Api/V1/Resources/ProductVariantResource.php`

### Cart, checkout, stock and returns

- `enkepos/app/Services/CartService.php`
- `enkepos/app/Http/Controllers/Api/V1/OrderController.php`
- `enkepos/app/Http/Controllers/Api/V1/CartController.php`
- `enkepos/app/Helper/Helper.php`
- `enkepos/app/Helper/OrderHelper.php`
- `enkepos/app/Helper/CartHelper.php`

### Tenant isolation

- `enkepos/app/Http/Middleware/IdentifyTenant.php`
- `enkepos/app/Models/Scopes/CompanyScope.php`
- `enkepos/app/Providers/AppServiceProvider.php`
- `enkepos/app/Http/Traits/HasCompany.php`

### Existing backend test coverage

At review time the Laravel test tree contained only:

- `enkepos/tests/Feature/ExampleTest.php`
- `enkepos/tests/Unit/ExampleTest.php`
- `enkepos/tests/TestCase.php`

There were no variant, stock-concurrency, price-integrity, tenant-isolation, or return-idempotency tests.

### Verified evidence map

Line numbers below reflect the reviewed code state on 2026-07-10 and may shift after edits.

| Concern | Current source region |
|---|---|
| Variant schema, global SKU uniqueness and aggregate quantity | `database/migrations/2026_02_10_172553_create_product_variants_table.php:13-29` |
| Variant attribute uniqueness | `database/migrations/2026_02_10_172554_create_product_variant_attributes_table.php:13-25` |
| Cart variant identity/snapshot columns | `database/migrations/2026_02_10_182443_add_variant_columns_to_cart_items_table.php:13-22` |
| Variant stock foreign key | `database/migrations/2026_02_13_162225_add_product_variant_id_to_product_stocks_table.php:14-17` |
| Variant casts, SKU generation and attribute accessors | `app/Models/ProductVariant.php:20-168` |
| Catalog variant response including stored quantity | `app/Http/Controllers/Api/V1/Resources/ProductVariantResource.php:14-36` |
| Product creation validation | `app/Http/Controllers/Api/V1/ProductController.php:637-707` |
| General opening-stock creation | `app/Http/Controllers/Api/V1/ProductController.php:748-765` |
| Variant creation after opening stock | `app/Http/Controllers/Api/V1/ProductController.php:825-827` |
| Product edit variant validation | `app/Http/Controllers/Api/V1/ProductController.php:1025-1038` |
| Variant sync ignores submitted quantity | `app/Http/Controllers/Api/V1/ProductController.php:2509-2557` |
| Cart request existence-only validation | `app/Services/CartService.php:151-177` |
| Explicit client price wins | `app/Services/CartService.php:225-249` |
| Strict variant stock validation, no general fallback | `app/Services/CartService.php:265-316` |
| Cart item variant snapshot and merge identity | `app/Services/CartService.php:318-378` |
| Main order transaction | `app/Http/Controllers/Api/V1/OrderController.php:198-383` |
| Order-level stock validation | `app/Http/Controllers/Api/V1/OrderController.php:387-400` |
| Order-level stock adjustment | `app/Http/Controllers/Api/V1/OrderController.php:437-455` |
| Non-atomic stock helper and boolean failure | `app/Helper/Helper.php:243-315` |
| Draft return stock restoration | `app/Http/Controllers/Api/V1/OrderController.php:1734-1804` |
| Completion-time second restoration | `app/Http/Controllers/Api/V1/OrderController.php:1951-2049` |
| Tenant resolution from `X-Tenant` | `app/Http/Middleware/IdentifyTenant.php:16-38` |
| Company global scope depends on active Filament tenant | `app/Models/Scopes/CompanyScope.php:25-47` |

---

## 2. Current data model

### 2.1 Product

`products` remains the parent catalog item. Relevant parent-level values include:

- base product price and MRP;
- base unit;
- category/tax context;
- product barcode and SKU;
- sellable/active state;
- general, non-variant product stock rows.

### 2.2 ProductVariant

`product_variants` currently stores:

- `product_id`;
- `sku`;
- `barcode`;
- optional `price`, `mrp`, and `purchase_price` overrides;
- aggregate `quantity`;
- `active`;
- `reorder_level`;
- `company_id`;
- soft-delete timestamps.

Important mismatch: the migration defines prices as `decimal(10,3)`, while the Eloquent model casts them using `decimal:2`. This should be standardized deliberately.

### 2.3 Variant attributes

`product_variant_attributes` normalizes each variant option as:

- `product_variant_id`;
- `product_prop_id`;
- `value`.

The unique key on `(product_variant_id, product_prop_id)` correctly prevents the same property from being assigned twice to one variant.

`ProductVariant::getAttributesAttribute()` returns a flattened machine-readable map keyed by property code, for example:

```json
{
  "COLOR": "Red",
  "SIZE": "L"
}
```

### 2.4 Variant stock

`product_stocks.product_variant_id` is nullable:

- null means general product stock;
- a value means stock scoped to that variant.

The foreign key guarantees that a referenced variant exists. It cannot guarantee that the stock row's `product_id`, `company_id`, and `product_variant_id` all describe the same product and tenant. Application validation must enforce that invariant.

### 2.5 Historical cart snapshot

`cart_items` stores both:

- `product_variant_id` for referential identity;
- `variant_attributes` as a JSON snapshot.

The snapshot is important because variants and their labels can later be edited or deleted. Historical receipts should continue displaying the values sold at the time.

### 2.6 Variant attachments

`product_attachments.product_variant_id` supports variant-specific images. The API resource returns these through `ProductVariantResource` when the relationship is available.

---

## 3. Required end-to-end invariants

Before changing code, the implementation agent should treat the following as non-negotiable system invariants.

### INV-01: Variant requirement must be explicit

A product needs a persistent `variant_mode` or equivalent flag. It must not be inferred solely from the active variants returned in the current response.

If `variant_mode = true`:

- checkout must include `product_variant_id`;
- the variant must belong to the product and tenant;
- the variant must be active for a new sale;
- a base/non-variant line must be rejected.

This prevents a product with all variants inactive from silently becoming a base product.

### INV-02: Stock ownership must be unambiguous

Recommended policy:

- variant-controlled products use only variant-scoped stock;
- non-variant products use only general stock;
- a stock row cannot point to a variant belonging to another product;
- selected stock must belong to the active store unless an explicit cross-store workflow is used.

Do not keep an undocumented mix of general fallback and strict variant stock.

### INV-03: Stock quantity has one authoritative source

`product_stocks.quantity`, scoped by product, variant and store, should be authoritative.

Variant available quantity should be derived as:

```text
SUM(product_stocks.quantity)
WHERE product_id = selected product
  AND product_variant_id = selected variant
  AND store_id = active store
  AND row is not deleted
```

Avoid maintaining a separate mutable aggregate unless every stock mutation updates it in the same transaction.

### INV-04: Server owns price resolution

The client may show a preview, but the server must validate or calculate the final charged price.

A recommended precedence is:

1. authorized manual override, with permission, reason and minimum-margin validation;
2. selected stock + sale-unit batch override;
3. sale-unit master price;
4. selected variant base-unit override;
5. selected stock retail base-unit price;
6. product base-unit price;
7. multiply base-unit price by sale-unit conversion when no explicit sale-unit price exists.

If the business chooses a different precedence, encode it once in a domain service and test it. Do not duplicate it across controllers, helpers and Flutter.

### INV-05: Checkout stock mutation is atomic

For a stock-managed sale, these operations must occur in one transaction:

1. load and lock the relevant stock rows;
2. verify tenant/product/variant/store ownership;
3. calculate authoritative price and tax;
4. validate available quantity or the server-side oversell policy;
5. decrement stock;
6. create cart/order lines and snapshots;
7. commit.

Any incomplete deduction must throw and roll back the order.

### INV-06: Returns restore once

Each returned base-unit quantity must restore physical stock exactly once. Repeated API calls and retrying a completion request must be idempotent.

### INV-07: Barcode identity is tenant-wide

A normalized non-empty barcode must identify at most one sellable entity within a tenant across:

- product barcodes;
- product sale-unit barcodes;
- variant barcodes.

### INV-08: Historical snapshots are immutable

Existing order lines retain the sold variant attributes, SKU/name snapshot, quantity, tax and final price even if the live variant changes later.

---

## 4. Confirmed strengths in the current backend

These should be preserved during refactoring:

- Variant attributes are normalized rather than stored only as an opaque JSON blob.
- Cart items store `product_variant_id` and an attribute snapshot.
- Product stock rows can be variant-scoped.
- Variant attachments are supported.
- Catalog endpoints eager-load active variants in the main product-list paths.
- `CartService` includes variant identity in its cart-item merge criteria.
- Order confirmation currently passes `product_variant_id` into the stock helpers.
- Sales-return draft creation currently passes both stock ID and variant ID to `Helper::adjustStock`.
- Order-detail serialization includes variant fields in at least the primary public order-detail mapping.
- Tenant middleware sets the Filament tenant before the global company scope is applied.

These strengths do not remove the blockers below; they provide a solid base for repair.

---

## 5. Confirmed backend defects and required changes

## B-01 — Critical: client/server stock fallback mismatch

### Current behavior

Flutter intentionally falls back to general stock when a selected variant has no variant-scoped stock. Backend `CartService::validateStock()` does not. With a variant ID it filters strictly to `product_variant_id = selected variant`.

`OrderHelper::validateStock()` and `Helper::adjustStock()` follow the same strict behavior when no explicit stock ID is supplied.

### Failure scenario

1. Create a product with variants and opening quantity through the mobile/API product creation flow.
2. Backend creates one general `product_stocks` row with `product_variant_id = null`.
3. Backend creates the variants afterward.
4. Flutter selects a variant and falls back to the general stock row.
5. Checkout sends both `product_variant_id` and the general `stock_id`.
6. Depending on path and validation stage, backend sees zero variant stock or accepts an incoherent stock/variant combination.
7. Order fails or stock is adjusted inconsistently.

### Required change

Adopt one policy. Recommended strict policy:

- remove general-stock fallback for a variant-controlled product;
- create stock rows per variant during opening-stock creation;
- require variant-scoped stock IDs for variant lines;
- reject mixed general-stock + variant payloads;
- provide a migration/admin workflow to allocate existing general stock across variants.

### Acceptance tests

- Variant A cannot consume Variant B stock.
- A variant line cannot consume general stock under strict policy.
- A non-variant line cannot consume variant stock.
- Opening stock created for variants is visible and sellable immediately.
- Existing legacy products receive a clear migration/validation error rather than silent fallback.

## B-02 — Critical: dual and stale quantity sources

### Current behavior

- `product_variants.quantity` defaults to zero.
- `ProductVariantResource` returns that stored value.
- stock sales modify `product_stocks.quantity`.
- `syncProductVariants()` does not store the quantity sent by the Flutter variant editor.
- a single variant quantity cannot represent multiple stores.

### Required change

Preferred option:

- stop using `product_variants.quantity` as live availability;
- expose computed quantity from stock sums, optionally as `available_quantity`;
- accept `store_id` in catalog queries and compute store-specific availability;
- make the Flutter variant quantity field a stock-allocation workflow, not a variant metadata field.

If the column must remain for reporting, mark it as derived and update it through a dedicated stock-domain service in the same transaction as every stock mutation.

### Backfill

```sql
-- Concept only; adapt to the actual database engine and store semantics.
UPDATE product_variants pv
SET quantity = (
  SELECT COALESCE(SUM(ps.quantity), 0)
  FROM product_stocks ps
  WHERE ps.product_variant_id = pv.id
    AND ps.deleted_at IS NULL
);
```

Do not treat that one-time backfill as a permanent synchronization solution.

## B-03 — Critical: stock check/decrement race

### Current behavior

The order path validates stock and later decrements it without locking the same rows. `Helper::adjustStock()` performs read-modify-write and returns `false` when it cannot deduct, but the caller does not consistently turn that false return into a transaction failure.

### Failure scenario

Two tills sell the last unit concurrently:

1. transaction A reads quantity 1;
2. transaction B reads quantity 1;
3. both validate successfully;
4. A decrements to zero;
5. B either fails to decrement silently or writes an invalid result depending on the selected path;
6. both orders may commit.

### Required change

Create a stock allocation service, for example:

```php
final class AllocateSaleStock
{
    public function allocate(SaleLineInput $line): StockAllocationResult
    {
        return DB::transaction(function () use ($line) {
            $rows = ProductStock::query()
                ->where('company_id', $line->companyId)
                ->where('product_id', $line->productId)
                ->where('product_variant_id', $line->variantId)
                ->where('store_id', $line->storeId)
                ->whereIn('id', $line->permittedStockIds)
                ->orderBy('expiry_date')
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            // Validate, allocate and decrement every required base unit.
            // Throw if remaining quantity is non-zero and oversell is forbidden.
        });
    }
}
```

The exact class name is optional. Centralized, locked behavior is required.

## B-04 — Critical: relationship validation is incomplete

### Current validation

`CartService` checks that IDs exist, but existence alone does not prove the graph is coherent.

### Required relational checks

For every line, assert:

```text
product.company_id == current tenant
variant.company_id == current tenant
variant.product_id == product.id
variant.active == true for new sale
stock.company_id == current tenant
stock.product_id == product.id
stock.product_variant_id == variant.id for variant line
stock.store_id == requested active store
sale_unit.company_id == current tenant
sale_unit.product_id == product.id
```

Use scoped `Rule::exists(...)->where(...)` rules where possible, then repeat invariant checks after loading the models. Validation rules alone are not enough for concurrent state.

### Tenant issue in product creation

`ProductController::createProduct()` currently accepts `request.company_id` before `Helper::tenantId()`. The request must never be allowed to select the write tenant. Always use the authenticated/current tenant.

## B-05 — Critical unless intentional: arbitrary client price wins

### Current behavior

`CartService::determineUnitPrice()` returns an explicit client price before checking variant, stock or product pricing.

The request accepts zero as a valid price. This permits a modified client to sell at an arbitrary amount unless the endpoint is intentionally an unrestricted cashier price-override API.

### Required change

Split normal price and override price:

```json
{
  "product_id": 10,
  "product_variant_id": 44,
  "stock_id": 91,
  "quantity": 2,
  "sale_unit_id": null,
  "manual_price_override": {
    "amount": "89.00",
    "reason": "manager-approved damaged box"
  }
}
```

Rules:

- absence of `manual_price_override` means the server calculates price;
- override requires a permission/policy check;
- validate minimum margin;
- store user, reason, original resolved price, override price and timestamp;
- never infer authorization merely because `price` was supplied.

## B-06 — High: oversell policy exists only in Flutter

### Current behavior

Flutter can confirm “sell anyway” and emits an unreserved remainder. Backend stock validation still rejects insufficient stock.

### Required change

Choose one:

1. Remove oversell from Flutter; or
2. implement a server-authorized oversell contract.

Recommended server contract:

```json
{
  "allow_oversell": true,
  "oversell_reason": "physical count differs from system",
  "manager_authorization_id": 123
}
```

The server must verify tenant setting, user permission and reason, and record an audit event. It must return the actual reserved and oversold quantities.

## B-07 — Critical: return stock is restored twice

### Current behavior

`OrderController::salesReturn()` restores stock when the draft return item is created. `completeReturnOrder()` restores the same physical stock again when the return is completed.

Additional inconsistencies:

- draft restoration uses submitted display quantity without consistently applying the sale-unit conversion rate;
- completion restoration converts to base quantity;
- completion does not pass `product_variant_id` to `Helper::adjustStock`.

### Required change

Restore stock exactly once, preferably when the return transitions to completed.

Add an idempotent stock movement record containing:

- return ID and return-item ID;
- original cart-item ID;
- company/store/product/variant/stock IDs;
- base quantity restored;
- unique movement key such as `return:{return_item_id}:complete`.

Enforce a unique index on that movement key or equivalent reference columns.

### Acceptance tests

- creating a draft return does not change physical stock;
- completing restores the correct base quantity once;
- retrying completion does not restore again;
- a CASE return restores CASE conversion-rate base units;
- a variant return restores the original variant stock row;
- a partial return followed by another partial return restores each accepted quantity once.

## B-08 — High: variant barcode namespace is not enforced

### Current behavior

- product and sale-unit creation validates collisions between those two domains;
- `variants.*.barcode` receives only basic string validation;
- database variant barcode is nullable and not uniquely indexed;
- SKU is globally unique, not `(company_id, sku)` unique;
- soft-deleted SKU rows continue occupying the global unique value.

### Required change

Introduce normalized barcode handling:

- trim all barcode inputs;
- decide whether alphabetic barcodes are case-sensitive; usually normalize consistently;
- reject variant barcode collisions with products, sale units and other variants in the same tenant;
- add appropriate indexes;
- change SKU uniqueness to tenant-scoped uniqueness;
- define soft-delete reuse policy explicitly.

Because barcode values span multiple tables, one unique database constraint cannot cover the complete namespace. Use a centralized `barcode_identities` table or a transactional barcode registry if strong cross-table uniqueness is required.

## B-09 — High: product/variant create and edit are not atomic as one aggregate

### Current behavior

`syncProductVariants()` has its own transaction, but product, opening stock, names, sale units, unit prices and variants are not created as one aggregate transaction. A later failure can leave a partially configured product.

### Required change

Move create/edit orchestration into an application service with one outer transaction. Nested domain operations should participate in that transaction rather than commit independent partial state.

## B-10 — High: all-inactive variants can become a base sale

### Current behavior

Catalog queries generally return only active variants. A client receiving an empty array cannot distinguish:

- a genuine non-variant product; from
- a variant-controlled product whose variants are all inactive.

### Required change

Persist and expose `variant_mode`/`has_variants`. Enforce it during cart creation and checkout.

Suggested response fields:

```json
{
  "product_id": 10,
  "variant_mode": true,
  "active_variant_count": 0,
  "variants": []
}
```

The client should disable sale and explain that no active variants are available.

## B-11 — Medium: order-detail response shapes are inconsistent

The primary public order-detail mapping contains `product_variant_id` and `variant_attributes`, while the protected checkout-response builder has a separate item mapping that does not consistently expose them.

Required change:

- create one order-line API resource;
- reuse it for public details, checkout response, saved orders, executive views and returns;
- include variant snapshot fields consistently.

## B-12 — Medium: precision contract is inconsistent

Current layers mix:

- database decimal scale 3;
- Eloquent decimal cast scale 2;
- PHP floats in calculation paths;
- Flutter doubles.

Required change:

- define supported currency scale per tenant/currency;
- use decimal strings or a money value object at API boundaries;
- avoid binary floating-point for authoritative totals;
- standardize variant, stock, cart and invoice rounding.

---

## 6. Recommended schema changes

Migration details depend on the production database. The following is a design checklist, not copy-paste SQL.

### Products

Add a persistent variant-mode flag:

```php
$table->boolean('variant_mode')->default(false)->index();
```

Backfill true where a product has any variant, including soft-deleted/inactive variants according to the chosen business rule.

### Product variants

- Replace global `sku` uniqueness with tenant-scoped uniqueness.
- Add an index such as `(company_id, product_id, active)`.
- Add `(company_id, barcode)` index even if full uniqueness is enforced through a registry.
- Decide whether to remove `quantity` or document it as derived only.
- Align decimal scale between migration and model casts.

### Product stocks

Add indexes supporting locked allocation queries:

```text
(company_id, store_id, product_id, product_variant_id, quantity)
(product_id, product_variant_id, store_id, expiry_date, id)
```

Database foreign keys cannot ensure variant/product equality. Add application invariant checks and a repair audit for existing rows.

### Stock movements

If not already available with equivalent semantics, create an immutable movement ledger containing:

- movement type;
- company/store/product/variant/stock IDs;
- signed base quantity;
- before/after quantity;
- source type and source ID;
- idempotency key;
- actor and timestamp.

This greatly simplifies return idempotency, audits and reconciliation.

---

## 7. Recommended API contract

### 7.1 Catalog variant response

```json
{
  "id": 44,
  "sku": "TS-RED-L",
  "barcode": "8900000044",
  "price": "349.000",
  "mrp": "399.000",
  "purchase_price": "220.000",
  "active": true,
  "attributes": {
    "COLOR": "Red",
    "SIZE": "L"
  },
  "available_quantity": "7.000",
  "stock_tracked": true,
  "images": []
}
```

`available_quantity` should reflect the requested/active store. If availability is intentionally withheld, return null instead of a misleading zero.

### 7.2 Checkout request line

```json
{
  "client_line_id": "uuid-from-terminal",
  "product_id": 10,
  "product_variant_id": 44,
  "stock_allocations": [
    {"stock_id": 91, "base_quantity": "2.000"}
  ],
  "display_quantity": "2.000",
  "base_quantity": "2.000",
  "product_sale_unit_id": null,
  "expected_catalog_version": "optional-version-token",
  "manual_price_override": null,
  "comment": "no bag"
}
```

The server should not need `variant_attributes` from the client. It creates the snapshot from the validated variant at checkout.

### 7.3 Checkout response line

Return authoritative values:

```json
{
  "client_line_id": "uuid-from-terminal",
  "cart_item_id": 555,
  "product_id": 10,
  "product_variant_id": 44,
  "variant_attributes": {"COLOR": "Red", "SIZE": "L"},
  "base_quantity": "2.000",
  "unit_price": "349.000",
  "tax_amount": "37.393",
  "line_total": "698.000",
  "reserved_quantity": "2.000",
  "oversold_quantity": "0.000"
}
```

---

## 8. Implementation sequence

### Phase 0 — Decide and document business rules

Decide these before code changes:

- strict variant stock versus general fallback;
- server price precedence;
- whether overselling is supported;
- whether SKU/barcode reuse after soft delete is allowed;
- currency precision;
- when returns affect stock;
- whether inactive/deleted variants remain printable and returnable historically.

Recommended answers in this document are strict variant stock, server-authoritative pricing, permission-gated oversell, and stock restoration only at completed return.

### Phase 1 — Protect inventory and checkout

1. Add relationship-aware request validation.
2. Centralize price resolution.
3. Centralize locked stock allocation.
4. Make failed deduction throw and roll back.
5. Remove request-controlled tenant ID.
6. Add server oversell enforcement or remove oversell.

### Phase 2 — Fix quantity and catalog contract

1. Add `variant_mode`.
2. Derive variant availability from store-specific stock.
3. Stop exposing stale `product_variants.quantity` as live stock.
4. Create/allocate opening stock per variant.

### Phase 3 — Fix returns and history

1. Remove draft-time physical restoration.
2. Add idempotent completion restoration.
3. Pass variant and original stock identity through every return path.
4. Use one order-line resource across responses.

### Phase 4 — Uniqueness, migration and hardening

1. Introduce tenant-wide barcode validation/registry.
2. Fix tenant-scoped SKU uniqueness.
3. Audit existing mismatched stock/variant/product rows.
4. Migrate legacy general stock for variant products.
5. Add reconciliation reports.

---

## 9. Required backend test matrix

### Catalog and CRUD

- Create variants with attributes and verify flattened response.
- Edit one variant without deleting omitted variants.
- Delete one variant and preserve historical cart snapshots.
- Reject a variant ID belonging to another product.
- Reject a property belonging to another tenant.
- Verify `variant_mode` remains true when all variants are inactive.
- Verify variant images serialize without N+1 behavior.

### Barcode and SKU

- Reject variant barcode equal to product barcode.
- Reject variant barcode equal to sale-unit barcode.
- Reject duplicate variant barcodes in one request and across existing rows.
- Allow the same SKU in different tenants when tenant-scoped uniqueness is selected.
- Exercise the chosen soft-delete reuse policy.

### Price

- Variant override versus product fallback.
- Stock price versus variant price according to chosen precedence.
- Sale-unit master price.
- Stock-specific sale-unit override.
- Variant plus sale unit.
- Tampered client price without override permission.
- Authorized override above and below minimum margin.
- Decimal rounding at the supported currency scale.

### Stock

- Non-variant general stock sale.
- Variant-scoped stock sale.
- Wrong variant stock ID rejected.
- Wrong store stock ID rejected.
- Split allocation across two stock rows.
- Insufficient stock rolls back order and all deductions.
- Concurrent last-unit checkouts: exactly one succeeds.
- Oversell forbidden.
- Oversell authorized and audited, if supported.

### Returns

- Draft return does not restock.
- Completed return restocks once.
- Repeated completion is idempotent.
- Variant return restores correct variant.
- Sale-unit return restores converted base quantity.
- Partial returns never exceed original quantity.

### Tenant isolation

- Request `company_id` cannot redirect writes.
- Product/variant/stock/sale unit from another tenant is rejected.
- Cross-tenant barcode and SKU behavior matches the chosen uniqueness policy.

### Contract integration

- Send the exact Flutter checkout payload into `/order/add-to-order`.
- Assert authoritative response contains variant identity and snapshot.
- Assert order-details and return-list responses retain the same fields.

---

## 10. Observability and operational requirements

Production rollout should include:

- structured logs for rejected relationship graphs;
- stock allocation and oversell audit events;
- metrics for insufficient-stock failures after the client showed availability;
- metrics for price overrides and minimum-margin rejections;
- reconciliation query comparing variant aggregate/reporting quantity with stock sums;
- alerting for negative stock or an order whose required stock movement is missing;
- correlation ID from Flutter checkout through cart, order and stock movement.

Do not log full customer information, access tokens, tenant API keys or unredacted payment data.

---

## 11. Definition of done for backend production readiness

The backend portion is ready only when all of the following are true:

- [ ] Variant-mode products cannot be sold without a valid active variant.
- [ ] Product, variant, stock, store and sale unit are validated as one tenant-scoped graph.
- [ ] Variant availability comes from authoritative store-specific stock.
- [ ] Client and backend implement the same stock policy.
- [ ] Server calculates price or explicitly authorizes/audits an override.
- [ ] Stock validation and decrement use locks/atomic mutation in the order transaction.
- [ ] A failed deduction fails the order.
- [ ] Returns restore converted base quantity exactly once.
- [ ] Variant, product and sale-unit barcode collisions are rejected tenant-wide.
- [ ] Product/variant aggregate creation is transactional.
- [ ] Order and return responses use a consistent variant-aware line resource.
- [ ] Backend feature tests cover all scenarios in Section 9.
- [ ] A legacy-data migration and reconciliation report have been run before rollout.

---

## 12. Cross-document dependency

The companion `frontent-changes-varient.md` describes the Flutter changes. Backend and frontend work must be coordinated around the same canonical rules. In particular, do not independently change:

- stock fallback behavior;
- price precedence;
- sale-unit quantity semantics;
- oversell behavior;
- active/inactive variant handling;
- barcode normalization;
- checkout request/response fields.

Those are shared contracts, not layer-local implementation details.
