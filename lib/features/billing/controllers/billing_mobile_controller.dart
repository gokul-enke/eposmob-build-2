import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/add_product_with_variant.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/checkout_service.dart';
export 'package:pos_machine/services/checkout_service.dart' show SaveOrderResult;
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/features/billing/presentation/pages/add_product_mobile.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/barcode_sale_unit.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

enum MobileBillingShortcutAction {
  clearCart,
  saveOrder,
  createOrderAndPrint,
  confirmOrder,
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
      final restoredCustomer = billingProvider.selectedCustomer ?? customerToSet;
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
  /// Supported on [BillingPageMobile] via a page-level [KeyboardListener]:
  /// - **F6** — clear cart
  /// - **F7** — save order
  /// - **F8** — confirm & print
  /// - **F9** — confirm order
  /// - **Esc** — restore focus to barcode or product-search entry
  /// - **Ctrl+A** — focus barcode field when `barcodeSales` is enabled
  ///
  /// Desktop-only shortcuts (F1–F5, F12, Ctrl+H/K/D/S/Q/P/U) are intentionally
  /// omitted on mobile. Shortcuts are dispatched from the page focus node, so
  /// they do not fire while a text field owns focus (text editing is preserved).

  void focusTextField(BuildContext context) {
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
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
    if (key == LogicalKeyboardKey.f6) {
      return MobileBillingShortcutAction.clearCart;
    }
    if (key == LogicalKeyboardKey.f7) {
      return MobileBillingShortcutAction.saveOrder;
    }
    if (key == LogicalKeyboardKey.f8) {
      return MobileBillingShortcutAction.createOrderAndPrint;
    }
    if (key == LogicalKeyboardKey.f9) {
      return MobileBillingShortcutAction.confirmOrder;
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
        case MobileBillingShortcutAction.saveOrder:
          billingProvider.executeKeyboardShortcut('saveOrder');
        case MobileBillingShortcutAction.createOrderAndPrint:
          billingProvider.executeKeyboardShortcut('createOrderAndPrint');
        case MobileBillingShortcutAction.confirmOrder:
          billingProvider.executeKeyboardShortcut('confirmOrder');
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
              BarcodeSaleUnit.resolveSaleUnitQuantity(matchedSaleUnit);
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

    _customerController.clearSelection(
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );

    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final defaultResult = _customerController.applyDefaultCustomerFromCacheIfNeeded(
      localProductProvider: localProductProvider,
      billingProvider: billingProvider,
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      appSettings: appSettings,
      customers: billingProvider.customerList,
    );
    _customerController.applyDefaultCustomerResult(
      result: defaultResult,
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
  }

  bool hasSelectedPayment(BuildContext context) =>
      Provider.of<BillingProvider>(context, listen: false)
          .getSelectedPaymentMethodsExcludingEmpty()
          .isNotEmpty;

  Future<SaveOrderResult> saveOrder(BuildContext context) async {
    return await CheckoutService(context).saveOrder();
  }

  Future<void> confirmOrder(BuildContext context) async {
    await CheckoutService(context).confirmOrder();
  }

  Future<CreateOrderAndPrintResult> createOrderAndPrint(
      BuildContext context) async {
    final createdOrderNumber =
        await CheckoutService(context).createOrderAndPrint();
    if (createdOrderNumber == null || createdOrderNumber.isEmpty) {
      return const CreateOrderAndPrintResult(
        orderCreated: false,
        orderNumber: null,
        printSucceeded: false,
      );
    }

    try {
      await const PrintService().printOrderById(context, createdOrderNumber);
      return CreateOrderAndPrintResult(
        orderCreated: true,
        orderNumber: createdOrderNumber,
        printSucceeded: true,
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

  Future<bool> retryPrintOrder(
      BuildContext context, String orderNumber) async {
    await const PrintService().printOrderById(context, orderNumber);
    return true;
  }

  Future<void> printSavedOrder(BuildContext context, SavedOrder order) async {
    await const PrintService().printSavedOrder(context, order);
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
    final customerNameToSave = billingProvider.selectedCustomer?.name;
    final customerPhoneToSave = billingProvider.selectedCustomerPhone ??
        billingProvider.mobileNumberText;
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
            ? billingProvider.coupenCodeTextController.text
            : null,
        deliveryMethodId: billingProvider.deliveryMethodId,
        carNumber: billingProvider.carNumberController.text,
        context: context,
        status: 'saved',
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
          ? billingProvider.coupenCodeTextController.text
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
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

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

    _customerController.clearSelection(
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );

    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final defaultResult = _customerController.applyDefaultCustomerFromCacheIfNeeded(
      localProductProvider: localProductProvider,
      billingProvider: billingProvider,
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      appSettings: appSettings,
      customers: billingProvider.customerList,
    );
    _customerController.applyDefaultCustomerResult(
      result: defaultResult,
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: billingProvider,
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
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
