import 'dart:convert';

import 'package:pos_machine/helpers/sales_return_calculation_helper.dart';

/// Server-computed refund breakdown from `refund_breakdown` on sales-return APIs.
class SalesReturnRefundBreakdown {
  final double orderItemsTotal;
  final double returnedItemsTotal;
  final double proRataDiscount;
  final double deliveryRefund;
  final double netRefund;

  const SalesReturnRefundBreakdown({
    required this.orderItemsTotal,
    required this.returnedItemsTotal,
    required this.proRataDiscount,
    required this.deliveryRefund,
    required this.netRefund,
  });

  factory SalesReturnRefundBreakdown.fromJson(Map<String, dynamic> json) {
    double readNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0.0;

    return SalesReturnRefundBreakdown(
      orderItemsTotal: readNum(json['order_items_total']),
      returnedItemsTotal: readNum(json['returned_items_total']),
      proRataDiscount: readNum(json['pro_rata_discount']),
      deliveryRefund: readNum(json['delivery_refund']),
      netRefund: readNum(json['net_refund']),
    );
  }

  /// Parses `refund_breakdown` from a standard API success body.
  static SalesReturnRefundBreakdown? fromResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      final breakdown = data['refund_breakdown'];
      if (breakdown is! Map) return null;
      return SalesReturnRefundBreakdown.fromJson(
        Map<String, dynamic>.from(breakdown),
      );
    } catch (_) {
      return null;
    }
  }

  /// Maps server figures to UI summary; reapplies delivery toggle from the screen.
  SalesReturnRefundSummary toRefundSummary({
    required bool deliveryRefundable,
    required double shippingCost,
  }) {
    final delivery = deliveryRefundable ? shippingCost : 0.0;
    final net =
        (returnedItemsTotal - proRataDiscount + delivery).clamp(0.0, double.infinity);
    final maxCash = returnedItemsTotal + delivery;

    return SalesReturnRefundSummary(
      sessionItemsTotal: returnedItemsTotal,
      orderItemsTotal: orderItemsTotal,
      proRataDiscount: proRataDiscount,
      netRefundAmount: net,
      maxCashRefundAmount: maxCash,
      isFromServer: true,
    );
  }
}
