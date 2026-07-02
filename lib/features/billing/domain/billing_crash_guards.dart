import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/customer_list.dart';

/// Null-safe parsing helpers for mobile billing display paths.
class BillingCrashGuards {
  BillingCrashGuards._();

  static double safePrice(double? price, {double fallback = 0.0}) {
    if (price == null || price.isNaN || price.isNegative) {
      return fallback;
    }
    return price;
  }

  static double safeMrp(double? mrp, {double fallback = 0.0}) {
    return safePrice(mrp, fallback: fallback);
  }

  static double safeTaxRate(double? taxRate, {double fallback = 0.0}) {
    if (taxRate == null || taxRate.isNaN || taxRate < 0) {
      return fallback;
    }
    return taxRate;
  }

  static String formatSafeAmount(double? value, {double fallback = 0.0}) {
    return AmountHelper.formatAmount(safePrice(value, fallback: fallback));
  }

  static double lineTotal({
    required double? unitPrice,
    required num quantity,
    double fallback = 0.0,
  }) {
    final safeUnit = safePrice(unitPrice, fallback: fallback);
    final qty = quantity.isNaN || quantity.isNegative ? 0.0 : quantity.toDouble();
    return safeUnit * qty;
  }

  static String customerDisplayName(
    CustomerListModelData? customer, {
    String fallback = 'Default B2C',
  }) {
    final name = customer?.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }

  static String? customerDisplayPhone(CustomerListModelData? customer) {
    final phone = customer?.phone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  static bool hasDeliveryMethods(List<dynamic> methods) => methods.isNotEmpty;

  /// Returns null when token is missing or blank (avoids empty-string API calls).
  static String? accessTokenOrNull(String? token) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
