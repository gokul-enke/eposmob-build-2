import 'package:flutter/material.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

/// Computes delivery charge using the same rules as desktop billing
/// (`billing_page.dart` `_getDeliveryChargeForOrder`).
double computeDeliveryCharge({
  required bool freeDeliveryEnabled,
  required double freeDeliveryMinimumAmount,
  required double netTotal,
  required String deliveryMethodId,
  required String deliveryMethodName,
  required List<DeliveryMethod> deliveryMethods,
  double? overrideCharge,
}) {
  if (!freeDeliveryEnabled) {
    return 0.0;
  }

  if (freeDeliveryMinimumAmount > 0 && netTotal >= freeDeliveryMinimumAmount) {
    return 0.0;
  }

  if (overrideCharge != null) {
    return overrideCharge;
  }

  if (deliveryMethodName.isEmpty) {
    return 0.0;
  }

  for (final method in deliveryMethods) {
    if ((deliveryMethodId.isNotEmpty && method.id == deliveryMethodId) ||
        method.name == deliveryMethodName) {
      return method.basePrice ?? 0.0;
    }
  }

  return 0.0;
}

/// Resolves delivery charge from the billing provider tree.
double resolveDeliveryCharge(
  BuildContext context, {
  double? overrideCharge,
  String? deliveryMethodId,
  String? deliveryMethodName,
}) {
  final appSettings =
      Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
  final billingProvider =
      Provider.of<BillingProvider>(context, listen: false);
  final deliveryMethodsProvider =
      Provider.of<DeliveryMethodsProvider>(context, listen: false);
  final localProductProvider =
      Provider.of<LocalProductProvider>(context, listen: false);

  final freeDeliveryEnabled = appSettings?.freeDeliveryEnabled ?? false;
  final freeDeliveryMinimumAmount = double.tryParse(
        appSettings?.freeDeliveryMinimumAmount.trim() ?? '',
      ) ??
      0.0;
  final netTotal = localProductProvider.priceSummary?.netTotal ??
      localProductProvider.cartTotal;

  return computeDeliveryCharge(
    freeDeliveryEnabled: freeDeliveryEnabled,
    freeDeliveryMinimumAmount: freeDeliveryMinimumAmount,
    netTotal: netTotal,
    deliveryMethodId: deliveryMethodId ?? billingProvider.deliveryMethodId,
    deliveryMethodName: deliveryMethodName ?? billingProvider.deliveryMethod,
    deliveryMethods: deliveryMethodsProvider.deliveryMethods,
    overrideCharge: overrideCharge ?? billingProvider.deliveryChargeOverride,
  );
}

/// Formats a delivery fee for UI chips and labels.
String formatDeliveryFeeLabel(double charge, String currency) {
  if (charge == 0.0) return 'Free';
  return '($currency ${charge.toStringAsFixed(2)})';
}
