import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/add_product_with_variant.dart';
import 'package:pos_machine/features/billing/domain/quotation_checkout.dart';
import 'package:pos_machine/features/billing/domain/order_customer_fields.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/checkout_service.dart';
export 'package:pos_machine/services/checkout_service.dart'
    show SaveOrderResult;
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/features/billing/presentation/pages/add_product_mobile.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/barcode_sale_unit.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/services/quotation_print_service.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

enum MobileBillingShortcutAction {
  clearCart,
  confirmOrder,
  createOrderAndPrint,
  newOrder,
  saveOrder,
  saveOrderAndPrint,
  restoreFocus,
  focusBarcode,
}

/// Business logic for the mobile billing page, extracted out of
/// `BillingPageMobile` (Phase 4) so the widget is left with pure UI
/// orchestration (build / setState / dialogs / tab control).
///
/// Methods operate on the existing providers (read from [context]); all logic
/// here was moved **verbatim** from the page to preserve behaviour exactly.
/// UI side-effects (snackbars, dialogs, key regeneration, tab switches) stay in
/// the page.
class BillingMobileController {
  static const _customerController = BillingMobileCustomerController();
  static const _settingsController = BillingMobileSettingsController();
  static const _paymentController = BillingMobilePaymentController();

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

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.clearSelectedCustomer();
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    _restoreCustomer(context, currentOrder, billingProvider);

    MasterDataProvider? masterDataProvider;
    try {
      masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
    } catch (_) {
      // MasterDataProvider may be absent in isolated unit tests.
    }
    restorePaymentMethods(
      currentOrder,
      billingProvider,
      resolvePaymentMethodValue: (methodId) {
        final id = int.tryParse(methodId);
        return id != null
            ? masterDataProvider?.getPaymentMethodValue(id)
            : null;
      },
    );
    restoreOrderDetails(context, currentOrder, billingProvider);

