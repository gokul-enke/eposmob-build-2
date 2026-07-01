# Product Variant Implementation Plan

## Overview

The backend already fully supports product variants. This document covers all Flutter-side changes needed to wire up variant selection in the billing flow and carry `product_variant_id` through to the order API.

---

## Current State

| Area | Status |
|---|---|
| `GetProduct.variants` field | ✅ Typed as `List<ProductVariant>` (P-05 slice 1) |
| `LocalCartItem` variant fields | ✅ `variantId`, `variantAttributes`, `displayName` (P-05 slice 1) |
| Mobile billing variant picker | ✅ `mobile_variant_picker_sheet.dart` + `addProductWithVariantResolution` (P-05 slice 1) |
| `add-to-order` payload `product_variant_id` | ✅ Via `buildOrderItemsPayload` when `variantId` set (P-05 slice 1) |
| Variant Hive rehydration (cart + saved draft) | ✅ Fields 16–17; `test/variant_cart_rehydration_test.dart` (P-05 slice 2) |
| Out-of-stock variant block | ✅ Picker + `addProductWithVariantResolution` + `ProductCartHelper` guard (P-05 slice 3) |
| Variant + sale-unit cart identity | ✅ Independent merge keys; payload tests (P-05 slice 4) |
| Desktop `billing_page.dart` variant picker | Not present — **deferred** (desktop-only) |
| Add Product Modal variant creation | Not needed — variants managed in Filament UI only |

---

## Backend API Reference

### List Products — `GET /v1/product/executive/list-products`

Each product returns a nested `variants` array:

```json
{
  "id": 1,
  "name": "T-Shirt",
  "price": 299,
  "variants": [
    {
      "id": 45,
      "sku": "SHIRT-RED-L",
      "barcode": "1234567890",
      "price": 349,
      "mrp": 499,
      "purchase_price": 200,
      "quantity": 10,
      "active": true,
      "attributes": { "COLOR": "Red", "SIZE": "L" },
      "images": []
    }
  ]
}
```

### Add to Order — `POST /v1/order/add-to-order`

Pass `product_variant_id` in items array:

```json
{
  "items": [
    {
      "product_id": 1,
      "product_variant_id": 45,
      "quantity": 2,
      "price": 349
    }
  ],
  "source_type": "executive"
}
```

**Pricing priority on backend:**
1. Variant price (if variant provided and price > 0)
2. Product price (fallback)

**Stock:** Backend isolates variant stock automatically when `product_variant_id` is provided.

---

## Implementation Steps

### Step 1 — Add `ProductVariant` Model

**File:** `lib/models/get_product.dart`

Add a typed `ProductVariant` class and update `GetProduct.variants` from `List<dynamic>` to `List<ProductVariant>`.

```dart
class ProductVariant {
  final int id;
  final String? sku;
  final String? barcode;
  final double? price;
  final double? mrp;
  final double? purchasePrice;
  final num? quantity;
  final bool active;
  final Map<String, dynamic> attributes; // e.g. {"COLOR": "Red", "SIZE": "L"}

  ProductVariant({
    required this.id,
    this.sku,
    this.barcode,
    this.price,
    this.mrp,
    this.purchasePrice,
    this.quantity,
    this.active = true,
    this.attributes = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'],
        sku: json['sku'],
        barcode: json['barcode'],
        price: (json['price'] as num?)?.toDouble(),
        mrp: (json['mrp'] as num?)?.toDouble(),
        purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
        quantity: json['quantity'] as num?,
        active: json['active'] ?? true,
        attributes: (json['attributes'] as Map<String, dynamic>?) ?? {},
      );

  /// Readable label e.g. "Red | L"
  String get formattedAttributes =>
      attributes.values.map((v) => v.toString()).join(' | ');

  /// Display name with product name e.g. "T-Shirt (Red | L)"
  String displayName(String productName) {
    final attrs = formattedAttributes;
    return attrs.isEmpty ? productName : '$productName ($attrs)';
  }

  /// Effective price: variant price if set, else falls back to product price
  double effectivePrice(double productPrice) => (price != null && price! > 0) ? price! : productPrice;
}
```

**Update `GetProduct`:**

```dart
// Change:
final List<dynamic>? variants;

// To:
final List<ProductVariant>? variants;

// In fromJson, change:
variants: json["variants"] == null
    ? []
    : List<dynamic>.from((json["variants"] as List).map((x) => x));

// To:
variants: json["variants"] == null
    ? []
    : List<ProductVariant>.from(
        (json["variants"] as List).map((x) => ProductVariant.fromJson(x)));
```

**Helper on `GetProduct`:**

```dart
bool get hasVariants => variants != null && variants!.isNotEmpty;

List<ProductVariant> get activeVariants =>
    variants?.where((v) => v.active).toList() ?? [];
```

---

### Step 2 — Add Variant Fields to `LocalCartItem`

