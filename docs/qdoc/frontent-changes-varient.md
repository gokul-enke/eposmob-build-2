# Flutter Frontend Variant System: Production Remediation and Implementation Handoff

> Requested filename uses `frontent` and `varient`; this document uses **frontend** and **variant** internally.

## Document status

- Repository: Flutter application rooted at `eposmob/`.
- Review date: 2026-07-10.
- Primary requested scope:
  - `lib/features/billing/`
  - `lib/helpers/product_cart_helper.dart`
  - `lib/providers/local_product_provider.dart`
- Related scope included because it participates in the same end-to-end contract:
  - product and stock models;
  - product variant create/edit UI;
  - checkout service and order payloads;
  - restaurant billing legacy paths;
  - Hive persistence;
  - order details, quotations and returns.
- This document supersedes the older `front-varient.md`, which describes an earlier state where variant resolution was not yet centralized.
- This began as a change plan and technical handoff. The implementation status below records the frontend remediation completed on 2026-07-10.

## Implementation update — 2026-07-10

The production-critical frontend slice has now been implemented and regression-tested. This does **not** make the end-to-end variant system production-ready by itself: the backend contract, transactional stock enforcement and conflict responses described in `backend-changes-varient.md` are still required.

| Finding | Frontend status | Notes |
|---|---|---|
| F-01 strict variant stock | Implemented | Variant lines use only exact `product_variant_id` stock; base lines use only general stock. No fallback remains. |
| F-02 Hive ordering | Implemented for cart/core writes | Writes are serialized, `flushPersistence()` reports failures, cart rows use stable line-ID keys, legacy integer keys migrate, and one corrupt cart row is isolated. Product/order bulk snapshots remain serialized full rewrites. |
| F-03 restaurant identity | Implemented | Increment and order restoration preserve variant ID/attributes, sale-unit identity, stock ID and fractional/base quantity conversion. |
| F-04 variant + sale-unit pricing | Implemented | New lines defer to the provider's single pricing chain; preview and insertion share the resolver. Sale-unit override/master/resolved price wins before variant price. |
| F-05 availability field | Client implemented; backend-dependent | `available_quantity` is preferred over legacy `quantity`; the backend must return the active-store derived value. |
| F-06 oversell | Implemented as an app policy | `ALLOW_OVERSELL` controls insufficient-stock blocking. Missing setting/default `true` allows oversell; explicit `false` restores strict frontend blocking. Compatible same-store/variant/pricing stock is allocated first in FEFO order, and only the remaining shortage is oversold. Variant stock identity remains strict in both modes. |
| F-07 empty active variants | Implemented; backend-dependent | `variant_mode`/`has_variants` is parsed and persisted. Variant-mode products with no active variants are blocked. Backend must emit the flag. |
| F-08 barcode ambiguity | Implemented defensively | Primary modern, desktop, restaurant and legacy mobile scan paths block when the local index returns multiple products. Backend uniqueness is still required. |
| F-09 setting gate | Implemented | The compatibility wrapper forwards `variantEnabled`; explicit settings are honored, with isolated-test compatibility for an already-selected variant. |
| F-10 canonical identity | Partially implemented | Every `LocalCartItem` now has an immutable stable `lineId`, preserved through Hive and snapshots. Several legacy mutation APIs still reconstruct the composite key and should later migrate to line-ID-only methods. |
| F-11 checkout reconciliation | Backend-dependent | The client still needs structured server conflict payloads before it can present authoritative stock/price reconciliation. |
| F-12 analyzer debt | Partially addressed | New core changes have no analyzer errors. Large billing screens retain pre-existing warnings and async-context notices. |
| F-13 logging | Not included in this slice | Existing verbose/mojibake logging remains a separate production-hardening task. |
| F-14 variant imagery | Not included in this slice | Picker imagery remains product-level. |

Regression evidence from this implementation:

