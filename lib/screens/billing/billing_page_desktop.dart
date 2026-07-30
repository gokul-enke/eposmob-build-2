import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/payment_summary.dart';
import 'package:pos_machine/features/billing/presentation/widgets/quick_access_bar.dart';
import 'package:pos_machine/features/billing/presentation/widgets/cart/cart_items_table.dart';
import 'package:pos_machine/features/billing/presentation/widgets/customer_input.dart';
import 'package:pos_machine/features/billing/presentation/widgets/product_entry_header.dart';
import 'package:pos_machine/features/billing/presentation/widgets/action_buttons.dart';
import 'package:pos_machine/features/billing/presentation/widgets/sidebar.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/features/billing/controllers/coordinators/payment_coordinator.dart';
import 'package:pos_machine/services/checkout_service.dart';
import 'package:pos_machine/features/billing/presentation/widgets/header.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => BillingPageState();
}

class BillingPageState extends State<BillingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  CartProvider cartProvider = CartProvider();
  UniqueKey keyTile = UniqueKey();

  final FocusNode _focusNode = FocusNode();

  // Add these variables for the new sidebar
  bool _isSidebarVisible = true;
  int _selectedSidebarTab =
      1; // 0 for products, 1 for orders/categories - default to orders tab

  StreamSubscription<String>? _barcodeSubscription;

  // Track last rehydrated order to avoid losing state on navigation
  String? _lastRehydratedOrderId;

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
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

    // Debug logging for AppSettings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      debugPrint('🎫 APP SETTINGS INIT DEBUG:');
      debugPrint('  - appSettingsProvider: $appSettingsProvider');
      debugPrint('  - appSettings: ${appSettingsProvider.appSettings}');
      if (appSettingsProvider.appSettings != null) {
        debugPrint(
            '  - discountAndCoupon: ${appSettingsProvider.appSettings?.discountAndCoupon}');
        debugPrint(
            '  - All settings: ${appSettingsProvider.appSettings.toString()}');
      }
    });

    // Initialize delivery method in provider
    billingProvider.initializeDeliveryMethod();

    // Fetch customers using provider
    billingProvider.fetchCustomers(accessToken: accessToken!);

    // After first frame, rehydrate UI from any saved order/discounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rehydrateFromProvider();
    });

    // Listen to the barcode stream
    final barcodeProvider =
        Provider.of<BarcodeProvider>(context, listen: false);
    _barcodeSubscription = barcodeProvider.barcodeStream.listen((barcode) {
      if (mounted) {
        billingProvider.processBarcodeWithDebounce(barcode, () {
          processBarcode(barcode);
        });
      }
    });

    // Listen for sales executive changes to update default customer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider
          .addListener(billingProvider.onSalesExecutiveChanged);

      // Also listen for auth changes (more direct indicator of user switch)
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(billingProvider.onUserSwitched);

      // Listen for app settings changes
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      appSettingsProvider.addListener(() {
        debugPrint('🎫 APP SETTINGS CHANGED:');
        debugPrint('  - New appSettings: ${appSettingsProvider.appSettings}');
        if (appSettingsProvider.appSettings != null) {
          debugPrint(
              '  - New discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}');
        }
      });
    });

    // Ensure UI updates when virtual keyboard edits the customer phone field
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

    // Remove sales executive listener
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

  // Rehydrate all UI state from the provider's current order
  void _rehydrateFromProvider() {
    // Prevent default customer from overriding when editing an order
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final SavedOrder? currentOrder = localProductProvider.currentOrder;
    if (currentOrder != null) {
      _lastRehydratedOrderId = currentOrder.id;
    }
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final SavedOrder? currentOrder = localProductProvider.currentOrder;

      // If there's no order, there's nothing to rehydrate.
      // We can infer coupon state from provider, but we'll keep it simple.
      if (currentOrder == null) {
        // Infer discount state from provider summary if any
        final summary = localProductProvider.priceSummary;
        setState(() {
          if (summary != null &&
              ((summary.flatDiscount > 0) ||
                  (summary.percentageDiscount > 0))) {
            // Coupon applied state managed by provider
          } else {
            // Coupon applied state managed by provider
          }
        });
        return;
      }

      // Start full UI state restoration
      setState(() {
        // 1. Restore Customer Information
        // Clear existing state first to prevent contamination
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        billingProvider.clearSelectedCustomer();
        Provider.of<CustomerSelectionProvider>(context, listen: false)
            .clearSelectedCustomer();

        // Check if there is any customer data to restore
        if (currentOrder.customerId != null ||
            (currentOrder.customerPhone != null &&
                currentOrder.customerPhone!.isNotEmpty)) {
          CustomerListModelData? customerToSet;

          // Try to find the customer in the main list if an ID exists
          if (currentOrder.customerId != null &&
              billingProvider.customerList != null) {
            try {
              customerToSet = billingProvider.customerList!
                  .firstWhere((c) => c.id == currentOrder.customerId);
            } catch (e) {
              // Not found in list, will create a virtual one next.
            }
          }

          // If not found in the list or if it's a phone-only order,
          // create a 'virtual' customer object from the order data.
          customerToSet ??= CustomerListModelData(
            id: currentOrder.customerId,
            name: currentOrder.customerName,
            phone: currentOrder.customerPhone,
          );

          // Set the customer using the provider method
          billingProvider.setSelectedCustomer(customerToSet, isManual: true);

          // Now, with a guaranteed selectedCustomer object, update the UI
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .setSelectedCustomer(billingProvider.selectedCustomer!);

          // Customer display is now handled by the provider's setSelectedCustomer method
        }

        // 2. Restore Payment Methods
        // Reset all payment state first - now handled by provider
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
                        amounts.containsKey(
                            billingProvider.cashPaymentMethodId))) {
                  billingProvider.setPaymentMethod('CASH', true);
                  billingProvider.cashAmountController.text =
                      (amounts[billingProvider.cashPaymentMethodId] ?? '0')
                          .toString();
                }
                if (!methods.contains('CARD') &&
                    (methods.contains(billingProvider.cardPaymentMethodId) ||
                        amounts.containsKey(
                            billingProvider.cardPaymentMethodId))) {
                  billingProvider.setPaymentMethod('CARD', true);
                  billingProvider.cardAmountController.text =
                      (amounts[billingProvider.cardPaymentMethodId] ?? '0')
                          .toString();
                }
                if (!methods.contains('UPI') &&
                    (methods.contains(billingProvider.upiPaymentMethodId) ||
                        amounts
                            .containsKey(billingProvider.upiPaymentMethodId))) {
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
                if (methods.contains('ONLINE') ||
                    amounts.containsKey('ONLINE')) {
                  billingProvider.setPaymentMethod('ONLINE', true);
                  billingProvider.setPineLabsPaymentSuccess(true);
                }
              }
            } catch (e) {
              debugPrint("Error parsing payment JSON on rehydration: $e");
            }
          } else {
            // Single method
            billingProvider.setPaymentMethod(pm.toUpperCase(), true);

            final paid = currentOrder.paidAmount ?? '0.0';
            if (pm.toUpperCase() == 'CASH')
              billingProvider.cashAmountController.text = paid;
            if (pm.toUpperCase() == 'CARD')
              billingProvider.cardAmountController.text = paid;
            if (pm.toUpperCase() == 'UPI')
              billingProvider.upiAmountController.text = paid;
            if (pm.toUpperCase() == 'DEBIT')
              billingProvider.debitAmountController.text = paid;
            if (pm == billingProvider.cashPaymentMethodId) {
              billingProvider.setPaymentMethod('CASH', true);
              billingProvider.cashAmountController.text = paid;
            }
            if (pm == billingProvider.cardPaymentMethodId) {
              billingProvider.setPaymentMethod('CARD', true);
              billingProvider.cardAmountController.text = paid;
            }
            if (pm == billingProvider.upiPaymentMethodId) {
              billingProvider.setPaymentMethod('UPI', true);
              billingProvider.upiAmountController.text = paid;
            }
            if (pm == billingProvider.codPaymentMethodId ||
                pm.toUpperCase() == 'COD') {
              billingProvider.setPaymentMethod('COD', true);
              billingProvider.codAmountController.text = paid;
            }
            if (pm.toUpperCase() == 'ONLINE') {
              billingProvider.setPaymentMethod('ONLINE', true);
              billingProvider.setPineLabsPaymentSuccess(true);
            }
          }
        }

        // 3. Restore Main Payment Amounts
        billingProvider.paidAmountController.text =
            currentOrder.paidAmount ?? "0.0";
        // Balance amount now managed by provider

        // 4. Restore Transaction, Delivery, and Other Details
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

        // 5. Restore Coupon State
        if ((currentOrder.couponId != null &&
                currentOrder.couponId!.isNotEmpty) ||
            (currentOrder.flatDiscount != null &&
                currentOrder.flatDiscount! > 0) ||
            (currentOrder.percentageDiscount != null &&
                currentOrder.percentageDiscount! > 0)) {
          Provider.of<BillingProvider>(context, listen: false)
              .coupenCodeTextController
              .text = currentOrder.couponId ?? "";
          // Coupon applied state managed by provider
        } else {
          Provider.of<BillingProvider>(context, listen: false)
              .coupenCodeTextController
              .clear();
          // Coupon applied state managed by provider
        }

        // 6. Restore To Customer Credit flag
        billingProvider
            .setToCustomerCreditEnabled(currentOrder.toCustomerCredit ?? false);
      });

      // 7. Final UI Updates
      // Balance amount now managed by provider
      Provider.of<BillingProvider>(context, listen: false).setTotalOrderAmount(
          Provider.of<LocalProductProvider>(context, listen: false)
                  .priceSummary
                  ?.netTotal ??
              0.0);
      // Force a rebuild of the autocomplete widget to reflect the new customer
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

  Future<void> _fetchCustomers() async {
    // Early guard: if editing a saved order, do not override customer with defaults
    final currentOrder =
        Provider.of<LocalProductProvider>(context, listen: false).currentOrder;
    if (currentOrder != null) {
      debugPrint(
          "🛡️ Skipping default customer fetch because a saved order is being edited");
      return;
    }
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    debugPrint("🔍 _fetchCustomers() called");
    debugPrint(
        "  - _isCustomerManuallySelected: ${billingProvider.isCustomerManuallySelected}");
    debugPrint("  - selectedCustomerID: ${billingProvider.selectedCustomerID}");
    debugPrint("  - mobileNumberText: '${billingProvider.mobileNumberText}'");
    debugPrint(
        "  - mobileNumberTextController.text: '${billingProvider.mobileNumberTextController.text}'");

    // If customer was manually selected (either from list or phone entry), don't reset to default
    if (billingProvider.isCustomerManuallySelected &&
        (billingProvider.selectedCustomerID != null ||
            billingProvider.mobileNumberText?.isNotEmpty == true)) {
      debugPrint("🛡️ Customer manually selected, skipping reset to default");
      debugPrint(
          "  - selectedCustomerID: ${billingProvider.selectedCustomerID}");
      debugPrint("  - mobileNumberText: '${billingProvider.mobileNumberText}'");
      return;
    }

    // Additional check: if the text field contains user-entered data that's not the sales executive's info, preserve it
    if (billingProvider.mobileNumberTextController.text.isNotEmpty &&
        !billingProvider.mobileNumberTextController.text.contains(
            "${Provider.of<SalesExecutiveProvider>(context, listen: false).getCurrentUser(context)?.name ?? ''} ${Provider.of<SalesExecutiveProvider>(context, listen: false).getCurrentUser(context)?.phone ?? ''}")) {
      debugPrint("🛡️ Text field contains user data, preserving manual entry");
      debugPrint(
          "  - mobileNumberTextController.text: '${billingProvider.mobileNumberTextController.text}'");

      // Mark as manually selected and preserve the current state
      setState(() {
        billingProvider.setMobileNumberText(
            billingProvider.mobileNumberTextController.text);
      });
      return;
    }

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    try {
      final response = await CustomerProvider()
          .listCustomer(accessToken: accessToken!, sortAscending: true);

      if (response["status"] == "success") {
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setState(() {
          billingProvider.setCustomerList(
              customerListModel.data); // Store the customer list

          // Check if auto-assign is enabled in app settings
          final appSettingsProvider =
              Provider.of<AppSettingsProvider>(context, listen: false);
          final bool autoAssignEnabled =
              appSettingsProvider.appSettings?.autoAssignDefaultCustomer ??
                  false;

          if (!autoAssignEnabled) {
            debugPrint(
                "🔧 APP SETTINGS: Auto-assign default customer is DISABLED - only fetching customer list");
            return; // Exit early, only customer list is fetched
          }

          CustomerListModelData? defaultCustomer;

          if (billingProvider.customerList!.isNotEmpty) {
            // Get the default customer phone from app settings
            final defaultPhone = appSettingsProvider
                    .appSettings?.autoAssignDefaultCustomerPhone ??
                "";

            debugPrint(
                "🏢 BILLING: Setting up default customer from app settings phone");
            debugPrint("  - Default phone from settings: '$defaultPhone'");
            debugPrint(
                "  - Available customers in list: ${billingProvider.customerList!.length}");

            if (defaultPhone.isNotEmpty) {
              // Try to find customer by phone number
              try {
                defaultCustomer = billingProvider.customerList!.firstWhere(
                  (customer) => customer.phone == defaultPhone,
                );
                debugPrint(
                    "✅ Found customer by phone: ${defaultCustomer.name} (${defaultCustomer.phone})");

                debugPrint(
                    "🎯 Selected default customer: ${defaultCustomer.name} (${defaultCustomer.phone})");

                debugPrint("📝 SETTING DEFAULT CUSTOMER STATE:");
                billingProvider
                    .setMobileNumberText(defaultCustomer.phone ?? "");
                billingProvider.mobileNumberTextController.text =
                    "${defaultCustomer.name ?? ''} ${defaultCustomer.phone ?? ''}"
                        .trim();

                debugPrint(
                    "  - Set mobileNumberText: '${defaultCustomer.phone}'");
                debugPrint(
                    "  - Set mobileNumberTextController.text: '${billingProvider.mobileNumberTextController.text}'");

                // Set the default customer in the global provider and mark as default
                billingProvider.setSelectedCustomer(defaultCustomer,
                    isManual: false);
                debugPrint("✅ Default customer set:");
                debugPrint(
                    "  - selectedCustomerID: ${billingProvider.selectedCustomerID}");
                debugPrint(
                    "  - selectedCustomerPhone: ${billingProvider.selectedCustomerPhone}");
                debugPrint(
                    "  - selectedCustomer: ${billingProvider.selectedCustomer?.name}");
              } catch (e) {
                // Customer not found - just show the phone number from settings
                debugPrint(
                    "⚠️ No customer found with phone '$defaultPhone', using phone number only");

                debugPrint("📝 SETTING PHONE NUMBER ONLY (no customer found):");
                billingProvider.setMobileNumberText(defaultPhone);
                billingProvider.mobileNumberTextController.text = defaultPhone;

                // Clear any previous customer selection
                billingProvider.clearSelectedCustomer();

                debugPrint(
                    "  - Set mobileNumberTextController.text: '$defaultPhone'");
                debugPrint("  - Cleared selectedCustomer");
              }
            } else {
              debugPrint(
                  "⚠️ No default phone configured, leaving customer field empty");
              // Don't set any customer - leave the field empty
            }
          }
        });
      }
    } catch (error) {
      debugPrint('Error fetching customers: $error');
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

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // debugPrint('Focus gained');
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
        // debugPrint("Error handling key press: $e");
      }
    }
  }

  Future<void> processBarcode(String barcode) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    // If the input is empty, do nothing. Debounce & processing flags are handled by the provider.
    if (barcode.isEmpty) {
      return;
    }
    String query = barcode;

    List<GetProduct> filteredProducts = [];
    try {
      String? prefix;
      String? productCode;
      String? lastFive;

      if (query.length > 2) {
        prefix = query.substring(0, 3); // First 3 digits;
      }

      if (prefix != '000' || query.length != 14) {
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(
          barCode: query,
        );
      } else {
        productCode = query.substring(3, 9); // Next 6 digits
        lastFive = query.substring(9, 14); // Last 5 digits
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(
          barCode: productCode,
        );
      }

      if (filteredProducts.length > 1) {
        showScaffoldError(
          context: context,
          message:
              'Barcode $query matches ${filteredProducts.length} products. Fix the duplicate barcode before selling.',
        );
        return;
      }
      if (filteredProducts.isNotEmpty) {
        // Get the first product
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
        final multiSaleUnitEnabled =
            Provider.of<AppSettingsProvider>(context, listen: false)
                .multiSaleUnitEnabled;
        if (matchedSaleUnit != null && !multiSaleUnitEnabled) {
          showScaffoldError(
            context: context,
            message: 'Multi sale units are disabled for this store.',
          );
          return;
        }
        if ((product.unit == 'KGS' || product.unit == 'KG') &&
            prefix == '000' &&
            query.length == 14) {
          // Weight-based product
          String weightKg = lastFive!.substring(0, 2); // First 2 digits = KG
          String weightGrams =
              lastFive.substring(2, 5); // Last 3 digits = Grams
          quantity =
              double.parse(weightKg) + (double.parse(weightGrams) / 1000);
        } else if ((product.unit == 'PCS' || product.unit == 'PC') &&
            prefix == '000' &&
            query.length == 14) {
          // Count-based product
          quantity = int.parse(lastFive!); // Last 5 digits represent quantity
        } else if (matchedSaleUnit != null) {
          quantity =
              num.tryParse(matchedSaleUnit.conversionRate?.trim() ?? '') ?? 1;
        }

        // Use centralized helper for stock handling
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        debugPrint("🛒 BARCODE SCAN - Calling ProductCartHelper with:");
        debugPrint("  - Product: ${product.productName}");
        debugPrint("  - Quantity: $quantity");
        debugPrint("  - Customer ID: ${billingProvider.selectedCustomerID}");
        debugPrint(
            "  - Customer Name: ${billingProvider.selectedCustomer?.name}");

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
          addToCartDirectly: true,
          customerId: billingProvider.selectedCustomerID,
          customerName: billingProvider.selectedCustomer?.name,
          selectedSaleUnit: multiSaleUnitEnabled ? matchedSaleUnit : null,
          scannedBarcode: query,
        );

        // Clear input fields
        setState(() {
          _autocompleteProductKey = GlobalKey();
        });
        billingProvider.clearProductFieldsAndReset();
        _focusTextField();
      } else {
        // Set dialog state to open
        await showDialog(
          context: context,
          builder: (context) =>
              AddProductWithBarcodeModal(barcode: query, isAddToCart: true),
        );
        // Reset dialog state

        billingProvider.barcodeController.clear();
        _focusTextField();

        debugPrint("No products found for barcode: $query");
      }
    } catch (e) {
      debugPrint("Error adding item: $e");
      showScaffoldError(
        context: context,
        message: "Invalid Barcode. Please try again.",
      );
    } finally {
      // Processing state is managed by BillingProvider's debounce logic
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Quick fix: if we are editing an order and it hasn't been rehydrated after navigation, rehydrate now
    final currentOrder =
        Provider.of<LocalProductProvider>(context, listen: true).currentOrder;
    if (currentOrder != null && currentOrder.id != _lastRehydratedOrderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rehydrateFromProvider();
        }
      });
    }

    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    debugPrint("🔨 BillingPage build() called");
    debugPrint(
        "  - Current mobileNumberText: '${billingProvider.mobileNumberText}'");

    // Debug AppSettings during build
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    debugPrint("🎫 BUILD TIME APP SETTINGS:");
    debugPrint("  - appSettings: ${appSettingsProvider.appSettings}");
    if (appSettingsProvider.appSettings != null) {
      debugPrint(
          "  - discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}");
    }

    return SafeArea(
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: Scaffold(
          body: Stack(
            children: [
              // Main content
              Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content area
                    Expanded(
                      flex: _isSidebarVisible ? 3 : 4,
                      child: BuildBoxShadowContainer(
                        circleRadius: 10,
                        margin: const EdgeInsets.only(
                            left: 10, top: 10, bottom: 10, right: 10),
                        child: Form(
                          key: _formKey,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                HeaderBar(
                                  isSidebarVisible: _isSidebarVisible,
                                  onToggleSidebar: () {
                                    setState(() {
                                      _isSidebarVisible = !_isSidebarVisible;
                                    });
                                  },
                                ),
                                const Divider(thickness: 1),
                                ProductEntryHeader(
                                  size: size,
                                  barcodeController:
                                      billingProvider.barcodeController,
                                  quantityController:
                                      billingProvider.quantityController,
                                  unitPriceController:
                                      billingProvider.unitPriceController,
                                  selectedProductIdController: billingProvider
                                      .selectedProductIdController,
                                  productProvider: productProvider,
                                  autocompleteProductKey:
                                      _autocompleteProductKey,
                                  onProcessBarcode: (q) => processBarcode(q),
                                  onClearProductFields: () {
                                    setState(() {
                                      _autocompleteProductKey = GlobalKey();
                                      billingProvider.quantityController
                                          .clear();
                                      billingProvider.barcodeController.clear();
                                      billingProvider
                                          .selectedProductIdController
                                          .clear();
                                      billingProvider.unitPriceController
                                          .clear();
                                    });
                                  },
                                  focusTextField: _focusTextField,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Expanded(
                                        child: CartItemsTable(),
                                      ),
                                      const SizedBox(height: 5),
                                      // Always show minimized view with quick access icons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Customer selection
                                          Expanded(
                                            flex: 4,
                                            child: Container(
                                              color: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 10),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  CustomerInput(
                                                    size: size,
                                                    autocompletePhoneKey:
                                                        _autocompletePhoneKey,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  QuickAccessBar(
                                                    onShowPaymentMethodModal:
                                                        () => PaymentCoordinator
                                                            .showPaymentMethodModal(
                                                                context),
                                                    onShowDeliveryMethodModal:
                                                        () => PaymentCoordinator
                                                            .showDeliveryMethodModal(
                                                                context),
                                                    onShowCouponModal: () =>
                                                        PaymentCoordinator
                                                            .showCouponModal(
                                                                context),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Payment summary
                                          Expanded(
                                            flex: 4,
                                            child: Container(
                                              color: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 10),
                                              child: const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  PaymentSummary(compact: true),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ActionButtons(
                                        onClearCart: _clearCart,
                                        onSaveOrder: _saveOrder,
                                        onCreateOrderAndPrint:
                                            _createOrderAndPrint,
                                        onConfirmOrder: _confirmOrder,
                                        onSaveAndPrint: _saveOrderAndPrint,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Collapsible Sidebar
                    if (_isSidebarVisible)
                      Expanded(
                        flex: 1,
                        child: SidebarWidget(
                          selectedTab: _selectedSidebarTab,
                          onSelectTab: (i) {
                            setState(() {
                              _selectedSidebarTab = i;
                            });
                          },
                          onToggleSidebar: () {
                            setState(() {
                              _isSidebarVisible = !_isSidebarVisible;
                            });
                          },
                          onOrderSelected: _loadSavedOrderForEditing,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCart() {
    debugPrint("Clear Cart pressed");
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider
        .setLoadingClearCart(true); // Indicate that loading has started
    try {
      // Clear local cart
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();

      // Clear UI state
      setState(() {
        billingProvider.coupenCodeTextController.clear();
        billingProvider.transactionNumberController.clear();
        billingProvider.paidAmountController.clear();
        // Reset all payment methods and amounts
        billingProvider.clearAllPaymentMethods();
        _autocompleteProductKey = GlobalKey();
        billingProvider.clearProductFields();
        // Reset customer-credit toggle
        billingProvider.setToCustomerCreditEnabled(false);
        // Clear delivery date and time
        billingProvider.setDeliveryDate(null);
        billingProvider.setDeliveryTime(null);
        // Clear delivery comment and car number
        billingProvider.commentController.clear();
        billingProvider.carNumberController.clear();

        // Clear customer-related state completely
        billingProvider.setMobileNumberText("");
        billingProvider.mobileNumberTextController.clear();
        billingProvider.clearSelectedCustomer();
        // salesExecutivemobileNumberText now managed by provider
        _autocompletePhoneKey = GlobalKey();
      });
      showScaffold(
        context: context,
        message: "Cart Cleared Succesfully",
      );
      resetAutocomplete(
          shouldFetchCustomers:
              false); // Don't reset customer selection when clearing cart
      _focusTextField();
      _fetchCustomers();
    } catch (e) {
      debugPrint("Error clearing cart: $e");
      // showScaffold(
      //   context: context,
      //   message: "Cart Cleared Succesfully",
      // );
      showScaffoldError(
        context: context,
        message: "Failed to clear cart. Please try again.",
      );
    } finally {
      billingProvider.setLoadingClearCart(false);
    }
  }

  void _saveOrder() async {
    debugPrint("Save Order pressed");
    final service = CheckoutService(context);
    final result = await service.saveOrder();
    if (result == SaveOrderResult.updatedExisting) {
      // Updated existing order -> only clear cart (matches previous UX)
      _clearCart();
    } else if (result == SaveOrderResult.savedNew) {
      // New saved order -> reset and clear
      resetAutocomplete();
      _fetchCustomers();
      _clearCart();
    }
    // validationFailed / failed: service already showed error snackbar; do not
    // clear the workspace or cart.
  }

  void _saveOrderAndPrint() async {
    debugPrint("Save Order and Print pressed");
    final service = CheckoutService(context);
    final order = await service.saveOrderAndReturnConfirmed();
    if (order != null) {
      try {
        await const PrintService().printSavedOrder(context, order);
      } catch (error) {
        debugPrint("Error printing saved order: ${error.toString()}");
      }
    }
    resetAutocomplete();
    _fetchCustomers();
    _clearCart();
  }

  // Function to load a saved order for editing
  void _loadSavedOrderForEditing(String orderId) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Load the order into the provider's state
      localProductProvider.loadOrderForEditing(orderId);

      // Rehydrate the entire UI from the newly loaded order
      _rehydrateFromProvider();

      showScaffold(
        context: context,
        message: "Order loaded for editing",
      );
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "Failed to load order. Please try again.");
    }
  }

  void _createOrderAndPrint() async {
    // Delegate orchestration to CheckoutService and print by returned order number
    final createdOrderNumber =
        await CheckoutService(context).createOrderAndPrint();
    if (createdOrderNumber != null && createdOrderNumber.isNotEmpty) {
      try {
        await const PrintService()
            .printOrderByIdWithOptions(context, createdOrderNumber);
      } catch (error) {
        debugPrint("❌ Error fetching order details for print: $error");
      }
    } else {
      // If service didn't return an order number, we already showed an error toast in the service
    }
  }

  void _confirmOrder() async {
    // Preserve UX: if no payment selected, show modal here (service stays UI-agnostic)
    final selectedPaymentMethods =
        Provider.of<BillingProvider>(context, listen: false)
            .getSelectedPaymentMethodsExcludingEmpty();
    if (selectedPaymentMethods.isEmpty) {
      showScaffoldError(
        context: context,
        message: "Please select a payment method",
      );
      PaymentCoordinator.showPaymentMethodModal(context);
      return;
    }

    await CheckoutService(context).confirmOrder();
    _focusTextField();
  }

  void resetAutocomplete({bool shouldFetchCustomers = true}) {
    debugPrint(
        "🔄 resetAutocomplete called - shouldFetchCustomers: $shouldFetchCustomers");
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    debugPrint(
        "  - _isCustomerManuallySelected: ${billingProvider.isCustomerManuallySelected}");
    debugPrint("  - mobileNumberText: '${billingProvider.mobileNumberText}'");
    debugPrint(
        "  - mobileNumberTextController.text: '${billingProvider.mobileNumberTextController.text}'");

    setState(() {
      _autocompleteProductKey = GlobalKey();

      // Only fetch customers if requested AND no customer was manually selected
      if (shouldFetchCustomers && !billingProvider.isCustomerManuallySelected) {
        debugPrint(
            "  - Calling _fetchCustomers() because no manual selection detected");
        _fetchCustomers();
      } else if (shouldFetchCustomers &&
          billingProvider.isCustomerManuallySelected) {
        debugPrint(
            "  - Skipping _fetchCustomers() because customer was manually selected");
      }

      _setDefaultDeliveryMethod(
        Provider.of<BillingProvider>(context, listen: false),
      );
      // Remove iconColor reset
      // iconColor = 1; // DELETE THIS LINE
    });
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  // Removed unused _scrollToHighlightedCustomer; provider handles scrolling

  // Function to handle sales executive changes
  void _onSalesExecutiveChanged() {
    debugPrint(
        "🔄 BILLING: Sales executive changed, updating default customer...");

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    // Check if auto-assign is enabled in app settings
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final bool autoAssignEnabled =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomer ?? true;

    if (!autoAssignEnabled) {
      debugPrint(
          "🔧 APP SETTINGS: Auto-assign default customer is DISABLED, skipping sales executive change");
      return;
    }

    // Don't reset if customer was manually selected (either from list or phone entry)
    if (billingProvider.isCustomerManuallySelected &&
        (billingProvider.selectedCustomerID != null ||
            (billingProvider.mobileNumberText?.isNotEmpty ?? false))) {
      debugPrint("🛡️ Customer manually selected, skipping reset");
      debugPrint(
          "  - selectedCustomerID: ${billingProvider.selectedCustomerID}");
      debugPrint("  - mobileNumberText: '${billingProvider.mobileNumberText}'");
      return;
    }

    // Clear current customer selection
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    // Reset billing page customer state
    setState(() {
      billingProvider.setMobileNumberText("");
      billingProvider.clearSelectedCustomer();
      // salesExecutivemobileNumberText now managed by provider
      billingProvider.mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey(); // Reset autocomplete
    });

    // Re-fetch customers to set new default based on new executive
    _fetchCustomers();
  }

  // Public method to reset to default sales executive (for external calls)
  void resetToDefaultSalesExecutive() {
    debugPrint(
        "🔄 BILLING: Public method called - resetting to default sales executive...");

    // Clear the current order being edited
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.clearCurrentOrder();

    // Reset all form fields
    setState(() {
      // Clear payment and delivery states
      // iconColor = 1; // Default to cash
      _setDefaultDeliveryMethod(
        Provider.of<BillingProvider>(context, listen: false),
      );

      // Clear all controllers
      final bp = Provider.of<BillingProvider>(context, listen: false);
      bp.coupenCodeTextController.clear();
      bp.transactionNumberController.clear();
      bp.paidAmountController.clear();
      bp.carNumberController.clear();
      bp.commentController.clear();

      bp.setDeliveryDate(null);
      bp.setDeliveryTime(null);

      // Reset other flags
      // Coupon applied state managed by provider
      // balance managed by provider

      // Clear product entry fields
      bp.clearProductFields();

      // Reset autocomplete keys
      _autocompletePhoneKey = GlobalKey();
      _autocompleteProductKey = GlobalKey();
    });

    _onSalesExecutiveChanged();
    resetAutocomplete();
  }

  // Public method to save current order (for external calls)
  void saveCurrentOrder() {
    debugPrint("===== PUBLIC SAVE CURRENT ORDER START =====");
    debugPrint("💾 BILLING: Public method called - saving current order...");
    debugPrint("📝 Current customer state:");
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    debugPrint("  - mobileNumberText: '${billingProvider.mobileNumberText}'");
    debugPrint(
        "  - mobileNumberTextController.text: '${billingProvider.mobileNumberTextController.text}'");
    debugPrint("  - selectedCustomerID: ${billingProvider.selectedCustomerID}");
    debugPrint(
        "  - selectedCustomerPhone: '${billingProvider.selectedCustomerPhone}'");
    debugPrint(
        "  - selectedCustomer?.name: '${billingProvider.selectedCustomer?.name}'");
    debugPrint("  - isCustomerFound: ${billingProvider.isCustomerFound}");
    debugPrint(
        "  - Delivery Method: ${billingProvider.deliveryMethod} (ID: ${billingProvider.deliveryMethodId})");
    debugPrint("  - Comment: '${billingProvider.commentController.text}'");
    debugPrint(
        "  - Cart Items: ${Provider.of<LocalProductProvider>(context, listen: false).cartItems.length}");
    _saveOrder();
    debugPrint("===== PUBLIC SAVE CURRENT ORDER END =====");
  }
}
