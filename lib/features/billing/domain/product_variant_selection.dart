import 'package:pos_machine/models/get_product.dart';

/// Shared variant resolution rules for mobile (and future desktop) billing.
class ProductVariantSelection {
  ProductVariantSelection._();

  static String normalizeBarcode(String? raw) => raw?.trim() ?? '';

  /// True when backend reports explicit zero quantity for this variant.
  /// `null` quantity means stock is not tracked at variant level.
  static bool isOutOfStock(ProductVariant variant) =>
      variant.quantity != null && variant.quantity == 0;

  /// Finds an active variant whose barcode matches [barcode] on [product].
  static ProductVariant? findVariantByBarcode(
    GetProduct product,
    String barcode,
  ) {
    final normalized = normalizeBarcode(barcode);
    if (normalized.isEmpty || !product.hasVariants) {
      return null;
    }

    for (final variant in product.activeVariants) {
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
  }) {
    if (!product.hasVariants) {
      return null;
    }

    final scanned = normalizeBarcode(scannedBarcode);
    if (scanned.isNotEmpty) {
      final matched = findVariantByBarcode(product, scanned);
      if (matched != null) {
        return matched;
      }
    }

    final active = product.activeVariants;
    if (active.length == 1) {
      return active.first;
    }

    return null;
  }

  /// Whether the user must pick among multiple active variants.
  static bool needsVariantPicker(GetProduct product) {
    if (!product.hasVariants) {
      return false;
    }
    return product.activeVariants.length > 1;
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
