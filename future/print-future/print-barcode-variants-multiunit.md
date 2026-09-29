# Print Barcodes: Variant and Multi-Unit Expansion

This document outlines the recent changes implemented in the **Print Barcodes** screen to support individual barcode selection and printing for products, variants, and sale units.

---

## 1. Problem Statement
Previously, the Print Barcodes screen displayed only **one row per product**. Products with multiple variants or sale units (multi-units) could not have their unique barcodes selected, viewed, or printed individually from the UI list. The screen only referenced the base product details.

---

## 2. Solution Summary
The row generation logic in [product_barcode.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart) has been upgraded to a **flat-map per product** architecture. Each product is expanded into multiple rows representing all of its printable barcodes:
1. **Base product row**: Always visible and represents the base barcode.
2. **Variant rows**: One row for each active variant that has a non-empty barcode.
3. **Sale unit rows**: One row for each sale unit that has a non-empty barcode. If a sale unit's barcode matches the base product's barcode exactly (e.g. `CASE` unit), that row is skipped to avoid showing duplicate rows for the same physical barcode.

---

## 3. Key Implementation Details

### `BarcodeRow` Wrapper Class
Introduced a lightweight wrapper class `BarcodeRow` to represent any printable line item on the screen (Base, Variant, or Sale Unit).
- **`displayName`**: Formatted as `Product Name` (Base), `Product Name - Attr1/Attr2` (Variant), or `Product Name (Unit)` (Sale Unit).
- **`barcode`**: Resolves to `variant.barcode`, `saleUnit.barcode`, or `product.barcode`.
- **`sku`**: Falls back to `product.sku` if not overridden on the variant level.
- **`selectionKey`**: Stable tracking key (e.g., `variant:<prodId>:<variantId>`) to persist check states correctly across search/pagination.

### Qty / Price / MRP Resolution Rules
Each row type resolves columns dynamically from the corresponding sub-model properties:
- **Price/MRP**: Resolves to the variant/sale-unit level price/MRP, falling back to the base product's price if not specified.
- **Variant Quantity**: Reads the variant's store-scoped availability (`available_quantity ?? quantity`).
- **Base / Sale Unit Quantity**: Resolves the base product's standalone quantity (excluding variants) by summing `stock` entries where `productVariantId == null`. If no variants exist, it safely falls back to `product.numberOfProductsAvailable`.

### Printing Integration (`toProductForPrint()`)
When a print action is triggered, `BarcodeRow.toProductForPrint()` generates a clone of `GetProduct` via `.copyWith()` with the row's specific barcode, quantity, price, MRP, and title baked in. This integrates seamlessly into the existing printing modal and `BarcodePrinterService` pipelines without requiring any changes to them.

---

## 4. What Was NOT Changed
- **Zero API Changes**: No modifications to endpoints or payloads.
- **Zero Model Changes**: Underlying models (`GetProduct`, `ProductVariant`, `SaleUnit`, `Stock`) remain completely untouched.
- **Filter and Pagination Logic**: Maintained original search filters and pagination controls in the provider; flat-mapping runs downstream on the paginated dataset.

---

## 5. Verification Performed

### Test Case: "Keyboard" Product
A manual verify test was carried out using a "Keyboard" test product with 2 variants and 1 multi-unit:
- **Base Barcode**: `111000372` (Qty: 10)
- **Variant 1 (Red)**: Barcode `111000374` (Qty: 10)
- **Variant 2 (Blue)**: Barcode `111000375` (Qty: 10)
- **Multi-Unit (BOX)**: Barcode `111000373` (Qty: 10)
- **Multi-Unit (CASE)**: Barcode `111000372` (Qty: 10)

#### Before vs. After Behavior:

| Behavior / Display | Before | After |
| :--- | :--- | :--- |
| **Row Count** | 1 row (`Keyboard` only) | 4 rows (`Keyboard`, `Keyboard - Red`, `Keyboard - Blue`, `Keyboard (BOX)`) |
| **Visible Barcodes** | Only `111000372` | `111000372`, `111000374`, `111000375`, `111000373` |
| **Row Quantity** | Summed total `30` | `10` (Base), `10` (Red), `10` (Blue), `10` (BOX) |
| **CASE Unit Row** | N/A | Excluded automatically (since barcode duplicates Base product) |

---

## 6. Code Audit Note
A code audit was performed to confirm:
- No hardcoded strings (like `"Keyboard"` or `"111000372"`) exist in the implementation.
- All attributes and identifiers are read dynamically from model properties.
- The project compiles clean with **0 warnings and 0 errors** on the modified file.