    _refreshOrderTotals(localProductProvider, billingProvider);
  }

  void _restoreCustomer(BuildContext context, SavedOrder currentOrder,
      BillingProvider billingProvider) {
    if (currentOrder.customerId != null ||
        (currentOrder.customerPhone != null &&
            currentOrder.customerPhone!.isNotEmpty) ||
        (currentOrder.customerName != null &&
            currentOrder.customerName!.isNotEmpty)) {
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
      final restoredCustomer =
          billingProvider.selectedCustomer ?? customerToSet;
      Provider.of<CustomerSelectionProvider>(context, listen: false)
          .setSelectedCustomer(restoredCustomer);
    }
  }

  void restorePaymentMethods(
    SavedOrder currentOrder,
    BillingProvider billingProvider, {
    String? Function(String methodId)? resolvePaymentMethodValue,
  }) {
    billingProvider.clearAllPaymentMethods();
    var restoredPaymentData = false;

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
            restoredPaymentData = methods.isNotEmpty ||
                amounts.entries.any((entry) =>
                    (double.tryParse(entry.value.toString()) ?? 0) > 0);

            bool hasMethodOrAmount(List<String> candidates) {
              final hasMethod = methods.any(candidates.contains);
              final hasAmount = candidates.any((key) {
                final amount =
                    double.tryParse((amounts[key] ?? '0').toString()) ?? 0;
                return amount > 0;
              });
              return hasMethod || hasAmount;
            }

            String firstAmount(List<String> candidates) {
              for (final key in candidates) {
                if (amounts.containsKey(key)) {
                  return (amounts[key] ?? '0').toString();
                }
              }
              return '0';
            }

            if (hasMethodOrAmount(['CASH'])) {
              billingProvider.setPaymentMethod('CASH', true);
              billingProvider.cashAmountController.text = firstAmount(['CASH']);
            }
            if (hasMethodOrAmount(['CARD'])) {
              billingProvider.setPaymentMethod('CARD', true);
              billingProvider.cardAmountController.text = firstAmount(['CARD']);
            }
            if (hasMethodOrAmount(['UPI'])) {
              billingProvider.setPaymentMethod('UPI', true);
              billingProvider.upiAmountController.text = firstAmount(['UPI']);
            }
            if (hasMethodOrAmount(['DEBIT'])) {
              billingProvider.setPaymentMethod('DEBIT', true);
              billingProvider.debitAmountController.text =
                  (amounts['DEBIT'] ?? '0').toString();
            }
            final cashId = billingProvider.cashPaymentMethodId ?? 'CASH';
            final cardId = billingProvider.cardPaymentMethodId ?? 'CARD';
            final upiId = billingProvider.upiPaymentMethodId ?? 'UPI';
            final codId = billingProvider.codPaymentMethodId ?? 'COD';

            if (!methods.contains('CASH') &&
                hasMethodOrAmount(['CASH', cashId])) {
              billingProvider.setPaymentMethod('CASH', true);
              billingProvider.cashAmountController.text =
                  firstAmount(['CASH', cashId]);
            }
            if (!methods.contains('CARD') &&
                hasMethodOrAmount(['CARD', cardId])) {
              billingProvider.setPaymentMethod('CARD', true);
              billingProvider.cardAmountController.text =
                  firstAmount(['CARD', cardId]);
            }
            if (!methods.contains('UPI') && hasMethodOrAmount(['UPI', upiId])) {
              billingProvider.setPaymentMethod('UPI', true);
              billingProvider.upiAmountController.text =
                  firstAmount(['UPI', upiId]);
            }
            if (hasMethodOrAmount(['COD', codId])) {
              billingProvider.setPaymentMethod('COD', true);
              billingProvider.codAmountController.text =
                  firstAmount(['COD', codId]);
            }
            if (methods.contains('ONLINE') ||
                ((double.tryParse((amounts['ONLINE'] ?? '0').toString()) ?? 0) >
                    0)) {
              billingProvider.setPaymentMethod('ONLINE', true);
              billingProvider.setPineLabsPaymentSuccess(true);
              restoredPaymentData = true;
            }

            billingProvider.restoreExtraPaymentsFromAmounts(
              amounts,
              resolveDisplayValue: resolvePaymentMethodValue,
            );
          }
        } catch (e) {
          billingDebugLog('Error parsing payment JSON on rehydration: $e');
        }
      } else {
        billingProvider.setPaymentMethod(pm.toUpperCase(), true);
        restoredPaymentData = pm.trim().isNotEmpty;
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

    final hasCoreAmount = (double.tryParse(
                    billingProvider.cashAmountController.text) ??
                0) >
            0 ||
        (double.tryParse(billingProvider.cardAmountController.text) ?? 0) > 0 ||
        (double.tryParse(billingProvider.upiAmountController.text) ?? 0) > 0 ||
        (double.tryParse(billingProvider.codAmountController.text) ?? 0) > 0 ||
        (double.tryParse(billingProvider.debitAmountController.text) ?? 0) > 0;
    if (restoredPaymentData ||
        hasCoreAmount ||
        billingProvider.hasAnyPaymentSelected()) {
      billingProvider.markPaymentStepVisited();
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
    billingProvider.setOrderAddress(currentOrder.address ?? "");

    if (currentOrder.deliveryDate != null) {
      billingProvider.setDeliveryDateString(currentOrder.deliveryDate);
    }
    if (currentOrder.deliveryTime != null) {
      billingProvider.setDeliveryTimeString(currentOrder.deliveryTime);
    }

    // Restore coupon / discount UI state
    if ((currentOrder.couponId != null && currentOrder.couponId!.isNotEmpty) ||
        (currentOrder.flatDiscount != null && currentOrder.flatDiscount! > 0) ||
        (currentOrder.percentageDiscount != null &&
            currentOrder.percentageDiscount! > 0)) {
      billingProvider.setCouponApplied(
        true,
        code: currentOrder.couponId ?? "",
      );
    } else {
      billingProvider.setCouponApplied(false);
    }

    billingProvider
        .setToCustomerCreditEnabled(currentOrder.toCustomerCredit ?? false);

    billingProvider.setDeliveryChargeOverride(currentOrder.deliveryCharge);
    final restoredBalance =
        double.tryParse(currentOrder.balanceAmount ?? '0.0') ?? 0.0;
    billingProvider.restoreBalanceAmount(restoredBalance);
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _refreshOrderTotals(
    LocalProductProvider localProductProvider,
    BillingProvider billingProvider,
  ) {
    // loadOrderForEditing restores discount fields but may not recalculate
    // priceSummary until cartTotal is read.
    localProductProvider.cartTotal;
    billingProvider.setTotalOrderAmount(
      localProductProvider.priceSummary?.netTotal ?? 0.0,
    );
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

  /// Mobile tablet POS keyboard shortcut subset (hardware keyboard / scanner wedge).
  ///
  /// F-key mappings match desktop [BillingPage._handleKeyPress] for actions that
  /// exist on mobile. Supported on [BillingPageMobile] via a page-level
  /// [KeyboardListener]:
  /// - **F1** — clear cart
  /// - **F2** — confirm order
  /// - **F6** — confirm & print
  /// - **F7** — create new order
  /// - **F8** — save order
  /// - **F9** — save & print (offline save & print when checkout is blocked)
  /// - **Esc** — restore focus to barcode or product-search entry
  /// - **Ctrl+A** — focus barcode field when `barcodeSales` is enabled
  ///
  /// Desktop-only shortcuts (F3–F5, F10, F12, Ctrl+H/K/D/S/Q/P/U, Alt+D) are
  /// intentionally omitted on mobile. Shortcuts are dispatched from the page
  /// focus node, so they do not fire while a text field owns focus (text editing
  /// is preserved).

  void focusTextField(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    billingProvider.focusTextField(
      appSettingsProvider.appSettings?.barcodeSales ?? false,
    );
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  /// Pure dispatch for mobile billing shortcuts; used by [handleShortcutKey] and
  /// unit tests.
  static MobileBillingShortcutAction? resolveShortcutAction({
    required LogicalKeyboardKey key,
    required bool controlPressed,
    required bool barcodeSalesEnabled,
  }) {
    if (key == LogicalKeyboardKey.escape) {
      return MobileBillingShortcutAction.restoreFocus;
    }
    if (controlPressed && key == LogicalKeyboardKey.keyA) {
      return barcodeSalesEnabled
          ? MobileBillingShortcutAction.focusBarcode
          : null;
    }
    if (key == LogicalKeyboardKey.f1) {
      return MobileBillingShortcutAction.clearCart;
    }
    if (key == LogicalKeyboardKey.f2) {
      return MobileBillingShortcutAction.confirmOrder;
    }
    if (key == LogicalKeyboardKey.f6) {
      return MobileBillingShortcutAction.createOrderAndPrint;
    }
    if (key == LogicalKeyboardKey.f7) {
      return MobileBillingShortcutAction.newOrder;
    }
    if (key == LogicalKeyboardKey.f8) {
      return MobileBillingShortcutAction.saveOrder;
    }
    if (key == LogicalKeyboardKey.f9) {
      return MobileBillingShortcutAction.saveOrderAndPrint;
    }
    return null;
  }

  void handleShortcutKey(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    try {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final action = resolveShortcutAction(
        key: event.logicalKey,
        controlPressed: HardwareKeyboard.instance.isControlPressed,
        barcodeSalesEnabled:
            appSettingsProvider.appSettings?.barcodeSales ?? false,
      );
      if (action == null) return;

      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      switch (action) {
        case MobileBillingShortcutAction.clearCart:
          billingProvider.executeKeyboardShortcut('clearCart');
        case MobileBillingShortcutAction.confirmOrder:
          if (appSettingsProvider.appSettings?.showConfirmOrderButton ?? true) {
            billingProvider.executeKeyboardShortcut('confirmOrder');
          }
        case MobileBillingShortcutAction.createOrderAndPrint:
          if (appSettingsProvider.appSettings?.showConfirmOrderAndPrintButton ??
              true) {
            billingProvider.executeKeyboardShortcut('createOrderAndPrint');
          }
        case MobileBillingShortcutAction.newOrder:
          billingProvider.executeKeyboardShortcut('newOrder');
        case MobileBillingShortcutAction.saveOrder:
          billingProvider.executeKeyboardShortcut('saveOrder');
        case MobileBillingShortcutAction.saveOrderAndPrint:
          billingProvider.executeKeyboardShortcut('saveOrderAndPrint');
        case MobileBillingShortcutAction.restoreFocus:
        case MobileBillingShortcutAction.focusBarcode:
          focusTextField(context);
      }
    } catch (e) {
      // Handle error
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
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (barcode.isEmpty) return;

    String query = barcode;
    List<GetProduct> filteredProducts = [];

    try {
      // Embedded scale barcodes (14 chars, '000' prefix) carry a product code
      // + weight/qty payload; parsing lives in the pure EmbeddedBarcode helper.
      final bool isEmbedded = EmbeddedBarcode.isEmbedded(query);

      filteredProducts = Provider.of<LocalProductProvider>(context,
              listen: false)
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
          quantity = BarcodeSaleUnit.resolveSaleUnitQuantity(matchedSaleUnit);
        }

        await addProductWithVariantResolution(
          context: context,
          product: product,
          scannedBarcode: query,
          quantity: quantity,
          addToCartDirectly: true,
          customerId: billingProvider.selectedCustomerID,
          customerName: billingProvider.selectedCustomer?.name,
          selectedSaleUnit:
              BarcodeSaleUnit.resolveBarcodeSaleUnit(matchedSaleUnit),
        );

        onProductKeyRegen();
        billingProvider.clearProductFieldsAndReset();
        focusTextField(context);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductMobileScreen(
              barcode: query,
              isAddToCart: true,
            ),
          ),
        );
        billingProvider.barcodeController.clear();
        focusTextField(context);
      }
    } catch (e) {
      billingDebugLog('Error adding item: $e');
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.invalidBarcode,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cart / checkout
  // ---------------------------------------------------------------------------

  /// Shared billing workspace reset used by clear-cart, post-order, and
  /// sales-executive flows.
  void _resetBillingWorkspaceCore(
    BuildContext context, {
    required bool clearCart,
    required bool syncDefaultDelivery,
    required bool syncSalesExecutive,
  }) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;

    if (clearCart) {
      localProductProvider.clearCart();
    }
    localProductProvider.clearCurrentOrder();

    billingProvider.coupenCodeTextController.clear();
    billingProvider.setCouponApplied(false);
    billingProvider.setOrderAddress('');
    billingProvider.transactionNumberController.clear();
    billingProvider.paidAmountController.clear();
    billingProvider.clearAllPaymentMethods();
    billingProvider.clearProductFields();
    billingProvider.setToCustomerCreditEnabled(false);
    billingProvider.setDeliveryDate(null);
    billingProvider.setDeliveryTime(null);
    billingProvider.commentController.clear();
    billingProvider.carNumberController.clear();
    billingProvider.setDeliveryChargeOverride(null);
    billingProvider.resetPaymentStepVisited();
    billingProvider.clearPristinePaymentState();

    if (syncDefaultDelivery) {
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      _settingsController.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: deliveryMethodsProvider,
        appSettings: appSettings,
      );
    }

    if (syncSalesExecutive) {
      _customerController.handleSalesExecutiveChanged(
        billingProvider: billingProvider,
        customerSelectionProvider: customerSelectionProvider,
        autoAssignEnabled: appSettings?.autoAssignDefaultCustomer ?? true,
      );
    } else {
      _customerController.clearSelection(
        customerSelectionProvider: customerSelectionProvider,
        billingProvider: billingProvider,
        cartProvider: Provider.of<CartProvider>(context, listen: false),
        auth: Provider.of<AuthModel>(context, listen: false),
      );

      final defaultResult =
          _customerController.applyDefaultCustomerFromCacheIfNeeded(
        localProductProvider: localProductProvider,
        billingProvider: billingProvider,
        customerSelectionProvider: customerSelectionProvider,
        appSettings: appSettings,
        customers: billingProvider.customerList,
      );
      _customerController.applyDefaultCustomerResult(
        result: defaultResult,
        customerSelectionProvider: customerSelectionProvider,
        billingProvider: billingProvider,
        cartProvider: Provider.of<CartProvider>(context, listen: false),
        auth: Provider.of<AuthModel>(context, listen: false),
      );
    }
  }

  /// Clears cart + order provider state (the page handles the surrounding
  /// `setState`, autocomplete-key regeneration and snackbar).
  void clearCartData(BuildContext context) {
    _resetBillingWorkspaceCore(
      context,
      clearCart: true,
      syncDefaultDelivery: true,
      syncSalesExecutive: true,
    );
  }

  bool hasSelectedPayment(BuildContext context) =>
      Provider.of<BillingProvider>(context, listen: false)
          .getSelectedPaymentMethodsExcludingEmpty()
          .isNotEmpty;

  /// Prepares default customer, payment, and delivery for direct confirm & print
  /// when [AppSettings.skipCheckoutOnConfirmAndPrint] is enabled.
  /// Mirrors desktop `_confirmAndPrintWithoutCheckoutModal` prep steps.
  Future<void> prepareDirectConfirmAndPrint(BuildContext context) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final cachedCustomers = customerProvider.allCustomers;
      if (cachedCustomers != null && cachedCustomers.isNotEmpty) {
        billingProvider.setCustomerList(
          List<CustomerListModelData>.from(cachedCustomers),
        );
      }
    } catch (_) {
      // CustomerProvider may be absent in isolated unit tests.
    }

    final defaultResult =
        _customerController.applyDefaultCustomerFromCacheIfNeeded(
      localProductProvider: localProductProvider,
      billingProvider: billingProvider,
      customerSelectionProvider: customerSelectionProvider,
      appSettings: appSettings,
      customers: billingProvider.customerList,
    );
    _customerController.applyDefaultCustomerResult(
      result: defaultResult,
      customerSelectionProvider: customerSelectionProvider,
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );

    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final methods = await masterDataProvider.fetchPaymentMethods();
    if (methods != null && context.mounted) {
      _paymentController.syncPaymentMethodIdsFromModels(
        billingProvider,
        masterDataProvider.enabledSortedPaymentMethods,
      );
    }

    if (!context.mounted) return;

    if (!billingProvider.hasAnyPaymentSelected()) {
      _settingsController.applyDefaultPaymentMethodIfNeeded(
        billingProvider: billingProvider,
        appSettings: appSettings,
      );
    }

    _settingsController.syncDefaultDeliveryMethod(
      billingProvider: billingProvider,
      deliveryMethodsProvider: deliveryMethodsProvider,
      appSettings: appSettings,
    );

    _paymentController.syncPaymentAutofillIfNeeded(billingProvider);
    billingProvider.markPaymentStepVisited();
    billingProvider.calculateBalance();
  }

  Future<SaveOrderResult> saveOrder(BuildContext context) async {
    return await CheckoutService(context).saveOrder();
  }

  Future<bool> confirmOrder(BuildContext context) async {
    return await CheckoutService(context).confirmOrder();
  }

  Future<CreateOrderAndPrintResult> createOrderAndPrint(
      BuildContext context) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final selectedCustomer = customerSelectionProvider.selectedCustomer ??
        billingProvider.selectedCustomer;
    final isDefaultCustomer = _customerController.isDefaultCustomer(
      customer: selectedCustomer,
      customerSelectionProvider: customerSelectionProvider,
      defaultCustomerPhone: appSettings?.autoAssignDefaultCustomerPhone ?? '',
    );
    final checkoutOldBalance =
        isDefaultCustomer ? null : selectedCustomer?.balance;
    final checkoutTotalPaid = billingProvider.getTotalPaidAmount();

    final createdOrderNumber =
        await CheckoutService(context).createOrderAndPrint();
    if (createdOrderNumber == null || createdOrderNumber.isEmpty) {
      return const CreateOrderAndPrintResult(
        orderCreated: false,
        orderNumber: null,
        printSucceeded: false,
      );
    }

    Future<bool> printOnce() => const PrintService().printOrderByIdWithOptions(
          context,
          createdOrderNumber,
          useCheckoutBalanceFields: true,
          checkoutOldBalance: checkoutOldBalance,
          checkoutTotalPaid: checkoutTotalPaid,
          checkoutIsDefaultCustomer: isDefaultCustomer,
        );

    try {
      final printSucceeded = await printOnce();
      if (context.mounted) {
        await maybePrintCustomerCopy(
          context: context,
          canPrompt: printSucceeded,
          printAction: printOnce,
        );
      }
      return CreateOrderAndPrintResult(
        orderCreated: true,
        orderNumber: createdOrderNumber,
        printSucceeded: printSucceeded,
      );
    } catch (error) {
      billingDebugCheckout(
        'createOrderAndPrint',
        'printFailed',
        errorType: error.runtimeType.toString(),
      );
      return CreateOrderAndPrintResult(
        orderCreated: true,
        orderNumber: createdOrderNumber,
        printSucceeded: false,
        printError: error.toString(),
      );
    }
  }

  Future<bool> retryPrintOrder(BuildContext context, String orderNumber) async {
    return const PrintService().printOrderByIdWithOptions(context, orderNumber);
  }

  Future<void> printSavedOrder(
    BuildContext context,
    SavedOrder order, {
    bool offerCustomerCopy = false,
  }) async {
    Future<bool> printOnce() =>
        const PrintService().printSavedOrder(context, order);
    final autoPrintSuccess = await printOnce();
    if (offerCustomerCopy && context.mounted) {
      await maybePrintCustomerCopy(
        context: context,
        canPrompt: autoPrintSuccess,
        printAction: printOnce,
      );
    }
  }

  void deleteSavedOrder(BuildContext context, String orderId) {
    Provider.of<LocalProductProvider>(context, listen: false)
        .deleteSavedOrder(orderId);
  }

  void loadOrderForEditing(BuildContext context, String orderId) {
    Provider.of<LocalProductProvider>(context, listen: false)
        .loadOrderForEditing(orderId);
  }

  /// Persists the current cart as a draft before switching orders or starting
  /// a new one. Mirrors desktop `_saveCurrentCartAsDraft`.
  SavedOrder? saveCurrentCartAsDraft(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    if (localProductProvider.cartItems.isEmpty) {
      return localProductProvider.currentOrder;
    }

    final orderData = billingProvider.createOrderData();
    final paymentMethod = orderData['paymentMethod']?.toString() ?? '';
    final paidAmount = orderData['paidAmount']?.toString() ?? '0';
    final customerNameToSave = OrderCustomerFields.nameForOrder(
        billingProvider.selectedCustomer?.name);
    final customerPhoneToSave = OrderCustomerFields.phoneForOrder(
      selectedPhone: billingProvider.selectedCustomerPhone,
      customerPhone: billingProvider.selectedCustomer?.phone,
      mobileNumberText: billingProvider.mobileNumberText,
      controllerText: billingProvider.mobileNumberTextController.text,
    );
    final deliveryCharge = resolveDeliveryCharge(context);
    final currentOrder = localProductProvider.currentOrder;

    if (currentOrder != null) {
      localProductProvider.updateSavedOrder(
        currentOrder.id,
        customerName: customerNameToSave,
        customerPhone: customerPhoneToSave,
        comment: billingProvider.commentController.text,
        deliveryMethod: billingProvider.deliveryMethod,
        customerId: billingProvider.selectedCustomerID,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        balanceAmount: billingProvider.balanceAmount.toString(),
        transactionId: billingProvider.transactionNumberController.text,
        couponId: billingProvider.isCouponApplied
            ? _trimToNull(billingProvider.coupenCodeTextController.text)
            : null,
        deliveryMethodId: billingProvider.deliveryMethodId,
        carNumber: billingProvider.carNumberController.text,
        context: context,
        status: currentOrder.status ?? 'saved',
        deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
        deliveryTime: billingProvider.deliveryTime,
        toCustomerCredit: billingProvider.toCustomerCreditEnabled,
        address: billingProvider.orderAddress.isNotEmpty
            ? billingProvider.orderAddress
            : null,
        deliveryCharge: deliveryCharge,
        customerType: billingProvider.selectedCustomer?.customerType,
      );
      return localProductProvider.findOrderById(currentOrder.id) ??
          currentOrder;
    }

    return localProductProvider.saveCurrentCartAsOrder(
      customerName: customerNameToSave,
      customerPhone: customerPhoneToSave,
      comment: billingProvider.commentController.text,
      deliveryMethod: billingProvider.deliveryMethod,
      customerId: billingProvider.selectedCustomerID,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      balanceAmount: billingProvider.balanceAmount.toString(),
      transactionId: billingProvider.transactionNumberController.text,
      couponId: billingProvider.isCouponApplied
          ? _trimToNull(billingProvider.coupenCodeTextController.text)
          : null,
      deliveryMethodId: billingProvider.deliveryMethodId,
      carNumber: billingProvider.carNumberController.text,
      status: 'saved',
      deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
      deliveryTime: billingProvider.deliveryTime,
      context: context,
      toCustomerCredit: billingProvider.toCustomerCreditEnabled,
      address: billingProvider.orderAddress.isNotEmpty
          ? billingProvider.orderAddress
          : null,
      deliveryCharge: deliveryCharge,
      customerType: billingProvider.selectedCustomer?.customerType,
    );
  }

  /// Resets billing UI after checkout/save-and-print when the cart is already
  /// cleared by [LocalProductProvider.clearCartAfterOrder].
  void resetBillingWorkspaceAfterOrder(BuildContext context) {
    _resetBillingWorkspaceCore(
      context,
      clearCart: false,
      syncDefaultDelivery: true,
      syncSalesExecutive: false,
    );
  }

  Future<void> createNewOrder(BuildContext context) async {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    if (localProductProvider.cartItems.isNotEmpty) {
      saveCurrentCartAsDraft(context);
    }

    clearCartData(context);
  }

  /// Mirrors desktop `BillingPage.resetToDefaultSalesExecutive` for external
  /// callers (e.g. saved-orders "new order" flows).
  void resetToDefaultSalesExecutive(BuildContext context) {
    _resetBillingWorkspaceCore(
      context,
      clearCart: false,
      syncDefaultDelivery: true,
      syncSalesExecutive: true,
    );
  }

  /// Refreshes the cached customer list after a sale so the next order sees
  /// updated balances (mirrors desktop `_refreshCustomersInBackgroundAfterSale`).
  void refreshCustomersInBackgroundAfterSale(BuildContext context) {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      final accessToken = authModel.token;

      if (accessToken == null || accessToken.isEmpty) {
        billingDebugLog(
          'Skipping background customer refresh: access token unavailable',
        );
        return;
      }

      unawaited(() async {
        try {
          billingDebugLog('Background customer refresh started after sale');
          await customerProvider.fetchCustomers(
            accessToken: accessToken,
            listAll: true,
          );

          final refreshedCustomers = customerProvider.allCustomers;
          if (refreshedCustomers == null || refreshedCustomers.isEmpty) {
            return;
          }

          billingProvider.setCustomerList(
            List<CustomerListModelData>.from(refreshedCustomers),
          );
          billingDebugLog(
            'Background customer refresh completed: ${refreshedCustomers.length} customers',
          );
        } catch (error) {
          billingDebugLog('Background customer refresh failed: $error');
        }
      }());
    } catch (error) {
      billingDebugLog('Failed to start background customer refresh: $error');
    }
  }

  Future<void> refreshPaymentMethodIdsThenRehydrate(
    BuildContext context,
    String orderId,
  ) async {
    try {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);

      final methods = await masterDataProvider.fetchPaymentMethods();
      if (methods == null || !context.mounted) {
        return;
      }

      String? cashId, cardId, upiId, codId;
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

      billingProvider.updatePaymentMethodIds(
        cashId: cashId,
        cardId: cardId,
        upiId: upiId,
        codId: codId,
      );

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      if (!context.mounted) return;
      if (localProductProvider.currentOrder?.id == orderId) {
        restoreOrderState(context);
      }
    } catch (error) {
      billingDebugLog(
        'Error refreshing payment methods for saved order: $error',
      );
    }
  }

  void onCartChanged(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (!billingProvider.hasCollectedPaymentAmounts()) {
      return;
    }

    billingProvider.clearCollectedPaymentAmountsOnly();
    billingProvider.resetPaymentStepVisited();
    billingProvider.clearPristinePaymentState();
  }

  /// Clears auto-assigned default customer when opening quotation checkout.
  /// Mirrors desktop `_clearAutomaticDefaultCustomerForQuotation`.
  void clearAutomaticDefaultCustomerForQuotation(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    if (localProductProvider.currentOrder?.quotationId != null) {
      return;
    }

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final defaultPhone = appSettings?.autoAssignDefaultCustomerPhone ?? '';

    final isAutoDefault = customerSelectionProvider.isDefaultCustomer ||
        (defaultPhone.isNotEmpty &&
            (billingProvider.selectedCustomerPhone == defaultPhone ||
                billingProvider.mobileNumberText == defaultPhone));
    if (!isAutoDefault) return;

    _customerController.clearSelection(
      customerSelectionProvider: customerSelectionProvider,
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
  }

  /// When inline quotation fields are edited, clear any saved customer selection
  /// so the payload uses `customer_type: new` (desktop checkout modal behaviour).
  void handleQuotationInlineCustomerChanged(
    BuildContext context, {
    required String inlineName,
    required String inlinePhone,
  }) {
    if (inlineName.trim().isEmpty && inlinePhone.trim().isEmpty) return;

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    customerSelectionProvider.clearSelectedCustomer();
    billingProvider.clearSelectedCustomer();
  }

  /// Syncs inline quotation customer into selection providers before POST.
  void syncInlineQuotationCustomer(
    BuildContext context, {
    required String inlineName,
    required String inlinePhone,
  }) {
    final name = inlineName.trim();
    if (name.isEmpty) return;

    final inlineCustomer = CustomerListModelData(
      name: name,
      phone: inlinePhone.trim().isEmpty ? null : inlinePhone.trim(),
      customerType: 'new',
      balance: 0,
    );
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    customerSelectionProvider.setSelectedCustomer(inlineCustomer);
    billingProvider.setSelectedCustomer(inlineCustomer, isManual: true);
  }

  Future<CreateQuotationResult> createQuotationFromCheckout(
    BuildContext context, {
    required bool shouldPrint,
    required DateTime quotationDate,
    required DateTime expiryDate,
    required String inlineCustomerName,
    required String inlineCustomerPhone,
  }) async {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthModel>(context, listen: false);
    final customerProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final quotationsProvider =
        Provider.of<QuotationsProvider>(context, listen: false);
    final storeProvider =
        Provider.of<StoreSessionProvider>(context, listen: false);

    if (inlineCustomerName.trim().isNotEmpty) {
      syncInlineQuotationCustomer(
        context,
        inlineName: inlineCustomerName,
        inlinePhone: inlineCustomerPhone,
      );
    }

    final quoteCustomer =
        customerProvider.selectedCustomer ?? billingProvider.selectedCustomer;
    final quoteCustomerId = customerProvider.selectedCustomerID ??
        billingProvider.selectedCustomerID ??
        quoteCustomer?.id;
    final quoteCustomerName = inlineCustomerName.trim().isNotEmpty
        ? inlineCustomerName.trim()
        : quoteCustomer?.name?.trim();
    final quoteCustomerPhone = inlineCustomerPhone.trim().isNotEmpty
        ? inlineCustomerPhone.trim()
        : ((customerProvider.selectedCustomerPhone ??
                        billingProvider.selectedCustomerPhone)
                    ?.trim()
                    .isNotEmpty ==
                true
            ? (customerProvider.selectedCustomerPhone ??
                    billingProvider.selectedCustomerPhone)
                ?.trim()
            : quoteCustomer?.phone?.trim());
    final hasExistingCustomer = quoteCustomerId != null;
    final hasInlineCustomer = quoteCustomerName?.isNotEmpty ?? false;

    final validationError = QuotationCheckout.validate(
      cartIsEmpty: localProductProvider.cartItems.isEmpty,
      hasExistingCustomer: hasExistingCustomer,
      hasInlineCustomer: hasInlineCustomer,
      quotationDate: quotationDate,
      expiryDate: expiryDate,
    );
    if (validationError != null) {
      return CreateQuotationResult.failure(validationError);
    }

    try {
      final deliveryMethodIdValue =
          int.tryParse(billingProvider.deliveryMethodId);
      final deliveryChargeValue = resolveDeliveryCharge(context);
      final priceSummary = localProductProvider.priceSummary;
      final discountValue = priceSummary?.discount ?? 0.0;
      final payload = QuotationCheckout.buildPayload(
        hasExistingCustomer: hasExistingCustomer,
        customerId: quoteCustomerId,
        customerName: quoteCustomerName,
        customerPhone: quoteCustomerPhone,
        storeId: storeProvider.activeStore?.storeId,
        deliveryMethodId: deliveryMethodIdValue,
        deliveryCharge: deliveryChargeValue,
        quotationDate: quotationDate,
        expiryDate: expiryDate,
        discount: discountValue,
        comment: billingProvider.commentController.text,
        cartItems: localProductProvider.cartItems,
      );

      final response = await quotationsProvider.createQuotation(
        accessToken: authProvider.token ?? '',
        data: payload,
      );

      if (!context.mounted) {
        return const CreateQuotationResult(success: true);
      }

      if (response['success'] == true || response['status'] == 'success') {
        var printSucceeded = false;
        String? printError;

        if (shouldPrint) {
          final quotationId =
              QuotationCheckout.extractCreatedQuotationId(response);
          if (quotationId == null) {
            printError = BillingMobileErrorMessages.quotationPrintMissingId;
          } else {
            final details = await quotationsProvider.fetchQuotationDetails(
              accessToken: authProvider.token ?? '',
              quotationId: quotationId,
            );
            if (!context.mounted) {
              return const CreateQuotationResult(success: true);
            }
            if (details == null) {
              printError =
                  BillingMobileErrorMessages.quotationPrintDetailsFailed;
            } else {
              Future<bool> printOnce() =>
                  printQuotationDetails(context, details);
              printSucceeded = await printOnce();
              if (!context.mounted) {
                return const CreateQuotationResult(success: true);
              }
              await maybePrintCustomerCopy(
                context: context,
                canPrompt: printSucceeded,
                printAction: printOnce,
              );
            }
          }
        }

        return CreateQuotationResult(
          success: true,
          printSucceeded: shouldPrint ? printSucceeded : null,
          printError: printError,
        );
      }

      return CreateQuotationResult.failure(
        response['message']?.toString() ??
            BillingMobileErrorMessages.quotationCreateFailed,
      );
    } catch (_) {
      return const CreateQuotationResult.failure(
        BillingMobileErrorMessages.quotationCreateFailed,
      );
    }
  }

  Future<bool> printQuotationDetails(
    BuildContext context,
    QuotationDetailsData details,
  ) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final selectedCustomer = customerSelectionProvider.selectedCustomer ??
        billingProvider.selectedCustomer;
    final isDefaultCustomer = _customerController.isDefaultCustomer(
      customer: selectedCustomer,
      customerSelectionProvider: customerSelectionProvider,
      defaultCustomerPhone: appSettings?.autoAssignDefaultCustomerPhone ?? '',
    );

    return const QuotationPrintService().printQuotationDetails(
      context,
      details,
      customerOldBalance: isDefaultCustomer ? null : selectedCustomer?.balance,
      paidAmount: null,
      paymentMethod: null,
      paymentBreakdown: null,
      customerType: selectedCustomer?.customerType,
      deliveryMethod: billingProvider.deliveryMethod,
      isDefaultCustomer: isDefaultCustomer,
    );
  }

  Future<void> maybePrintCustomerCopy({
    required BuildContext context,
    required bool canPrompt,
    required Future<bool> Function() printAction,
  }) async {
    if (!canPrompt || !context.mounted) return;

    final shouldDoublePrint = Provider.of<AppSettingsProvider>(
          context,
          listen: false,
        ).appSettings?.posPrintDoubleBill ??
        false;
    if (!shouldDoublePrint) return;

    final shouldPrintCustomerCopy = await ConfirmationDialog.show(
          context: context,
          title: 'Print customer copy?',
          message: 'Do you want to print a customer copy now?',
          confirmText: 'Yes, print',
          cancelText: 'No',
        ) ??
        false;
    if (!shouldPrintCustomerCopy || !context.mounted) return;

    await printAction();
  }
}

/// Outcome of confirm-and-print: order may succeed while print fails.
class CreateOrderAndPrintResult {
  const CreateOrderAndPrintResult({
    required this.orderCreated,
    required this.orderNumber,
    required this.printSucceeded,
    this.printError,
  });

  final bool orderCreated;
  final String? orderNumber;
  final bool printSucceeded;
  final String? printError;

  bool get printFailed =>
      orderCreated && orderNumber != null && !printSucceeded;
}

class CreateQuotationResult {
  const CreateQuotationResult({
    required this.success,
    this.errorMessage,
    this.printSucceeded,
    this.printError,
  });

  const CreateQuotationResult.failure(String message)
      : success = false,
        errorMessage = message,
        printSucceeded = null,
        printError = null;

  final bool success;
  final String? errorMessage;
  final bool? printSucceeded;
  final String? printError;
}
