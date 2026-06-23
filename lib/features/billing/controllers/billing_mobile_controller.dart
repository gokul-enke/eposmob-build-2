import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/checkout_service.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';

/// Business logic for the mobile billing page, extracted out of
/// `BillingPageMobile` (Phase 4) so the widget is left with pure UI
/// orchestration (build / setState / dialogs / tab control).
///
/// Methods operate on the existing providers (read from [context]); all logic
/// here was moved **verbatim** from the page to preserve behaviour exactly.
/// UI side-effects (snackbars, dialogs, key regeneration, tab switches) stay in
/// the page.
class BillingMobileController {
  // ---------------------------------------------------------------------------
  // Order rehydration / restore
  // ---------------------------------------------------------------------------

  /// Restores all provider state from the currently-loaded saved order:
  /// selected customer, payment methods, and order details. No-op when there is
  /// no current order. Mirrors the page's previous `_rehydrateFromProvider`
  /// body (minus the widget-local key/`setState` handling, which stays in the
  /// page).
  void restoreOrderState(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final SavedOrder? currentOrder = localProductProvider.currentOrder;
    if (currentOrder == null) return;

    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    billingProvider.clearSelectedCustomer();
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    _restoreCustomer(context, currentOrder, billingProvider);
    restorePaymentMethods(currentOrder, billingProvider);
    restoreOrderDetails(context, currentOrder, billingProvider);

    billingProvider.setTotalOrderAmount(
        localProductProvider.priceSummary?.netTotal ?? 0.0);
  }

  void _restoreCustomer(BuildContext context, SavedOrder currentOrder,
      BillingProvider billingProvider) {
    if (currentOrder.customerId != null ||
        (currentOrder.customerPhone != null &&
            currentOrder.customerPhone!.isNotEmpty)) {
      CustomerListModelData? customerToSet;

      if (currentOrder.customerId != null &&
          billingProvider.customerList != null) {
        try {
          customerToSet = billingProvider.customerList!
              .firstWhere((c) => c.id == currentOrder.customerId);
        } catch (e) {
          // Not found in list
        }
      }

      customerToSet ??= CustomerListModelData(
        id: currentOrder.customerId,
        name: currentOrder.customerName,
        phone: currentOrder.customerPhone,
      );

      billingProvider.setSelectedCustomer(customerToSet, isManual: true);
      Provider.of<CustomerSelectionProvider>(context, listen: false)
          .setSelectedCustomer(billingProvider.selectedCustomer!);
    }
  }

  void restorePaymentMethods(
      SavedOrder currentOrder, BillingProvider billingProvider) {
    billingProvider.clearAllPaymentMethods();

    if (currentOrder.paymentMethod != null) {
      final pm = currentOrder.paymentMethod!;
      if (pm.startsWith('{')) {
        try {
          final Map<String, dynamic> multi = json.decode(pm);
          if (multi['isMultiPayment'] == true) {
            final List<String> methods =
                List<String>.from(multi['methods'] ?? []);
            final Map<String, dynamic> amounts =
                Map<String, dynamic>.from(multi['amounts'] ?? {});

            if (methods.contains('CASH')) {
              billingProvider.setPaymentMethod('CASH', true);
              billingProvider.cashAmountController.text =
                  (amounts['CASH'] ?? '0').toString();
            }
            if (methods.contains('CARD')) {
              billingProvider.setPaymentMethod('CARD', true);
              billingProvider.cardAmountController.text =
                  (amounts['CARD'] ?? '0').toString();
            }
            if (methods.contains('UPI')) {
              billingProvider.setPaymentMethod('UPI', true);
              billingProvider.upiAmountController.text =
                  (amounts['UPI'] ?? '0').toString();
            }
            if (methods.contains('DEBIT')) {
              billingProvider.setPaymentMethod('DEBIT', true);
              billingProvider.debitAmountController.text =
                  (amounts['DEBIT'] ?? '0').toString();
            }
            if (!methods.contains('CASH') &&
                (methods.contains(billingProvider.cashPaymentMethodId) ||
                    amounts.containsKey(billingProvider.cashPaymentMethodId))) {
              billingProvider.setPaymentMethod('CASH', true);
              billingProvider.cashAmountController.text =
                  (amounts[billingProvider.cashPaymentMethodId] ?? '0')
                      .toString();
            }
            if (!methods.contains('CARD') &&
                (methods.contains(billingProvider.cardPaymentMethodId) ||
                    amounts.containsKey(billingProvider.cardPaymentMethodId))) {
              billingProvider.setPaymentMethod('CARD', true);
              billingProvider.cardAmountController.text =
                  (amounts[billingProvider.cardPaymentMethodId] ?? '0')
                      .toString();
            }
            if (!methods.contains('UPI') &&
                (methods.contains(billingProvider.upiPaymentMethodId) ||
                    amounts.containsKey(billingProvider.upiPaymentMethodId))) {
              billingProvider.setPaymentMethod('UPI', true);
              billingProvider.upiAmountController.text =
                  (amounts[billingProvider.upiPaymentMethodId] ?? '0')
                      .toString();
            }
            if (methods.contains('COD') ||
                methods.contains(billingProvider.codPaymentMethodId) ||
                amounts.containsKey('COD') ||
                amounts.containsKey(billingProvider.codPaymentMethodId)) {
              billingProvider.setPaymentMethod('COD', true);
              billingProvider.codAmountController.text = (amounts['COD'] ??
                      amounts[billingProvider.codPaymentMethodId] ??
                      '0')
                  .toString();
            }
            if (methods.contains('ONLINE') || amounts.containsKey('ONLINE')) {
              billingProvider.setPaymentMethod('ONLINE', true);
              billingProvider.setPineLabsPaymentSuccess(true);
            }
          }
        } catch (e) {
          debugPrint("Error parsing payment JSON on rehydration: $e");
        }
      } else {
        billingProvider.setPaymentMethod(pm.toUpperCase(), true);
        final paid = currentOrder.paidAmount ?? '0.0';

        switch (pm.toUpperCase()) {
          case 'CASH':
            billingProvider.cashAmountController.text = paid;
            break;
          case 'CARD':
            billingProvider.cardAmountController.text = paid;
            break;
          case 'UPI':
            billingProvider.upiAmountController.text = paid;
            break;
          case 'DEBIT':
            billingProvider.debitAmountController.text = paid;
            break;
        }

        if (pm == billingProvider.cashPaymentMethodId) {
          billingProvider.setPaymentMethod('CASH', true);
          billingProvider.cashAmountController.text = paid;
        } else if (pm == billingProvider.cardPaymentMethodId) {
          billingProvider.setPaymentMethod('CARD', true);
          billingProvider.cardAmountController.text = paid;
        } else if (pm == billingProvider.upiPaymentMethodId) {
          billingProvider.setPaymentMethod('UPI', true);
          billingProvider.upiAmountController.text = paid;
        } else if (pm == billingProvider.codPaymentMethodId ||
            pm.toUpperCase() == 'COD') {
          billingProvider.setPaymentMethod('COD', true);
          billingProvider.codAmountController.text = paid;
        } else if (pm.toUpperCase() == 'ONLINE') {
          billingProvider.setPaymentMethod('ONLINE', true);
          billingProvider.setPineLabsPaymentSuccess(true);
        }
      }
    }
  }

