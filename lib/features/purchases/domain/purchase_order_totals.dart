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
