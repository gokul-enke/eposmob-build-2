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

  String? get discountValidationMessage {
    if (!discountAmount.isFinite || discountAmount < 0) {
      return 'Overall discount cannot be negative.';
    }
    if (discountAmount > grossAmount) {
      return 'Overall discount cannot exceed the gross total.';
    }
    return null;
  }

  String? validatePaymentAmount(double paidAmount) {
    if (!paidAmount.isFinite || paidAmount < 0) {
      return 'Payment amount cannot be negative.';
    }
    if (paidAmount - netPayable > 0.005) {
      return 'Payment amount cannot exceed the net payable.';
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
