import 'package:pos_machine/models/list_sales_return_items.dart';

/// Refund breakdown for a sales-return session (pro-rata discount).
class SalesReturnRefundSummary {
  final double sessionItemsTotal;
  final double orderItemsTotal;
  final double proRataDiscount;
  /// Suggested refund after pro-rata discount (and delivery if toggled).
  final double netRefundAmount;
  /// Upper limit for cash paid out — returned items total (+ delivery if toggled).
  /// Cashier may refund up to this without applying the discount reduction.
  final double maxCashRefundAmount;

  const SalesReturnRefundSummary({
    required this.sessionItemsTotal,
    required this.orderItemsTotal,
    required this.proRataDiscount,
    required this.netRefundAmount,
    required this.maxCashRefundAmount,
  });
}

class SalesReturnCalculationHelper {
  /// Quantity still returnable for a line (sold qty minus already returned).
  static double remainingReturnableQuantity(SalesReturnCart item) {
    final sold = double.tryParse(item.quantity) ?? 0;
    final remaining = sold - item.returnedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  /// Sum of line return totals added in the current session only.
  static double sessionItemsTotal({
    required List<SalesReturnCart> items,
    required Map<int, double> initialReturnedTotals,
  }) {
    var total = 0.0;
    for (final item in items) {
      final initial = initialReturnedTotals[item.cartItemId] ?? 0.0;
      final current =
          double.tryParse(item.returnedTotal.toString()) ?? 0.0;
      total += current - initial;
    }
    return total;
  }

  /// Pro-rata discount: only the share of order discount attributable to
  /// returned items (not the full order discount when returning a subset).
  static SalesReturnRefundSummary calculateRefund({
    required List<SalesReturnCart> items,
    required Map<int, double> initialReturnedTotals,
    required double orderDiscount,
    required double shippingCost,
    required bool deliveryRefundable,
  }) {
    final sessionTotal = sessionItemsTotal(
      items: items,
      initialReturnedTotals: initialReturnedTotals,
    );

    var orderItemsTotal = 0.0;
    for (final item in items) {
      orderItemsTotal +=
          double.tryParse(item.totalPrice.toString()) ?? 0.0;
    }

    final proRataDiscount = orderItemsTotal > 0 && orderDiscount > 0
        ? (sessionTotal / orderItemsTotal) * orderDiscount
        : 0.0;

    var netRefund = sessionTotal - proRataDiscount;
    final deliveryAmount = deliveryRefundable ? shippingCost : 0.0;
    if (deliveryRefundable) {
      netRefund += shippingCost;
    }

    final maxCashRefund = sessionTotal + deliveryAmount;

    return SalesReturnRefundSummary(
      sessionItemsTotal: sessionTotal,
      orderItemsTotal: orderItemsTotal,
      proRataDiscount: proRataDiscount,
      netRefundAmount: netRefund < 0 ? 0 : netRefund,
      maxCashRefundAmount: maxCashRefund < 0 ? 0 : maxCashRefund,
    );
  }
}
