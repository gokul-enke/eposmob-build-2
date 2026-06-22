/// Shared B2B/B2C customer-segment detection.
///
/// This single source of truth is used both for selecting the invoice title
/// in [ReceiptLayoutParams.displayConfig] and for routing the print job to the
/// correct printer / paper size / receipt theme in [PrintPage]. Keeping the
/// rule in one place ensures the title shown and the printer chosen can never
/// disagree about whether a customer is B2B.
class ReceiptCustomerSegment {
  const ReceiptCustomerSegment._();

  /// Returns true when the customer should be treated as a business (B2B).
  ///
  /// A customer is B2B when either:
  ///   1. [customerType] is explicitly "B2B" (case-insensitive), or
  ///   2. [customerType] is missing/empty but the customer has KYC details
  ///      (a VAT number or a CR number).
  /// Otherwise the customer is B2C.
  static bool isBusiness({
    String? customerType,
    String? vatNumber,
    String? crNumber,
  }) {
    final normalizedType = customerType?.trim().toUpperCase();
    final hasKycDetails = (vatNumber?.trim().isNotEmpty ?? false) ||
        (crNumber?.trim().isNotEmpty ?? false);
    return normalizedType == 'B2B' ||
        ((normalizedType == null || normalizedType.isEmpty) && hasKycDetails);
  }
}
