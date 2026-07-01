import 'package:pos_machine/models/get_product.dart';

/// Shared sale-unit rules for barcode scans (desktop/mobile parity).
///
/// Desktop only passes [selectedSaleUnit] to [ProductCartHelper] when the
/// matched sale unit's conversion rate is greater than 1. A rate of 1 means
/// "base unit" — add as a plain product line without sale-unit cart identity.
class BarcodeSaleUnit {
  const BarcodeSaleUnit._();

  /// Parsed conversion rate for a sale-unit barcode match; defaults to 1.
  static num resolveSaleUnitQuantity(SaleUnit saleUnit) {
    final parsedRate = num.tryParse(saleUnit.conversionRate?.trim() ?? '');
    if (parsedRate == null || parsedRate <= 0) {
      return 1;
    }
    return parsedRate;
  }

  /// True when a matched sale-unit barcode should set cart sale-unit fields.
  static bool shouldUseSaleUnitForBarcode(SaleUnit? matchedSaleUnit) =>
      matchedSaleUnit != null &&
      resolveSaleUnitQuantity(matchedSaleUnit) > 1;

  /// Returns [matchedSaleUnit] only when it should affect cart identity.
  static SaleUnit? resolveBarcodeSaleUnit(SaleUnit? matchedSaleUnit) =>
      shouldUseSaleUnitForBarcode(matchedSaleUnit) ? matchedSaleUnit : null;
}
