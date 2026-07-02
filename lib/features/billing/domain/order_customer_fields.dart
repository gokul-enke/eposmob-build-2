/// Shared helpers for deriving the customer name/phone that get persisted onto a
/// saved order, so the desktop billing page and the mobile billing flow build
/// the exact same values.
///
/// Mirrors desktop `BillingPage._customerNameForOrder()` /
/// `_customerPhoneForOrder()`.
class OrderCustomerFields {
  OrderCustomerFields._();

  static String? trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Customer name to persist on a draft/saved order.
  static String? nameForOrder(String? customerName) => trimToNull(customerName);

  /// Customer phone to persist on a draft/saved order.
  ///
  /// Resolution order mirrors desktop: an explicitly selected phone, then the
  /// selected customer's own phone, then the typed mobile-number text, then the
  /// raw mobile-number field text.
  static String? phoneForOrder({
    String? selectedPhone,
    String? customerPhone,
    String? mobileNumberText,
    String? controllerText,
  }) {
    return trimToNull(selectedPhone) ??
        trimToNull(customerPhone) ??
        trimToNull(mobileNumberText) ??
        trimToNull(controllerText);
  }
}
