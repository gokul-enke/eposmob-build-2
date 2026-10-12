import 'package:pos_machine/features/offers/domain/offer_money.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/item_discount_details.dart';

/// Item price reductions are already inside total_price. line_discount is
/// the separate order/coupon allocation and must never be deducted twice.
class ReceiptLineDiscount {
  const ReceiptLineDiscount({
    required this.itemDiscount,
    required this.orderDiscount,
    required this.standardRate,
    required this.originalRate,
    required this.discountedTotal,
    required this.rateExcTax,
  });

  factory ReceiptLineDiscount.fromItem(dynamic item) {
    dynamic read(String key, String alias,
        dynamic Function(OrderDetailsModelDataCartItem) model) {
      if (item is Map) return item[key] ?? item[alias];
      return item is OrderDetailsModelDataCartItem ? model(item) : null;
    }

    double? money(dynamic value) {
      final result =
          double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '');
      return result != null && result.isFinite ? result : null;
    }

    final quantity =
        money(read('quantity', 'quantity', (i) => i.quantity)) ?? 0;
    final total =
        money(read('total_price', 'totalPrice', (i) => i.totalPrice)) ?? 0;
    final standard = money(read('standard_unit_price', 'standardUnitPrice',
        (i) => i.standardUnitPrice));
    final referenceTotal =
        money(read('standard_line_total', 'standardLineTotal', (_) => null)) ??
            (standard != null ? roundMoney(standard * quantity) : total);
    final details = detailsFromItem(item);
    final itemDiscount = money(details.itemDiscountAmount) ??
        (quantity > 0 && standard != null
            ? roundMoney((referenceTotal - total).clamp(0, double.infinity))
            : 0.0);
    final orderDiscount =
        money(read('line_discount', 'lineDiscount', (i) => i.lineDiscount)) ??
            0;
    final discountedTotal = money(read(
            'discounted_total', 'discountedTotal', (i) => i.discountedTotal)) ??
        roundMoney(total - orderDiscount);
    final rate =
        money(read('unit_price', 'unitPrice', (i) => i.unitPrice)) ?? 0;
    // Use the frozen sale-time reference only for an actual item reduction.
    // Explicit zero metadata and price increases retain the selling rate.
    final originalRate = itemDiscount > 0 && quantity > 0
        ? standard ?? (total + itemDiscount) / quantity
        : rate;
    final tax = money(read('tax_amount', 'taxAmount', (i) => i.taxAmount)) ?? 0;
    final taxRate = money(read('tax_rate', 'taxRate', (i) => i.taxRate));
    // Both Rate columns precede item and order reductions. Discounted VAT
    // cannot identify the original tax rate reliably, especially after a
    // large coupon reduction.
    final rateExcTax = taxRate != null
        ? originalRate / (1 + taxRate / 100)
        : itemDiscount > 0 || orderDiscount > 0
            ? null
            : originalRate - (quantity > 0 ? tax / quantity : 0);
    return ReceiptLineDiscount(
      itemDiscount: itemDiscount,
      orderDiscount: orderDiscount,
      standardRate: standard,
      originalRate: originalRate,
      discountedTotal: discountedTotal,
      rateExcTax: rateExcTax,
    );
  }

  final double itemDiscount;
  final double orderDiscount;
  final double? standardRate;
  final double originalRate;
  final double discountedTotal;
  final double? rateExcTax;

  /// Total saving on this row. Both components are already accounted for in
  /// selling prices/order totals; the table cell never deducts them again.
  double get totalDiscount =>
      roundMoney(itemDiscount.clamp(0, double.infinity) +
          orderDiscount.clamp(0, double.infinity));

  static ItemDiscountDetails detailsFromItem(dynamic item) => item is Map
      ? ItemDiscountDetails.fromJson(item)
      : item is OrderDetailsModelDataCartItem
          ? item.discountDetails
          : const ItemDiscountDetails();

  String get formattedRateExcTax => rateExcTax?.toStringAsFixed(2) ?? '-';
}
