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
