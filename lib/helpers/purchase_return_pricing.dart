import 'dart:math' as math;

import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/models/purchase_return_model.dart';

/// Keeps the return form's displayed amount in sync with the API calculation.
///
/// The API calculates a return line from the stored purchase line total and
/// allocates the voucher discount proportionally across purchase lines. The
/// list endpoint already exposes the fields needed to reproduce that
/// calculation on the client.
class PurchaseReturnPricing {
  const PurchaseReturnPricing._();

  static double unitPrice({
    required ReturnableItem item,
    PurchaseOrderData? voucher,
  }) {
    final fallback = _parseDouble(item.unitPrice) ?? 0;
    final purchaseItem = _findPurchaseItem(voucher, item.purchaseItemId);
    if (purchaseItem == null) return fallback;

    final quantity = _parseDouble(purchaseItem.quantity);
    final totalPrice = _parseDouble(purchaseItem.totalPrice);
    if (quantity == null || quantity <= 0 || totalPrice == null) {
      return fallback;
    }

    final lineDiscount = _discountForItem(voucher, purchaseItem.id);
    return math.max(0.0, totalPrice / quantity - lineDiscount / quantity);
  }

  static double lineAmount({
    required ReturnableItem item,
    required double quantity,
    PurchaseOrderData? voucher,
  }) {
    return roundCurrency(
      quantity * unitPrice(item: item, voucher: voucher),
    );
  }

  static double roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  static String formatQuantity(double? value) {
    if (value == null || !value.isFinite || value == 0) return '0';
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static PurchaseOrderItemData? _findPurchaseItem(
    PurchaseOrderData? voucher,
    int? purchaseItemId,
  ) {
    if (voucher?.items == null || purchaseItemId == null) return null;
    for (final item in voucher!.items!) {
      if (item.id == purchaseItemId) return item;
    }
    return null;
  }

  static double _discountForItem(
    PurchaseOrderData? voucher,
    int? purchaseItemId,
  ) {
    final items = voucher?.items;
    if (items == null || items.isEmpty || purchaseItemId == null) return 0;

    final lineTotals = items
        .map((item) => math.max(
              0.0,
              roundCurrency(_parseDouble(item.totalPrice) ?? 0),
            ))
        .toList();
    final total = lineTotals.fold<double>(0, (sum, value) => sum + value);
    final normalizedDiscount = math.max(
      0.0,
      roundCurrency(_parseDouble(voucher?.discount) ?? 0),
    );
    if (total <= 0 || normalizedDiscount <= 0) return 0;

    var allocated = 0.0;
    for (var index = 0; index < items.length; index++) {
      final isLast = index == items.length - 1;
      final discount = isLast
          ? roundCurrency(normalizedDiscount - allocated)
          : roundCurrency((lineTotals[index] / total) * normalizedDiscount);
      if (!isLast) allocated += discount;

      if (items[index].id == purchaseItemId) {
        return math.min(discount, lineTotals[index]);
      }
    }
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}