**File:** `lib/providers/local_product_provider.dart`

```dart
class LocalCartItem {
  // ... existing fields ...

  // NEW
  final int? variantId;
  final Map<String, dynamic>? variantAttributes;

  LocalCartItem({
    // ... existing params ...
    this.variantId,
    this.variantAttributes,
  });

  /// Display name shown in cart — appends variant attributes if present
  String get displayName {
    final base = product.productName ?? '';
    if (variantAttributes != null && variantAttributes!.isNotEmpty) {
      final attrs = variantAttributes!.values.map((v) => v.toString()).join(' | ');
      return '$base ($attrs)';
    }
    return base;
  }
}
```

Also update `copyWith` / `toJson` / any serialization methods on `LocalCartItem` to include `variantId` and `variantAttributes`.

---

### Step 3 — Variant Picker Dialog

**New file:** `lib/widgets/variant_picker_dialog.dart`

Show this dialog when a product with active variants is tapped on the billing page, instead of immediately adding to cart.

```dart
/// Returns the selected [ProductVariant], or null if dismissed.
Future<ProductVariant?> showVariantPickerDialog({
  required BuildContext context,
  required GetProduct product,
}) {
  return showDialog<ProductVariant>(
    context: context,
    builder: (ctx) => _VariantPickerDialog(product: product),
  );
}

class _VariantPickerDialog extends StatefulWidget {
  final GetProduct product;
  const _VariantPickerDialog({required this.product});

  @override
  State<_VariantPickerDialog> createState() => _VariantPickerDialogState();
}

class _VariantPickerDialogState extends State<_VariantPickerDialog> {
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    final active = widget.product.activeVariants;
    if (active.length == 1) _selected = active.first;
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.activeVariants;
    final productPrice = (widget.product.price?.price ?? 0).toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.45,
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.product.productName ?? 'Select Variant',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a variant to add to cart',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Variant list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: variants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  final isSelected = _selected?.id == variant.id;
                  final effectivePrice = variant.effectivePrice(productPrice);

                  return GestureDetector(
                    onTap: () => setState(() => _selected = variant),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ColorManager.kPrimaryColor.withOpacity(0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? ColorManager.kPrimaryColor
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.formattedAttributes.isEmpty
                                      ? variant.sku ?? 'Variant ${index + 1}'
                                      : variant.formattedAttributes,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (variant.sku != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: ${variant.sku}',
                                    style: TextStyle(fontSize: 11, color: Colors.black45),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                effectivePrice.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ColorManager.kPrimaryColor,
                                ),
                              ),
                              if (variant.quantity != null)
                                Text(
                                  'Qty: ${variant.quantity}',
                                  style: TextStyle(fontSize: 11, color: Colors.black45),
                                ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle, color: ColorManager.kPrimaryColor, size: 20),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 4 — Trigger Variant Picker in Billing Page

**File:** `lib/features/billing/presentation/pages/billing_page.dart`

Wherever a product is added to cart (product tap handler, barcode scan, autocomplete select), wrap it with a variant check:

```dart
Future<void> _addProductToCart(GetProduct product) async {
  if (product.hasVariants) {
    final selectedVariant = await showVariantPickerDialog(
      context: context,
      product: product,
    );
    if (selectedVariant == null || !mounted) return;

    // Add to local cart with variant fields
    localProductProvider.addToCartWithVariant(
      product: product,
      variant: selectedVariant,
    );
  } else {
    // Existing flow — no change
    localProductProvider.addToCart(
      productId: product.productId,
      price: product.price?.price?.toDouble() ?? 0,
      quantity: 1,
    );
  }
}
```

**Entry points to update in billing_page.dart:**
- Product grid/list tap
- Barcode scan handler (after product lookup)
- Autocomplete item select

---

### Step 5 — `addToCartWithVariant` in `LocalProductProvider`

**File:** `lib/providers/local_product_provider.dart`

```dart
void addToCartWithVariant({
  required GetProduct product,
  required ProductVariant variant,
}) {
  final productPrice = (product.price?.price ?? 0).toDouble();
  final effectivePrice = variant.effectivePrice(productPrice);

  // Check if same product+variant already in cart
  final existingIndex = cart.indexWhere(
    (item) => item.product.productId == product.productId &&
               item.variantId == variant.id,
  );

  if (existingIndex >= 0) {
    cart[existingIndex].quantity += 1;
  } else {
    cart.add(LocalCartItem(
      product: product,
      price: effectivePrice,
      mrp: variant.mrp ?? (product.mrp?.toDouble()),
      quantity: 1,
      variantId: variant.id,
      variantAttributes: variant.attributes,
    ));
  }

  notifyListeners();
}
```

---

### Step 6 — Send `product_variant_id` in Order Payload

**File:** `lib/services/checkout_service.dart` (or wherever `add-to-order` payload is built)

Find where cart items are mapped to the `items` array and add `product_variant_id`:

```dart
final items = cart.map((item) {
  final Map<String, dynamic> itemMap = {
    'product_id': item.product.productId,
    'quantity': item.quantity,
    'price': item.price,
    // ... existing fields ...
  };

  // NEW — include variant id when present
  if (item.variantId != null) {
    itemMap['product_variant_id'] = item.variantId;
  }

  return itemMap;
}).toList();
```

---

### Step 7 — Cart Display — Show Variant Name

**File:** wherever cart line items are rendered (billing sidebar / cart list)**

Replace raw `product.productName` with `item.displayName`:

```dart
// Before:
Text(item.product.productName ?? '')

