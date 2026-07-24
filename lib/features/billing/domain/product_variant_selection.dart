import 'package:pos_machine/models/get_product.dart';

/// Shared variant resolution rules for mobile (and future desktop) billing.
class ProductVariantSelection {
  ProductVariantSelection._();

  static String normalizeBarcode(String? raw) => raw?.trim() ?? '';

  /// True when backend reports explicit zero quantity for this variant.
  /// `null` quantity means stock is not tracked at variant level.
  static bool isOutOfStock(ProductVariant variant) =>
      variant.quantity != null && variant.quantity == 0;

  /// Variants applicable to the selected store. Older API responses did not
  /// include `store_id`, so unscoped rows remain valid everywhere.
  static List<ProductVariant> variantsForStore(
    GetProduct product, {
    int? activeStoreId,
  }) {
    final variants = product.variants ?? const <ProductVariant>[];
    if (activeStoreId == null) return variants;
    return variants
        .where((variant) =>
            variant.storeId == null || variant.storeId == activeStoreId)
        .toList(growable: false);
  }

  static List<ProductVariant> activeVariantsForStore(
    GetProduct product, {
    int? activeStoreId,
  }) =>
      variantsForStore(product, activeStoreId: activeStoreId)
          .where((variant) => variant.active)
          .toList(growable: false);

  static bool isVariantAvailableInStore(
    ProductVariant variant, {
    int? activeStoreId,
  }) =>
      activeStoreId == null ||
      variant.storeId == null ||
      variant.storeId == activeStoreId;

  /// Finds an active variant whose barcode matches [barcode] on [product].
  static ProductVariant? findVariantByBarcode(
    GetProduct product,
    String barcode, {
    int? activeStoreId,
  }) {
    final normalized = normalizeBarcode(barcode);
    if (normalized.isEmpty || !product.hasVariants) {
      return null;
    }

    for (final variant in activeVariantsForStore(
      product,
      activeStoreId: activeStoreId,
    )) {
      if (normalizeBarcode(variant.barcode) == normalized) {
        return variant;
      }
    }
    return null;
  }

  /// Resolves a variant without UI when there is exactly one active variant or
  /// when [scannedBarcode] matches a variant barcode directly.
  ///
  /// Returns `null` when the product has no variants, when multiple variants
  /// require user choice, or when no barcode match was found among many variants.
  ///
  /// Out-of-stock variants are still resolved here because this pure function
  /// identifies a barcode/choice; the stock-aware add flow performs the block.
  static ProductVariant? tryResolveWithoutPicker(
    GetProduct product, {
    String? scannedBarcode,
    int? activeStoreId,
  }) {
    if (!product.hasVariants) {
      return null;
    }

    final scanned = normalizeBarcode(scannedBarcode);
    if (scanned.isNotEmpty) {
      final matched = findVariantByBarcode(
        product,
        scanned,
        activeStoreId: activeStoreId,
      );
      if (matched != null) {
        return matched;
      }
    }

    final active = activeVariantsForStore(
      product,
      activeStoreId: activeStoreId,
    );
    final matchedVariantId = product.matchedVariantId;
    if (matchedVariantId != null) {
      for (final variant in active) {
        if (variant.id == matchedVariantId) {
          return variant;
        }
      }
    }
    if (active.length == 1) {
      return active.first;
    }

    return null;
  }

  /// Whether the user must pick among multiple active variants.
  static bool needsVariantPicker(
    GetProduct product, {
    int? activeStoreId,
  }) {
    if (!product.hasVariants) {
      return false;
    }
    return activeVariantsForStore(
          product,
          activeStoreId: activeStoreId,
        ).length >
        1;
  }

  static String cartDisplayName({
    required String? productName,
    Map<String, dynamic>? variantAttributes,
  }) {
    final base = productName ?? '';
    if (variantAttributes == null || variantAttributes.isEmpty) {
      return base;
    }
    final attrs =
        variantAttributes.values.map((value) => value.toString()).join(' | ');
    return attrs.isEmpty ? base : '$base ($attrs)';
  }

  static double resolveVariantPrice({
    required ProductVariant variant,
    required double productPrice,
  }) =>
      variant.effectivePrice(productPrice);

  static double productBasePrice(GetProduct product) {
    final raw = product.price?.price;
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static double? resolveVariantMrp({
    required ProductVariant variant,
    required GetProduct product,
    required double effectivePrice,
  }) {
    if (variant.mrp != null && variant.mrp! > 0) {
      return variant.mrp;
    }
    final productMrp = double.tryParse(product.mrp?.toString() ?? '');
    return productMrp ?? effectivePrice;
  }
}
