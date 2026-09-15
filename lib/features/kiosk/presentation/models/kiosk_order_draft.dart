import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Presentation-only helpers for the kiosk UI flow.
///
/// These helpers never write to [LocalProductProvider]. They create detached
/// cart rows from the real catalogue data so the kiosk screens can be reviewed
/// before order creation and payment orchestration are connected.
class KioskOrderDraft {
  final List<LocalCartItem> items;

  const KioskOrderDraft({required this.items});

  factory KioskOrderDraft.fromCartItems(Iterable<LocalCartItem> items) {
    return KioskOrderDraft(items: items.map(copyKioskCartItem).toList());
  }

  int get itemCount => items
      .fold<num>(
        0,
        (sum, item) => sum + item.displayQuantity,
      )
      .ceil();

  double get subtotal => items.fold<double>(
        0,
        (sum, item) =>
            sum +
            ((item.displayPrice ?? item.price ?? 0) * item.displayQuantity),
      );

  double get includedTax => items.fold<double>(
        0,
        (sum, item) => sum + ((item.taxAmount ?? 0) * item.quantity),
      );

  double get total => subtotal;
}

LocalCartItem copyKioskCartItem(LocalCartItem item) {
  return LocalCartItem(
    lineId: item.lineId,
    product: item.product,
    price: item.price,
    mrp: item.mrp,
    taxRate: item.taxRate,
    taxAmount: item.taxAmount,
    quantity: item.quantity,
    selectedStock: item.selectedStock,
    stockDeducted: item.stockDeducted,
    stockGroupIds: List<int>.from(item.stockGroupIds),
    stockReservations: item.stockReservations
        .map((reservation) => reservation.copy())
        .toList(),
    comment: item.comment,
    isManualPriceOverride: item.isManualPriceOverride,
    warrantyEnabled: item.warrantyEnabled,
    saleUnitId: item.saleUnitId,
    saleUnitName: item.saleUnitName,
    saleUnitConversionRate: item.saleUnitConversionRate,
    variantId: item.variantId,
    variantAttributes: item.variantAttributes == null
        ? null
        : Map<String, dynamic>.from(item.variantAttributes!),
  );
}

double kioskProductPrice(
  GetProduct product, {
  ProductVariant? variant,
  SaleUnit? saleUnit,
}) {
  if (variant?.price != null && variant!.price! > 0) {
    return variant.price!;
  }

  if (saleUnit != null) {
    final unitPrice = SaleUnit.resolveDisplayPrice(
      product: product,
      saleUnit: saleUnit,
    );
    if (unitPrice != null && unitPrice > 0) return unitPrice;
  }

  final candidates = <dynamic>[
    product.offerPrice,
    product.price?.price,
    product.price?.totalPrice,
    product.mrp,
  ];
  for (final candidate in candidates) {
    final parsed = candidate is num
        ? candidate.toDouble()
        : double.tryParse(candidate?.toString() ?? '');
    if (parsed != null && parsed >= 0) return parsed;
  }
  return 0;
}

LocalCartItem createKioskDraftItem({
  required GetProduct product,
  required int quantity,
  ProductVariant? variant,
  SaleUnit? saleUnit,
  String? note,
}) {
  final price = kioskProductPrice(
    product,
    variant: variant,
    saleUnit: saleUnit,
  );
  final taxRate = product.totalTaxRate;
  final taxAmount = taxRate <= 0 ? 0.0 : (price * taxRate) / (100 + taxRate);

  return LocalCartItem(
    product: product,
    price: price,
    mrp: variant?.mrp ?? _asDouble(product.mrp),
    taxRate: taxRate,
    taxAmount: taxAmount,
    quantity: quantity,
    comment: note?.trim().isEmpty == true ? null : note?.trim(),
    saleUnitId: saleUnit?.id,
    saleUnitName: saleUnit?.unitName,
    // The draft stores display quantity and display price. Billing will replace
    // this with its canonical conversion logic when integration is added.
    saleUnitConversionRate: saleUnit == null ? null : 1,
    variantId: variant?.id,
    variantAttributes:
        variant == null ? null : Map<String, dynamic>.from(variant.attributes),
  );
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
