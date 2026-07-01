import 'dart:developer' as developer;

/// Debug-only billing logs. Entirely stripped in release builds.
void billingDebugLog(String message) {
  assert(() {
    developer.log(message, name: 'billing');
    return true;
  }());
}

/// Checkout lifecycle logs without PII, tokens, transaction refs, or payloads.
void billingDebugCheckout(
  String operation,
  String phase, {
  int? itemCount,
  bool? hasCustomer,
  bool? hasPayment,
  String? errorType,
}) {
  assert(() {
    final parts = <String>[
      '[BillingCheckout] $operation: $phase',
      if (itemCount != null) 'items=$itemCount',
      if (hasCustomer != null) 'hasCustomer=$hasCustomer',
      if (hasPayment != null) 'hasPayment=$hasPayment',
      if (errorType != null) 'error=$errorType',
    ];
    developer.log(parts.join(' | '), name: 'billing');
    return true;
  }());
}
