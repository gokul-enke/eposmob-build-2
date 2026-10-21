class PurchaseOrderTotals {
  final double grossAmount;
  final double discountAmount;

  const PurchaseOrderTotals({
    required this.grossAmount,
    required this.discountAmount,
  });

  double get netPayable {
    final netAmount = grossAmount - discountAmount;
    return netAmount > 0 ? netAmount : 0;
  }

  /// Translation key of the discount error, or null when it is valid.
  String? get discountErrorKey {
    if (!discountAmount.isFinite || discountAmount < 0) {
      return 'purchase_order.discount_negative';
    }
    if (discountAmount > grossAmount) {
      return 'purchase_order.discount_exceeds_gross';
    }
    return null;
  }

  /// Translation key of the payment error, or null when it is valid.
  String? paymentErrorKey(double paidAmount) {
    if (!paidAmount.isFinite || paidAmount < 0) {
      return 'purchase_order.payment_negative';
    }
    if (paidAmount - netPayable > 0.005) {
      return 'purchase_order.payment_exceeds_net';
    }
    return null;
  }
}

bool isPurchaseItemReceived(dynamic status) {
  final normalized = (status ?? '').toString().trim().toUpperCase();
  return normalized == 'Y' ||
      normalized == 'RECEIVED' ||
      normalized == 'FULLY_RECEIVED';
}

/// Gross amount of the received lines of a partially received order, or null
/// when all or none of the lines are received and the order total applies.
double? partiallyReceivedPurchaseGross(Iterable<Map> items) {
  var receivedCount = 0;
  var lineCount = 0;
  double receivedGross = 0;
  for (final item in items) {
    lineCount++;
    if (!isPurchaseItemReceived(item['status'])) continue;
    receivedCount++;
    final totalPrice = double.tryParse('${item['total_price'] ?? ''}');
    receivedGross += totalPrice ??
        (double.tryParse('${item['quantity'] ?? ''}') ?? 0) *
            (double.tryParse('${item['unit_price'] ?? ''}') ?? 0);
  }
  if (receivedCount == 0 || receivedCount == lineCount) return null;
  return receivedGross;
}

double parsePurchaseAmount(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null || !parsed.isFinite) {
    return 0;
  }
  return parsed;
}

double resolveEffectivePurchaseRate({
  required double enteredRate,
  required bool taxIncludePurchase,
  double? calculatedPurchaseRate,
}) {
  if (taxIncludePurchase) return enteredRate;
  final calculated = calculatedPurchaseRate;
  if (calculated == null ||
      !calculated.isFinite ||
      calculated < 0 ||
      (enteredRate > 0 && calculated == 0)) {
    return enteredRate;
  }
  return calculated;
}
