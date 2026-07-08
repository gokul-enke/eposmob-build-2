# Backend Product Variants — Implementation Audit

Scope: `enkepos/` Laravel backend, audited against `PRODUCT_VARIANTS_API.md`.

## Summary

| # | Section | Status |
|---|---|---|
| — | Data model | Implemented, with bugs |
| 1 | Create | Implemented, minor issue |
| 2 | Edit | Implemented correctly |
| 3 | Get Products | Implemented, with bug (carries N+1) |
| 4 | Add to Order | **Implemented but broken** — pricing precedence missing, stock scoping dropped at confirm time |
| 5 | Sales Return | **Missing** — no stock restoration logic at all |
| 6 | Order Details | Implemented correctly |
| — | `PRODUCT_VARIANT_ENABLED` gate | Web-only, API unguarded (documented in spec, not a bug) |

---

## Data model — implemented, with bugs

Tables (`product_variants`, `product_variant_attributes`, `cart_items.product_variant_id/variant_attributes`, `product_stocks.product_variant_id`, `product_attachments.product_variant_id`) all match spec. Migrations are correct (unique SKU, soft deletes, indexes, sensible cascade/nullOnDelete rules).

### Bug: attribute key uses prop `name`, not `code`
Spec's variant object shows `attributes: { "COLOR": "Red", "SIZE": "L" }` keyed by prop **code**. But:

```php
// app/Models/ProductVariant.php:122-134
public function getAttributesAttribute(): array
{
    return $this->variantAttributes()->with('productProp')->get()
        ->mapWithKeys(fn($attr) => [$attr->productProp->name => $attr->value])
        ->toArray();
}
```

This keys by `productProp->name` (human label) instead of `productProp->code`, while the rest of the codebase (`ProductController.php:63,188,900`) treats `code` as the machine key. Clients filtering/rendering by `COLOR`/`SIZE` will get mismatched keys.

### Bug: N+1 despite eager-loading
`getAttributesAttribute()` / `getFormattedAttributesAttribute()` / `generateSku()` call `$this->variantAttributes()->with('productProp')->get()` — a **fresh query**, not the already-eager-loaded `$this->variantAttributes` relation. Even though controllers eager-load `variants.variantAttributes.productProp`, this accessor re-queries per variant per product on every list/detail response.

**Fix:** use `$this->variantAttributes` (loaded collection) instead of calling `variantAttributes()` as a fresh query builder, and switch the map key to `productProp->code`.

---

## 1. Create — `POST /product/create-product` — implemented, minor issue

`ProductController.php:637-942`, variant sync via `syncProductVariants()` (`:2509-2557`).

- Validation matches spec exactly (`:696-706`).
- SKU auto-generation on blank `sku` works via `creating()` boot hook.
- Response returns `ProductVariantResource::collection($product->variants)` with proper eager-load — but inherits the N+1 accessor bug above.
- Note: create's eager-load is intentionally not active-only (echoes back everything just created) — this is correct, not a bug.

---

## 2. Edit — `POST /product/edit-product/{id}` — implemented correctly

`ProductController.php:945-1230` → `syncProductVariants()` (`:2509-2557`).

- `variants.*.id` and `variants.*._delete` validation matches spec.
- Action table matches spec exactly: no `id` → create; `id` + `_delete` → delete variant + attributes; `id` only → update; omitted → untouched.
- Attributes fully replaced every save (`delete()` then recreate) — matches spec.
- Whole sync wrapped in `DB::transaction()`.

No bugs found.

---

## 3. Get Products — implemented, N+1 carries through

- `list_product`, executive `list_products`, and `get_product`/`{slug}` all correctly eager-load `variants` scoped to `where('active', true)` — **the "only active variants eager-loaded" claim is verified true**.
- `ProductVariantResource` shape matches spec field-for-field except the `attributes` key bug above.
- `ProductCollection.php:38-40` defensively checks `relationLoaded('variants')` before mapping — good.

---

## 4. Add to Order — `POST /order/add-to-order` — implemented but broken

Validation is correct (`items.*.product_variant_id => nullable|exists:product_variants,id`).

**Cart-add time is correct**: `CartService::validateStock()` (`:251-299`) properly scopes stock by variant, and `updateOrCreateCartItem()` stores `product_variant_id` + `variant_attributes` snapshot correctly.

