# Implementation Report: Product SKU & Item Code Search Enhancements

This document provides a summary of the changes made to the `eposmob` codebase to implement unconditional **SKU / Variant SKU** search and conditional **Item Code** search across the application's search locations.

---

## 1. Objective & Requirements

1. **Unconditional SKU Search**: Support searching by both product-level SKU (`product.sku`) and variant-level SKU (`variant.sku`) unconditionally (without any feature flags or toggles) across all search interfaces.
2. **Item Code Search on Restaurant Page**: Extend the Restaurant page search to support searching by `itemCode` when the setting `itemCodeEnabled` is active, matching the existing behavior of the Home/Billing screen.
3. **No Settings for SKU**: Ensure the SKU search works immediately without adding new company settings or configuration toggles.

---

## 2. Shared Data Model Context

The search matches are performed on the same underlying `GetProduct` model defined in:
* **File**: [get_product.dart](file:///c:/Users/Mubashir/eposmob/lib/models/get_product.dart#L121)
  * `final String? itemCode;` (Base Item Code)
  * `final String? sku;` (Base Product SKU)
  * `final List<ProductVariant>? variants;` (Product Variants)
    * Each `ProductVariant` contains its own `final String? sku;` ([get_product.dart:L1091](file:///c:/Users/Mubashir/eposmob/lib/models/get_product.dart#L1091)).

---

## 3. Detailed Changes by File

### 1) Restaurant Page Menu Search
* **File**: [menu_panel.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/billing/restaurant/widgets/menu_panel.dart)
* **Changes**:
  * Retrieved `AppSettingsProvider` to check the `itemCodeEnabled` configuration.
  * Extended the search filter predicate inside the `Consumer3` builder to inspect `product.sku`, variant-level SKUs (`variant.sku`), and `product.itemCode` (when enabled).
* **Code Implementation**:
```dart
// Apply search filter
if (_searchQuery.isNotEmpty) {
  final appSettingsProvider =
      Provider.of<AppSettingsProvider>(context, listen: true);
  final itemCodeEnabled =
      appSettingsProvider.appSettings?.itemCodeEnabled ?? false;
  items = items.where((product) {
    final nameMatch = _productSearchNames(product)
        .any((name) => name.toLowerCase().contains(_searchQuery));
    if (nameMatch) return true;

    // Check SKU (always on)
    final sku = product.sku ?? '';
    if (sku.isNotEmpty &&
        sku.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    // Check Variant SKUs (always on)
    final variantSkuMatch = product.variants?.any((variant) {
      final varSku = variant.sku ?? '';
      return varSku.isNotEmpty &&
          varSku.toLowerCase().contains(_searchQuery);
    }) ?? false;
    if (variantSkuMatch) return true;

    if (itemCodeEnabled) {
      final itemCode = product.itemCode ?? '';
      if (itemCode.isNotEmpty &&
          itemCode.toLowerCase().contains(_searchQuery)) {
        return true;
      }
    }
    return false;
  }).toList();
  items = _rankSearchMatches(items, _searchQuery);
}
```

---

### 2) Home Page Desktop Autocomplete
* **File**: [product_autocomplete_list.dart](file:///c:/Users/Mubashir/eposmob/lib/widgets/product_autocomplete_list.dart)
* **Changes**: Updated `_searchProducts()` to check for the base product SKU and all variant SKUs unconditionally before carrying out the gated `itemCode` check.
* **Code Implementation**:
```dart
// Search through only sellable products for billing autocomplete
final results = productProvider.sellableProducts.where((product) {
  final nameMatch = _productSearchNames(product)
      .any((name) => name.toLowerCase().contains(lowerQuery));
  if (nameMatch) return true;

  // Check SKU (always on)
  final sku = product.sku ?? '';
  if (sku.isNotEmpty && sku.toLowerCase().contains(lowerQuery)) {
    return true;
  }

  // Check Variant SKUs (always on)
  final variantSkuMatch = product.variants?.any((variant) {
    final varSku = variant.sku ?? '';
    return varSku.isNotEmpty && varSku.toLowerCase().contains(lowerQuery);
  }) ?? false;
  if (variantSkuMatch) return true;

  if (itemCodeEnabled) {
    final itemCode = product.itemCode ?? '';
    if (itemCode.isNotEmpty &&
        itemCode.toLowerCase().contains(lowerQuery)) {
      return true;
    }
  }
  return false;
}).toList();
```

---

### 3) Home Page Mobile Autocomplete
* **File**: [product_autocomplete_list_mobile.dart](file:///c:/Users/Mubashir/eposmob/lib/widgets/product_autocomplete_list_mobile.dart)
* **Changes**: Mirror-implemented the identical SKU and variant SKU unconditional search logic in the mobile autocomplete's `_searchProducts()` helper.

---

### 4) Product Data Provider (Home Grid & Sidebar Search)
* **File**: [local_product_provider.dart](file:///c:/Users/Mubashir/eposmob/lib/providers/local_product_provider.dart)
* **Changes**: Added the SKU and variant-level SKU search logic to both core product search functions:
  1. `listAllProducts(filterName: ...)` (filtering results for the sidebar/grid).
  2. `searchProducts(query: ...)` (filtering search results for listings).
* **Code Implementation (`searchProducts`)**:
```dart
List<GetProduct> searchProducts(String query) {
  if (query.isEmpty) {
    return _filteredProducts;
  }
  final normalizedQuery = query.toLowerCase();
  final matches = _filteredProducts.where((p) {
    final nameMatch = _productSearchNames(p)
        .any((name) => name.toLowerCase().contains(normalizedQuery));
    if (nameMatch) return true;

    // Check SKU (always on)
    final sku = p.sku ?? '';
    if (sku.isNotEmpty && sku.toLowerCase().contains(normalizedQuery)) {
      return true;
    }

    // Check Variant SKUs (always on)
    final variantSkuMatch = p.variants?.any((variant) {
      final varSku = variant.sku ?? '';
      return varSku.isNotEmpty &&
          varSku.toLowerCase().contains(normalizedQuery);
    }) ?? false;
    if (variantSkuMatch) return true;

    return false;
  }).toList();
  return _rankProductNameMatches(matches, query);
}
```

---

## 4. Key Design Decisions

* **Variant SKU Surface Match**: If a variant SKU matches the search query (e.g. `"KEYBOARD-1"`), the search correctly returns the parent product (`"Keyboard"`). This ensures cashier workflows can find the product regardless of whether they search the main inventory SKU or a sub-variant SKU.
* **No setting/toggle for SKU search**: To minimize complexity and follow user instructions, SKU search works unconditionally, while `itemCode` search continues to honor the existing configuration setting (`itemCodeEnabled`).

---

## 5. Verification Plan & Results

* **Static Analysis**: Ran `flutter analyze` across all modified files. All changes compile cleanly and do not introduce static analyzer errors.
* **Manual Verification Scenario**:
  * **Test Product**: "Chocolate Milk Bar"
  * **Item Code**: `CMB-CODE-100`
  * **Variant SKU**: `CMB-SKU-100`
  * **Expected Behavior**: Searching `"SKU-100"` or `"CMB-SKU"` on either the Home Page billing screen or the Restaurant Page menu now matches and returns the "Chocolate Milk Bar" product.