- The earlier 122 focused tests passed across variant selection, picker behavior, cart identity, scoped stock, sale-unit pricing, payloads, Hive restart/migration/corruption handling and barcode indexing. After adding `ALLOW_OVERSELL` and compatible-stock-first allocation, 58 focused setting/cart/quantity/variant tests passed for both allow and strict modes.
- A repository-wide run reached 612 passing tests and exposed three stale/shared-Hive test assumptions plus an unrelated zero-price modal fixture that omits `KeyboardProvider`. The stock, sale-unit and persistence assumptions were corrected and their suites pass individually. The zero-price fixture remains outside this variant slice, so the repository-wide suite should not yet be represented as fully green.
- Targeted analyzer runs found no errors in the core and modern billing changes.
- The initial legacy restaurant analysis found a restoration-scope compile error; it was corrected, and the follow-up analysis found no errors (only the repository's existing warning/info backlog).

## Executive verdict

The core Flutter implementation is significantly better than a partial UI feature. Variant identity is represented in cart lines, payloads, saved orders, order details and stock reservations. Selection is now centralized in `ProductCartHelper`, so standard mobile and desktop entry points generally receive the same picker/barcode behavior.

It is still not production-ready because:

1. local stock fallback disagrees with the backend;
2. Hive writes are started without awaiting/serializing them;
3. some restaurant cart mutations drop variant identity;
4. variant plus sale-unit pricing bypasses the provider's intended price chain;
5. displayed variant quantity is based on a stale backend aggregate;
6. oversell confirmation has no compatible server contract;
7. barcode ambiguity is not blocked;
8. a product with no returned active variants can be sold as a base product;
9. cart operations use long optional parameter lists instead of one canonical line identity;
10. checkout relies too heavily on local snapshots without a server-authoritative revalidation result.

---

## 1. Important files and responsibilities

### Variant model and parsing

- `lib/models/get_product.dart`
  - `GetProduct.variants`
  - `GetProduct.hasVariants`
  - `GetProduct.activeVariants`
  - `ProductVariant`
  - `Stock.productVariantId`
  - variant attributes and images

### Variant selection

- `lib/features/billing/domain/product_variant_selection.dart`
  - barcode normalization/matching
  - single-active-variant auto-selection
  - picker requirement
  - display naming
  - price/MRP helpers
- `lib/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart`
  - mobile bottom sheet and desktop dialog
- `lib/features/billing/domain/add_product_with_variant.dart`
  - compatibility wrapper around the centralized helper

### Product-to-cart orchestration

- `lib/helpers/product_cart_helper.dart`
  - setting gate
  - variant resolution
  - sellable validation
  - oversell prompt
  - active-store stock filtering
  - stock group selection
  - sale-unit selection
  - zero-price prompt
  - final cart insertion

### Cart state and local persistence

- `lib/providers/local_product_provider.dart`
  - `LocalCartItem`
  - cart merge identity
  - stock reservations
  - pricing refresh
  - payload expansion
  - Hive persistence
  - saved orders
- `lib/models/local_models.dart`
- `lib/models/local_models.g.dart`

### Quantity controls

- `lib/helpers/cart_quantity_stock_helper.dart`
- `lib/widgets/compact_quantity_control_local.dart`
- billing/mobile/restaurant cart widgets

### Checkout

- `lib/services/checkout_service.dart`
- `lib/providers/cart.dart`
- `lib/features/billing/domain/quotation_checkout.dart`
- `lib/providers/billing_provider.dart`

### Variant CRUD

- `lib/features/products/domain/variant_form_payload.dart`
- `lib/features/products/presentation/variant_editor_section.dart`
- `lib/features/billing/presentation/pages/add_product_mobile.dart`
- other add/edit product dialogs using the same editor controller

### Historical display

- `lib/models/order_details.dart`
- `lib/models/list_sales_return_items.dart`
- receipt/print services and order-detail widgets

### Known legacy paths requiring attention

- `lib/screens/billing/billing_page_restaurant.dart`
- `lib/screens/billing/restaurant/widgets/order_panel.dart`
- other files under `lib/screens/billing/restaurant/`

### Verified evidence map

Line numbers below reflect the reviewed code state on 2026-07-10 and may shift after edits.

| Concern | Current source region |
|---|---|
| Product variant and stock parsing | `lib/models/get_product.dart:1046-1174` and `:784-1000` |
| Variant selection rules | `lib/features/billing/domain/product_variant_selection.dart:1-96` |
| Mobile/desktop picker presentation | `lib/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart:1-286` |
| Central variant resolution and setting gate | `lib/helpers/product_cart_helper.dart:90-126` |
| Client-only oversell confirmation | `lib/helpers/product_cart_helper.dart:191-216` and `:429-454` |
| Variant price pre-resolution | `lib/helpers/product_cart_helper.dart:223-240` |
| Variant stock filtering in add flow | `lib/helpers/product_cart_helper.dart:242-257` |
| Variant explicit price forwarded into cart | `lib/helpers/product_cart_helper.dart:478-530` and `:580-593` |
| Local cart item variant/sale-unit fields | `lib/providers/local_product_provider.dart:57-203` |
| Provider price precedence | `lib/providers/local_product_provider.dart:631-718` |
| Hive cart deserialization/serialization | `lib/providers/local_product_provider.dart:873-962` |
| Stock reservation and restore | `lib/providers/local_product_provider.dart:1106-1227` |
| Canonical behavior currently reconstructed by optional keys | `lib/providers/local_product_provider.dart:1278-1325` |
| Variant-aware checkout payload expansion | `lib/providers/local_product_provider.dart:1331-1403` |
| Local product/sale-unit/variant barcode index | `lib/providers/local_product_provider.dart:1405-1436` |
| Unawaited product-box rewrite | `lib/providers/local_product_provider.dart:1643-1661` |
| Unawaited cart-box rewrite | `lib/providers/local_product_provider.dart:1709-1724` |
| Provider add-to-cart merge and insertion | `lib/providers/local_product_provider.dart:2547-2728` |
| Client general-stock fallback | `lib/providers/local_product_provider.dart:4238-4256` |
| Store stock filtering | `lib/providers/local_product_provider.dart:4271-4306` |
| Restaurant order restoration drops variant identity | `lib/screens/billing/restaurant/widgets/order_panel.dart:6077-6093` |
| Restaurant plus control drops variant identity | `lib/screens/billing/billing_page_restaurant.dart:8307-8326` |
| Variant CRUD payload includes quantity | `lib/features/products/domain/variant_form_payload.dart:17-174` |
| Hive variant adapter fields | `lib/models/local_models.dart:18-96` |
| Checkout consumes provider payload | `lib/services/checkout_service.dart:194-250` and `:389-443` |

---

## 2. Current client-side architecture

## 2.1 Product and variant model

`GetProduct` contains:

- base product identity and pricing;
- product-level stock rows;
- sale units;
- variant list;
- sellable/purchasable state.

`ProductVariant` parses:

- `id`;
- SKU and barcode;
- price/MRP/purchase price;
- quantity;
- active state;
- flattened attribute map;
- variant images.

Important detail: invalid/missing variant IDs currently parse to `0`. A production contract should reject malformed IDs rather than silently manufacturing a shared ID zero.

## 2.2 Central selection flow

`ProductCartHelper.handleProductSelection()` is now the effective central flow. It:

1. reads `PRODUCT_VARIANT_ENABLED`;
2. resolves a passed variant, barcode-matched variant, or the only active variant;
3. opens the picker when multiple active variants remain;
4. handles sellability;
5. reads active store and stock settings;
6. filters and groups stock;
7. resolves prices and MRP;
8. prompts for oversell/zero price where configured;
9. inserts a `LocalCartItem` including variant identity.

This means older documentation saying desktop product clicks never resolve variants is no longer correct. Standard call sites that invoke `ProductCartHelper` directly now receive variant resolution.

## 2.3 Cart-line representation

`LocalCartItem` stores:

- product snapshot;
- base-unit quantity;
- base-unit price and MRP;
- selected/grouped stock;
- raw stock reservations;
- sale-unit ID/name/conversion rate;
- variant ID and attribute snapshot;
- comment and manual-price state.

This is conceptually sound. The primary weakness is that identity is reconstructed repeatedly from optional arguments rather than represented by one immutable value object.

## 2.4 Cart merge identity

The provider currently distinguishes lines by a combination of:

- product ID;
- sale-unit ID;
- variant ID;
- stock pricing group or selected stock.

This correctly prevents Red/L and Blue/L variants from merging. It also keeps sale-unit choices separate.

## 2.5 Stock reservations

A cart line can reserve quantity from several raw stock rows. `stockReservations` is the source for:

- local stock decrement/restore;
- expanding checkout payload into one line per raw stock ID;
- preserving grouped-price selection while consuming stock FEFO/FIFO-style.

This is an important strength and should not be lost during refactoring.

## 2.6 Checkout payload

`LocalProductProvider.buildOrderItemsPayloadFrom()` emits:

- `product_id`;
- display or base quantity according to sale-unit compatibility;
- price and MRP at the matching scale;
- `stock_id` per reservation;
- sale-unit keys when applicable;
- `product_variant_id` on every variant row.

Variant attributes are not sent because the backend snapshots them from the variant. That is the preferred ownership model.

## 2.7 Local persistence

Hive fields preserve:

- variant ID at field 16;
- serialized attributes at field 17;
- stock group IDs and reservations;
- selected stock and product snapshots;
- sale-unit identity.

Schema compatibility is good. Write ordering is not yet safe.

---

## 3. Shared frontend/backend contracts

The frontend implementation must not proceed independently of `backend-changes-varient.md` on these rules.

### CONTRACT-01: Variant-controlled product

The API should expose a persistent `variant_mode` or equivalent. Flutter must not infer variant mode only from whether the current `variants` list is empty.

If variant mode is true:

- no base cart line is allowed;
- an active variant must be selected;
- checkout must contain variant ID;
- UI should show “No active variants available” when the active list is empty.

### CONTRACT-02: Stock policy

Recommended policy is strict variant stock:

- variant line uses only stock rows for that variant;
- non-variant line uses only general stock;
- no local general-stock fallback for variant lines.

If the business insists on general fallback, backend and frontend must implement and test exactly the same rule.

### CONTRACT-03: Quantity scale

Internally maintain:

- cart quantity in base units;
- selected sale-unit conversion rate;
- display quantity derived from base quantity;
- stock reservations in base units.

Never mix display quantity and base quantity under the same ambiguous field name inside domain code.

### CONTRACT-04: Price ownership

Flutter may calculate a preview but the backend response is authoritative.

Manual override must be explicit, permission-aware, and distinguishable from a normal resolved price.

### CONTRACT-05: Oversell

Do not show a successful “Sell anyway” flow unless the backend supports and authorizes it. The response must state reserved and oversold quantities.

### CONTRACT-06: Historical variant snapshot

Cart/order display uses the line snapshot after checkout. A later catalog refresh must not rename or reprice historical order lines.

---

## 4. Confirmed strengths to preserve

- Variant resolution is centralized in `ProductCartHelper`.
- Barcode matching prefers the exact active variant.
- A single active variant can be auto-selected.
- Multiple active variants use one shared picker on mobile and desktop.
- Out-of-stock variants remain distinguishable instead of disappearing silently.
- Variant ID participates in cart merge identity.
- Variant attributes are snapshotted into local cart lines.
- Hive adapters include backward-compatible variant fields.
- Payload expansion preserves variant ID on split stock lines.
- Variant and sale-unit identities can coexist on one line.
- Order details and sales-return models parse variant snapshots from maps or JSON strings.
- Quotations include variant identity.
- Variant images are parsed by the current model.
- Focused variant tests cover selection, picker, cart identity, payloads, scoped reservations, persistence and quotations.

During the audit, 69 focused Flutter tests passed. This confirms the intended client contract but does not validate the backend behavior.

---

## 5. Confirmed frontend defects and required changes

> Historical audit baseline: each “Current behavior” subsection below describes the pre-remediation code. Use the implementation-status table near the top of this document for the present state and the remaining backend dependencies.

## F-01 — Critical: local general-stock fallback conflicts with backend

### Current behavior

`LocalProductProvider.filterStocksForVariant()`:

- returns matching variant stock if present;
- otherwise returns general stock.

`ProductCartHelper` uses this rule before stock selection. The backend currently requires variant-scoped stock when a variant ID is present.

### Required change

After the shared stock policy is confirmed, implement it once in a pure domain function. Under the recommended strict policy:

```dart
List<Stock> stocksForLine(GetProduct product, int? variantId) {
  final stocks = product.stock ?? const <Stock>[];
  if (variantId == null) {
    return stocks.where((s) => s.productVariantId == null).toList();
  }
  return stocks.where((s) => s.productVariantId == variantId).toList();
}
```

When no variant stock exists, show a clear unavailable state instead of silently changing stock ownership.

### Required tests

- variant cannot receive general stock;
- variant cannot receive another variant's stock;
- non-variant cannot receive variant stock;
- stock-disabled mode still allows sales according to tenant policy;
- legacy incompatible catalog data shows a migration-required error.

## F-02 — Critical: Hive persistence operations are not awaited

### Current behavior

Methods such as `_saveProductsToHive()` and `_saveCartToHive()` are synchronous `void` methods, but call asynchronous Hive operations including `clear()` and `add()` without awaiting them.

This can interleave:

1. clear request;
2. multiple add requests;
3. a second cart mutation and second clear;
4. application restart or load.

During the focused test run, logged Hive box lengths sometimes exceeded the current cart line count, which is consistent with unsynchronized full-box rewrites.

### Required change

Do not clear and rebuild the full box on every mutation.

Introduce an immutable `cartLineId` and persist by key:

```dart
await cartBox.put(item.cartLineId, toHive(item));
await cartBox.delete(removedItem.cartLineId);
```

For bulk replacement, serialize writes through a mutex/queue and await `putAll()`/deletes.

Provider mutation APIs can either become `Future<void>` or enqueue a write and expose a `flushPersistence()` operation required before shutdown/checkout.

### Required tests

- 100 rapid increments, restart, exact quantity retained;
- rapid add/remove of two variants never creates duplicate lines;
- save order while cart write is pending;
- app restart immediately after mutation;
- migration from old integer Hive keys to stable line IDs;
- corrupted row is isolated and reported rather than breaking the full load.

## F-03 — High: restaurant paths drop variant identity

### Confirmed path 1

The large restaurant cart “+” control in `billing_page_restaurant.dart` calls `addToCart()` with sale-unit and stock fields but omits:

- `variantId`;
- `variantAttributes`.

Result: incrementing a variant line can fail to find the original line and create a separate non-variant line.

### Confirmed path 2

`restaurant/widgets/order_panel.dart` rebuilds local cart items from order data but calls `addToCart()` without variant identity. It also converts quantity with `toInt()`, which can lose legitimate fractional base quantities.

### Required change

Stop reconstructing identity manually at call sites. Use one API such as:

```dart
provider.incrementLine(item.key, displayStep: 1);
provider.restoreOrderLine(OrderLineSnapshot snapshot);
```

Audit every direct `LocalProductProvider.addToCart()` call outside `ProductCartHelper` and quantity helpers.

## F-04 — High: variant plus sale-unit price precedence is inconsistent

### Current behavior

The provider's `_resolveUnitPrice()` intends this order:

1. sale-unit stock/batch override;
2. sale-unit master/resolved price;
3. variant price;
4. wholesale/stock/product fallback.

`ProductCartHelper`, however, precomputes variant price and passes it explicitly for a new variant line. This bypasses the provider sale-unit resolution path.

### Failure scenario

- variant base price = 10;
- CASE conversion = 12;
- CASE master promotional price = 100;
- expected according to provider chain = 100 per CASE;
- helper passes variant base price, causing display/payload to become 120 per CASE.

### Required change

Create one pure pricing resolver used by product preview and cart insertion. It should return a structured result:

```dart
class ResolvedLinePrice {
  final Decimal baseUnitPrice;
  final Decimal displayUnitPrice;
  final Decimal mrp;
  final PriceSource source;
  final bool isManualOverride;
}
```

Flutter `double` may remain temporarily if adding a decimal package is out of scope, but the final API boundary should use decimal strings.

### Required tests

- variant only;
- sale unit only;
- variant plus sale-unit master price;
- variant plus stock-specific sale-unit override;
- manual override plus variant/sale unit;
- price refresh after quantity change;
- wholesale threshold with variant line according to chosen policy.

## F-05 — Critical UX/integrity: displayed variant quantity is stale

### Current behavior

The picker uses `ProductVariant.quantity` to display quantity and determine `isOutOfStock()`. The backend currently returns a separately stored aggregate that is not synchronized with stock rows and is not store-specific.

### Required change

Consume a backend `available_quantity` derived for the active store. Model stock state explicitly:

```dart
enum AvailabilityState { available, outOfStock, notTracked, unknown }
```

Do not interpret missing data as zero. Do not use a global total when the sale is store-scoped.

The variant editor quantity input should either:

- be removed from variant metadata; or
- open a store/stock allocation workflow.

## F-06 — Oversell policy (updated 2026-07-10)

### Current behavior

The backend is confirmed to accept oversold quantities. Flutter now reads the app setting `ALLOW_OVERSELL`:

- missing or enabled: allow the requested cart quantity and unit conversion;
- disabled: block initial adds, direct increases, quantity controls and sale-unit conversions when available stock is insufficient.

When overselling is allowed, Flutter first expands the selected allocation to every compatible stock row: same store, same product/variant and the same configured pricing-group signature. Those rows are consumed in FEFO order. Only a shortage remaining after compatible stock is exhausted becomes oversold. The cart and order payload retain the full requested base quantity for the backend, while local stock remains clamped at zero rather than becoming negative.

Stocks with a different store, variant or pricing signature are not silently consumed. Strict mode can still present the existing alternative-stock selection flow for a different pricing group.

This policy does not weaken variant scoping. A variant still requires a stock row belonging to that exact variant and cannot consume a general or different-variant row.

### Backend configuration

Ensure the backend app-settings response includes this entry when a tenant needs strict enforcement:

```json
{
  "code": "ALLOW_OVERSELL",
  "status": "false",
  "value": ""
}
```

No backend entry is required for the requested default behavior because Flutter defaults the setting to `true`.

If audited oversell is required later, additionally collect and send:

- reason;
- manager authorization when required;
- requested base quantity;
- available/reserved quantity;
- expected oversold quantity.

Display server-confirmed oversold quantity on success.

## F-07 — High: empty active variant list is ambiguous

### Current behavior

`GetProduct.hasVariants` checks whether the returned variant list is non-empty. The backend generally sends active variants only.

If all variants are inactive, the list is empty and Flutter can add the product as a base line.

### Required change

Read a persistent backend `variantMode` field. In `ProductCartHelper`:

```text
variantMode false -> normal base flow
variantMode true + active variants -> resolve/pick
variantMode true + no active variants -> block with explicit message
```

## F-08 — High: barcode ambiguity is not safely resolved

### Current behavior

The local barcode index includes:

- product barcode;
- sale-unit barcodes;
- variant barcodes.

It can return multiple products for one barcode. Most billing scan paths select the first result. The exact winner depends on catalog ordering, which is not safe for POS.

### Required change

- backend must prevent collisions;
- client should still detect `matches.length > 1` and block the scan;
- show diagnostic product IDs/names to an authorized user;
- never silently choose the first ambiguous product;
- normalize barcode exactly the same way in product creation, sync and scanning.

## F-09 — Medium: variant setting behavior is inconsistent/misleading

### Current behavior

- missing setting generally defaults variants on;
- missing `AppSettingsProvider` in `ProductCartHelper` defaults variants off;
- `addProductWithVariantResolution()` accepts `variantEnabled` but does not forward or use it;
- an explicitly passed `selectedVariant` can still be applied even when the setting is off.

### Required change

Use one policy:

- settings provider should always be present in production billing trees;
- remove the unused `variantEnabled` parameter or honor it explicitly;
- decide whether disabling variants hides management only or also blocks variant sale;
- fail closed during an unknown setting state if variant correctness affects stock.

## F-10 — High: cart identity is too easy to omit

### Current behavior

Mutations accept several optional fields:

```text
productId
selectedStock
stockGroupIds
saleUnitId
variantId
```

Callers can compile while omitting one identity dimension, as the restaurant bug demonstrates.

### Required change

Introduce immutable identity types:

```dart
@immutable
class CartLineKey {
  final int productId;
  final int? variantId;
  final int? saleUnitId;
  final String stockPricingSignature;
}

@immutable
class CartLineSnapshot {
  final String lineId;
  final CartLineKey key;
  // Product, attributes, quantities, prices and reservations.
}
```

All update/remove/increment APIs should accept `lineId` or `CartLineKey`, not rebuild identity from optional parameters.

## F-11 — Medium: local snapshots can be stale at checkout

Local product and stock snapshots are valuable for offline responsiveness, but they cannot be authoritative when multiple devices sell concurrently.

### Required change

Checkout must handle server reconciliation:

- authoritative price changed;
- stock no longer available;
- variant deactivated;
- stock moved to another store;
- sale-unit configuration changed;
- override permission rejected.

Provide a structured conflict UI instead of a generic “order failed” message. Do not clear the cart until the server has committed the order.

## F-12 — Medium: analyzer and async context warnings remain

Targeted analysis of the requested billing scope reported 165 warnings/info messages. Most were style/deprecation notices, but several were `use_build_context_synchronously` warnings in billing controllers, checkout and widgets.

Required change:

- check the same context's `mounted` state after every awaited operation;
- avoid capturing widget contexts in long-running service callbacks;
- migrate deprecated color APIs;
- reduce unused/dead billing code;
- make the release CI fail on analyzer errors and selected serious warning categories.

## F-13 — Medium: production logging is noisy and contains business/customer context

Billing and local provider code contains extensive `debugPrint()` calls, including product, stock, customer and persistence state. Some source strings also contain mojibake from earlier encoding transformations.

Required change:

- use structured, release-configurable logging;
- redact customer and payment identifiers;
- attach checkout correlation IDs;
- replace malformed source encodings with UTF-8;
- avoid logging every Hive row in normal production operation.

## F-14 — Low/medium: variant images are parsed but not used by the picker

The current `ProductVariant` model parses `images`, correcting the older missing-model gap. The variant picker header still uses the product-level thumbnail and list rows do not update imagery when selection changes.

Required change:

- use selected variant primary image when available;
- fall back to product image;
- pre-cache safely and provide an error placeholder;
- test image-less and broken-URL variants.

---

## 6. Recommended frontend domain model

The current functionality can be stabilized incrementally. A larger cleanup should introduce these domain concepts.

### VariantSelectionResult

```dart
class VariantSelectionResult {
  final ProductVariant variant;
  final VariantSelectionSource source; // barcode, autoSingle, picker
}
```

### StockSelection

```dart
class StockSelection {
  final List<int> stockIds;
  final String pricingSignature;
  final num availableBaseQuantity;
  final int storeId;
  final int? variantId;
}
```

### SaleQuantity

```dart
class SaleQuantity {
  final num baseQuantity;
  final num displayQuantity;
  final int? saleUnitId;
  final num conversionRate;
}
```

### ResolvedCartLine

```dart
class ResolvedCartLine {
  final CartLineKey key;
  final VariantSelectionResult? variant;
  final StockSelection? stock;
  final SaleQuantity quantity;
  final ResolvedLinePrice price;
  final Map<String, dynamic>? variantAttributesSnapshot;
}
```

`ProductCartHelper` should orchestrate these services rather than contain all business rules in one large method.

---

## 7. Recommended refactoring sequence

### Phase 0 — Pin shared contracts

Coordinate with backend and decide:

- strict variant stock or general fallback;
- price precedence;
- oversell policy;
- variant-mode semantics;
- barcode normalization;
- decimal precision;
- sale-unit request quantity scale.

### Phase 1 — Stop integrity failures

1. Fix restaurant direct mutations to preserve variant identity.
2. Block ambiguous barcode matches.
3. Block variant-mode products with no active variants.
4. Align local stock policy with backend.
5. Disable oversell until server support exists.

### Phase 2 — Fix persistence

1. Add stable cart line IDs.
2. Replace clear-and-rewrite Hive persistence with keyed writes.
3. Serialize and await writes.
4. Add migration and restart stress tests.

### Phase 3 — Centralize pricing and quantity

1. Extract pure quantity conversion service.
2. Extract pure pricing resolver.
3. Make variant plus sale-unit precedence explicit.
4. Represent manual override separately.
5. consume backend authoritative checkout response.

### Phase 4 — Simplify cart APIs

1. Introduce `CartLineKey`/line ID.
2. Convert increment, decrement, remove, edit-price and edit-MRP methods.
3. Remove long optional identity argument lists.
4. Audit every direct provider call.

### Phase 5 — UX, diagnostics and cleanup

1. Improve stock/variant conflict messages.
2. Use variant images.
3. Redact and structure logs.
4. resolve async-context warnings.
5. Remove obsolete compatibility wrappers/parameters after all callers migrate.

---

## 8. Scenario matrix the implementation must support

| Scenario | Expected behavior |
|---|---|
| Non-variant, stock disabled | Add base line using server-compatible product pricing |
| Non-variant, one general stock group | Auto-select stock and reserve base quantity |
| Non-variant, multiple pricing groups | Require explicit pricing-group selection |
| One active variant | Auto-select variant |
| Multiple active variants | Open picker |
| Variant barcode scan | Select exact active variant without picker |
| Inactive variant barcode | Do not sell; show inactive/not-found message |
| Variant mode with zero active variants | Block base sale |
| Variant with strict stock and no stock | Block or server-authorized oversell only |
| Variant with multiple stock batches | Reserve only that variant's batches |
| Two variants same product | Maintain separate cart lines |
| Same variant, same sale unit/group | Merge quantity |
| Same variant, different sale units | Separate lines |
| Different variants, same stock price | Separate lines |
| Variant + CASE master price | Apply agreed variant/sale-unit precedence |
| Variant + batch unit override | Apply agreed override precedence |
| Manual price override | Permission-aware request and visible audit state |
| Rapid plus button taps | Exact cart and Hive quantity, no duplicate line |
| Save and reload draft order | Preserve variant, unit, stock reservations and price snapshot |
| Catalog refresh deactivates carted variant | Existing cart snapshot remains visible; checkout reconciles with server |
| Concurrent sale exhausts stock | Server conflict shown without clearing cart |
| Partial stock + oversell | Only possible with server authorization and explicit quantities |
| Quotation with variant | Preserve variant ID and sale-unit identity |
| Order details after variant rename | Show historical attribute snapshot |
| Partial variant return | Return UI targets original cart item and displays snapshot |
| Duplicate barcode received from catalog | Block scan and report ambiguity |

---

## 9. Required frontend test plan

### Pure domain tests

- variant barcode normalization and exact match;
- inactive barcode rejection;
- variant-mode empty-list behavior;
- strict stock scoping;
- base/display quantity conversions;
- all price precedence combinations;
- canonical cart-line key equality;
- decimal serialization and rounding.

### Provider tests

- different variants never merge;
- same canonical key merges;
- every mutation targets by line ID/key;
- reservations stay variant-scoped;
- quantity decrease restores only actual reserved stock;
- server conflict does not clear cart;
- catalog refresh preserves frozen cart price when intended;
- legacy persisted cart migration.

### Hive stress tests

- rapid sequential and concurrent mutation queue;
- restart immediately after write;
- repeated save/load cycles do not grow box rows;
- two variants survive restart as two lines;
- deleted line does not reappear;
- saved order and active cart writes cannot overwrite each other.

### Widget tests

- picker mobile sheet and desktop dialog;
- no active variants blocked;
- selected variant image updates;
- out-of-stock/unknown/not-tracked states differ;
- ambiguous barcode error;
- restaurant plus/minus preserves line identity;
- conflict UI for server repricing and stock exhaustion;
- oversell authorization flow if implemented.

### Contract tests

Build payloads and validate them against captured backend feature-test fixtures for:

- plain item;
- variant item;
- sale-unit item;
- variant plus sale unit;
- split stock allocation;
- authorized manual override;
- oversell request;
- quotation conversion;
- return response.

### End-to-end tests

At minimum automate:

1. create variant product with stock;
2. sync catalog;
3. scan variant barcode;
4. add and modify quantity;
5. checkout;
6. verify backend stock;
7. reload order details;
8. partially return;
9. complete return once;
10. verify restored variant stock.

Repeat the sale for desktop, mobile and restaurant surfaces.

---

## 10. Suggested implementation task breakdown

### Task F-A: Canonical identity

- Add `CartLineKey` and stable line ID.
- Convert provider lookup/mutation methods.
- Migrate standard billing widgets.
- Migrate restaurant widgets.
- Add compile-time-safe APIs that cannot omit variant identity.

### Task F-B: Persistence queue

- Create Hive repository abstraction.
- Key rows by stable line ID.
- Await every write.
- Add migration from existing adapter rows.
- Add stress/restart tests.

### Task F-C: Variant availability

- Add `variantMode` and `AvailabilityState` models.
- consume store-specific backend availability.
- remove stale aggregate assumptions.
- update picker badges and disabled states.

### Task F-D: Unified pricing

- Create pure resolver and source enum.
- Define variant/sale-unit/stock precedence.
- update helper and provider to use the same result.
- separate manual override from normal price.
- reconcile authoritative server response.

### Task F-E: Stock and oversell contract

- remove local general fallback under strict policy;
- represent stock allocations explicitly;
- synchronize `ALLOW_OVERSELL` into every cart entry point;
- keep strict variant stock identity independent from the quantity policy;
- optionally add reason/manager authorization later if the business requires an audited override.

### Task F-F: Barcode safety

- centralize normalization;
- return a discriminated result: none, unique, ambiguous;
- block ambiguous scans;
- surface actionable catalog repair information.

### Task F-G: Legacy restaurant cleanup

- audit every direct provider mutation;
- remove `toInt()` truncation where fractional units are legal;
- preserve variant/sale-unit/stock identity on order rehydration;
- run the same scenario suite as standard billing.

---

## 11. Rollout and backward compatibility

### Hive compatibility

Do not reuse or renumber existing Hive fields. Add new fields with new indexes. Keep readers tolerant of:

- missing variant fields from old carts;
- legacy selected stock without reservation list;
- missing stable line ID;
- old sale-unit metadata.

Generate stable line IDs during migration and persist them before normal mutation resumes.

### Catalog compatibility

During backend rollout, Flutter should tolerate missing new fields:

- `variant_mode` missing: use a temporary compatibility policy and log it;
- `available_quantity` missing: show unknown, not zero;
- authoritative price source missing: retain current display but never assume checkout success.

Remove compatibility fallbacks after all supported backend versions expose the new contract.

### Feature rollout

Recommended tenant rollout order:

1. internal test tenant;
2. stock-disabled tenant;
3. single-store stock tenant;
4. multi-store tenant;
5. restaurant/table-order tenant;
6. tenants using sale units and returns.

Monitor server stock conflicts, ambiguous barcode events, persistence errors and checkout repricing.

---

## 12. Definition of done for frontend production readiness

- [ ] Variant-mode products cannot enter cart without an active variant.
- [ ] Client stock scoping exactly matches backend policy.
- [ ] Variant availability is store-specific or explicitly unknown.
- [ ] Variant plus sale-unit pricing uses one tested resolver.
- [ ] Manual price override is distinct from normal price.
- [ ] Oversell UI is shown only when backend capability/permission exists.
- [ ] Every cart mutation targets a stable line ID/key.
- [ ] No direct restaurant path can omit variant identity.
- [ ] Hive writes are awaited, keyed and restart-safe.
- [ ] Ambiguous barcodes block instead of selecting the first match.
- [ ] Checkout handles server stock/price/active-state conflicts without losing the cart.
- [ ] Historical orders and returns display snapshot attributes.
- [ ] Focused domain, provider, Hive, widget, contract and end-to-end tests pass.
- [ ] Serious analyzer warnings in touched flows are resolved.
- [ ] Production logging is structured and redacted.

---

## 13. Backend dependencies

Frontend work is blocked or shaped by backend decisions in `backend-changes-varient.md`:

- `variant_mode` field and empty-active-list behavior;
- store-specific variant availability;
- strict versus fallback stock rule;
- authoritative price precedence;
- manual override permission contract;
- oversell capability and audit contract;
- checkout allocation and conflict response;
- barcode uniqueness guarantees;
- return idempotency and response shape.

An implementation agent should update both documents if any shared contract decision changes. Do not silently fix one layer with behavior the other layer does not understand.
