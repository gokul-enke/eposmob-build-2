import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';
import 'package:pos_machine/models/discount_list_model.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Consistent user-facing error and recovery copy for mobile billing flows.
class BillingMobileErrorMessages {
  BillingMobileErrorMessages._();

  // Checkout / save / confirm
  static String get selectCustomer => 'billing.select_customer'.tr;
  static String get selectPaymentMethod => 'billing.select_payment_method'.tr;
  static String get configurePaymentBeforeConfirm =>
      'billing.configure_payment_before_confirm'.tr;
  static const emptyCart = 'Please add items to cart';
  static const clearCartFailed = 'Failed to clear cart. Please try again.';
  static const saveOrderFailed = 'Failed to save order. Please try again.';
  static const confirmOrderFailed =
      'Failed to confirm order. Check connection and try again.';
  static const createOrderFailed =
      'Failed to create order. Check connection and try again.';
  static const loadOrderFailed = 'Failed to load order. Please try again.';
  static const invalidPricingBeforeConfirm =
      'Please ensure all items have valid prices and MRP before confirming order';
  static const invalidPricingBeforeSave =
      'Please ensure all items have valid prices before saving';
  static String get enterCarNumber => 'billing.enter_car_number'.tr;
  static const noInternetConfirm =
      'No internet connection. Cannot confirm order online.';
  static const noInternetCreateOrder =
      'No internet connection. Cannot create order online.';

  // Quotation
  static const quotationCreateFailed = 'Failed to create quotation';
  static const quotationPrintMissingId =
      'Quotation created, but print failed because the API response did not include quotation id.';
  static const quotationPrintDetailsFailed =
      'Quotation created, but details could not be loaded for printing.';

  // Print
  static const printOrderFailed =
      'Failed to print order. Check printer and try again.';
  static const printRetryPrompt =
      'Order confirmed. Print failed — tap Retry to print again.';
  static const printRetryFailedAgain =
      'Print failed again. Check printer connection and tap Retry.';
  static const printRetrySuccess = 'Print completed successfully';

  // Barcode / product add
  static const invalidBarcode = 'Invalid barcode. Please try again.';
  static const addToCartFailed =
      'Could not add product to cart. Please try again.';

  static String insufficientStock(String unitLabel) =>
      'Insufficient stock for $unitLabel';

  static String variantOutOfStock(String variantLabel) =>
      '$variantLabel is out of stock';

  // Coupon / discount
  static const emptyCartDiscount = 'Cannot apply discount to empty cart';
  static const discountNegative = 'Discount cannot be negative';
  static const discountPercentMax = 'Percentage discount cannot exceed 100%';
  static const discountFlatExceedsTotal =
      'Flat discount cannot exceed cart total';
  static const applyCouponFailed = 'Failed to apply coupon. Please try again.';
  static const loadDiscountsFailed =
      'Could not load coupons. Check connection and try again.';

  static String couponInvalid(String couponName) =>
      'Cannot apply $couponName: coupon is not valid';

  // Customer
  static const loadCustomersFailed =
      'Could not load customers. Check connection and tap Retry.';
  static const addCustomerFailed = 'Could not add customer. Please try again.';
  static const customersUnavailable =
      'Customer list is unavailable. Tap Retry or add a new customer.';

  // Pine Labs
  static const pineLabsInvalidAmount = 'Invalid amount for Pine Labs payment';

  static String pineLabsPaymentFailed([String? terminalMessage]) {
    final detail = terminalMessage?.trim().isNotEmpty == true
        ? terminalMessage!.trim()
        : 'Pine Labs payment failed';
    return '$detail. Choose another payment method or tap Pay with Pine Labs to retry.';
  }

  /// Strips wrapper prefixes so snackbars show the underlying API message.
  static String userFacingException(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    var text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length).trim();
    }
    if (text.startsWith('HttpException: ')) {
      text = text.substring('HttpException: '.length).trim();
    }
    return text.isEmpty ? fallback : text;
  }

  /// Prefer API `message` when confirm/create-order calls return no order id.
  static String orderApiFailure(
    Map<dynamic, dynamic> response, {
    String fallback = confirmOrderFailed,
  }) {
    final message = response['message'];
    if (message is String && message.trim().isNotEmpty) {
      return userFacingException(message, fallback: fallback);
    }
    return fallback;
  }

  /// Network/timeout failures during checkout — cart is left intact.
  static String checkoutException(Object error, {required String operation}) {
    final detail = userFacingException(error);
    return 'Could not $operation: $detail Your cart is unchanged — try again.';
  }
}

/// Connectivity predicates for mobile billing checkout flows.
class BillingMobileConnectivityController {
  const BillingMobileConnectivityController();

  static const offlineConfirmMessage =
      'No internet connection. Save the order locally and confirm when you are back online.';

  static const offlineConfirmPrintMessage =
      'No internet connection. Save the order locally and confirm when you are back online.';

  /// Online confirm / confirm-print require live connectivity.
  bool canConfirmOnline(BillingProvider billingProvider) {
    return billingProvider.hasInternet;
  }

  /// Local draft save uses Hive only and does not require network.
  bool canSaveOrderOffline() => true;

  bool shouldBlockOnlineCheckout(BillingProvider billingProvider) {
    return !canConfirmOnline(billingProvider);
  }
}

class MobileDeliveryMethodSyncResult {
  const MobileDeliveryMethodSyncResult._({
    required this.applied,
    this.method,
  });

  const MobileDeliveryMethodSyncResult.skipped()
      : applied = false,
        method = null;

  const MobileDeliveryMethodSyncResult.applied(DeliveryMethod this.method)
      : applied = true;

  final bool applied;
  final DeliveryMethod? method;
}

/// App/general settings predicates and sync helpers for mobile billing.
class BillingMobileSettingsController {
  const BillingMobileSettingsController();

  bool syncStockEnabled({
    required bool? stockEnabled,
    required LocalProductProvider localProductProvider,
  }) {
    final enabled = stockEnabled ?? false;
    localProductProvider.setStockEnabled(enabled);
    return enabled;
  }

  bool isBarcodeSalesEnabled(AppSettings? appSettings) {
    return appSettings?.barcodeSales ?? false;
  }

  bool shouldShowCouponSection(AppSettings? appSettings) {
    return appSettings?.discountAndCoupon ?? false;
  }

  bool shouldShowPineLabPayment(AppSettings? appSettings) {
    if (appSettings == null) return false;
    try {
      return appSettings.pineLabPayment == true;
    } catch (_) {
      // Stale AppSettings instances after hot reload may not have new fields.
      return false;
    }
  }

  bool shouldShowPurchaseHistoryAction({
    required AppSettings? appSettings,
    required bool hasSelectedCustomer,
    required bool isDefaultCustomer,
  }) {
    return appSettings?.showCustomerLastBuyedPriceList == true &&
        hasSelectedCustomer &&
        !isDefaultCustomer;
  }

  bool shouldShowDeliveryDateTime(AppSettings? appSettings) {
    return appSettings?.askDeliveryDate ?? false;
  }

  void syncAppSettingsFlags({
    required AppSettings? appSettings,
    required BillingProvider billingProvider,
  }) {
    billingProvider.setBarcodeSalesEnabled(isBarcodeSalesEnabled(appSettings));
    billingProvider.setDiscountsEnabled(shouldShowCouponSection(appSettings));
  }

  /// Mirrors desktop `_applyDefaultPaymentMethod`: only when nothing is selected.
  bool applyDefaultPaymentMethodIfNeeded({
    required BillingProvider billingProvider,
    required AppSettings? appSettings,
  }) {
    if (billingProvider.hasAnyPaymentSelected()) {
      return false;
    }

    final defaultPayment = appSettings?.defaultPaymentMethod;
    if (defaultPayment == null || defaultPayment.isEmpty) {
      return false;
    }

    switch (defaultPayment.toUpperCase()) {
      case 'CASH':
        billingProvider.setPaymentMethod('CASH', true);
        return true;
      case 'CARD':
        billingProvider.setPaymentMethod('CARD', true);
        return true;
      case 'UPI':
        billingProvider.setPaymentMethod('UPI', true);
        return true;
      case 'COD':
        billingProvider.setPaymentMethod('COD', true);
        return true;
      default:
        return false;
    }
  }

  MobileDeliveryMethodSyncResult syncDefaultDeliveryMethod({
    required BillingProvider billingProvider,
    required DeliveryMethodsProvider deliveryMethodsProvider,
    required AppSettings? appSettings,
  }) {
    if (deliveryMethodsProvider.isLoading ||
        deliveryMethodsProvider.deliveryMethods.isEmpty) {
      return const MobileDeliveryMethodSyncResult.skipped();
    }

    final defaultMethod = deliveryMethodsProvider.resolveDefaultDeliveryMethod(
      appSettingsDefault: appSettings?.defaultDeliveryMethod,
    );
    if (defaultMethod == null) {
      return const MobileDeliveryMethodSyncResult.skipped();
    }

    if (billingProvider.deliveryMethod == defaultMethod.name &&
        billingProvider.deliveryMethodId == defaultMethod.id) {
      return const MobileDeliveryMethodSyncResult.skipped();
    }

    billingProvider.setDeliveryMethod(defaultMethod.name, defaultMethod.id);
    return MobileDeliveryMethodSyncResult.applied(defaultMethod);
  }
}

class BillingMobileMarketController {
  const BillingMobileMarketController();

  static const String allProductsCategory = 'All products';

