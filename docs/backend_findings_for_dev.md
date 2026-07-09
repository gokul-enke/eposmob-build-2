# Backend Findings — For Backend Dev Review

Source: a review of `enkepos/` (Laravel/Filament) against what the Flutter POS app (`eposmob/`) actually sends and expects, covering (1) cart/billing flows and (2) product create/edit. All line numbers were correct at time of review — re-check before fixing if the file has since moved.

No backend code was changed. This is a findings list for triage and fixing.

---

## Priority 1 — Silent data corruption / security bypass

### 1. Editing a product's quantity is additive, not absolute (silent stock inflation)

**File:** `app/Http/Controllers/Api/V1/ProductController.php`, `editProduct()`, ~line 1124

```php
$stock->quantity = ($stock->quantity ?? 0) + $request->quantity;
```

The app's edit-product dialog (`lib/widgets/product_details_dialog.dart:527`) leaves the quantity field **blank by default** — it does not pre-fill the current stock count. So a user opening the dialog to "correct" the stock and typing `50` (thinking that's the new total) will actually get `existing + 50`, silently inflating stock with no warning on either side.

**Fix options (pick one):**
- Make edit-time quantity an absolute **set**, matching what a blank-then-typed field implies to a user, or
- Add an explicit `quantity_mode` param (`set` / `add`) so app and backend agree on intent, and update the app to send it explicitly.

Either way, coordinate with the app side since the current field's blank-by-default UX assumes "set," not "add."

---

### 2. `min_margin_percentage` / `min_margin_price` price floor is enforced only client-side

**Files:** `app/Services/CartService.php` (`validateMultipleRequest`, ~lines 167-190; `addMultipleToCart`, ~lines 82-135)

The product's `min_margin_percentage`/`min_margin_price` columns exist and are returned in API responses (`ProductController.php:475-476,672-674,740-741,985-986`), but nothing in `CartService` reads them when validating an incoming cart-item price. The only server-side price check is `items.*.price => nullable|numeric|min:0`.

**Impact:** any client that talks to the API directly (not through the official app) — or a modified/rooted build of the app — can submit any non-negative price, completely bypassing the configured margin floor. The app's own UI enforcement (`local_product_provider.dart:2932-2951`) is correct as far as it goes, but there is no server-side backstop.

**Fix:** in `CartService::validateMultipleRequest` (or right before/in `addMultipleToCart`), look up each product's `min_margin_percentage`/`min_margin_price`, compute the same floor the app computes, and reject or clamp any submitted price below it.

---

### 3. `sellable` flag (category `is_sellable`) is enforced only client-side

**Files:** `app/Services/CartService.php` (`addMultipleToCart`), `app/Http/Controllers/Api/V1/OrderController.php`

`sellable` is correctly derived from the product's category (`'sellable' => $product->category?->is_sellable`, `ProductController.php:464,864,1288`) and consumed correctly by the app to block adding non-sellable products in the UI. But no code in `CartService`/`OrderController` re-checks `is_sellable` when an order is actually submitted.

**Impact:** a bypassed client (direct API call) can add and sell a product flagged as not-sellable — the guard exists nowhere except the app's own UI.

**Fix:** add an `is_sellable` check in `CartService::addMultipleToCart` (or wherever items are validated before persisting to an order), rejecting any product whose category has `is_sellable = false`.

---

## Priority 2 — Wrong HTTP semantics / broken error messages

### 4. Product-create validation failures return HTTP 500 instead of 422

**File:** `app/Http/Controllers/Api/V1/ProductController.php`, `createProduct()`, ~line 710

```php
return $this->errorResponse($validator->errors(), []);
```

`errorResponse()` (`app/Http/Traits/ApiResponseTrait.php:21`) defaults its status code to **500** when none is passed. So a duplicate-barcode/SKU error, or any other validation failure on product create, comes back as a server error, not a client error. `editProduct()` does this correctly two hundred lines later (`return $this->errorResponse($validator->errors(), 422);`, line 1041) — `createProduct` should match.

**Impact:** duplicate-barcode rejection (a completely normal user mistake) gets misclassified as a 500 in logs/monitoring, and any client code that branches on status code (not just message content) will treat a validation error as an infrastructure failure.

**Fix:** pass `422` explicitly in the `createProduct` validation-failure branch, same as `editProduct`.

---

### 5. Validation error payload is a raw `MessageBag`/array under `message`, not a clean string or a dedicated `errors` key

**Files:** both `createProduct` and `editProduct` in `ProductController.php`

The app's error-rendering code (`add_product_modal.dart:2878-2894`, `product_provider.dart:193`) does `.toString()` on `result['message']` expecting a string, and has a separate, nicer code path that looks for a structured `result['errors']` map — but the backend puts everything under `message`, so that nicer path never triggers. Users see something like a stringified object dump instead of "Barcode already exists."

**Fix:** either put `$validator->errors()` under a dedicated `errors` key (and put a plain human-readable summary string under `message`), or standardize on whichever shape the app's nicer error-rendering path expects. Coordinate with app side — this is a two-sided contract fix, not backend-only.

---

### 6. No `category_id` existence check on product create

**File:** `ProductController.php`, `createProduct()` validator, ~lines 642-707

`category_id` is required but has no `exists:categories,id` rule — `editProduct`'s validator does have this (line 956). A stale/deleted/invalid category id currently passes validation and hits `Product::create()` directly, which will either throw a raw FK-constraint DB error or (if the FK isn't enforced at the DB level) silently create an orphaned product.

**Fix:** add `'category_id' => 'required|integer|exists:categories,id'` to `createProduct`'s validation rules, matching `editProduct`.