---

## 7. Post-Implementation Fix: Print Label Price/Name Mismatch

### Issue
During PR review (PR #235), it was flagged that `toProductForPrint()` copied the row's barcode correctly but did not copy its price or name. Manually verified: printing "Keyboard (BOX)" (on-screen price 700) produced a label showing 130 (the base product's price) instead of 700.

### Root Cause
`BarcodePrinterService` reads `product.price?.price` for the label price and resolves the product name from `product.names` (the localized translations map) before falling back to `productName`. Because the print clone built by `toProductForPrint()` only overrode the barcode field, variant/sale-unit rows inherited the base product's price and localized names map. This caused printed labels to fall back to base values, even though the on-screen table displayed correct row-specific values.

### Fix Applied
- **Price override**: `toProductForPrint()` now passes the row's own price (`variant.price` or `saleUnit.resolvedPrice ?? saleUnit.price`, falling back to base price) wrapped in a `ProductPrice` object during `product.copyWith()`.
- **Localized Name suffixing**: Added `_variantSuffix` and `_saleUnitSuffix` helper getters and a `_buildRowNames()` helper. `_buildRowNames()` traverses the base product's `names` structure and appends the row's suffix (e.g. ` - Blue/XL` or ` (BOX)`) to each translation leaf. This ensures localized names (Arabic, etc.) are correctly updated and preserved on variant/unit labels instead of being cleared or falling back to English.
- **Base row behavior**: Unchanged (returns base product as is).

### Test Coverage
Added a new unit test `BarcodeRow.toProductForPrint copies correct prices and updates names with suffixes` in [barcode_print_flow_smoke_test.dart](file:///c:/Users/Mubashir/eposmob/test/barcode_print_flow_smoke_test.dart) verifying correct price, sku, quantity, mrp, and localized names for base, variant, and sale-unit rows. All tests pass successfully.

### Manual Verification
Confirmed via manual testing that printing "Keyboard (BOX)" now produces a label showing 700, while printing the base "Keyboard" row still correctly shows 130.

---

## 8. Second Post-Implementation Fix: Print Label Batch Dates & Barcode Search Refinement

### Wrong Expiry/Mfg Date on Variant/Unit Labels (P1)
- **Issue**: `toProductForPrint()` cloned the base product but retained its unfiltered `product.stock` list. When printing a variant or unit that had no stock entries, if the base product had exactly one stock entry (belonging to a *different* variant), the `ConfirmBarcodePrintModal` assumed it was unambiguous and pre-filled that unrelated batch's manufacturing and expiry dates on the printed label.
- **Fix**:
  - **Variant print rows**: Overrode the `stock` field in `product.copyWith(...)` to include only stock entries matching the variant's ID (`productVariantId == v.id`).
  - **Sale Unit print rows**: Cleared the stock list entirely (`const []`) so the print modal leaves the dates blank instead of guessing from unrelated batches.
- **Test Coverage**: Added a unit test `BarcodeRow.toProductForPrint filters stock correctly` in [barcode_print_flow_smoke_test.dart](file:///c:/Users/Mubashir/eposmob/test/barcode_print_flow_smoke_test.dart).

### Barcode Search Filter & Exact-Matching Row Expansion (P2)
- **Issue**: The "Barcode" filter field on the Print Barcodes screen was ignoring variant/unit barcodes entirely because filtering in [local_product_provider.dart](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart) only matched the base product's `barcode` before the UI expanded them. Additionally, when a product did match, the UI expanded all of its rows (base + every variant/unit sibling), cluttering search results with unrelated items.
- **Fix**:
  - **Extended search matching**: Extended the provider's `filterBarcode` predicate in `listAllProducts(...)` to also match if any associated variant's or sale unit's barcode contains the search query.
  - **Exact-matching row expansion**: Renamed the UI helper to `expandProductsToBarcodeRows(...)` (public) and added a post-expansion exact-matching filter step. If a barcode filter query is active, the UI discards all sibling rows whose own barcode does not match the search term, displaying only the exact matched row(s). Other searches (Name, Category) continue to display all sibling rows.
  - **Init Robustness**: Wrapped `loadInitData()` with `Future.microtask()` inside `initState()` in [product_barcode.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart) to avoid synchronous state notification issues during widget building in testing and runtime environments.
- **Test Coverage**:
  - Added unit test `LocalProductProvider.listAllProducts filters by variant and sale unit barcodes` in [variant_scoped_stock_test.dart](file:///c:/Users/Mubashir/eposmob/test/variant_scoped_stock_test.dart).
  - Added widget test `ProductBarcodeScreen.expandProductsToBarcodeRows filters correctly based on barcodeController` in [variant_scoped_stock_test.dart](file:///c:/Users/Mubashir/eposmob/test/variant_scoped_stock_test.dart) to verify sibling row discarding.

---

## 9. PR #236 Review Fixes — 2026-07-29

### Context
This PR (variant/multi-unit barcode printing) went through multiple rounds of review feedback (chatgpt-codex-connector bot). This section documents the resolution of 6 issues raised together in the final review pass.

### Issues Fixed

#### 1. Base-row batch dates inheriting variant-owned stock
- **Impact:** A product with only variant-owned stock records would cause the base row's print label to inherit those variant-batch manufacturing/expiry dates.
- **Fix:** In `BarcodeRow.toProductForPrint()` ([product_barcode.dart:L213-L216](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart#L213-L216)), the base-product branch now filters `product.stock` to only entries where `productVariantId == null`. If empty, passes `const []`.
- **Code:**
  ```dart
  // BEFORE (L216):
  return product;

  // AFTER (L213-L216):
  final baseStock = product.stock
          ?.where((s) => s.productVariantId == null)
          .toList() ??
      const [];
  return product.copyWith(stock: baseStock);
  ```

#### 2. Multi-unit pricing missing conversion-rate fallback
- **Impact:** Print labels for sale units with no explicit price/resolvedPrice fell back to the base product price without multiplying by `conversionRate`, printing an incorrect (under-calculated) unit price.
- **Fix:** Extracted `SaleUnit.resolveDisplayPrice()` static method on `SaleUnit` ([get_product.dart:L725-L755](file:///c:/Users/Mubashir/eposmob/lib/models/get_product.dart#L725-L755)) which implements billing's exact resolution chain. `BarcodeRow.priceDisplay` and `toProductForPrint()` now invoke this method ([product_barcode.dart:L151-L157, L203-L208](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart#L151-L157)).
- **Code:**
  ```dart
  // BEFORE (product_barcode.dart):
  final rowPrice = u.resolvedPrice ?? u.price ?? product.price?.price;

  // AFTER (product_barcode.dart):
  final rowPrice = SaleUnit.resolveDisplayPrice(
    product: product,
    saleUnit: u,
  );
  ```

#### 3. Zero price/MRP treated as valid instead of falling back to base
- **Impact:** Setting a variant/sale-unit price or MRP to `0.0` caused the screen and print pipeline to display `$0.00` instead of falling back to the base product's price/MRP.
- **Fix:** Replaced null-only `??` checks with `> 0` validity guards in `BarcodeRow.priceDisplay`, `mrpDisplay`, and `toProductForPrint()` ([product_barcode.dart:L143-L170](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart#L143-L170)).
- **Code:**
  ```dart
  // BEFORE:
  return (variant!.price ?? product.price?.price)?.toString() ?? 'N/A';

  // AFTER:
  final v = variant!;
  final vPrice = (v.price != null && v.price! > 0) ? v.price : null;
  return (vPrice ?? product.price?.price)?.toString() ?? 'N/A';
  ```

#### 4. Selection key collisions for sale units without a database ID
- **Impact:** Two locally-created/unsaved sale units on the same product with `id == null` generated identical selection keys (`"unit:25:null"`), causing check/selection state toggles to overwrite each other.
- **Fix:** Updated `BarcodeRow.selectionKey` ([product_barcode.dart:L181-L187](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart#L181-L187)) to use a composite fallback key.
- **Code:**
  ```dart
  // BEFORE:
  return 'unit:${product.productId}:${saleUnit!.id}';

  // AFTER:
  final u = saleUnit!;
  return 'unit:${product.productId}:'
      '${u.id ?? u.unitId}:'
      '${u.conversionRate ?? u.unitName}:'
      '${u.barcode ?? ''}';
  ```

#### 5. Pagination counting parent products instead of expanded rows
- **Impact:** Pagination sliced the parent product list before row expansion, resulting in unpredictable page sizes (e.g. 20 products with sub-rows expanding to 60+ rows on a single "page") and incorrect/jumping serial numbers across pages.
- **Fix & Memoization:** 
  - Added `allFilteredProducts` getter and `filteredProductsVersion` counter to `LocalProductProvider` ([local_product_provider.dart:L507-L512](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart#L507-L512)).
  - `ProductBarcodeScreen` now expands `allFilteredProducts` first, then paginates the resulting `BarcodeRow` list ([product_barcode.dart:L284-L308, L1521-L1532](file:///c:/Users/Mubashir/eposmob/lib/screens/product/product_barcode.dart#L284-L308)).
  - **Memoization:** `_allBarcodeRows` is re-expanded **only** when `gridProvider.filteredProductsVersion` increments (when search/filters change). Selection state `setState` calls and page turns skip re-expansion, avoiding catalog performance bottlenecks.
- **Code:**
  ```dart
  // AFTER (product_barcode.dart Consumer):
  if (gridProvider.filteredProductsVersion != _lastFilteredVersion) {
    _lastFilteredVersion = gridProvider.filteredProductsVersion;
    _allBarcodeRows = expandProductsToBarcodeRows(gridProvider.allFilteredProducts);
    _barcodePage = 1;
  }
  final pageRows = _currentPageRows;
  ```

#### 6. Inactive variants surfacing in search but excluded from printable rows
- **Impact:** Searching for an inactive variant's barcode/SKU matched `product.variants.any(...)` and surfaced the parent product, but `expandProductsToBarcodeRows()` excluded inactive variants, leaving an unprintable or confusing row set.
- **Fix:** Added `v.active` (or `!variant.active`) guards to all 7 variant search/index predicates across `local_product_provider.dart` ([L1569](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart#L1569), [L2369](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart#L2369), [L2408](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart#L2408), [L2493](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart#L2493)), `product_autocomplete_list.dart` ([L128](file:///c:/Users/Mubashir/eposmob/lib/widgets/product_autocomplete_list.dart#L128)), `product_autocomplete_list_mobile.dart` ([L107](file:///c:/Users/Mubashir/eposmob/lib/widgets/product_autocomplete_list_mobile.dart#L107)), and `menu_panel.dart` ([L893](file:///c:/Users/Mubashir/eposmob/lib/screens/billing/restaurant/widgets/menu_panel.dart#L893)).
- **Code:**
  ```dart
  // AFTER (local_product_provider.dart):
  final variantMatch = p.variants?.any((v) =>
      v.active &&
      v.barcode != null &&
      v.barcode!.toLowerCase().contains(filterBarcode.toLowerCase())) ?? false;
  ```

---

### Shared Pricing Utility (`SaleUnit.resolveDisplayPrice`)

Extracted `SaleUnit.resolveDisplayPrice()` as a static method on `SaleUnit` ([get_product.dart:L725-L755](file:///c:/Users/Mubashir/eposmob/lib/models/get_product.dart#L725-L755)). 
- **What it does:** Resolves the price per sale unit following the hierarchy: Batch Override (`> 0`) → Master Price (`> 0`) → Backend-Resolved Price (`> 0`) → Base Price × Conversion Rate (`basePrice > 0, rate > 0`).
- **Why extracted:** Billing's internal `_resolveSaleUnitBasePrice` normalizes prices to per-base-unit values (dividing by conversion rate) for cart accounting, whereas barcode printing requires the per-sale-unit price. By centralizing the fallback rules on `SaleUnit`, both billing and barcode printing invoke the exact same pricing hierarchy without logic duplication or risk of drift.

---

### Test Coverage

Full test suite pass: **68 / 68 tests passing**.

| Test File | Count | Scope Covered |
| :--- | :---: | :--- |
| `test/barcode_row_test.dart` | **38 / 38** | Base row stock filtering, `SaleUnit.resolveDisplayPrice()` chain, zero price/MRP fallback, selection key composite uniqueness, expanded row pagination math & memoized version counter, inactive variant search exclusion. |
| `test/barcode_filter_test.dart` | **12 / 12** | Product indexing, barcode lookup, normalization, store filtering. |
| `test/barcode_sale_unit_test.dart` | **13 / 13** | Sale unit quantity resolution, mobile/desktop barcode path parity. |
| `test/sale_unit_cart_change_test.dart` | **3 / 3** | Cart unit switching, base-to-unit reinterpretation, merging. |
| `test/variant_deactivated_pricing_test.dart` | **2 / 2** | Cart line quantity refresh on deactivated variants (frozen pricing). |

---

### Manual Verification
Manual verification was performed separately by the developer covering:
1. Base product date fallback on print preview.
2. Multi-unit price calculation (master vs resolved vs base×rate).
3. Zero-price fallback display on variants and sale units.
4. Independent selection state tracking for sale units without database IDs.
5. Strict 20-row-per-page pagination and continuous serial numbers across page 1, 2, and 3.
6. Searching by inactive variant barcode/SKU returning zero matching products.