  List<GetProduct> visibleProducts({
    required List<GetProduct> products,
    required String query,
    required String selectedCategory,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedCategory = selectedCategory.trim().toLowerCase();

    return products.where((product) {
      final name = product.productName?.toLowerCase() ?? '';
      final category = product.category?.name?.trim().toLowerCase() ?? '';
      final matchesSearch =
          normalizedQuery.isEmpty || name.contains(normalizedQuery);
      final matchesCategory =
          normalizedCategory == allProductsCategory.toLowerCase() ||
              category == normalizedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> categories(List<GetProduct> products, {int maxCategories = 8}) {
    final names = <String>{};
    for (final product in products) {
      final name = product.category?.name?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return [allProductsCategory, ...names.take(maxCategories)];
  }

  static const _cartController = BillingMobileCartController();

  /// Default quantity for market add sheet — mirrors desktop billing header.
  String defaultQuantityText() => '1';

  double defaultUnitPrice(GetProduct product) {
    return double.tryParse(product.price?.price ?? '0') ?? 0;
  }

  double defaultMrp(GetProduct product) {
    return double.tryParse(product.mrp ?? '0') ?? 0;
  }

  String formatAddFieldPrice(double value) =>
      _cartController.formatPrice(value);

  List<MobileCartUnitOption> saleUnitOptionsForProduct(GetProduct product) {
    final uniqueSaleUnits = <int, SaleUnit>{};
    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      final id = saleUnit.id;
      if (id == null || _cartController.parseSaleUnitRate(saleUnit) == null) {
        continue;
      }
      uniqueSaleUnits[id] = saleUnit;
    }

    final baseUnit = product.unit?.trim();
    final baseLabel = baseUnit == null || baseUnit.isEmpty ? '-' : baseUnit;
    final options = <MobileCartUnitOption>[
      MobileCartUnitOption(value: 'base', label: baseLabel),
    ];
    final normalizedBaseLabel = baseLabel.trim().toLowerCase();

    for (final saleUnit in uniqueSaleUnits.values) {
      final saleUnitId = saleUnit.id;
      final saleUnitLabel = saleUnit.unitName?.trim().isNotEmpty == true
          ? saleUnit.unitName!.trim()
          : saleUnitId?.toString();
      if (saleUnitId == null || saleUnitLabel == null) {
        continue;
      }
      final isDuplicateBaseUnit =
          saleUnitLabel.trim().toLowerCase() == normalizedBaseLabel;
      if (isDuplicateBaseUnit) {
        continue;
      }
      options.add(
        MobileCartUnitOption(
          value: saleUnitId.toString(),
          label: saleUnitLabel,
        ),
      );
    }
    return options;
  }

  bool canChangeSaleUnit(GetProduct product) {
    return saleUnitOptionsForProduct(product).length > 1;
  }

  SaleUnit? resolveSaleUnit(GetProduct product, String value) {
    if (value == 'base') {
      return null;
    }
    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      if (saleUnit.id?.toString() == value) {
        return saleUnit;
      }
    }
    return null;
  }

  MobileMarketAddParseResult parseAddForm({
    required String quantityText,
    required String priceText,
    String? mrpText,
  }) {
    final quantity = num.tryParse(quantityText.trim());
    if (quantity == null || quantity <= 0) {
      return const MobileMarketAddParseResult.failure(
        'Enter a valid quantity greater than zero.',
      );
    }

    final price = double.tryParse(priceText.trim());
    if (price == null || price < 0) {
      return const MobileMarketAddParseResult.failure(
        'Enter a valid unit price.',
      );
    }

    double? mrp;
    if (mrpText != null && mrpText.trim().isNotEmpty) {
      mrp = double.tryParse(mrpText.trim());
      if (mrp == null || mrp < 0) {
        return const MobileMarketAddParseResult.failure(
          'Enter a valid MRP.',
        );
      }
    }

    return MobileMarketAddParseResult.success(
      MobileMarketAddFormValues(
        quantity: quantity,
        customPrice: price > 0 ? price : null,
        customMrp: mrp,
      ),
    );
  }
}

class MobileMarketAddFormValues {
  const MobileMarketAddFormValues({
    required this.quantity,
    this.customPrice,
    this.customMrp,
    this.selectedSaleUnit,
  });

  final num quantity;
  final double? customPrice;
  final double? customMrp;
  final SaleUnit? selectedSaleUnit;

  MobileMarketAddFormValues copyWith({
    SaleUnit? selectedSaleUnit,
  }) {
    return MobileMarketAddFormValues(
      quantity: quantity,
      customPrice: customPrice,
      customMrp: customMrp,
      selectedSaleUnit: selectedSaleUnit ?? this.selectedSaleUnit,
    );
  }
}

class MobileMarketAddParseResult {
  const MobileMarketAddParseResult._({
    required this.success,
    this.values,
    this.errorMessage,
  });

  const MobileMarketAddParseResult.success(MobileMarketAddFormValues values)
      : this._(success: true, values: values);

  const MobileMarketAddParseResult.failure(String message)
      : this._(success: false, errorMessage: message);

  final bool success;
  final MobileMarketAddFormValues? values;
  final String? errorMessage;
}

class MobileCartUnitOption {
  const MobileCartUnitOption({
    required this.value,
    required this.label,
  });

  /// `base` for the product base unit, otherwise the sale unit id as string.
  final String value;
  final String label;
}

class MobileSaleUnitChangeResult {
  const MobileSaleUnitChangeResult.success()
      : success = true,
        errorMessage = null;

  const MobileSaleUnitChangeResult.failure(this.errorMessage) : success = false;

  final bool success;
  final String? errorMessage;
}

class MobilePriceCommitResult {
  const MobilePriceCommitResult({
    required this.committed,
    this.clampedToDisplayPrice,
  });

  final bool committed;
  final double? clampedToDisplayPrice;
}

class BillingMobileCartController {
  const BillingMobileCartController();

  double? parseSaleUnitRate(SaleUnit saleUnit) {
    final rate = double.tryParse(saleUnit.conversionRate?.trim() ?? '');
    if (rate == null || rate <= 0) {
      return null;
    }
    return rate;
  }

  List<SaleUnit> validSaleUnitsForCartItem(LocalCartItem item) {
    final uniqueSaleUnits = <int, SaleUnit>{};
    for (final saleUnit in item.product.saleUnits ?? const <SaleUnit>[]) {
      final id = saleUnit.id;
      if (id == null || parseSaleUnitRate(saleUnit) == null) {
        continue;
      }
      uniqueSaleUnits[id] = saleUnit;
    }
    return uniqueSaleUnits.values.toList();
  }

  List<MobileCartUnitOption> cartUnitOptionsForItem(LocalCartItem item) {
    final saleUnits = validSaleUnitsForCartItem(item);
    final baseUnit = item.product.unit?.trim();
    final baseLabel = baseUnit == null || baseUnit.isEmpty ? '-' : baseUnit;
    final options = <MobileCartUnitOption>[
      MobileCartUnitOption(value: 'base', label: baseLabel),
    ];
    final normalizedBaseLabel = baseLabel.trim().toLowerCase();

    for (final saleUnit in saleUnits) {
      final saleUnitId = saleUnit.id;
      final saleUnitLabel = saleUnit.unitName?.trim().isNotEmpty == true
          ? saleUnit.unitName!.trim()
          : saleUnitId?.toString();
      if (saleUnitId == null || saleUnitLabel == null) {
        continue;
      }
      final isDuplicateBaseUnit =
          saleUnitLabel.trim().toLowerCase() == normalizedBaseLabel;
      if (isDuplicateBaseUnit && item.saleUnitId != saleUnitId) {
        continue;
      }
      options.add(
        MobileCartUnitOption(
          value: saleUnitId.toString(),
          label: saleUnitLabel,
        ),
      );
    }
    return options;
  }

  String selectedCartUnitValue(LocalCartItem item) {
    return item.saleUnitId == null ? 'base' : item.saleUnitId.toString();
  }

  bool canChangeSaleUnit(LocalCartItem item) {
    final options = cartUnitOptionsForItem(item);
    return options.length > 1 || item.saleUnitId != null;
  }

  MobileSaleUnitChangeResult changeSaleUnit({
    required LocalProductProvider provider,
    required LocalCartItem item,
    required String value,
  }) {
    if (item.product.productId == null) {
      return const MobileSaleUnitChangeResult.failure(
        'Unable to change unit for this cart item.',
      );
    }

    if (value == 'base') {
      if (item.saleUnitId == null) {
        return const MobileSaleUnitChangeResult.success();
      }
      final changed = provider.changeCartItemSaleUnit(
        item.product.productId!,
        item.selectedStock,
        stockGroupIds: item.stockGroupIds,
        currentSaleUnitId: item.saleUnitId,
      );
      if (!changed) {
        return const MobileSaleUnitChangeResult.failure(
          'Unable to change unit for this cart item.',
        );
      }
      return const MobileSaleUnitChangeResult.success();
    }

    if (value == item.saleUnitId?.toString()) {
      return const MobileSaleUnitChangeResult.success();
    }

    SaleUnit? selectedSaleUnit;
    for (final saleUnit in validSaleUnitsForCartItem(item)) {
      if (saleUnit.id?.toString() == value) {
        selectedSaleUnit = saleUnit;
        break;
      }
    }
    final selectedRate =
        selectedSaleUnit == null ? null : parseSaleUnitRate(selectedSaleUnit);
    if (selectedSaleUnit == null || selectedRate == null) {
      return const MobileSaleUnitChangeResult.failure(
        'Unable to change unit for this cart item.',
      );
    }

    final changed = provider.changeCartItemSaleUnit(
      item.product.productId!,
      item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      currentSaleUnitId: item.saleUnitId,
      newSaleUnitId: selectedSaleUnit.id,
      newSaleUnitName: selectedSaleUnit.unitName,
      newSaleUnitConversionRate: selectedRate,
    );
    if (!changed) {
      return MobileSaleUnitChangeResult.failure(
        'Insufficient stock for ${selectedSaleUnit.unitName ?? item.product.unit ?? 'selected unit'}.',
      );
    }
    return const MobileSaleUnitChangeResult.success();
  }

  /// Inclusive tax extraction: `(price * quantity * rate) / (100 + rate)`.
  double inclusiveTaxAmount({
    required double unitPrice,
    required num quantity,
    required double taxRate,
  }) {
    if (taxRate <= 0) {
      return 0;
    }
    final itemTotal = unitPrice * quantity;
    return (itemTotal * taxRate) / (100 + taxRate);
  }

  String formatPrice(double value) {
    final roundedValue = value.roundToDouble();
    if ((value - roundedValue).abs() < 0.0001) {
      return roundedValue.toInt().toString();
    }
    return value.toString();
  }

  MobilePriceCommitResult commitDisplayPrice({
    required LocalProductProvider provider,
    required LocalCartItem item,
    required double displayPrice,
  }) {
    if (item.product.productId == null) {
      return const MobilePriceCommitResult(committed: false);
    }

    final enteredBase = item.toBaseAmount(displayPrice) ?? displayPrice;
    final minBase = provider.minimumSalePriceForProduct(item.product);

    if (minBase != null && enteredBase < minBase - 0.001) {
      provider.updateItemPrice(
        item.product.productId!,
        item.selectedStock,
        minBase,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
      final minDisplay = item.toDisplayAmount(minBase) ?? minBase;
      return MobilePriceCommitResult(
        committed: true,
        clampedToDisplayPrice: minDisplay,
      );
    }

    provider.updateItemPrice(
      item.product.productId!,
      item.selectedStock,
      enteredBase,
      stockGroupIds: item.stockGroupIds,
      saleUnitId: item.saleUnitId,
    );
    return const MobilePriceCommitResult(committed: true);
  }

  void updateDisplayPriceWhileEditing({
    required LocalProductProvider provider,
    required LocalCartItem item,
    required String text,
  }) {
    if (item.product.productId == null) {
      return;
    }

    final parsedPrice = double.tryParse(text);
    if (parsedPrice != null && parsedPrice >= 0) {
      provider.updateItemPrice(
        item.product.productId!,
        item.selectedStock,
        item.toBaseAmount(parsedPrice) ?? parsedPrice,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
    } else if (text.isEmpty) {
      provider.updateItemPrice(
        item.product.productId!,
        item.selectedStock,
        0.0,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
    }
  }

  void updateDisplayMrpWhileEditing({
    required LocalProductProvider provider,
    required LocalCartItem item,
    required String text,
  }) {
    if (item.product.productId == null) {
      return;
    }

    final parsedMrp = double.tryParse(text);
    if (parsedMrp != null && parsedMrp >= 0) {
      provider.updateItemMrp(
        item.product.productId!,
        item.selectedStock,
        item.toBaseAmount(parsedMrp) ?? parsedMrp,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
    } else if (text.isEmpty) {
      provider.updateItemMrp(
        item.product.productId!,
        item.selectedStock,
        0.0,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
    }
  }

  MobileCartTotals totals(LocalProductProvider provider) {
    final total = provider.cartTotal;
    final summary = provider.priceSummary;
    final tax = summary?.totalTax ?? 0.0;
    final rawSubtotal = (summary?.subTotal ?? total) - tax;
    final subtotal = rawSubtotal < 0 ? 0.0 : rawSubtotal.toDouble();

    return MobileCartTotals(
      subtotal: subtotal,
      tax: tax,
      total: total,
    );
  }

  Future<void> changeQuantity(
    BuildContext context,
    LocalProductProvider provider,
    LocalCartItem item,
    int step,
  ) async {
    final newDisplayQty = item.displayQuantity + step;
    final newBaseQty =
        item.hasSaleUnit ? item.toBaseQuantity(newDisplayQty) : newDisplayQty;

    await CartQuantityStockHelper.syncCartItemQuantity(
      cartItem: item,
      newQuantity: newBaseQty,
      context: context,
      localProductProvider: provider,
    );
  }

  void removeItem(LocalProductProvider provider, LocalCartItem item) {
    provider.removeFromCart(
      item.product.productId!,
      item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      saleUnitId: item.saleUnitId,
    );
  }

  /// Applies a price selected from customer purchase history. Historical
  /// prices are recorded per base unit (matching desktop
  /// `billing_page.dart`'s purchase-history apply-old-price flow), so unlike
  /// [commitDisplayPrice] no sale-unit conversion is applied here.
  MobileHistoricalPriceResult applyPurchaseHistoryPrice({
    required LocalProductProvider provider,
    required LocalCartItem item,
    required double historicalBasePrice,
  }) {
    if (item.product.productId == null) {
      return const MobileHistoricalPriceResult(applied: false);
    }

    final minBase = provider.minimumSalePriceForProduct(item.product);
    if (minBase != null && historicalBasePrice < minBase - 0.001) {
      return MobileHistoricalPriceResult(
        applied: false,
        belowMinimumPrice: minBase,
      );
    }

    provider.updateItemPrice(
      item.product.productId!,
      item.selectedStock,
      historicalBasePrice,
      stockGroupIds: item.stockGroupIds,
      saleUnitId: item.saleUnitId,
    );
    return const MobileHistoricalPriceResult(applied: true);
  }
}

class MobileHistoricalPriceResult {
  const MobileHistoricalPriceResult({
    required this.applied,
    this.belowMinimumPrice,
  });

  final bool applied;
  final double? belowMinimumPrice;
}

class MobileCartTotals {
  const MobileCartTotals({
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double tax;
  final double total;
}

class MobileDiscountValidationResult {
  const MobileDiscountValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const MobileDiscountValidationResult.invalid(this.errorMessage)
      : isValid = false;

  final bool isValid;
  final String? errorMessage;
}

class MobileApplyDiscountResult {
  const MobileApplyDiscountResult.success()
      : success = true,
        errorMessage = null,
        couponApiFailed = false;

  const MobileApplyDiscountResult.failure(this.errorMessage)
      : success = false,
        couponApiFailed = false;

  const MobileApplyDiscountResult.couponApiFailed()
      : success = false,
        errorMessage = BillingMobileErrorMessages.applyCouponFailed,
        couponApiFailed = true;

  final bool success;
  final String? errorMessage;
  final bool couponApiFailed;
}

/// Coupon selection, validation, and discount application for mobile billing.
class BillingMobileCouponController {
  const BillingMobileCouponController();

  String initialDiscountFieldText(double value) {
    return value == 0.0 ? '' : value.toString();
  }

  DiscountData? findDiscountByCode(List<DiscountData> discounts, String code) {
    if (code.isEmpty) return null;
    for (final discount in discounts) {
      if (discount.couponCode.toLowerCase() == code.toLowerCase()) {
        return discount;
      }
    }
    return null;
  }

  bool shouldClearSelectedCouponOnManualInput({
    required String flatDiscountText,
    required String percentageDiscountText,
    required DiscountData? selectedDiscount,
  }) {
    if (selectedDiscount == null) return false;
    return flatDiscountText.isNotEmpty || percentageDiscountText.isNotEmpty;
  }

  ({String flat, String percent}) fieldValuesForSelectedDiscount(
    DiscountData discount,
  ) {
    final isPercentage = discount.discountType.toLowerCase() == 'percent';
    final value = discount.discountValue.toDouble();
    if (isPercentage) {
      return (flat: '', percent: value.toString());
    }
    return (flat: value.toString(), percent: '');
  }

  double originalSubTotal(LocalProductProvider localProductProvider) {
    return localProductProvider.priceSummary?.originalSubTotal ??
        localProductProvider.cartTotal;
  }

  MobileDiscountValidationResult validateCanApplyDiscount({
    required bool cartIsEmpty,
    required double originalSubTotal,
  }) {
    if (cartIsEmpty || originalSubTotal <= 0) {
      return const MobileDiscountValidationResult.invalid(
        BillingMobileErrorMessages.emptyCartDiscount,
      );
    }
    return const MobileDiscountValidationResult.valid();
  }

  MobileDiscountValidationResult validateDiscountInputs({
    required String flatDiscountText,
    required String percentageDiscountText,
    required double originalSubTotal,
  }) {
    final flatDiscount = double.tryParse(flatDiscountText) ?? 0.0;
    final percentageDiscount = double.tryParse(percentageDiscountText) ?? 0.0;

    if (flatDiscount < 0 || percentageDiscount < 0) {
      return const MobileDiscountValidationResult.invalid(
        BillingMobileErrorMessages.discountNegative,
      );
    }
    if (percentageDiscount > 100) {
      return const MobileDiscountValidationResult.invalid(
        BillingMobileErrorMessages.discountPercentMax,
      );
    }
    if (flatDiscount > originalSubTotal && originalSubTotal > 0) {
      return const MobileDiscountValidationResult.invalid(
        BillingMobileErrorMessages.discountFlatExceedsTotal,
      );
    }
    return const MobileDiscountValidationResult.valid();
  }

  MobileDiscountValidationResult validateCouponValidity({
    required DiscountValidity validity,
    required String couponName,
  }) {
    if (validity == DiscountValidity.valid) {
      return const MobileDiscountValidationResult.valid();
    }
    return MobileDiscountValidationResult.invalid(
      BillingMobileErrorMessages.couponInvalid(couponName),
    );
  }

  ({double flat, double percent}) parseDiscountAmounts({
    required String flatDiscountText,
    required String percentageDiscountText,
  }) {
    return (
      flat: double.tryParse(flatDiscountText) ?? 0.0,
      percent: double.tryParse(percentageDiscountText) ?? 0.0,
    );
  }

  double deliveryChargeFromTotals({
    required double effectiveTotal,
    required double netTotal,
  }) {
    return effectiveTotal - netTotal;
  }

  bool shouldSyncClearedDiscountFields({
    required double flatDiscount,
    required double percentageDiscount,
    required String flatFieldText,
    required String percentageFieldText,
  }) {
    return flatDiscount == 0.0 &&
        percentageDiscount == 0.0 &&
        (flatFieldText.isNotEmpty || percentageFieldText.isNotEmpty);
  }

  /// Applies manual/coupon discount locally, optionally calls coupon API, then
  /// remaps payment amounts for the new payable total.
  Future<MobileApplyDiscountResult> applyDiscount({
    required LocalProductProvider localProductProvider,
    required BillingProvider billingProvider,
    required DiscountProvider discountProvider,
    required BillingMobilePaymentController paymentController,
    required String flatDiscountText,
    required String percentageDiscountText,
    required DiscountData? selectedDiscount,
    required Future<bool> Function() applyCouponApi,
  }) async {
    final subTotal = originalSubTotal(localProductProvider);

    final canApply = validateCanApplyDiscount(
      cartIsEmpty: localProductProvider.cartItems.isEmpty,
      originalSubTotal: subTotal,
    );
    if (!canApply.isValid) {
      return MobileApplyDiscountResult.failure(canApply.errorMessage);
    }

    final inputValidation = validateDiscountInputs(
      flatDiscountText: flatDiscountText,
      percentageDiscountText: percentageDiscountText,
      originalSubTotal: subTotal,
    );
    if (!inputValidation.isValid) {
      return MobileApplyDiscountResult.failure(inputValidation.errorMessage);
    }

    if (selectedDiscount != null) {
      final validity = discountProvider.getValidityForDiscount(
        selectedDiscount,
        subTotal,
      );
      final couponValidation = validateCouponValidity(
        validity: validity,
        couponName: selectedDiscount.couponName,
      );
      if (!couponValidation.isValid) {
        return MobileApplyDiscountResult.failure(couponValidation.errorMessage);
      }
    }

    final oldEffectiveTotal = billingProvider.totalOrderAmount;
    final oldNetTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;
    final deliveryCharge = deliveryChargeFromTotals(
      effectiveTotal: oldEffectiveTotal,
      netTotal: oldNetTotal,
    );

    final amounts = parseDiscountAmounts(
      flatDiscountText: flatDiscountText,
      percentageDiscountText: percentageDiscountText,
    );

    localProductProvider.applyDiscount(
      flatDiscount: amounts.flat,
      percentageDiscount: amounts.percent,
    );

    if (selectedDiscount != null) {
      billingProvider.coupenCodeTextController.text =
          selectedDiscount.couponCode;
      try {
        final couponApplied = await applyCouponApi();
        if (!couponApplied) {
          return const MobileApplyDiscountResult.couponApiFailed();
        }
      } catch (_) {
        return const MobileApplyDiscountResult.couponApiFailed();
      }
      if (!billingProvider.isCouponApplied) {
        return const MobileApplyDiscountResult.couponApiFailed();
      }
      billingProvider.setCouponApplied(
        true,
        code: selectedDiscount.couponCode,
        discount: amounts.flat > 0 ? amounts.flat : amounts.percent,
      );
    } else {
      billingProvider.coupenCodeTextController.text = '';
      billingProvider.setCouponApplied(
        amounts.flat > 0 || amounts.percent > 0,
        code: '',
        discount: amounts.flat > 0 ? amounts.flat : amounts.percent,
      );
    }

    final newNetTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;
    paymentController.remapPaymentsAfterDiscountChange(
      bp: billingProvider,
      oldEffectiveTotal: oldEffectiveTotal,
      newEffectiveTotal: newNetTotal + deliveryCharge,
    );

    return const MobileApplyDiscountResult.success();
  }

  /// Clears cart discount, billing coupon state, and remaps payments.
  void clearDiscount({
    required LocalProductProvider localProductProvider,
    required BillingProvider billingProvider,
    required BillingMobilePaymentController paymentController,
    void Function({required int customerId, required String accessToken})?
        refreshCart,
    String? accessToken,
    int? customerId,
  }) {
    final oldEffectiveTotal = billingProvider.totalOrderAmount;
    final oldNetTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;
    final deliveryCharge = deliveryChargeFromTotals(
      effectiveTotal: oldEffectiveTotal,
      netTotal: oldNetTotal,
    );

    localProductProvider.clearDiscount();
    billingProvider.clearDiscounts();

    if (customerId != null && accessToken != null && refreshCart != null) {
      refreshCart(customerId: customerId, accessToken: accessToken);
    }

    final newNetTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;
    paymentController.remapPaymentsAfterDiscountChange(
      bp: billingProvider,
      oldEffectiveTotal: oldEffectiveTotal,
      newEffectiveTotal: newNetTotal + deliveryCharge,
    );
  }
}

class BillingMobilePaymentController {
  const BillingMobilePaymentController();

  static const Set<String> knownPaymentTypes = {
    'CASH',
    'CARD',
    'UPI',
    'COD',
    'DEBIT',
    'ONLINE',
  };

  bool isDynamicBackendMethod(MasterDataValue method) {
    return !knownPaymentTypes.contains(method.value.toUpperCase());
  }

  String displayNameForMethod(MasterDataValue method) {
    final description = method.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return method.value;
  }

  List<MasterDataValue> sortPaymentMethods(List<MasterDataValue> methods) {
    final sortedMethods = List<MasterDataValue>.from(methods);
    sortedMethods.sort((a, b) {
      if (a.value.toUpperCase() == 'CASH') return -1;
      if (b.value.toUpperCase() == 'CASH') return 1;
      return a.value.compareTo(b.value);
    });
    return sortedMethods;
  }

  MobilePaymentMethodIds paymentMethodIds(List<MasterDataValue> methods) {
    String? cashId;
    String? cardId;
    String? upiId;
    String? codId;

    for (final method in methods) {
      final value = method.value.toUpperCase();
      if (value == 'CASH') {
        cashId = method.id.toString();
      } else if (value == 'CARD') {
        cardId = method.id.toString();
      } else if (value == 'UPI') {
        upiId = method.id.toString();
      } else if (value == 'COD') {
        codId = method.id.toString();
      }
    }

    return MobilePaymentMethodIds(
      cashId: cashId,
      cardId: cardId,
      upiId: upiId,
      codId: codId,
    );
  }

  List<MasterDataValue> preparePaymentMethods(List<MasterDataValue> methods) {
    return sortPaymentMethods(methods);
  }

  void syncPaymentMethodIds(
    BillingProvider bp,
    List<MasterDataValue> methods,
  ) {
    final ids = paymentMethodIds(methods);
    bp.updatePaymentMethodIds(
      cashId: ids.cashId,
      cardId: ids.cardId,
      upiId: ids.upiId,
      codId: ids.codId,
    );
  }

  /// Builds the mobile payment rows entirely from the backend/config-driven
  /// [methods] list (already enabled + sorted upstream). No hardcoded core
  /// scaffold — order, label, icon, and behavior all come from the backend.
  ///
  /// `ONLINE`/terminal methods have no inline amount row (the Pine Labs section
  /// handles them), so they are skipped here.
  List<MobilePaymentItem> paymentItems(
    BillingProvider bp,
    List<PaymentMethod> methods,
  ) {
    final items = <MobilePaymentItem>[];

    for (final method in methods) {
      // Terminal methods (e.g. ONLINE / Pine Labs) are driven by the dedicated
      // Pine Labs section, not an inline amount field.
      if (method.behavior == PaymentBehavior.terminal) continue;

      final code = method.code.toUpperCase();
      final isCore = bp.isCoreCode(code);
      final methodId =
          isCore ? null : (method.id.isNotEmpty ? method.id : code);

      items.add(
        MobilePaymentItem(
          name: method.label,
          type: code,
          methodId: methodId,
          iconKey: method.iconKey,
          behavior: method.behavior,
          controller: bp.amountControllerForCode(
            code,
            methodId: methodId,
            displayValue: code,
          ),
          selected: bp.isCodeSelected(code, methodId: methodId),
          // Credit (DEBIT) amount is auto-calculated → read-only.
          readOnly: method.behavior == PaymentBehavior.credit,
          isDynamic: !isCore,
        ),
      );
    }

    return items;
  }

  /// Syncs core payment method backend ids into [bp] from the model list, so
  /// order payloads carry the store-specific ids for CASH/CARD/UPI/COD.
  void syncPaymentMethodIdsFromModels(
    BillingProvider bp,
    List<PaymentMethod> methods,
  ) {
    String? cashId;
    String? cardId;
    String? upiId;
    String? codId;
    for (final method in methods) {
      if (method.id.isEmpty) continue;
      switch (method.code.toUpperCase()) {
        case 'CASH':
          cashId = method.id;
          break;
        case 'CARD':
          cardId = method.id;
          break;
        case 'UPI':
          upiId = method.id;
          break;
        case 'COD':
          codId = method.id;
          break;
      }
    }
    bp.updatePaymentMethodIds(
      cashId: cashId,
      cardId: cardId,
      upiId: upiId,
      codId: codId,
    );
  }

  /// Icon for a payment row. Prefers the backend [iconKey], then falls back to
  /// a heuristic on the method code/type.
  IconData iconForItem(MobilePaymentItem item) {
    final key = item.iconKey?.trim().toLowerCase();
    if (key != null && key.isNotEmpty) {
      final byKey = _iconForKeyword(key);
      if (byKey != null) return byKey;
    }
    return iconForType(item.type);
  }

  IconData? _iconForKeyword(String value) {
    if (value.contains('cash')) return Icons.money;
    if (value.contains('card')) return Icons.credit_card;
    if (value.contains('upi') || value.contains('qr')) return Icons.qr_code;
    if (value.contains('cod') || value.contains('ship')) {
      return Icons.local_shipping;
    }
    if (value.contains('debit') ||
        value.contains('credit') ||
        value.contains('wallet')) {
      return Icons.account_balance_wallet;
    }
    if (value.contains('bank')) return Icons.account_balance;
    if (value.contains('online') || value.contains('terminal')) {
      return Icons.point_of_sale;
    }
    return null;
  }

  IconData iconForType(String type) {
    return _iconForKeyword(type.toLowerCase()) ?? Icons.payment;
  }

  bool shouldShowItem(MobilePaymentItem item, BillingProvider bp) {
    if (item.behavior == PaymentBehavior.credit || item.type == 'DEBIT') {
      // Pay-from-credit row conflicts with to-customer-credit amount field.
      if (bp.toCustomerCreditEnabled) return false;
      return bp.selectedCustomer != null;
    }
    return true;
  }

  /// Whether the to-customer-credit section should appear (non-walk-in customer).
  bool shouldShowToCustomerCreditSection({
    required CustomerListModelData? customer,
    required CustomerSelectionProvider customerSelectionProvider,
    required String defaultCustomerPhone,
  }) {
    if (customer == null) return false;
    return !const BillingMobileCustomerController().isDefaultCustomer(
      customer: customer,
      customerSelectionProvider: customerSelectionProvider,
      defaultCustomerPhone: defaultCustomerPhone,
    );
  }

  /// Transaction excess before customer-credit allocation (mirrors desktop
  /// `_computeBaseBalance`).
  double computeTransactionExcess(BillingProvider bp) {
    final excess = bp.getTotalPaidAmount() - bp.effectiveOrderTotal;
    return excess > 0 ? excess : 0.0;
  }

  /// Maximum allocatable credit (mirrors desktop balance clamping).
  double maxToCustomerCreditAmount(BillingProvider bp) {
    final cartTotal = bp.effectiveOrderTotal;
    final totalCollected = bp.getTotalPaidAmount();
    final customerPrevBalance = bp.selectedCustomer?.balance ?? 0.0;

    if (customerPrevBalance < 0) {
      final transactionExcess = totalCollected - cartTotal;
      return transactionExcess > 0 ? transactionExcess : 0.0;
    }

    final netDue =
        (cartTotal - customerPrevBalance).clamp(0.0, double.infinity);
    final availableBalance = totalCollected - netDue;
    return availableBalance > 0 ? availableBalance : 0.0;
  }

  /// Prefill when enabling the toggle (mirrors desktop `_setToCustomerCreditEnabled`).
  double prefillToCustomerCreditAmount(BillingProvider bp) {
    final transactionExcess = computeTransactionExcess(bp);
    if (transactionExcess <= 0) return 0.0;

    final customerPrevBalance = bp.selectedCustomer?.balance ?? 0.0;
    if (customerPrevBalance < 0) {
      final customerDebt = customerPrevBalance.abs();
      return customerDebt <= transactionExcess
          ? customerDebt
          : transactionExcess;
    }
    return transactionExcess;
  }

  void toggleToCustomerCredit(BillingProvider bp, bool enabled) {
    bp.setToCustomerCreditEnabled(enabled);
    if (enabled) {
      final prefill = prefillToCustomerCreditAmount(bp);
      if (prefill > 0) {
        bp.debitAmountController.text = prefill.toStringAsFixed(2);
      } else {
        bp.debitAmountController.clear();
      }
    } else {
      bp.debitAmountController.clear();
    }
    bp.calculateBalance();
    bp.validatePayment();
  }

  void onToCustomerCreditAmountChanged(BillingProvider bp, String value) {
    if (value.isNotEmpty && (double.tryParse(value) ?? 0.0) > 0) {
      if (!bp.toCustomerCreditEnabled) {
        bp.setToCustomerCreditEnabled(true);
      }
    }
    bp.calculateBalance();
    bp.validatePayment();
  }

  /// Clamps the entered credit to the allowed excess (on field commit).
  void clampToCustomerCreditAmount(BillingProvider bp) {
    if (!bp.toCustomerCreditEnabled) return;

    final amount = double.tryParse(bp.debitAmountController.text) ?? 0.0;
    final maxAllowed = maxToCustomerCreditAmount(bp);
    if (amount > maxAllowed) {
      bp.debitAmountController.text = maxAllowed.toStringAsFixed(2);
      bp.calculateBalance();
      bp.validatePayment();
    }
  }

  double remainingPayable(BillingProvider bp) {
    final remaining = bp.effectiveOrderTotal - bp.getTotalPaidAmount();
    return remaining > 0 ? remaining : 0.0;
  }

  bool _amountsEqual(String a, String b) {
    final da = double.tryParse(a) ?? 0;
    final db = double.tryParse(b) ?? 0;
    return (da - db).abs() < 0.001;
  }

  bool _isFullCartTotal(BillingProvider bp, String text) {
    final amount = double.tryParse(text) ?? 0;
    return amount > 0 && (amount - bp.effectiveOrderTotal).abs() < 0.001;
  }

  String _extraMethodKey(String methodId) => 'extra_$methodId';

  String _methodKeyForType(String type, {String? methodId}) {
    if (methodId != null) return _extraMethodKey(methodId);
    return type.toUpperCase();
  }

  bool _isMethodActive(String methodKey, BillingProvider bp) {
    switch (methodKey.toUpperCase()) {
      case 'CASH':
        return bp.isCashSelected;
      case 'CARD':
        return bp.isCardSelected;
      case 'UPI':
        return bp.isUpiSelected;
      case 'COD':
        return bp.isCodSelected;
      case 'DEBIT':
        return bp.isDebitSelected;
      default:
        if (methodKey.startsWith('extra_')) {
          final id = methodKey.substring('extra_'.length);
          return bp.selectedExtraMethodIds.contains(id);
        }
        return false;
    }
  }

  TextEditingController? _controllerForKey(
      String methodKey, BillingProvider bp) {
    if (methodKey.startsWith('extra_')) {
      final id = methodKey.substring('extra_'.length);
      return bp.getExtraAmountController(
        id,
        displayValue: bp.extraPaymentValues[id],
      );
    }
    return _controllerFor(methodKey, bp);
  }

  void _deselectMethod(String methodKey, BillingProvider bp) {
    if (methodKey.startsWith('extra_')) {
      final id = methodKey.substring('extra_'.length);
      bp.toggleExtraMethod(id, displayValue: bp.extraPaymentValues[id]);
      return;
    }
    bp.setPaymentMethod(methodKey, false);
  }

  void _recordPristineIfFullTotal(
    String methodKey,
    BillingProvider bp,
    TextEditingController controller,
  ) {
    if (_isFullCartTotal(bp, controller.text)) {
      bp.setPristinePaymentState(methodKey, controller.text);
    }
  }

  bool _applyPristineSwitch(
    String newMethodKey,
    BillingProvider bp,
    TextEditingController targetController,
  ) {
    if (newMethodKey == 'DEBIT' || newMethodKey == 'credit') return false;
    final pristineKey = bp.pristinePaymentMethodKey;
    if (pristineKey == null || pristineKey == newMethodKey) return false;

    final pristineController = _controllerForKey(pristineKey, bp);
    if (pristineController == null || !_isMethodActive(pristineKey, bp)) {
      return false;
    }
    if (!_amountsEqual(
        pristineController.text, bp.pristinePaymentAmount ?? '')) {
      return false;
    }

    _deselectMethod(pristineKey, bp);
    targetController.text = bp.effectiveOrderTotal.toStringAsFixed(2);
    bp.setPristinePaymentState(newMethodKey, targetController.text);
    return true;
  }

  List<({String key, TextEditingController controller})>
      _listActiveCollectedMethodEntries(BillingProvider bp) {
    final entries = <({String key, TextEditingController controller})>[];
    if (bp.isCashSelected) {
      entries.add((key: 'CASH', controller: bp.cashAmountController));
    }
    if (bp.isCardSelected) {
      entries.add((key: 'CARD', controller: bp.cardAmountController));
    }
    if (bp.isUpiSelected) {
      entries.add((key: 'UPI', controller: bp.upiAmountController));
    }
    if (bp.isCodSelected) {
      entries.add((key: 'COD', controller: bp.codAmountController));
    }
    for (final methodId in bp.selectedExtraMethodIds) {
      entries.add((
        key: _extraMethodKey(methodId),
        controller: bp.getExtraAmountController(
          methodId,
          displayValue: bp.extraPaymentValues[methodId],
        ),
      ));
    }
    return entries;
  }

  void _refillIfSingleCollectedMethodRemaining(BillingProvider bp) {
    final active = _listActiveCollectedMethodEntries(bp);
    if (active.length != 1) return;

    final only = active.first;
    only.controller.text = bp.effectiveOrderTotal.toStringAsFixed(2);
    _recordPristineIfFullTotal(only.key, bp, only.controller);
  }

  /// Keeps to-customer-credit amount in sync as other payment amounts change.
  void syncCreditAmountWithRemaining(BillingProvider bp) {
    if (!bp.toCustomerCreditEnabled) return;

    final excessAmount = bp.getTotalPaidAmount() - bp.effectiveOrderTotal;
    if (excessAmount > 0) {
      final maxCredit = maxToCustomerCreditAmount(bp);
      final creditAmount =
          maxCredit > 0 ? excessAmount.clamp(0.0, maxCredit) : excessAmount;
      bp.debitAmountController.text = creditAmount.toStringAsFixed(2);
    } else {
      bp.debitAmountController.clear();
    }
    bp.calculateBalance();
  }

  void _finalizePaymentMutation(BillingProvider bp) {
    bp.calculateBalance();
    syncCreditAmountWithRemaining(bp);
    bp.validatePayment();
  }

  void toggleMethod(
    String type,
    BillingProvider bp, {
    String? methodId,
    String? displayValue,
  }) {
    if (methodId != null) {
      final methodKey = _extraMethodKey(methodId);
      final controller = bp.getExtraAmountController(
        methodId,
        displayValue: displayValue ?? type,
      );
      final wasSelected = bp.selectedExtraMethodIds.contains(methodId);

      if (wasSelected) {
        bp.toggleExtraMethod(methodId, displayValue: displayValue ?? type);
        if (bp.pristinePaymentMethodKey == methodKey) {
          bp.clearPristinePaymentState();
        }
        _refillIfSingleCollectedMethodRemaining(bp);
        _finalizePaymentMutation(bp);
        return;
      }

      bp.selectExtraMethod(methodId, displayValue: displayValue ?? type);
      if (!_applyPristineSwitch(methodKey, bp, controller)) {
        if (controller.text.isEmpty ||
            (double.tryParse(controller.text) ?? 0.0) == 0.0) {
          final remaining = remainingPayable(bp);
          if (remaining > 0) {
            bp.setExtraPaymentAmount(
              methodId,
              remaining.toStringAsFixed(2),
              displayValue: displayValue ?? type,
            );
          }
        }
      }
      _recordPristineIfFullTotal(methodKey, bp, controller);
      _finalizePaymentMutation(bp);
      return;
    }

    final methodKey = type.toUpperCase();
    final controller = _controllerFor(type, bp);
    if (controller == null) return;

    final isSelected = _isSelected(type, bp);
    if (isSelected) {
      bp.setPaymentMethod(type, false);
      if (bp.pristinePaymentMethodKey == methodKey) {
        bp.clearPristinePaymentState();
      }
      _refillIfSingleCollectedMethodRemaining(bp);
      _finalizePaymentMutation(bp);
      return;
    }

    bp.setPaymentMethod(type, true);
    if (!_applyPristineSwitch(methodKey, bp, controller)) {
      if (controller.text.isEmpty || double.tryParse(controller.text) == 0.0) {
        final remaining = remainingPayable(bp);
        if (remaining > 0) {
          controller.text = remaining.toStringAsFixed(2);
        }
      }
    }
    _recordPristineIfFullTotal(methodKey, bp, controller);
    _finalizePaymentMutation(bp);
  }

  void onAmountChanged(
    MobilePaymentItem item,
    String value,
    BillingProvider bp,
  ) {
    final methodKey = _methodKeyForType(item.type, methodId: item.methodId);
    if (bp.pristinePaymentMethodKey == methodKey &&
        !_amountsEqual(value, bp.pristinePaymentAmount ?? '')) {
      bp.clearPristinePaymentState();
    }

    if (item.isDynamic && item.methodId != null) {
      bp.setExtraPaymentAmount(
        item.methodId!,
        value,
        displayValue: item.type,
      );
      _finalizePaymentMutation(bp);
      return;
    }

    if (value.isNotEmpty && double.tryParse(value) != 0.0) {
      if (!item.selected) {
        bp.setPaymentMethod(item.type, true);
      }
    }
    _finalizePaymentMutation(bp);
  }

  void selectMethodOnTap(MobilePaymentItem item, BillingProvider bp) {
    toggleMethod(
      item.type,
      bp,
      methodId: item.methodId,
      displayValue: item.type,
    );
  }

  bool _hasAnyCollectedPayment(BillingProvider bp) {
    if ((double.tryParse(bp.cashAmountController.text) ?? 0) > 0) return true;
    if ((double.tryParse(bp.cardAmountController.text) ?? 0) > 0) return true;
    if ((double.tryParse(bp.upiAmountController.text) ?? 0) > 0) return true;
    if ((double.tryParse(bp.codAmountController.text) ?? 0) > 0) return true;
    for (final entry in bp.extraPaymentAmounts.entries) {
      if ((double.tryParse(entry.value) ?? 0) > 0) return true;
    }
    return bp.pineLabsPaymentSuccess || bp.isOnlineSelected;
  }

  /// Mirrors desktop payment-modal autofill: when a method is selected but no
  /// amounts are entered yet, prefill the selected method with the full total.
  /// Falls back to CASH when nothing is selected (desktop safety net).
  bool syncPaymentAutofillIfNeeded(BillingProvider bp) {
    final total = bp.effectiveOrderTotal;
    if (total <= 0) return false;
    if (_hasAnyCollectedPayment(bp)) return false;

    final totalStr = total.toStringAsFixed(2);
    String pristineKey = 'CASH';

    if (bp.isCashSelected) {
      bp.cashAmountController.text = totalStr;
      pristineKey = 'CASH';
    } else if (bp.isCardSelected) {
      bp.cardAmountController.text = totalStr;
      pristineKey = 'CARD';
    } else if (bp.isUpiSelected) {
      bp.upiAmountController.text = totalStr;
      pristineKey = 'UPI';
    } else if (bp.isCodSelected) {
      bp.codAmountController.text = totalStr;
      pristineKey = 'COD';
    } else if (bp.selectedExtraMethodIds.isNotEmpty) {
      final methodId = bp.selectedExtraMethodIds.first;
      bp.setExtraPaymentAmount(
        methodId,
        totalStr,
        displayValue: bp.extraPaymentValues[methodId],
      );
      pristineKey = _extraMethodKey(methodId);
    } else {
      bp.setPaymentMethod('CASH', true);
      bp.cashAmountController.text = totalStr;
      pristineKey = 'CASH';
    }
    bp.setPristinePaymentState(pristineKey, totalStr);
    bp.calculateBalance();
    return true;
  }

  /// Fills CASH with the full payable total (quick cashier action).
  void fillExactCash(BillingProvider bp) {
    bp.clearAllPaymentMethods();
    bp.setPaymentMethod('CASH', true);
    if (bp.effectiveOrderTotal > 0) {
      bp.cashAmountController.text = bp.effectiveOrderTotal.toStringAsFixed(2);
      bp.setPristinePaymentState('CASH', bp.cashAmountController.text);
    }
    bp.calculateBalance();
  }

  /// Clears all selected payment methods and entered amounts.
  void clearAllCollectedPayments(BillingProvider bp) {
    bp.clearAllPaymentMethods();
    bp.calculateBalance();
  }

  bool syncDebitAmount(BillingProvider bp) {
    if (!bp.isDebitSelected || bp.effectiveOrderTotal <= 0) return false;

    final autoDebit = remainingPayable(bp);
    final nextText = autoDebit.toStringAsFixed(2);
    if (bp.debitAmountController.text == nextText) return false;

    bp.debitAmountController.text = nextText;
    bp.calculateBalance();
    return true;
  }

  /// Realigns collected payment amounts when the payable total changes after a
  /// coupon or manual discount update. Mirrors checkout discount-step remap.
  void remapPaymentsAfterDiscountChange({
    required BillingProvider bp,
    required double oldEffectiveTotal,
    required double newEffectiveTotal,
  }) {
    final remapped = PaymentAutoFillHelper.remapAmountsAfterDiscount(
      isCashSelected: bp.isCashSelected,
      isCardSelected: bp.isCardSelected,
      isUpiSelected: bp.isUpiSelected,
      isCodSelected: bp.isCodSelected,
      cashAmount: bp.cashAmountController.text,
      cardAmount: bp.cardAmountController.text,
      upiAmount: bp.upiAmountController.text,
      codAmount: bp.codAmountController.text,
      oldEffectiveTotal: oldEffectiveTotal,
      newEffectiveTotal: newEffectiveTotal,
    );

    if (remapped.cash != bp.cashAmountController.text) {
      bp.cashAmountController.text = remapped.cash;
    }
    if (remapped.card != bp.cardAmountController.text) {
      bp.cardAmountController.text = remapped.card;
    }
    if (remapped.upi != bp.upiAmountController.text) {
      bp.upiAmountController.text = remapped.upi;
    }
    if (remapped.cod != bp.codAmountController.text) {
      bp.codAmountController.text = remapped.cod;
    }

    final anyTypedSelected = bp.isCashSelected ||
        bp.isCardSelected ||
        bp.isUpiSelected ||
        bp.isCodSelected;
    final extraRemap = PaymentAutoFillHelper.remapSingleExtraAfterDiscount(
      anyTypedMethodSelected: anyTypedSelected,
      selectedExtraMethodIds: bp.selectedExtraMethodIds,
      extraAmounts: bp.extraPaymentAmounts,
      oldEffectiveTotal: oldEffectiveTotal,
      newEffectiveTotal: newEffectiveTotal,
    );
    if (extraRemap != null) {
      for (final entry in extraRemap.entries) {
        bp.setExtraPaymentAmount(
          entry.key,
          entry.value,
          displayValue: bp.extraPaymentValues[entry.key],
        );
      }
    }

    bp.setTotalOrderAmount(newEffectiveTotal);
    syncDebitAmount(bp);
    bp.calculateBalance();
  }

  bool _isSelected(String type, BillingProvider bp) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return bp.isCashSelected;
      case 'CARD':
        return bp.isCardSelected;
      case 'UPI':
        return bp.isUpiSelected;
      case 'COD':
        return bp.isCodSelected;
      case 'DEBIT':
        return bp.isDebitSelected;
      default:
        return false;
    }
  }

  TextEditingController? _controllerFor(String type, BillingProvider bp) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return bp.cashAmountController;
      case 'CARD':
        return bp.cardAmountController;
      case 'UPI':
        return bp.upiAmountController;
      case 'COD':
        return bp.codAmountController;
      case 'DEBIT':
        return bp.debitAmountController;
      default:
        return null;
    }
  }

  /// Gates confirm / confirm-print when ONLINE is selected without a successful
  /// terminal payment (mirrors desktop `_ensurePaymentReadyForConfirm` for Pine Labs).
  MobilePaymentReadyResult validatePaymentReadyForConfirm(
    BillingProvider bp, {
    bool paymentStepVisited = false,
  }) {
    if (bp.isOnlineSelected) {
      if (!bp.pineLabsPaymentSuccess) {
        return const MobilePaymentReadyResult(
          isValid: false,
          message:
              'Complete Pine Labs payment before confirming with ONLINE payment',
        );
      }
      if (bp.transactionNumberController.text.trim().isEmpty) {
        return const MobilePaymentReadyResult(
          isValid: false,
          message:
              'Terminal transaction reference is required for ONLINE payment',
        );
      }
    }

    if (!bp.validatePayment()) {
      return MobilePaymentReadyResult(
        isValid: false,
        message: bp.paymentValidationError ??
            'Please configure payment before confirm',
      );
    }

    if (!paymentStepVisited && !bp.paymentStepVisited) {
      return const MobilePaymentReadyResult(
        isValid: false,
        message: 'Please configure payment before confirm',
      );
    }

    return const MobilePaymentReadyResult(isValid: true);
  }

  /// Whether the order total is high enough to attempt a Pine Labs charge.
  bool isPineLabsAmountValid(double totalAmount) => totalAmount > 0;

  /// Resets prior Pine Labs/ONLINE state before starting a new terminal attempt.
  void resetPineLabsBeforeAttempt(BillingProvider bp) {
    bp.setPineLabsPaymentSuccess(false);
    bp.setPaymentMethod('ONLINE', false);
  }

  /// Parses the raw Pine Labs terminal response string into a typed result.
  /// Tries the structured `Response.ResponseCode == 0` contract first, then
  /// falls back to a plain success/failure keyword match for non-JSON results.
  PineLabsTerminalResult parsePineLabsResult(String resultStr) {
    try {
      final decoded = jsonDecode(resultStr) as Map<String, dynamic>;
      final response = decoded['Response'] as Map<String, dynamic>?;
      final dynamic rawCode = response?['ResponseCode'];
      final int code = rawCode is int
          ? rawCode
          : int.tryParse(rawCode?.toString() ?? '') ?? -1;
      final String msg = (response?['ResponseMsg'] ?? '').toString();

      if (code == 0) {
        final detail = decoded['Detail'] as Map<String, dynamic>?;
        final String ref = (detail?['RetrievalReferenceNumber'] ??
                detail?['ApprovalCode'] ??
                detail?['BillingRefNo'] ??
                '')
            .toString();
        return PineLabsTerminalResult(
          success: true,
          message: msg.isNotEmpty ? msg : 'Pine Labs payment successful',
          referenceNumber: ref,
        );
      }
      return PineLabsTerminalResult(success: false, message: msg);
    } catch (_) {
      final String normalized = resultStr.toUpperCase();
      final bool isSuccess = normalized.contains('SUCCESS') ||
          normalized.contains('APPROVED') ||
          normalized.contains('TXN SUCCESS');
      if (isSuccess) {
        return const PineLabsTerminalResult(
          success: true,
          message: 'Pine Labs payment successful',
        );
      }
      return PineLabsTerminalResult(success: false, message: resultStr);
    }
  }

  /// Applies a parsed Pine Labs terminal result to billing state.
  void applyPineLabsResult(BillingProvider bp, PineLabsTerminalResult result) {
    if (result.success) {
      bp.setPineLabsPaymentSuccess(true);
      bp.setPaymentMethod('ONLINE', true);
      bp.transactionNumberController.text = result.referenceNumber ?? '';
    } else {
      bp.setPineLabsPaymentSuccess(false);
      bp.setPaymentMethod('ONLINE', false);
      bp.transactionNumberController.clear();
    }
  }
}

/// Result of parsing a Pine Labs terminal response.
class PineLabsTerminalResult {
  const PineLabsTerminalResult({
    required this.success,
    required this.message,
    this.referenceNumber,
  });

  final bool success;
  final String message;
  final String? referenceNumber;
}

class MobilePaymentReadyResult {
  const MobilePaymentReadyResult({
    required this.isValid,
    this.message,
  });

  final bool isValid;
  final String? message;
}

class MobilePaymentMethodIds {
  const MobilePaymentMethodIds({
    this.cashId,
    this.cardId,
    this.upiId,
    this.codId,
  });

  final String? cashId;
  final String? cardId;
  final String? upiId;
  final String? codId;
}

class MobilePaymentItem {
  const MobilePaymentItem({
    required this.name,
    required this.type,
    required this.controller,
    required this.selected,
    this.readOnly = false,
    this.methodId,
    this.isDynamic = false,
    this.iconKey,
    this.behavior = PaymentBehavior.collected,
  });

  final String name;
  final String type;
  final TextEditingController controller;
  final bool selected;
  final bool readOnly;
  final String? methodId;
  final bool isDynamic;

  /// Optional backend icon hint used by [BillingMobilePaymentController.iconForItem].
  final String? iconKey;

  /// Behavior class from the backend model (collected/credit/terminal).
  final PaymentBehavior behavior;
}

class BillingMobileDeliveryController {
  const BillingMobileDeliveryController();

  bool shouldShowDeliveryDateTime(bool askDeliveryDate) => askDeliveryDate;

  TimeOfDay? parseDeliveryTime(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$');
    final match = twentyFourHour.firstMatch(trimmed);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour < 0 || hour > 23) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String formatDeliveryTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData iconForMethod(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('dine')) return Icons.restaurant;
    if (lower.contains('toyou')) return Icons.local_shipping;
    if (lower.contains('door')) return Icons.doorbell_outlined;
    if (lower.contains('store') || lower.contains('takeaway')) {
      return Icons.store;
    }
    if (lower.contains('car')) return Icons.directions_car;
    if (lower.contains('third') || lower.contains('logistics')) {
      return Icons.hub;
    }
    if (lower.contains('hunger')) return Icons.motorcycle;
    return Icons.local_shipping;
  }

  bool isSelected(DeliveryMethod method, BillingProvider bp) {
    return bp.deliveryMethod == method.name ||
        (bp.deliveryMethod.isEmpty && method.name == 'Store Takeaway');
  }

  String feeLabel(DeliveryMethod method, String currency) {
    return formatDeliveryFeeLabel(method.basePrice ?? 0.0, currency);
  }

  String feeLabelForMethodInOrder({
    required DeliveryMethod method,
    required String currency,
    required bool freeDeliveryEnabled,
    required double freeDeliveryMinimumAmount,
    required double netTotal,
    required List<DeliveryMethod> deliveryMethods,
  }) {
    final charge = computeDeliveryCharge(
      freeDeliveryEnabled: freeDeliveryEnabled,
      freeDeliveryMinimumAmount: freeDeliveryMinimumAmount,
      netTotal: netTotal,
      deliveryMethodId: method.id,
      deliveryMethodName: method.name,
      deliveryMethods: deliveryMethods,
    );
    return formatDeliveryFeeLabel(charge, currency);
  }

  void selectMethod(BillingProvider bp, DeliveryMethod method) {
    bp.setDeliveryMethod(method.name, method.id);
  }

  String formatAddress(Address address) {
    final parts = <String?>[
      address.address,
      address.city,
    ].whereType<String>().map((part) => part.trim()).where((part) {
      return part.isNotEmpty;
    }).toList();

    return parts.join(', ');
  }
}

class MobileCustomerBalanceDisplay {
  const MobileCustomerBalanceDisplay({
    required this.label,
    required this.amountText,
    required this.color,
  });

  final String label;
  final String amountText;
  final Color color;
}

/// Result of attempting to auto-assign the configured default customer.
class MobileDefaultCustomerResult {
  const MobileDefaultCustomerResult.skipped()
      : applied = false,
        matchedCustomer = null,
        phoneOnlyText = null,
        isDefaultAssignment = false;

  const MobileDefaultCustomerResult.matched(
    this.matchedCustomer, {
    this.isDefaultAssignment = true,
  })  : applied = true,
        phoneOnlyText = null;

  const MobileDefaultCustomerResult.phoneOnly(this.phoneOnlyText)
      : applied = true,
        matchedCustomer = null,
        isDefaultAssignment = false;

  final bool applied;
  final CustomerListModelData? matchedCustomer;
  final String? phoneOnlyText;
  final bool isDefaultAssignment;
}

class BillingMobileCustomerController {
  const BillingMobileCustomerController();

  bool isDefaultCustomerPhone(String? phone, String defaultPhone) {
    final normalizedDefault = defaultPhone.trim();
    final customerPhone = phone?.trim() ?? '';
    return normalizedDefault.isNotEmpty && customerPhone == normalizedDefault;
  }

  bool isDefaultCustomer({
    required CustomerListModelData? customer,
    required CustomerSelectionProvider customerSelectionProvider,
    required String defaultCustomerPhone,
  }) {
    if (customer == null) return false;

    final selectedCustomer = customerSelectionProvider.selectedCustomer;
    if (customerSelectionProvider.isDefaultCustomer &&
        ((selectedCustomer?.id != null &&
                selectedCustomer?.id == customer.id) ||
            (selectedCustomer?.phone?.trim().isNotEmpty == true &&
                selectedCustomer?.phone?.trim() == customer.phone?.trim()))) {
      return true;
    }

    return isDefaultCustomerPhone(customer.phone, defaultCustomerPhone);
  }

  bool shouldShowCustomerBalance({
    required CustomerListModelData? customer,
    required CustomerSelectionProvider customerSelectionProvider,
    required String defaultCustomerPhone,
    required bool isQuotationDraft,
    String? salesExecutivePhone,
  }) {
    if (customer?.phone == null) return false;
    if (!isQuotationDraft &&
        isDefaultCustomer(
          customer: customer,
          customerSelectionProvider: customerSelectionProvider,
          defaultCustomerPhone: defaultCustomerPhone,
        )) {
      return false;
    }
    if (salesExecutivePhone != null && customer!.phone == salesExecutivePhone) {
      return false;
    }
    return customer?.balance != null;
  }

  MobileCustomerBalanceDisplay balanceDisplay({
    required double balance,
    required String currency,
  }) {
    if (balance > 0) {
      return MobileCustomerBalanceDisplay(
        label: 'Previous balance',
        amountText: '+$currency ${balance.toStringAsFixed(2)}',
        color: const Color(0xFF059669),
      );
    }
    if (balance < 0) {
      return MobileCustomerBalanceDisplay(
        label: 'Previous balance (debt)',
        amountText: '$currency ${balance.toStringAsFixed(2)}',
        color: const Color(0xFFDC2626),
      );
    }
    return MobileCustomerBalanceDisplay(
      label: 'Previous balance',
      amountText: '$currency ${balance.toStringAsFixed(2)}',
      color: Colors.black87,
    );
  }

  /// Mirrors desktop `_applyDefaultCustomerFromCacheIfNeeded` preconditions.
  MobileDefaultCustomerResult applyDefaultCustomerFromCacheIfNeeded({
    required LocalProductProvider localProductProvider,
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required AppSettings? appSettings,
    required List<CustomerListModelData>? customers,
  }) {
    if (localProductProvider.currentOrder != null) {
      return const MobileDefaultCustomerResult.skipped();
    }

    if (billingProvider.isCustomerManuallySelected &&
        (billingProvider.selectedCustomerID != null ||
            billingProvider.mobileNumberText?.isNotEmpty == true)) {
      return const MobileDefaultCustomerResult.skipped();
    }

    if (billingProvider.selectedCustomer != null ||
        billingProvider.selectedCustomerID != null ||
        (billingProvider.selectedCustomerPhone?.isNotEmpty ?? false) ||
        customerSelectionProvider.hasSelectedCustomer) {
      return const MobileDefaultCustomerResult.skipped();
    }

    final autoAssignEnabled = appSettings?.autoAssignDefaultCustomer ?? false;
    if (!autoAssignEnabled) {
      return const MobileDefaultCustomerResult.skipped();
    }

    final defaultPhone = appSettings?.autoAssignDefaultCustomerPhone ?? '';
    if (defaultPhone.isEmpty) {
      return const MobileDefaultCustomerResult.skipped();
    }

    if (customers == null || customers.isEmpty) {
      return const MobileDefaultCustomerResult.skipped();
    }

    CustomerListModelData? matched;
    for (final customer in customers) {
      if (customer.phone == defaultPhone) {
        matched = customer;
        break;
      }
    }

    if (matched != null) {
      return MobileDefaultCustomerResult.matched(matched);
    }

    return MobileDefaultCustomerResult.phoneOnly(defaultPhone);
  }

  void applyDefaultCustomerResult({
    required MobileDefaultCustomerResult result,
    required CustomerSelectionProvider customerSelectionProvider,
    required BillingProvider billingProvider,
    required CartProvider cartProvider,
    required AuthModel auth,
  }) {
    if (!result.applied) return;

    if (result.matchedCustomer != null) {
      final customer = result.matchedCustomer!;
      customerSelectionProvider.setSelectedCustomer(
        customer,
        isDefault: result.isDefaultAssignment,
      );
      final label = '${customer.name ?? ''} ${customer.phone ?? ''}'.trim();
      billingProvider.setMobileNumberText(customer.phone ?? '');
      billingProvider.setSelectedCustomer(customer, isManual: false);
      billingProvider.mobileNumberTextController.text = label;
      billingProvider.setSalesExecutiveMobileNumberText(customer.phone ?? '');

      cartProvider.fetchCartDataFromApi(
        customerId: customer.id ?? 0,
        accessToken: auth.token ?? '',
      );
      return;
    }

    final phone = result.phoneOnlyText ?? '';
    billingProvider.setSalesExecutiveMobileNumberText(phone);
    billingProvider.setMobileNumberText(phone);
    billingProvider.mobileNumberTextController.text = phone;
    billingProvider.clearSelectedCustomerButKeepText();
    customerSelectionProvider.clearSelectedCustomer();
  }

  /// Desktop confirm/checkout parity: customer id, typed phone, or sales-exec
  /// phone satisfies selection unless [skipCustomerSelection] allows walk-in.
  bool isCustomerSatisfiedForCheckout({
    required BillingProvider billingProvider,
    required bool skipCustomerSelection,
  }) {
    final hasCustomer = billingProvider.selectedCustomerID != null ||
        (billingProvider.mobileNumberText?.trim().isNotEmpty == true) ||
        (billingProvider.salesExecutivemobileNumberText?.trim().isNotEmpty ==
            true);
    if (hasCustomer) return true;
    return skipCustomerSelection;
  }

  void resetCartContextForAuthUser({
    required CartProvider cartProvider,
    required AuthModel auth,
  }) {
    final userId = auth.userId;
    if (userId == null) return;
    cartProvider.fetchCartDataFromApi(
      customerId: userId,
      accessToken: auth.token ?? '',
    );
  }

  /// Mirrors desktop `BillingPage._onSalesExecutiveChanged`.
  ///
  /// Returns `true` when customer state was cleared.
  bool handleSalesExecutiveChanged({
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required bool autoAssignEnabled,
  }) {
    if (!autoAssignEnabled) {
      return false;
    }

    if (billingProvider.isCustomerManuallySelected &&
        (billingProvider.selectedCustomerID != null ||
            billingProvider.mobileNumberText?.isNotEmpty == true)) {
      return false;
    }

    customerSelectionProvider.clearSelectedCustomer();
    billingProvider.resetCustomerForExecutiveOrUserChange(
      resetManualSelectionFlag: true,
    );
    return true;
  }

  /// Mirrors desktop `BillingPage._onUserSwitched`.
  ///
  /// Returns `true` when customer state was cleared.
  bool handleUserSwitched({
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required bool autoAssignEnabled,
  }) {
    if (!autoAssignEnabled) {
      return false;
    }

    customerSelectionProvider.clearSelectedCustomer();
    billingProvider.resetCustomerForExecutiveOrUserChange(
      resetManualSelectionFlag: false,
    );
    return true;
  }

  /// Mirrors desktop read-only default sales-exec phone field visibility.
  bool shouldShowDefaultSalesExecutivePhone({
    required BillingProvider billingProvider,
    required LocalProductProvider localProductProvider,
    required CustomerSelectionProvider customerSelectionProvider,
  }) {
    final phone = billingProvider.salesExecutivemobileNumberText?.trim();
    if (phone == null || phone.isEmpty) return false;
    if (billingProvider.isCustomerManuallySelected) return false;
    if (localProductProvider.currentOrder != null) return false;
    if (customerSelectionProvider.hasSelectedCustomer) return false;
    if (billingProvider.selectedCustomer != null) return false;
    return true;
  }

  CustomerListModelData? defaultSalesExecutivePhoneCustomer({
    required BillingProvider billingProvider,
    required LocalProductProvider localProductProvider,
    required CustomerSelectionProvider customerSelectionProvider,
  }) {
    if (!shouldShowDefaultSalesExecutivePhone(
      billingProvider: billingProvider,
      localProductProvider: localProductProvider,
      customerSelectionProvider: customerSelectionProvider,
    )) {
      return null;
    }

    final phone = billingProvider.salesExecutivemobileNumberText!.trim();
    final label = billingProvider.mobileNumberText?.trim();
    return CustomerListModelData(
      phone: phone,
      name: label != null && label.isNotEmpty && label != phone ? label : null,
    );
  }

  void clearSelection({
    required CustomerSelectionProvider customerSelectionProvider,
    required BillingProvider billingProvider,
    required CartProvider cartProvider,
    required AuthModel auth,
    bool reapplyDefaultCustomer = false,
    MobileDefaultCustomerResult? defaultCustomerResult,
  }) {
    customerSelectionProvider.clearSelectedCustomer();
    billingProvider.clearSelectedCustomer();
    billingProvider.setSalesExecutiveMobileNumberText('');
    resetCartContextForAuthUser(cartProvider: cartProvider, auth: auth);

    if (reapplyDefaultCustomer && defaultCustomerResult != null) {
      applyDefaultCustomerResult(
        result: defaultCustomerResult,
        customerSelectionProvider: customerSelectionProvider,
        billingProvider: billingProvider,
        cartProvider: cartProvider,
        auth: auth,
      );
    }
  }

  CustomerListModelData? parseCreatedCustomerFromAddResponse(
    Map<dynamic, dynamic> result,
  ) {
    final responseData = result['response']?['data'];
    final userData = responseData?['user'];
    final customerData = responseData?['customer'];

    final createdCustomerId =
        int.tryParse(customerData?['id']?.toString() ?? '');
    if (createdCustomerId == null) return null;

    return CustomerListModelData(
      id: createdCustomerId,
      userId: int.tryParse(userData?['id']?.toString() ?? ''),
      companyId: int.tryParse(customerData?['company_id']?.toString() ?? ''),
      storeId: int.tryParse(customerData?['store_id']?.toString() ?? ''),
      name: (userData?['name'] ?? result['name'] ?? '').toString(),
      email: userData?['email']?.toString(),
      phone: (userData?['phone'] ?? result['phone'] ?? '').toString(),
      altPhone: customerData?['alt_phone']?.toString(),
      gender: customerData?['gender']?.toString(),
      dob: customerData?['dob']?.toString(),
      balance: double.tryParse(customerData?['balance']?.toString() ?? '0'),
      paymentType: customerData?['payment_type']?.toString(),
      customerType: customerData?['customer_type']?.toString(),
    );
  }

  CustomerListModelData? findCustomerByPhone(
    List<CustomerListModelData> customers,
    String phone,
  ) {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty) return null;

    for (final customer in customers) {
      final customerPhone =
          customer.phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (customerPhone == normalizedPhone) {
        return customer;
      }
    }
    return null;
  }

  /// Blocks confirm when a quotation-only inline customer has not been saved.
  bool hasQuoteOnlyCustomerNeedingSave({
    required CustomerListModelData? customer,
    required bool requireSavedCustomer,
  }) {
    if (!requireSavedCustomer) return false;
    if (customer == null || customer.id != null) return false;
    return customer.name?.trim().isNotEmpty == true;
  }

  void syncPaymentValidationCustomerContext({
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required AppSettings? appSettings,
  }) {
    final customer = customerSelectionProvider.selectedCustomer ??
        billingProvider.selectedCustomer;
    final isDefault = isDefaultCustomer(
      customer: customer,
      customerSelectionProvider: customerSelectionProvider,
      defaultCustomerPhone: appSettings?.autoAssignDefaultCustomerPhone ?? '',
    );
    billingProvider.setPaymentValidationCustomerContext(
      isDefaultCustomer: isDefault,
      configuredDefaultCustomerPhone:
          appSettings?.autoAssignDefaultCustomerPhone ?? '',
    );
  }

  /// Walk-in phone entry without creating a full customer record.
  void applyWalkInPhone({
    required BillingProvider billingProvider,
    required CustomerSelectionProvider customerSelectionProvider,
    required String phone,
  }) {
    final trimmed = phone.trim();
    billingProvider.setMobileNumberText(trimmed);
    billingProvider.mobileNumberTextController.text = trimmed;
    billingProvider.clearSelectedCustomerButKeepText();
    customerSelectionProvider.clearSelectedCustomer();
  }

  List<CustomerListModelData> filterCustomers(
    List<CustomerListModelData> customers,
    String query,
  ) {
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return List<CustomerListModelData>.from(customers);

    final normalizedQuery = lowerQuery.replaceAll(RegExp(r'[^0-9]'), '');

    return customers.where((customer) {
      final name = (customer.name ?? '').toLowerCase();
      final phone = (customer.phone ?? '').toLowerCase();
      final altPhone = (customer.altPhone ?? '').toLowerCase();

      if (name.contains(lowerQuery) ||
          phone.contains(lowerQuery) ||
          altPhone.contains(lowerQuery)) {
        return true;
      }

      if (normalizedQuery.isEmpty) return false;

      final normalizedPhone =
          (customer.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      final normalizedAltPhone =
          (customer.altPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      return normalizedPhone.contains(normalizedQuery) ||
          normalizedAltPhone.contains(normalizedQuery);
    }).toList();
  }

  List<CustomerListModelData> frequentCustomers(
    List<CustomerListModelData> customers, {
    int limit = 10,
  }) {
    return customers.length > limit ? customers.sublist(0, limit) : customers;
  }

  String avatarInitial(CustomerListModelData customer) {
    final name = customer.name ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color avatarColor(String initial) {
    const colors = [
      Color(0xFF1D4ED8),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFFDB2777),
      Color(0xFF4F46E5),
    ];
    final safeInitial = initial.isEmpty ? '?' : initial;
    final index = safeInitial.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  void applySelection({
    required CustomerListModelData customer,
    required CustomerSelectionProvider customerSelectionProvider,
    required BillingProvider billingProvider,
    required CartProvider cartProvider,
    required AuthModel auth,
    bool isManual = true,
    bool isDefault = false,
  }) {
    customerSelectionProvider.setSelectedCustomer(
      customer,
      isDefault: isDefault,
    );

    final label = '${customer.name ?? ''} ${customer.phone ?? ''}'.trim();
    billingProvider.setMobileNumberText(customer.phone ?? '');
    billingProvider.setSelectedCustomer(customer, isManual: isManual);
    billingProvider.mobileNumberTextController.text = label;
    billingProvider.setCustomerBalance(customer.balance ?? 0.0);

    cartProvider.fetchCartDataFromApi(
      customerId: customer.id ?? 0,
      accessToken: auth.token ?? '',
    );
  }
}
