import 'package:pos_machine/models/customer_list.dart';

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

  /// Address snapshot used by an immediate local/offline receipt.
  ///
  /// Delivery details win when the cashier selected or typed a delivery
  /// address. For takeaway/counter sales, fall back to the selected customer's
  /// saved address so the local receipt contains the same buyer details that a
  /// later server-backed reprint obtains from `customer_details`.
  static String? addressForReceipt({
    CustomerListModelData? customer,
    String? orderAddress,
    int? orderAddressId,
    String? orderPincode,
  }) {
    final explicitAddress = trimToNull(orderAddress);
    if (explicitAddress != null) {
      return _joinAddressParts(<String?>[explicitAddress, orderPincode]);
    }

    final savedAddresses = customer?.addresses ?? const <Address>[];
    Address? savedAddress;
    if (orderAddressId != null) {
      for (final candidate in savedAddresses) {
        if (candidate.id == orderAddressId) {
          savedAddress = candidate;
          break;
        }
      }
    }
    savedAddress ??= savedAddresses.isEmpty ? null : savedAddresses.first;

    return _joinAddressParts(<String?>[
      savedAddress?.address ?? customer?.address,
      savedAddress?.landmark,
      savedAddress?.city ?? customer?.city,
      savedAddress?.pincode ?? customer?.pincode,
      customer?.district,
      customer?.state,
      customer?.country,
    ]);
  }

  static String? _joinAddressParts(Iterable<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      final part = trimToNull(value);
      if (part == null) continue;

      final alreadyIncluded = parts.any(
        (existing) =>
            existing.toLowerCase() == part.toLowerCase() ||
            existing.toLowerCase().contains(part.toLowerCase()),
      );
      if (!alreadyIncluded) parts.add(part);
    }
    return parts.isEmpty ? null : parts.join(', ');
  }
}