  void restoreOrderDetails(BuildContext context, SavedOrder currentOrder,
      BillingProvider billingProvider) {
    billingProvider.paidAmountController.text =
        currentOrder.paidAmount ?? "0.0";
    billingProvider.transactionNumberController.text =
        currentOrder.transactionId ?? "";
    if (currentOrder.deliveryMethodId != null ||
        currentOrder.deliveryMethod != null) {
      billingProvider.setDeliveryMethod(
          currentOrder.deliveryMethod ?? "Store Takeaway",
          currentOrder.deliveryMethodId ??
              billingProvider.getDefaultDeliveryMethodId());
    } else {
      setDefaultDeliveryMethod(context, billingProvider);
    }
    billingProvider.commentController.text = currentOrder.comment ?? "";
    billingProvider.carNumberController.text = currentOrder.carNumber ?? "";

    if (currentOrder.deliveryDate != null) {
      billingProvider.setDeliveryDateString(currentOrder.deliveryDate);
    }
    if (currentOrder.deliveryTime != null) {
      billingProvider.setDeliveryTimeString(currentOrder.deliveryTime);
    }

    // Restore coupon state
    if ((currentOrder.couponId != null && currentOrder.couponId!.isNotEmpty) ||
        (currentOrder.flatDiscount != null && currentOrder.flatDiscount! > 0) ||
        (currentOrder.percentageDiscount != null &&
            currentOrder.percentageDiscount! > 0)) {
      billingProvider.coupenCodeTextController.text =
          currentOrder.couponId ?? "";
    } else {
      billingProvider.coupenCodeTextController.clear();
    }

    billingProvider
        .setToCustomerCreditEnabled(currentOrder.toCustomerCredit ?? false);
  }

  void setDefaultDeliveryMethod(
      BuildContext context, BillingProvider billingProvider) {
    final appSettingsDefault =
        Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.defaultDeliveryMethod;
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    final defaultMethod = deliveryMethodsProvider.resolveDefaultDeliveryMethod(
      appSettingsDefault: appSettingsDefault,
    );
    billingProvider.setDeliveryMethod(
      defaultMethod?.name ?? "Store Takeaway",
      defaultMethod?.id ?? billingProvider.getDefaultDeliveryMethodId(),
    );
  }

  // ---------------------------------------------------------------------------
  // Input focus / keyboard shortcuts
  // ---------------------------------------------------------------------------

