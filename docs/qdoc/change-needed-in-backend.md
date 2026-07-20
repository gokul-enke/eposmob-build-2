# Backend changes needed — Product Variants

Found while auditing the variant system against `PRODUCT_VARIANTS_API.md`. Ordered by priority. File:line refs are in `enkepos/`.

---

## 1. [Critical] Order-confirm stock validate/adjust drops `product_variant_id`

Cart-add already scopes stock correctly per variant. But at the actual order-confirm step, the variant id is never passed through, so stock checks/deductions run as if every line were a plain (non-variant) product.

```php
// app/Http/Controllers/Api/V1/OrderController.php:387-401
foreach ($cart->cartItems as $cartItem) {
    OrderHelper::validateStock($cartItem->product_id, $cartItem->quantity); // missing product_variant_id
}
// :437-456
Helper::adjustStock($cartItem->product_id, $baseQuantity, false); // missing product_stock_id AND product_variant_id
```

Both helpers already accept a `$productVariantId` param (`OrderHelper::validateStock`, `Helper::adjustStock`) — they're just not being given it.

**Impact:** for products where stock is tracked only at the variant level (no general stock row), this can wrongly reject a valid order, or silently fail to deduct stock at all (the `adjustStock` return value isn't checked). If a general stock row also exists for the same product, that unrelated row gets decremented instead — wrong-row stock corruption.

**Fix:** pass `$cartItem->product_variant_id` (and `$cartItem->product_stock_id` where available) into both calls.

---

## 2. [High] Sales return never restores stock

`OrderController::salesReturn()` (`:1728-1815`) creates the `OrderReturn`/`OrderReturnItem` rows and recomputes refund totals, but never calls `Helper::adjustStock(..., increment: true, ...)` anywhere. Confirmed via grep — no stock-restoration call exists on this path at all, for variant or non-variant products.

**Impact:** stock is never restored on a return, regardless of variant.

**Fix:** in `salesReturn()`, after the `OrderReturnItem` is created, call `Helper::adjustStock($cartItem->product_id, $returnedQty, increment: true, $cartItem->product_stock_id, $cartItem->product_variant_id)`.

---

## 3. [High] Cart pricing never applies variant price/mrp

Spec states pricing precedence is "variant price → product price," but `CartService::determineUnitPrice()` (`:218-246`) only checks: explicit client price → stock's `retail_price` → product price. It never reads the variant's own `price`/`mrp` (the `ProductVariant::$effective_price`/`$effective_mrp` accessors already exist at `ProductVariant.php:165-176` but are unused here).

**Impact:** if a client adds a variant without passing an explicit price, the order is priced off the base product/stock instead of the variant.

**Fix:** in `determineUnitPrice()`, when `$productVariantId` is set and no explicit price was given, use the variant's effective price/mrp before falling back to stock/product price.

---

## 4. [Medium] Variant `attributes` keyed by prop name instead of code

```php
// app/Models/ProductVariant.php:122-134
public function getAttributesAttribute(): array
{
    return $this->variantAttributes()->with('productProp')->get()
        ->mapWithKeys(fn($attr) => [$attr->productProp->name => $attr->value])
        ->toArray();
}
```

Spec's variant shape (`PRODUCT_VARIANTS_API.md` line 128) keys attributes by prop **code** (e.g. `COLOR`, `SIZE`), matching how the rest of the API treats props (`ProductController.php:63,188,900`). This accessor uses `productProp->name` (the human label) instead.

**Impact:** the Flutter app's attribute-parsing already expects code-keyed maps in some places; a client matching against `COLOR`/`SIZE` will get mismatched keys if `name` differs from `code`.

**Fix:** change the map key from `$attr->productProp->name` to `$attr->productProp->code`.

---

## 5. [Medium] N+1 query on variant attributes despite eager-loading

Same accessor (and `getFormattedAttributesAttribute()`, `generateSku()`) calls `$this->variantAttributes()->with('productProp')->get()` — this is a **fresh query builder call**, not the already-eager-loaded `$this->variantAttributes` relation. Controllers correctly eager-load `variants.variantAttributes.productProp`, but this accessor ignores that and re-queries per variant on every product list/detail response.

**Fix:** use the loaded relation (`$this->variantAttributes`) instead of calling `variantAttributes()` as a query builder.

---

## 6. [Low / by design, confirm intent] `PRODUCT_VARIANT_ENABLED` is not enforced on the API

Only the Filament (web admin) side checks this setting (`ManageVariants.php:45-51` and similar). No API controller (`ProductController`, `OrderController`, `CartService`) checks it at all — a client can create/edit/add variants via the API even when the tenant has variants disabled. This matches what the spec doc already discloses ("the API still stores whatever is sent"), so it may be intentional — flagging just to confirm this is the desired behavior, since it means the setting is purely a UI toggle with no server-side enforcement.

---

## Quick summary

| # | Issue | File |
|---|---|---|
| 1 | Order-confirm stock ops drop `product_variant_id` | `OrderController.php:387-401, 437-456` |
| 2 | Sales return never restores stock | `OrderController.php:1728-1815` |
| 3 | Cart pricing ignores variant price/mrp | `CartService.php:218-246` (`determineUnitPrice`) |
| 4 | Attributes keyed by `name` not `code` | `ProductVariant.php:122-134` |
| 5 | N+1 on variant attributes accessor | `ProductVariant.php` (`getAttributesAttribute`, `getFormattedAttributesAttribute`, `generateSku`) |
| 6 | `PRODUCT_VARIANT_ENABLED` unenforced on API | confirm intent |