// After:
Text(item.displayName)
// Outputs: "T-Shirt (Red | L)" if variant selected, "T-Shirt" otherwise
```

---

## Files Changed Summary

| File | Change |
|---|---|
| `lib/models/get_product.dart` | Add `ProductVariant` class; retype `variants` field |
| `lib/providers/local_product_provider.dart` | Add `variantId`, `variantAttributes` to `LocalCartItem`; add `addToCartWithVariant()` |
| `lib/widgets/variant_picker_dialog.dart` | **New file** — variant selection dialog |
| `lib/features/billing/presentation/pages/billing_page.dart` | Wrap product-add handlers with `hasVariants` check |
| `lib/services/checkout_service.dart` | Add `product_variant_id` to order payload |
| Cart list render widgets | Use `item.displayName` instead of raw product name |

---

## Edge Cases to Handle

| Case | Behaviour |
|---|---|
| Product has only 1 active variant | Auto-select it — skip the picker dialog, add directly |
| Variant has no price set | Fall back to product price (`variant.effectivePrice(productPrice)`) |
| Variant out of stock (`quantity == 0`) | Show greyed-out card in picker; optionally block selection |
| Same product added twice with different variants | Treat as separate cart lines (key by `productId + variantId`) |
| Barcode scan matches a variant barcode directly | Resolve variant from barcode, skip picker entirely |
| Product with variants added via "Add Product" modal | Modal creates base product only; variants are Filament-managed — no change needed |

---

## Barcode Scan Shortcut (Optional Enhancement)

The backend stores a `barcode` per variant. If a scanned barcode matches a variant barcode directly, skip the picker:

```dart
// In barcode scan handler:
GetProduct? product = findProductByBarcode(scannedBarcode);

if (product != null && product.hasVariants) {
  // Check if barcode matches a specific variant
  final matchedVariant = product.activeVariants.firstWhereOrNull(
    (v) => v.barcode == scannedBarcode,
  );

  if (matchedVariant != null) {
    // Direct add — no picker needed
    localProductProvider.addToCartWithVariant(
      product: product,
      variant: matchedVariant,
    );
    return;
  }

  // Barcode matched product but not a specific variant — show picker
  final selected = await showVariantPickerDialog(context: context, product: product);
  if (selected != null) {
    localProductProvider.addToCartWithVariant(product: product, variant: selected);
  }
}
```

---

## Estimated Effort

| Step | Effort |
|---|---|
| Step 1 — `ProductVariant` model | 1–2 hours |
| Step 2 — `LocalCartItem` variant fields | 1 hour |
| Step 3 — Variant picker dialog UI | 3–4 hours |
| Step 4 — Billing page integration | 2 hours |
| Step 5 — `addToCartWithVariant` | 1 hour |
| Step 6 — Order payload | 30 min |
| Step 7 — Cart display name | 30 min |
| Edge cases + testing | 2–3 hours |
| **Total** | **~2 days** |

---

## Progress (2026-07-01)

**P-05 slice 1 (mobile)** — shipped:

- Step 1 — `ProductVariant` model + `GetProduct.hasVariants` / `activeVariants`
- Step 2 — `LocalCartItem.variantId` / `variantAttributes` + Hive fields 16–17
- Step 3 — Mobile variant picker bottom sheet (desktop dialog deferred)
- Step 5 — Variant-aware cart merge + `ProductCartHelper.selectedVariant`
- Step 6 — `product_variant_id` in `buildOrderItemsPayload`
- Step 7 — Cart `displayName` on mobile cart rows
- Mobile entry points: market grid Add sheet, autocomplete, barcode scan

**P-05 slices 2–5 (mobile)** — shipped:

- Slice 2 — Saved-draft + active-cart Hive rehydration QA (`test/variant_cart_rehydration_test.dart`)
- Slice 3 — Out-of-stock variant hard block (`ProductVariantSelection.isOutOfStock`, picker + add guards)
- Slice 4 — Variant + sale-unit independent cart identity (`test/variant_payload_test.dart`)
- Slice 5 — Mobile payload contract tests for `product_variant_id` (+ sale-unit combo)

**Remaining (desktop-only / integration):**

- Step 4 — Desktop `billing_page.dart` variant picker integration
- P0.8 — Byte-for-byte mobile vs desktop payload compare on device