  void focusTextField(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    billingProvider
        .focusTextField(appSettingsProvider.appSettings!.barcodeSales);
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  void handleShortcutKey(BuildContext context, KeyEvent event) {
    if (event is KeyDownEvent) {
      try {
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        if (event.logicalKey == LogicalKeyboardKey.f6) {
          billingProvider.executeKeyboardShortcut('clearCart');
        } else if (event.logicalKey == LogicalKeyboardKey.f7) {
          billingProvider.executeKeyboardShortcut('saveOrder');
        } else if (event.logicalKey == LogicalKeyboardKey.f8) {
          billingProvider.executeKeyboardShortcut('createOrderAndPrint');
        } else if (event.logicalKey == LogicalKeyboardKey.f9) {
          billingProvider.executeKeyboardShortcut('confirmOrder');
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Barcode scanning
  // ---------------------------------------------------------------------------

  /// Resolves [barcode] to a product and adds it to the cart, or shows the
  /// add-product modal when unknown. [onProductKeyRegen] is invoked (in lieu of
  /// the page's `setState`) to refresh the product autocomplete after a
  /// successful add.
  Future<void> processBarcode(
    BuildContext context,
    String barcode, {
    required VoidCallback onProductKeyRegen,
  }) async {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);

    if (barcode.isEmpty) return;

    String query = barcode;
    List<GetProduct> filteredProducts = [];

    try {
      // Embedded scale barcodes (14 chars, '000' prefix) carry a product code
      // + weight/qty payload; parsing lives in the pure EmbeddedBarcode helper.
      final bool isEmbedded = EmbeddedBarcode.isEmbedded(query);

      filteredProducts =
          Provider.of<LocalProductProvider>(context, listen: false)
              .filterProductByBarcode(barCode: EmbeddedBarcode.searchCode(query));

      if (filteredProducts.isNotEmpty) {
        GetProduct product = filteredProducts.first;
        num? quantity;
        SaleUnit? matchedSaleUnit;

        for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
          final saleUnitBarcode = saleUnit.barcode?.trim() ?? '';
          if (saleUnitBarcode.isNotEmpty && saleUnitBarcode == query.trim()) {
            matchedSaleUnit = saleUnit;
            break;
          }
        }

        if ((product.unit == 'KGS' || product.unit == 'KG') && isEmbedded) {
          quantity = EmbeddedBarcode.weightQuantityKg(query);
        } else if ((product.unit == 'PCS' || product.unit == 'PC') &&
            isEmbedded) {
          quantity = EmbeddedBarcode.pieceQuantity(query);
        } else if (matchedSaleUnit != null) {
          quantity =
              num.tryParse(matchedSaleUnit.conversionRate?.trim() ?? '') ?? 1;
        }

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
          addToCartDirectly: true,
          customerId: billingProvider.selectedCustomerID,
          customerName: billingProvider.selectedCustomer?.name,
          selectedSaleUnit: matchedSaleUnit,
        );

        onProductKeyRegen();
        billingProvider.clearProductFieldsAndReset();
        focusTextField(context);
      } else {
        await showDialog(
          context: context,
          builder: (context) =>
              AddProductWithBarcodeModal(barcode: query, isAddToCart: true),
        );
        billingProvider.barcodeController.clear();
        focusTextField(context);
      }
    } catch (e) {
      debugPrint("Error adding item: $e");
      showScaffoldError(
        context: context,
        message: "Invalid Barcode. Please try again.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cart / checkout
  // ---------------------------------------------------------------------------

  /// Clears cart + order provider state (the page handles the surrounding
  /// `setState`, autocomplete-key regeneration and snackbar).
  void clearCartData(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.clearCart();
    localProductProvider.clearCurrentOrder();

    billingProvider.coupenCodeTextController.clear();
    billingProvider.transactionNumberController.clear();
    billingProvider.paidAmountController.clear();
    billingProvider.clearAllPaymentMethods();
    billingProvider.clearProductFields();
    billingProvider.setToCustomerCreditEnabled(false);
    billingProvider.setDeliveryDate(null);
    billingProvider.setDeliveryTime(null);
    billingProvider.commentController.clear();
    billingProvider.carNumberController.clear();
    billingProvider.setMobileNumberText("");
    billingProvider.mobileNumberTextController.clear();
    billingProvider.clearSelectedCustomer();
  }

  bool hasSelectedPayment(BuildContext context) =>
      Provider.of<BillingProvider>(context, listen: false)
          .getSelectedPaymentMethodsExcludingEmpty()
          .isNotEmpty;

  Future<bool> saveOrder(BuildContext context) async {
    return await CheckoutService(context).saveOrder();
  }

  Future<void> confirmOrder(BuildContext context) async {
    await CheckoutService(context).confirmOrder();
  }

  Future<void> createOrderAndPrint(BuildContext context) async {
    final createdOrderNumber =
        await CheckoutService(context).createOrderAndPrint();
    if (createdOrderNumber != null && createdOrderNumber.isNotEmpty) {
      try {
        await const PrintService().printOrderById(context, createdOrderNumber);
      } catch (error) {
        debugPrint("❌ Error fetching order details for print: $error");
      }
    }
  }

  void loadOrderForEditing(BuildContext context, String orderId) {
    Provider.of<LocalProductProvider>(context, listen: false)
        .loadOrderForEditing(orderId);
  }
}
