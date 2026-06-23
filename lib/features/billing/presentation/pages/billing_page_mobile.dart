import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/controllers/coordinators/payment_coordinator.dart';
import 'package:pos_machine/services/checkout_service.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders_tab.dart';

class BillingPageMobile extends StatefulWidget {
  const BillingPageMobile({super.key});

  @override
  State<BillingPageMobile> createState() => BillingPageMobileState();
}

class BillingPageMobileState extends State<BillingPageMobile>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Bottom navigation
  int _currentTabIndex = 0;
  late TabController _tabController;

  // Keys for autocomplete widgets
  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  CartProvider cartProvider = CartProvider();
  UniqueKey keyTile = UniqueKey();

  final FocusNode _focusNode = FocusNode();
  StreamSubscription<String>? _barcodeSubscription;
  String? _lastRehydratedOrderId;
  bool _isConfirmingOrder = false;

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    // Initialize providers and listeners (same as original)
    _initializeProviders();
    _setupListeners();
  }

  void _initializeProviders() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');

    _focusNode.addListener(_handleFocusChange);

    // Initialize BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.initConnectivityListener(
      onConnectivityChanged: (message) {
        if (mounted) {
          if (message.contains('No internet')) {
            showScaffoldError(context: context, message: message);
          } else {
            showScaffold(context: context, message: message);
          }
        }
      },
    );

    // Setup focus listeners
    billingProvider.paidAmountFocusNode
        .addListener(billingProvider.handlePaidAmountFocusChange);
    billingProvider.quantityFocusNode
        .addListener(billingProvider.handleQuantityFocusChange);
    billingProvider.unitPriceFocusNode
        .addListener(billingProvider.handleUnitPriceFocusChange);

    // Initialize delivery method
    billingProvider.initializeDeliveryMethod();
    billingProvider.fetchCustomers(accessToken: accessToken!);

    // Rehydrate UI from saved order/discounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rehydrateFromProvider();
    });
  }

  void _setupListeners() {
    // Barcode listener
    final barcodeProvider =
        Provider.of<BarcodeProvider>(context, listen: false);
    _barcodeSubscription = barcodeProvider.barcodeStream.listen((barcode) {
      if (mounted) {
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        billingProvider.processBarcodeWithDebounce(barcode, () {
          processBarcode(barcode);
        });
      }
    });

    // Sales executive and auth listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);

      salesExecutiveProvider
          .addListener(billingProvider.onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(billingProvider.onUserSwitched);

      // App settings listener
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      appSettingsProvider.addListener(() {
        debugPrint('🎫 APP SETTINGS CHANGED:');
        debugPrint('  - New appSettings: ${appSettingsProvider.appSettings}');
      });
    });

    // Mobile number controller listener
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.mobileNumberTextController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    _focusNode.dispose();
    _tabController.dispose();

    // Remove listeners
    try {
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider
          .removeListener(billingProvider.onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.removeListener(billingProvider.onUserSwitched);
    } catch (e) {
      debugPrint("Error removing listeners: $e");
    }

    super.dispose();
  }

  void _setDefaultDeliveryMethod(BillingProvider billingProvider) {
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

  // Rehydrate UI state from provider (same logic as original)
  void _rehydrateFromProvider() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final SavedOrder? currentOrder = localProductProvider.currentOrder;

    if (currentOrder != null) {
      _lastRehydratedOrderId = currentOrder.id;
    }

    try {
      if (currentOrder == null) {
        final summary = localProductProvider.priceSummary;
        setState(() {
          // Handle coupon state from provider summary
        });
        return;
      }

      // Full UI state restoration logic (same as original)
      setState(() {
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        billingProvider.clearSelectedCustomer();
        Provider.of<CustomerSelectionProvider>(context, listen: false)
            .clearSelectedCustomer();

        // Restore customer information
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

        // Restore payment methods and other state (same logic as original)
        _restorePaymentMethods(currentOrder, billingProvider);
        _restoreOrderDetails(currentOrder, billingProvider);
      });

      // Final UI updates
      Provider.of<BillingProvider>(context, listen: false).setTotalOrderAmount(
          Provider.of<LocalProductProvider>(context, listen: false)
                  .priceSummary
                  ?.netTotal ??
              0.0);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _autocompletePhoneKey = GlobalKey();
          });
        }
      });
    } catch (e) {
      debugPrint("Error during rehydration: $e");
    }
  }

  void _restorePaymentMethods(
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

  void _restoreOrderDetails(
      SavedOrder currentOrder, BillingProvider billingProvider) {
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
      _setDefaultDeliveryMethod(billingProvider);
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

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // Handle focus changes
    }
  }

  void _handleKeyPress(KeyEvent event) {
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

  Future<void> processBarcode(String barcode) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (barcode.isEmpty) return;

    String query = barcode;
    List<GetProduct> filteredProducts = [];

    try {
      String? prefix;
      String? productCode;
      String? lastFive;

      if (query.length > 2) {
        prefix = query.substring(0, 3);
      }

      if (prefix != '000' || query.length != 14) {
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(barCode: query);
      } else {
        productCode = query.substring(3, 9);
        lastFive = query.substring(9, 14);
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(barCode: productCode);
      }

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

        if ((product.unit == 'KGS' || product.unit == 'KG') &&
            prefix == '000' &&
            query.length == 14) {
          String weightKg = lastFive!.substring(0, 2);
          String weightGrams = lastFive.substring(2, 5);
          quantity =
              double.parse(weightKg) + (double.parse(weightGrams) / 1000);
        } else if ((product.unit == 'PCS' || product.unit == 'PC') &&
            prefix == '000' &&
            query.length == 14) {
          quantity = int.parse(lastFive!);
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

        setState(() {
          _autocompleteProductKey = GlobalKey();
        });
        billingProvider.clearProductFieldsAndReset();
        _focusTextField();
      } else {
        await showDialog(
          context: context,
          builder: (context) =>
              AddProductWithBarcodeModal(barcode: query, isAddToCart: true),
        );
        billingProvider.barcodeController.clear();
        _focusTextField();
      }
    } catch (e) {
      debugPrint("Error adding item: $e");
      showScaffoldError(
        context: context,
        message: "Invalid Barcode. Please try again.",
      );
    }
  }

  void _focusTextField() {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    billingProvider
        .focusTextField(appSettingsProvider.appSettings!.barcodeSales);
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  // Action methods (same as original)
  void clearCart() {
    debugPrint("Clear Cart pressed");
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.setLoadingClearCart(true);

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();

      setState(() {
        billingProvider.coupenCodeTextController.clear();
        billingProvider.transactionNumberController.clear();
        billingProvider.paidAmountController.clear();
        billingProvider.clearAllPaymentMethods();
        _autocompleteProductKey = GlobalKey();
        billingProvider.clearProductFields();
        billingProvider.setToCustomerCreditEnabled(false);
        billingProvider.setDeliveryDate(null);
        billingProvider.setDeliveryTime(null);
        billingProvider.commentController.clear();
        billingProvider.carNumberController.clear();
        billingProvider.setMobileNumberText("");
        billingProvider.mobileNumberTextController.clear();
        billingProvider.clearSelectedCustomer();
        _autocompletePhoneKey = GlobalKey();
      });

      showScaffold(context: context, message: "Cart Cleared Successfully");
      _focusTextField();
    } catch (e) {
      debugPrint("Error clearing cart: $e");
      showScaffoldError(
          context: context, message: "Failed to clear cart. Please try again.");
    } finally {
      billingProvider.setLoadingClearCart(false);
    }
  }

  void saveOrder() async {
    debugPrint("Save Order pressed");
    final service = CheckoutService(context);
    final updated = await service.saveOrder();
    if (updated) {
      clearCart();
    } else {
      clearCart();
    }
  }

  void confirmOrder() async {
    final selectedPaymentMethods =
        Provider.of<BillingProvider>(context, listen: false)
            .getSelectedPaymentMethodsExcludingEmpty();

    if (selectedPaymentMethods.isEmpty) {
      showScaffoldError(
          context: context, message: "Please select a payment method");
      // Switch to billing tab to show payment options
      setState(() {
        _currentTabIndex = 1;
        _tabController.animateTo(1);
      });
      PaymentCoordinator.showPaymentMethodModal(context);
      return;
    }

    setState(() {
      _isConfirmingOrder = true;
    });

    try {
      await CheckoutService(context).confirmOrder();
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingOrder = false;
        });
      }
    }
    _focusTextField();
  }

  void createOrderAndPrint() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final selectedMethods =
        billingProvider.getSelectedPaymentMethodsExcludingEmpty();

    debugPrint('🖨️ [Print Order] Starting print order...');
    debugPrint('🖨️ [Print Order] Selected payment methods: $selectedMethods');
    debugPrint(
        '🖨️ [Print Order] isOnlineSelected: ${billingProvider.isOnlineSelected}');
    debugPrint(
        '🖨️ [Print Order] isCashSelected: ${billingProvider.isCashSelected}');
    debugPrint(
        '🖨️ [Print Order] isCardSelected: ${billingProvider.isCardSelected}');
    debugPrint(
        '🖨️ [Print Order] isUpiSelected: ${billingProvider.isUpiSelected}');

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

  void loadSavedOrderForEditing(String orderId) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.loadOrderForEditing(orderId);
      _rehydrateFromProvider();

      // Switch to home tab to show loaded cart
      setState(() {
        _currentTabIndex = 0;
        _tabController.animateTo(0);
      });

      showScaffold(context: context, message: "Order loaded for editing");
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "Failed to load order. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Check for order rehydration
    final currentOrder =
        Provider.of<LocalProductProvider>(context, listen: true).currentOrder;
    if (currentOrder != null && currentOrder.id != _lastRehydratedOrderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rehydrateFromProvider();
        }
      });
    }

    return SafeArea(
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                // Home Tab
                MobileHomeTab(
                  autocompleteProductKey: _autocompleteProductKey,
                  onProcessBarcode: processBarcode,
                  onClearProductFields: () {
                    setState(() {
                      _autocompleteProductKey = GlobalKey();
                      final billingProvider =
                          Provider.of<BillingProvider>(context, listen: false);
                      billingProvider.quantityController.clear();
                      billingProvider.barcodeController.clear();
                      billingProvider.selectedProductIdController.clear();
                      billingProvider.unitPriceController.clear();
                    });
                  },
                  focusTextField: _focusTextField,
                  onClearCart: clearCart,
                ),
                // Billing Tab
                MobileBillingTab(
                  autocompletePhoneKey: _autocompletePhoneKey,
                  onConfirmOrder: confirmOrder,
                  onSaveOrder: saveOrder,
                  onCreateOrderAndPrint: createOrderAndPrint,
                  isConfirmingOrder: _isConfirmingOrder,
                ),
                // Orders Tab
                MobileOrdersTab(
                  onOrderSelected: loadSavedOrderForEditing,
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                  _tabController.animateTo(index);
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: ColorManager.kPrimaryColor,
              unselectedItemColor: Colors.grey.shade600,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.payment_outlined),
                  activeIcon: Icon(Icons.payment),
                  label: 'Billing',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Orders',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