---

## Priority 3 — Data loss (smaller, but real)

### 7. Variant `quantity` is silently dropped on BOTH create and edit — confirmed same root cause

**File:** `ProductController.php`, `syncProductVariants()`, lines 2509-2557

Confirmed directly in code: `createProduct()` (line 827) and `editProduct()` (line 1230) both call the **same** private `syncProductVariants()` method — there's only one variant-write path in the whole controller, not separate ones for create vs edit. Its `updateOrCreate` attributes array (lines 2532-2542) writes `sku, barcode, price, mrp, purchase_price, reorder_level, active, company_id` — `quantity` is never in that list, for either caller.

Additionally, the **validation rules don't even declare `variants.*.quantity`** on either endpoint (create: lines 696-706, edit: lines 1025-1037). Laravel doesn't reject unknown array keys by default, so if the app sends `quantity` per variant row today, it's silently accepted as an unvalidated extra field and then dropped by `syncProductVariants` regardless of whether it's a create or an edit call.

**Fix (single fix covers both endpoints):**
1. Add `'variants.*.quantity' => 'nullable|numeric|min:0'` to both validators (lines ~696-706 and ~1025-1037).
2. Add `'quantity' => $variantData['quantity'] ?? null` to the `updateOrCreate` attributes array in `syncProductVariants` (~line 2532-2542).

---

### Follow-up sweep: any other shared write-helpers dropping a field?

Given the variant-quantity bug, we did a targeted second pass: every `updateOrCreate(`, `::create(`, and `->fill(` call in `ProductController.php`, `OrderController.php`, and `CartService.php` was checked against its target model's `$fillable` and the actual Flutter payload builders, specifically looking for the same shape (a shared helper used by 2+ endpoints, missing a column the app actually sends). **No other instance of this pattern was found.** Checked and confirmed clean:

- Sale-unit sync (create + edit) — writes all of `ProductSaleUnit::$fillable`, no drop.
- `product_stocks` writes on create/edit — omit `wholesale_price`, `wholesale_min_unit`, `expiry_date`, `tax_rate`, `batch_number`, `rack` (all real columns), but confirmed the app's product create/edit screens never send these fields either — they're only sent via a separate purchase/stock-add flow, a different endpoint entirely. Not a live bug.
- `product_names` sync (create + edit) — writes both fillable columns, no drop.
- Order creation (`OrderController::createOrder`) — writes everything in `Order::$fillable`; the order-level `comment` the app sends is intentionally routed through a separate helper, not dropped.

**One small unrelated finding from the same sweep:** `CartService::updateOrCreateCartItem()` (`CartService.php:362-363`) sets `customer_id` and `store_id` in its `fill()` array, but neither is an actual column on `cart_items` or in `CartItem::$fillable` — Laravel silently no-ops both on every call. Not data loss (nothing the app sends is being dropped elsewhere because of it), just dead/confusing code worth deleting.

---

## Lower priority / FYI, not blocking

- **`CartService::updateOrCreateCartItem()` sets two fields that don't exist on the model.** `customer_id` and `store_id` (`CartService.php:362-363`) are passed to `fill()` but are not in `CartItem::$fillable` nor a column on `cart_items` at all — both are silent no-ops. Harmless today, but confusing for future maintainers who might assume these are actually being persisted. Recommend removing the two dead lines.
- **`unit_id` sent by the app on product edit is never read.** `editProduct` derives the base unit entirely from `$request->unit` (cast to int), never a top-level `$request->unit_id`. Currently harmless because the app happens to populate `unit` with the correct id as a fallback, but it's dead weight on the wire and would silently break if that fallback logic ever changes. No action required unless you want to clean it up — flag to app side if you do.
- **Fields the backend already supports on edit but the app never sends:** `sku`, `reorder_level`, `hsn_code` (`editProduct` lines ~1082-1084 accept them via `$request->x ?? $product->x`). Not a bug — just unused capability. Only relevant if the app team wants to expose these in the edit UI.
- **`list-product-properties` response shape** (`ProductController.php:2559-2614`): confirmed the real shape (`options` as a `{value: value}` map) already matches what the app's defensive parser expects. No backend change needed here — mentioned only so it's not re-flagged in a future review.
- **Product photo upload does not exist end-to-end.** Neither the app's create modal nor edit dialog send any image data, and `createProduct`/`editProduct` accept none. A separate legacy app screen references an "attach existing pre-uploaded image by ID" flow via different endpoints (`edit-product-image`, referenced in `lib/resources/app_url.dart:130`), but it appears disused. Not a backend bug — flagging in case product photo support is expected to work and currently silently doesn't.

---

## Already verified correct (no action needed)

- Stock/batch schema (`product_stocks` table/model) matches the app's `Stock` model field-for-field.
- Sale-unit conversion/price-resolution fallback chain (`ProductSaleUnit::resolvePrice`) matches the app's documented fallback exactly.
- Order-item submission payload (`buildOrderItemsPayloadFrom` → `CartService::validateMultipleRequest`) — all core fields match; the app's extra unused `product_sale_unit_id` key is harmlessly ignored.
- Stock cascade on product create — the single `createProduct` call already creates the initial `product_stocks` row server-side when `quantity > 0`; no second call is needed or made.
- Sale-unit sync on product edit — proper diff + `DB::transaction`, more robust than create's simpler create-only logic.
- Order-details and sales-return API responses already include `product_variant_id`/`variant_attributes` — the "receipt doesn't show variant" issue is confirmed to be purely an app-side print-template gap, not missing backend data.
