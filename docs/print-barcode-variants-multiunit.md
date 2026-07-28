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


