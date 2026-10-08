import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';

class BarcodeRow {
  final GetProduct product;
  final ProductVariant? variant;
  final SaleUnit? saleUnit;

  const BarcodeRow({required this.product, this.variant, this.saleUnit});

  // ── Display helpers ──

  String get _variantSuffix {
    if (variant == null) return '';
    final attrs = variant!.attributes.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .join('/');
    return attrs.isNotEmpty ? ' - $attrs' : '';
  }

  String get _saleUnitSuffix {
    if (saleUnit == null) return '';
    final unitLabel = saleUnit!.unitName ?? '';
    return unitLabel.isNotEmpty ? ' ($unitLabel)' : '';
  }

  dynamic _buildRowNames(dynamic originalNames, String suffix) {
    if (originalNames == null) return null;
    if (originalNames is Map) {
      final newNames = <dynamic, dynamic>{};
      originalNames.forEach((key, value) {
        if (value is String) {
          newNames[key] =
              value.trim().isNotEmpty ? '${value.trim()}$suffix' : value;
        } else if (value is Map) {
          final newSubMap = <dynamic, dynamic>{};
          value.forEach((subKey, subValue) {
            if (subKey == 'name' || subKey == 'value') {
              newSubMap[subKey] =
                  (subValue != null && subValue.toString().trim().isNotEmpty)
                      ? '${subValue.toString().trim()}$suffix'
                      : subValue;
            } else {
              newSubMap[subKey] = subValue;
            }
          });
          newNames[key] = newSubMap;
        } else {
          newNames[key] = value;
        }
      });
      return newNames;
    }
    if (originalNames is List) {
      return originalNames.map((item) {
        if (item is Map) {
          final newItem = <dynamic, dynamic>{};
          item.forEach((key, value) {
            if (key == 'name' || key == 'value') {
              newItem[key] =
                  (value != null && value.toString().trim().isNotEmpty)
                      ? '${value.toString().trim()}$suffix'
                      : value;
            } else {
              newItem[key] = value;
            }
          });
          return newItem;
        }
        return item;
      }).toList();
    }
    return originalNames;
  }

  String get displayName {
    if (variant != null) {
      return '${product.productName ?? ''}$_variantSuffix';
    }
    if (saleUnit != null) {
      return '${product.productName ?? ''}$_saleUnitSuffix';
    }
    return product.productName ?? '';
  }

  String? get barcode {
    if (variant != null) return variant!.barcode;
    if (saleUnit != null) return saleUnit!.barcode;
    return product.barcode;
  }

  String? get sku {
    if (variant != null) return variant!.sku ?? product.sku;
    return product.sku;
  }

  String get quantity {
    if (variant != null) {
      return variant!.quantity?.toString() ?? '0';
    }
    // If the product has variants, the base product's own standalone quantity
    // is the sum of stock entries where productVariantId is null (excluding variants).
    final hasVariants =
        product.variants != null && product.variants!.isNotEmpty;
    if (hasVariants) {
      final baseStockQty = product.stock
          ?.where((s) => s.productVariantId == null)
          .fold<num>(0, (sum, s) => sum + (s.quantity ?? 0));
      if (baseStockQty != null && baseStockQty > 0) {
        return baseStockQty % 1 == 0
            ? baseStockQty.toInt().toString()
            : baseStockQty.toString();
      }
      return '0';
    }
    return product.numberOfProductsAvailable ?? 'product_barcode.na'.tr;
  }

  String get priceDisplay {
    if (variant != null) {
      //  treat zero variant price as invalid — fall back to base.
      final v = variant!;
      final vPrice = (v.price != null && v.price! > 0) ? v.price : null;
      return (vPrice ?? product.price?.price)?.toString() ?? 'N/A';
    }
    if (saleUnit != null) {
      //  reuse the shared resolution chain (batch override →
      // master price → resolvedPrice → base×rate), all with > 0 guards.
      final resolved = SaleUnit.resolveDisplayPrice(
        product: product,
        saleUnit: saleUnit!,
      );
      return resolved?.toString() ??
          product.price?.price?.toString() ??
          'product_barcode.na'.tr;
    }
    return product.price?.price?.toString() ?? 'product_barcode.na'.tr;
  }

  String get mrpDisplay {
    if (variant != null) {
      //  treat zero variant MRP as invalid — fall back to base.
      final v = variant!;
      final vMrp = (v.mrp != null && v.mrp! > 0) ? v.mrp : null;
      return (vMrp ?? product.mrp)?.toString() ?? 'N/A';
    }
    return product.mrp?.toString() ?? 'N/A';
  }

  /// Stable, unique key for selection tracking.
  ///
  ///  sale-unit key uses a composite fallback so two local/unsaved
  /// sale units with null [SaleUnit.id] on the same product produce distinct
  /// keys (distinguished by unitId, conversionRate/unitName, and barcode).
  String get selectionKey {
    if (variant != null) {
      return 'variant:${product.productId}:${variant!.id}';
    }
    if (saleUnit != null) {
      final u = saleUnit!;
      return 'unit:${product.productId}:'
          '${u.id ?? u.unitId}:'
          '${u.conversionRate ?? u.unitName}:'
          '${u.barcode ?? ''}';
    }
    if (product.productId != null) {
      return 'id:${product.productId}';
    }
    return 'fallback:${product.barcode ?? ''}|${product.productName ?? ''}';
  }

  /// Returns a [GetProduct] copy with this row's specific barcode, name,
  /// price, MRP, SKU and quantity baked in — so the existing print pipeline
  /// (ConfirmBarcodePrintModal → BarcodePrinterService) works unchanged.
  GetProduct toProductForPrint() {
    if (variant != null) {
      final v = variant!;
      //  treat zero variant price/MRP as invalid — fall back to base.
      final vPrice = (v.price != null && v.price! > 0) ? v.price : null;
      final vMrp = (v.mrp != null && v.mrp! > 0) ? v.mrp : null;
      final rowPrice = vPrice ?? product.price?.price;
      final rowMrp = vMrp ?? product.mrp;
      return product.copyWith(
        barcode: v.barcode ?? product.barcode,
        productName: displayName,
        sku: v.sku ?? product.sku,
        numberOfProductsAvailable: quantity,
        mrp: rowMrp,
        price: ProductPrice(
          price: rowPrice,
          oldPrice: product.price?.oldPrice,
          percentage: product.price?.percentage,
          totalPrice: product.price?.totalPrice,
        ),
        names: _buildRowNames(product.names, _variantSuffix),
        stock: product.stock?.where((s) => s.productVariantId == v.id).toList(),
      );
    }
    if (saleUnit != null) {
      final u = saleUnit!;
      //  use the shared resolution chain so batch overrides and the
      // base×conversionRate auto-fallback are included, matching billing.
      final rowPrice = SaleUnit.resolveDisplayPrice(
        product: product,
        saleUnit: u,
      );
      return product.copyWith(
        barcode: u.barcode ?? product.barcode,
        productName: displayName,
        numberOfProductsAvailable: quantity,
        price: ProductPrice(
          price: rowPrice ?? product.price?.price,
          oldPrice: product.price?.oldPrice,
          percentage: product.price?.percentage,
          totalPrice: product.price?.totalPrice,
        ),
        names: _buildRowNames(product.names, _saleUnitSuffix),
        stock: const [],
      );
    }
    //  base branch — only pass stock records that belong to the base
    // product (productVariantId == null). Variant-owned batch records must not
    // bleed into the base row's print output.
    final baseStock =
        product.stock?.where((s) => s.productVariantId == null).toList() ??
            const [];
    return product.copyWith(stock: baseStock);
  }
}
