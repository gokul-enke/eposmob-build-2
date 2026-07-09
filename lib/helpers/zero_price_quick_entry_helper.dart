import 'package:flutter/material.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_purchase_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/zero_price_quick_entry_modal.dart';
import 'package:provider/provider.dart';

/// Result of the pre-add zero-price prompt.
class ZeroPriceQuickEntryResult {
  final double price;
  final num quantity;

  const ZeroPriceQuickEntryResult({
    required this.price,
    required this.quantity,
  });
}

/// Prompts for price/quantity before a zero-priced product is added to the
/// cart. The price field is pre-filled with the default customer's last
/// bought price for the product (fetched from the existing customer
/// last-purchases API). The zero price itself is the only gate — no
/// app-settings check.
class ZeroPriceQuickEntryHelper {
  static const double _zeroPriceEpsilon = 0.001;

  static bool isZeroPrice(double? price) {
    return (price ?? 0).abs() < _zeroPriceEpsilon;
  }

  /// Shows the quick entry modal for [product] and returns the entered
  /// price/quantity, or null when the user cancelled.
  static Future<ZeroPriceQuickEntryResult?> promptForProduct({
    required BuildContext context,
    required GetProduct product,
    num initialQuantity = 1,
    double? mrp,
    Stock? selectedStock,
  }) async {
    final int? productId = product.productId;
    if (productId == null) return null;

    // Always fetch history against the configured default customer for now.
    CustomerPurchaseItem? lastPurchase;
    final int? defaultCustomerId = _resolveDefaultCustomerId(context);
    final String? token = Provider.of<AuthModel>(context, listen: false).token;

    if (defaultCustomerId != null && token != null && token.isNotEmpty) {
      try {
        final CustomerPurchaseHistory? purchaseHistory =
            await CustomerPurchaseProvider().getCustomerLastPurchases(
          accessToken: token,
          customerId: defaultCustomerId,
          productId: productId,
        );
        if (purchaseHistory != null &&
            purchaseHistory.success &&
            purchaseHistory.data.isNotEmpty) {
          lastPurchase = purchaseHistory.data.first;
        }
      } catch (error) {
        debugPrint(
            'Failed to load last purchase for zero-price entry: $error');
      }
    }

    if (!context.mounted) return null;

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';
    final double? minPrice =
        localProductProvider.minimumSalePriceForProduct(product);

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => ZeroPriceQuickEntryModal(
        product: product,
        initialQuantity: initialQuantity,
        mrp: mrp,
        stockQuantity: selectedStock?.quantity,
        currency: currency,
        lastPurchase: lastPurchase,
        minimumPrice: minPrice,
      ),
    );

    // Dialog pop restores focus to the previous field (often product search),
    // which would auto-open the alphanumeric virtual keyboard in the
    // background. Clear that before returning.
    if (context.mounted) {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      keyboardProvider.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Provider.of<KeyboardProvider>(context, listen: false).hide();
        FocusManager.instance.primaryFocus?.unfocus();
      });
    }

    if (result == null) return null;

    final double? price = (result['price'] as num?)?.toDouble();
    final num? quantity = result['quantity'] as num?;
    if (price == null || price <= 0 || quantity == null || quantity <= 0) {
      return null;
    }

    return ZeroPriceQuickEntryResult(price: price, quantity: quantity);
  }

  /// Resolves the configured default customer's id by matching the
  /// auto-assign default customer phone against the cached customer list.
  static int? _resolveDefaultCustomerId(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final String defaultPhone = appSettingsProvider
            .appSettings?.autoAssignDefaultCustomerPhone
            .trim() ??
        '';
    if (defaultPhone.isEmpty) return null;

    final customers =
        Provider.of<CustomerProvider>(context, listen: false).allCustomers;
    if (customers == null || customers.isEmpty) return null;

    for (final customer in customers) {
      if (customer.phone == defaultPhone) {
        return customer.id;
      }
    }
    return null;
  }
}