### Bug: pricing precedence "variant → product" not implemented
`CartService::determineUnitPrice()` (`:218-246`) never reads the variant's `price`/`mrp` (the `ProductVariant::$effective_price`/`$effective_mrp` accessors at `ProductVariant.php:165-176` exist but are unused here). It only considers explicit client price → stock retail price → product price. If a client picks a variant without passing an explicit price, the order is priced off the base product, contradicting the spec.

### Critical bug: variant id dropped at order-confirm time
The stock helpers support variant scoping:
```php
// app/Helper/OrderHelper.php:1213
public static function validateStock($productId, $quantity, $productVariantId = null)
// app/Helper/Helper.php:243
public static function adjustStock($productId, $quantity, $increment = false, $productStockId = null, $productVariantId = null): bool
```
But `OrderController` never passes it through:
```php
// app/Http/Controllers/Api/V1/OrderController.php:387-401
foreach ($cart->cartItems as $cartItem) {
    OrderHelper::validateStock($cartItem->product_id, $cartItem->quantity); // missing product_variant_id
}
// :437-456
Helper::adjustStock($cartItem->product_id, $baseQuantity, false); // missing product_stock_id AND product_variant_id
```
Effect: every order-confirm stock check/adjustment falls into the "no variant" (`whereNull('product_variant_id')`) branch, even when the cart item has a variant. Consequences:
- If stock only exists on a variant-scoped row, validation sees 0 stock (can wrongly reject valid orders), and/or `adjustStock` returns `false` silently (return value unchecked) — variant stock is **never decremented**.
- If a general stock row also exists for the same product, that unrelated row gets decremented instead — wrong-row stock corruption.

**Fix:** thread `$cartItem->product_variant_id` through both `validateStockForCartItems` and `adjustStockForCartItems` call sites into `OrderHelper::validateStock` / `Helper::adjustStock`, and check `adjustStock`'s boolean return.

---

## 5. Sales Return — `POST /order/sales-return` — missing

`OrderController::salesReturn()` (`:1728-1815`) validates input, computes already-returned quantity, and creates `OrderReturn`/`OrderReturnItem` rows — but **never calls `Helper::adjustStock(..., increment: true, ...)`** anywhere. Confirmed via grep: `adjustStock` is only referenced in `OrderController` (add-to-order path), `Helper.php`, `StockService.php`, `StockManagementController.php`, and unrelated Filament pages — none wired to `salesReturn()`.

Result: the spec's claim "stock is restored to the correct variant" is **not implemented at all** — no stock row (variant or general) is restored on return. `product_variant_id`/`variant_attributes` are correctly preserved (nothing mutates them), but physical stock restoration is entirely missing.

**Fix:** in `salesReturn()`, after creating the `OrderReturnItem`, call `Helper::adjustStock($cartItem->product_id, $returnedQty, increment: true, $cartItem->product_stock_id, $cartItem->product_variant_id)`.

---

## 6. Order Details — implemented correctly

`CartHelper::listCartItems()` includes `product_variant_id` and `variant_attributes` (cast to array on `CartItem`) exactly per spec. Executive variant follows the same pattern.

---

## `PRODUCT_VARIANT_ENABLED` — web-only gate, API unguarded

Only referenced in Filament (`ManageVariants.php`, `ProductResource.php`, `ProductStockCreate.php`) and the settings seeder. **No API controller checks it** — this matches the spec's own disclosure ("the API still stores whatever is sent"), so it's documented/intentional, not a bug. Worth flagging: a misconfigured/malicious mobile client can create/edit variants via the API even when the tenant setting is `0`.

---

## Priority fix list

1. **Critical** — Thread `product_variant_id` through order-confirm stock validate/adjust (`OrderController.php:387-401, 437-456`). Currently causes stock corruption or silent non-deduction for variant products.
2. **High** — Implement stock restoration in `salesReturn()` (`OrderController.php:1728-1815`). Returns currently never restore stock.
3. **High** — Fix pricing precedence in `CartService::determineUnitPrice()` to check variant price/mrp before falling back to product price.
4. **Medium** — Fix `ProductVariant::getAttributesAttribute()` to key by `code` not `name`, and use the loaded relation instead of re-querying (N+1).
