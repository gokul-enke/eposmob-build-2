import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/horizontal_saved_orders_view.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:pos_machine/widgets/live_clock.dart';
import 'package:provider/provider.dart';

import 'package:websafe_svg/websafe_svg.dart';

// Import modals
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:pos_machine/screens/billing/widgets/delivery_method_modal.dart';
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/price_fields.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => BillingPageState();
}

class BillingPageState extends State<BillingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final FocusNode _paidAmountFocusNode = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  // Flag to track if user has manually changed the paid amount

  String? mobileNumberText = "";
  String? salesExecutivemobileNumberText = "";
  int? selectedCustomerID;
  String? selectedCustomerPhone;
  CartProvider cartProvider = CartProvider();
  String deliveryMethod = "";
  String deliveryMethodId = "";
  double _balanceAmount = 0;
  UniqueKey keyTile = UniqueKey();

  // Multi-payment method controllers
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final TextEditingController _upiAmountController = TextEditingController();
  final TextEditingController _codAmountController = TextEditingController();
  final TextEditingController _debitAmountController = TextEditingController();
  final FocusNode _cashAmountFocusNode = FocusNode();
  final FocusNode _cardAmountFocusNode = FocusNode();
  final FocusNode _upiAmountFocusNode = FocusNode();
  final FocusNode _codAmountFocusNode = FocusNode();
  final FocusNode _debitAmountFocusNode = FocusNode();

  // Payment method selection states
  bool _isCashSelected = false;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  bool _isCodSelected = false;
  bool _isDebitSelected = false;
  bool _hasOpenedPaymentModalOnce = false;
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;
  List<ListCartModelDataCartItem>? cartProductItems = [];
  Map<String, num> taxNames = {};
  Map<int, bool> hoverMap = {};
  TextEditingController barcodeController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController selectedProductIdController = TextEditingController();
  TextEditingController selectedProductNameController = TextEditingController();

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();

  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _unitPriceFocusNode = FocusNode();

  bool isCustomerFound = false;
  bool isCouponApplied = false;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _barcodeNode = FocusNode();

  bool isLoadingClearCart = false;
  bool isLoadingSaveOrder = false;
  bool isLoadingCreateOrder = false;
  bool isLoadingConfirmOrder = false;
  bool isLoadingSaveOrderAndPrint = false;
  bool isLoadingAddItem = false;
  bool _isProcessingBarcode = false;
  bool _toCustomerCreditEnabled = false;

  // Add these variables for the new sidebar
  bool _isSidebarVisible = true;
  int _selectedSidebarTab =
      1; // 0 for products, 1 for orders/categories - default to orders tab

  Timer? _debounceTimer;

  // Add these variables for keyboard navigation in customer list
  int? _highlightedCustomerIndex;
  final FocusNode _customerTextFieldFocus = FocusNode();
  FocusNode?
      _autocompleteFocusNode; // Store reference to Autocomplete's focusNode
  TextEditingController?
      _autocompleteController; // Store reference to Autocomplete's controller
  final ScrollController _customerScrollController = ScrollController();
  List<CustomerListModelData> _currentCustomerOptions = [];
  final double _customerItemHeight = 48.0; // Height for customer list items

  // Add this variable to track internet connectivity
  bool _hasInternet = true;
  StreamSubscription? _internetSubscription;

  // Add flag to track if customer was manually selected
  bool _isCustomerManuallySelected = false;

  StreamSubscription<String>? _barcodeSubscription;

  String? deliveryDate;
  String? deliveryTime;
  String? deliveryAddress;

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
    _paidAmountFocusNode
        .addListener(_handlePaidAmountFocusChange); // Add this line

    // Debug logging for AppSettings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      debugPrint('🎫 APP SETTINGS INIT DEBUG:');
      debugPrint('  - appSettingsProvider: $appSettingsProvider');
      debugPrint('  - appSettings: ${appSettingsProvider.appSettings}');
      if (appSettingsProvider.appSettings != null) {
        debugPrint(
            '  - discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}');
        debugPrint(
            '  - All settings: ${appSettingsProvider.appSettings.toString()}');
      }
    });

    // Initialize with dynamic default delivery method
    _initializeDeliveryMethod();
    _initializePaymentMethod();

    // Initialize multi-payment with no defaults - let user select manually
    _isCashSelected = false;
    _isCardSelected = false;
    _isUpiSelected = false;
    _isDebitSelected = false;
    _isCodSelected = false;

    _fetchCustomers();

    // After first frame, rehydrate UI from any saved order/discounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rehydrateFromProvider();
    });

    _quantityFocusNode.addListener(() {
      if (_quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    _unitPriceFocusNode.addListener(() {
      if (_unitPriceFocusNode.hasFocus) {
        unitPriceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: unitPriceController.text.length,
        );
      }
    });

    // Initialize internet connectivity listener
    _initConnectivityListener();

    // Listen to the barcode stream
    final barcodeProvider =
        Provider.of<BarcodeProvider>(context, listen: false);
    debugPrint("🟡 [BillingPage] Setting up barcode stream listener...");
    _barcodeSubscription = barcodeProvider.barcodeStream.listen((barcode) {
      debugPrint(
          "🟡 [BillingPage] ========== BARCODE STREAM RECEIVED ==========");
      debugPrint("🟡 [BillingPage] Barcode from stream: '$barcode'");
      debugPrint("🟡 [BillingPage] Widget mounted: $mounted");
      if (mounted) {
        debugPrint("🟡 [BillingPage] Calling processBarcode()...");
        processBarcode(barcode);
      } else {
        debugPrint(
            "⚠️ [BillingPage] Widget not mounted - skipping processBarcode");
      }
      debugPrint(
          "🟡 [BillingPage] =============================================\n");
    });
    debugPrint("🟡 [BillingPage] Barcode stream listener setup complete");

    // Listen for sales executive changes to update default customer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider.addListener(_onSalesExecutiveChanged);

      // Also listen for auth changes (more direct indicator of user switch)
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(_onUserSwitched);

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

      // Listen for cart changes to reset payment modal flag
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.addListener(_onCartChanged);
    });

    // Ensure UI updates when virtual keyboard edits the customer phone field
    mobileNumberTextController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _fetchCustomers();
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    barcodeController.dispose();
    mobileNumberTextController.dispose();
    coupenCodeTextController.dispose();
    _transactionNumberController.dispose();
    _paidAmountController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    selectedProductIdController.dispose();
    _focusNode.dispose();
    _barcodeNode.dispose();

    // Dispose all the focus nodes
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();
    _paidAmountFocusNode.dispose();

    // Dispose multi-payment controllers and focus nodes
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _upiAmountController.dispose();
    _codAmountController.dispose();
    _debitAmountController.dispose();
    _cashAmountFocusNode.dispose();
    _cardAmountFocusNode.dispose();
    _upiAmountFocusNode.dispose();
    _codAmountFocusNode.dispose();
    _debitAmountFocusNode.dispose();

    _debounceTimer?.cancel();
    _customerTextFieldFocus.dispose();
    _customerScrollController.dispose();
    _internetSubscription?.cancel(); // Cancel the subscription

    // Remove sales executive listener
    try {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider.removeListener(_onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.removeListener(_onUserSwitched);

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.removeListener(_onCartChanged);
    } catch (e) {
      debugPrint("Error removing listeners: $e");
    }

    super.dispose();
  }

  void _handlePaidAmountFocusChange() {
    if (_paidAmountFocusNode.hasFocus) {
      _paidAmountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _paidAmountController.text.length,
      );
    }
    // We don't necessarily need to do anything here, just having the listener
    // attached allows us to check focus state later.
    // debugPrint('Paid Amount field focus: ${_paidAmountFocusNode.hasFocus}');
  }

  void _onCartChanged() {
    if (_hasOpenedPaymentModalOnce && mounted) {
      debugPrint("🛒 Cart changed - Resetting payment modal flag");
      setState(() {
        _hasOpenedPaymentModalOnce = false;
      });
    }
  }

  // Function to initialize the connectivity listener
  void _initConnectivityListener() async {
    try {
      // Check initial connectivity status
      final hasConnection = await InternetConnection().hasInternetAccess;
      if (mounted) {
        setState(() {
          _hasInternet = hasConnection;
        });
      }

      // Listen for connectivity changes
      _internetSubscription =
          InternetConnection().onStatusChange.listen((InternetStatus status) {
        final isConnected = status == InternetStatus.connected;
        if (mounted) {
          setState(() {
            _hasInternet = isConnected;
          });

          // Optional: Show feedback when connectivity changes
          if (!isConnected) {
            showScaffoldError(
              context: context,
              message: 'billing.internet_lost'.tr,
            );
          } else {
            showScaffold(
              context: context,
              message: 'billing.internet_restored'.tr,
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing connectivity listener: $e');
      // Fallback to assuming connection is available
      if (mounted) {
        setState(() {
          _hasInternet = true;
        });
      }
    }
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
            isCouponApplied = true;
          } else {
            isCouponApplied = false;
          }
        });
        return;
      }

      // Start full UI state restoration
      setState(() {
        // 1. Restore Customer Information
        // Clear existing state first to prevent contamination
        selectedCustomerID = null;
        selectedCustomerPhone = null;
        selectedCustomer = null;
        isCustomerFound = false;
        mobileNumberTextController.clear();
        Provider.of<CustomerSelectionProvider>(context, listen: false)
            .clearSelectedCustomer();

        // Check if there is any customer data to restore
        if (currentOrder.customerId != null ||
            (currentOrder.customerPhone != null &&
                currentOrder.customerPhone!.isNotEmpty)) {
          selectedCustomerID = currentOrder.customerId;
          selectedCustomerPhone = currentOrder.customerPhone;

          // Try to find the customer in the main list if an ID exists
          if (currentOrder.customerId != null && customerList != null) {
            try {
              selectedCustomer = customerList!
                  .firstWhere((c) => c.id == currentOrder.customerId);
            } catch (e) {
              // Not found in list, will create a virtual one next.
            }
          }

          // If not found in the list or if it's a phone-only order,
          // create a 'virtual' customer object from the order data.
          if (selectedCustomer == null) {
            selectedCustomer = CustomerListModelData(
              id: currentOrder.customerId,
              name: currentOrder.customerName,
              phone: currentOrder.customerPhone,
            );
          }

          // Now, with a guaranteed selectedCustomer object, update the UI
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .setSelectedCustomer(selectedCustomer!);

          // **FIX**: Properly restore customer display based on whether it's a phone-only order
          if (selectedCustomer!.id != null &&
              (selectedCustomer!.name != null &&
                  selectedCustomer!.name!.isNotEmpty)) {
            // Customer from list - show name and phone
            String name = selectedCustomer!.name ?? '';
            String phone = selectedCustomer!.phone ?? '';
            mobileNumberTextController.text = "$name $phone".trim();
            mobileNumberText = "$name $phone"
                .trim(); // Fix: Set mobileNumberText for Autocomplete initialValue
            isCustomerFound = true;
          } else {
            // Phone-only order - show just the phone number
            mobileNumberTextController.text = selectedCustomer!.phone ?? '';
            mobileNumberText = selectedCustomer!.phone ?? '';
            isCustomerFound = false;
          }

          _isCustomerManuallySelected = true;
        }

        // 2. Restore Payment Methods
        // Reset all payment state first
        _isCashSelected = false;
        _isCardSelected = false;
        _isUpiSelected = false;
        _isDebitSelected = false;
        _isCodSelected = false;
        _cashAmountController.clear();
        _cardAmountController.clear();
        _upiAmountController.clear();
        _codAmountController.clear();
        _debitAmountController.clear();

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
                  _isCashSelected = true;
                  _cashAmountController.text =
                      (amounts['CASH'] ?? '0').toString();
                }
                if (methods.contains('CARD')) {
                  _isCardSelected = true;
                  _cardAmountController.text =
                      (amounts['CARD'] ?? '0').toString();
                }
                if (methods.contains('UPI')) {
                  _isUpiSelected = true;
                  _upiAmountController.text =
                      (amounts['UPI'] ?? '0').toString();
                }
                if (methods.contains('DEBIT')) {
                  _isDebitSelected = true;
                  _debitAmountController.text =
                      (amounts['DEBIT'] ?? '0').toString();
                }
                if (methods.contains('COD')) {
                  _isCodSelected = true;
                  _codAmountController.text =
                      (amounts['COD'] ?? '0').toString();
                }
              }
            } catch (e) {
              debugPrint("Error parsing payment JSON on rehydration: $e");
            }
          } else {
            // Single method
            _isCashSelected = pm.toUpperCase() == 'CASH';
            _isCardSelected = pm.toUpperCase() == 'CARD';
            _isUpiSelected = pm.toUpperCase() == 'UPI';
            _isDebitSelected = pm.toUpperCase() == 'DEBIT';
            _isCodSelected = pm.toUpperCase() == 'COD';

            final paid = currentOrder.paidAmount ?? '0.0';
            if (_isCashSelected) _cashAmountController.text = paid;
            if (_isCardSelected) _cardAmountController.text = paid;
            if (_isUpiSelected) _upiAmountController.text = paid;
            if (_isCodSelected) _codAmountController.text = paid;
            if (_isDebitSelected) _debitAmountController.text = paid;
          }
        }

        // 3. Restore Main Payment Amounts
        _paidAmountController.text = currentOrder.paidAmount ?? "0.0";
        _balanceAmount =
            double.tryParse(currentOrder.balanceAmount ?? "0.0") ?? 0.0;

        // 4. Restore Transaction, Delivery, and Other Details
        _transactionNumberController.text = currentOrder.transactionId ?? "";
        deliveryMethod =
            currentOrder.deliveryMethod ?? "billing.store_takeaway".tr;
        deliveryMethodId =
            currentOrder.deliveryMethodId ?? _getDefaultDeliveryMethodId();
        _commentController.text = currentOrder.comment ?? "";
        _carNumberController.text = currentOrder.carNumber ?? "";
        deliveryDate = currentOrder.deliveryDate;
        deliveryTime = currentOrder.deliveryTime;
        deliveryAddress = currentOrder.address; // Restore address

        // 5. Restore Coupon State
        if ((currentOrder.couponId != null &&
                currentOrder.couponId!.isNotEmpty) ||
            (currentOrder.flatDiscount != null &&
                currentOrder.flatDiscount! > 0) ||
            (currentOrder.percentageDiscount != null &&
                currentOrder.percentageDiscount! > 0)) {
          coupenCodeTextController.text = currentOrder.couponId ?? "";
          isCouponApplied = true;
        } else {
          coupenCodeTextController.clear();
          isCouponApplied = false;
        }

        // 6. Restore To Customer Credit flag
        _toCustomerCreditEnabled = currentOrder.toCustomerCredit ?? false;
      });

      // 7. Final UI Updates
      _updateBalanceAmount();
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
    debugPrint("🔍 _fetchCustomers() called");
    debugPrint("  - _isCustomerManuallySelected: $_isCustomerManuallySelected");
    debugPrint("  - selectedCustomerID: $selectedCustomerID");
    debugPrint("  - mobileNumberText: '$mobileNumberText'");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

    // If customer was manually selected (either from list or phone entry), don't reset to default
    if (_isCustomerManuallySelected &&
        (selectedCustomerID != null || mobileNumberText?.isNotEmpty == true)) {
      debugPrint("🛡️ Customer manually selected, skipping reset to default");
      debugPrint("  - selectedCustomerID: $selectedCustomerID");
      debugPrint("  - mobileNumberText: '$mobileNumberText'");
      return;
    }

    // Additional check: if the text field contains user-entered data that's not the sales executive's info, preserve it
    if (mobileNumberTextController.text.isNotEmpty &&
        !mobileNumberTextController.text.contains(
            "${Provider.of<SalesExecutiveProvider>(context, listen: false).getCurrentUser(context)?.name ?? ''} ${Provider.of<SalesExecutiveProvider>(context, listen: false).getCurrentUser(context)?.phone ?? ''}")) {
      debugPrint("🛡️ Text field contains user data, preserving manual entry");
      debugPrint(
          "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

      // Mark as manually selected and preserve the current state
      setState(() {
        _isCustomerManuallySelected = true;
        if (mobileNumberText?.isEmpty == true) {
          mobileNumberText = mobileNumberTextController.text;
        }
      });
      return;
    }

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    try {
      final response = await CustomerProvider().listCustomer(
          accessToken: accessToken!, sortAscending: true, loadAll: true);

      if (response["status"] == "success") {
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setState(() {
          customerList = customerListModel.data; // Store the customer list

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

          if (customerList!.isNotEmpty) {
            // Get the default customer phone from app settings
            final defaultPhone = appSettingsProvider
                    .appSettings?.autoAssignDefaultCustomerPhone ??
                "";

            debugPrint(
                "🏢 BILLING: Setting up default customer from app settings phone");
            debugPrint("  - Default phone from settings: '$defaultPhone'");
            debugPrint(
                "  - Available customers in list: ${customerList!.length}");
            // Debug: print first 5 customer phones for comparison
            debugPrint("  - First 5 customer phones in list:");
            for (int i = 0; i < customerList!.length && i < 5; i++) {
              debugPrint(
                  "    [$i] ${customerList![i].name}: '${customerList![i].phone}'");
            }

            if (defaultPhone.isNotEmpty) {
              // Try to find customer by phone number
              try {
                defaultCustomer = customerList!.firstWhere(
                  (customer) => customer.phone == defaultPhone,
                );
                debugPrint(
                    "✅ Found customer by phone: ${defaultCustomer.name} (${defaultCustomer.phone})");

                debugPrint(
                    "🎯 Selected default customer: ${defaultCustomer.name} (${defaultCustomer.phone})");

                debugPrint("📝 SETTING DEFAULT CUSTOMER STATE:");
                salesExecutivemobileNumberText = defaultCustomer.phone ?? "";
                mobileNumberText = defaultCustomer.phone ?? "";
                mobileNumberTextController.text =
                    "${defaultCustomer.name ?? ''} ${defaultCustomer.phone ?? ''}"
                        .trim();

                debugPrint(
                    "  - Set salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
                debugPrint("  - Set mobileNumberText: '$mobileNumberText'");
                debugPrint(
                    "  - Set mobileNumberTextController.text: '${mobileNumberTextController.text}'");

                // Set the default customer in the global provider and mark as default
                Provider.of<CustomerSelectionProvider>(context, listen: false)
                    .setSelectedCustomer(defaultCustomer, isDefault: true);

                selectedCustomerID = defaultCustomer.id;
                selectedCustomerPhone = defaultCustomer.phone;
                selectedCustomer = defaultCustomer;

                debugPrint("  - Set selectedCustomerID: $selectedCustomerID");
                debugPrint(
                    "  - Set selectedCustomerPhone: $selectedCustomerPhone");
                debugPrint(
                    "  - Set selectedCustomer: ${selectedCustomer?.name}");
              } catch (e) {
                // Customer not found - just show the phone number from settings
                debugPrint(
                    "⚠️ No customer found with phone '$defaultPhone', using phone number only");

                debugPrint("📝 SETTING PHONE NUMBER ONLY (no customer found):");
                salesExecutivemobileNumberText = defaultPhone;
                mobileNumberText = defaultPhone;
                mobileNumberTextController.text = defaultPhone;

                // Clear any previous customer selection
                selectedCustomerID = null;
                selectedCustomerPhone = defaultPhone;
                selectedCustomer = null;

                // Clear the provider selection
                Provider.of<CustomerSelectionProvider>(context, listen: false)
                    .clearSelectedCustomer();

                debugPrint(
                    "  - Set mobileNumberTextController.text: '$defaultPhone'");
                debugPrint("  - Cleared selectedCustomerID");
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
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Provider.of<CustomerProvider>(context, listen: false)
        .loadAllCustomers(accessToken!);
    // debugPrint("Focusing Text Field");
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings!.barcodeSales) {
      FocusScope.of(context).requestFocus(_barcodeNode);
    } else {}
    selectedProductNameController.clear();
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
        if (event.logicalKey == LogicalKeyboardKey.f6) {
          _clearCart();
        } else if (event.logicalKey == LogicalKeyboardKey.f7) {
          _saveOrder();
        } else if (event.logicalKey == LogicalKeyboardKey.f8) {
          _createOrderAndPrint();
        } else if (event.logicalKey == LogicalKeyboardKey.f9) {
          _confirmOrder();
        }
      } catch (e) {
        // debugPrint("Error handling key press: $e");
      }
    }
  }

  Future<void> processBarcode(String barcode) async {
    debugPrint(
        "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE START ==========");
    debugPrint("🔴 [BillingPage.processBarcode] Input barcode: '$barcode'");
    debugPrint(
        "🔴 [BillingPage.processBarcode] Barcode length: ${barcode.length}");
    debugPrint(
        "🔴 [BillingPage.processBarcode] _isProcessingBarcode: $_isProcessingBarcode");
    debugPrint(
        "🔴 [BillingPage.processBarcode] barcode.isEmpty: ${barcode.isEmpty}");

    // If a barcode is already being processed, or if the input is empty, do nothing.
    if (_isProcessingBarcode || barcode.isEmpty) {
      debugPrint(
          "⚠️ [BillingPage.processBarcode] SKIPPING - Already processing or empty barcode");
      debugPrint(
          "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE END (SKIPPED) ==========\n");
      return;
    }

    debugPrint("✅ [BillingPage.processBarcode] Starting barcode processing...");
    // Set the flag to true to prevent duplicate processing.
    setState(() {
      _isProcessingBarcode = true;
    });
    debugPrint(
        "🔴 [BillingPage.processBarcode] _isProcessingBarcode set to true");
    String query = barcode;

    List<GetProduct> filteredProducts = [];
    try {
      debugPrint("🔴 [BillingPage.processBarcode] Parsing barcode...");
      String? prefix;
      String? productCode;
      String? lastFive;

      if (query.length > 2) {
        prefix = query.substring(0, 3); // First 3 digits;
        debugPrint("🔴 [BillingPage.processBarcode] Prefix: $prefix");
      }

      if (prefix != '000' || query.length != 14) {
        debugPrint(
            "🔴 [BillingPage.processBarcode] Standard barcode - searching by: '$query'");
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(
          barCode: query,
        );
      } else {
        productCode = query.substring(3, 9); // Next 6 digits
        lastFive = query.substring(9, 14); // Last 5 digits
        debugPrint(
            "🔴 [BillingPage.processBarcode] Weight/Count barcode - productCode: $productCode, lastFive: $lastFive");
        filteredProducts =
            Provider.of<LocalProductProvider>(context, listen: false)
                .filterProductByBarcode(
          barCode: productCode,
        );
      }

      debugPrint(
          "🔴 [BillingPage.processBarcode] Products found: ${filteredProducts.length}");
      if (filteredProducts.isNotEmpty) {
        debugPrint(
            "🔴 [BillingPage.processBarcode] First product: ${filteredProducts.first.productName}");
        // Get the first product
        GetProduct product = filteredProducts.first;

        num? quantity;
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
        }

        // Use centralized helper for stock handling
        debugPrint(
            "🔴 [BillingPage.processBarcode] 🛒 Calling ProductCartHelper with:");
        debugPrint(
            "🔴 [BillingPage.processBarcode]   - Product: ${product.productName}");
        debugPrint("🔴 [BillingPage.processBarcode]   - Quantity: $quantity");
        debugPrint(
            "🔴 [BillingPage.processBarcode]   - Customer ID: $selectedCustomerID");
        debugPrint(
            "🔴 [BillingPage.processBarcode]   - Customer Name: ${selectedCustomer?.name}");

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
          addToCartDirectly: true,
          customerId: selectedCustomerID,
          customerName: selectedCustomer?.name,
        );

        debugPrint(
            "✅ [BillingPage.processBarcode] Product added to cart successfully");

        // Clear input fields
        debugPrint("🔴 [BillingPage.processBarcode] Clearing input fields...");
        setState(() {
          _autocompleteProductKey = GlobalKey();
          quantityController.clear();
          barcodeController.clear();
          selectedProductIdController.clear();
          unitPriceController.clear();
        });
        debugPrint("🔴 [BillingPage.processBarcode] Input fields cleared");
        _focusTextField();
        debugPrint("🔴 [BillingPage.processBarcode] Focus reset");
      } else {
        debugPrint(
            "⚠️ [BillingPage.processBarcode] No products found for barcode: '$query'");
        // Set dialog state to open
        await showDialog(
          context: context,
          builder: (context) =>
              AddProductWithBarcodeModal(barcode: query, isAddToCart: true),
        );
        // Reset dialog state - wrap in setState to trigger UI rebuild
        setState(() {
          barcodeController.clear();
        });
        _focusTextField();

        debugPrint(
            "🔴 [BillingPage.processBarcode] No products found for barcode: '$query'");
      }
    } catch (e) {
      debugPrint("❌ [BillingPage.processBarcode] ERROR: $e");
      debugPrint(
          "❌ [BillingPage.processBarcode] Stack trace: ${StackTrace.current}");
      showScaffoldError(
        context: context,
        message: "billing.invalid_barcode".tr,
      );
      // Clear barcode on error too
      setState(() {
        barcodeController.clear();
      });
      debugPrint("🔴 [BillingPage.processBarcode] Barcode cleared after error");
    } finally {
      debugPrint(
          "🔴 [BillingPage.processBarcode] Finally block - resetting processing flag...");
      // Reset the flag and ensure barcode is always cleared
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) {
          debugPrint(
              "🔴 [BillingPage.processBarcode] Resetting _isProcessingBarcode to false");
          setState(() {
            _isProcessingBarcode = false;
            // Ensure barcode is always cleared
            barcodeController.clear();
          });
          debugPrint(
              "🔴 [BillingPage.processBarcode] Processing complete - ready for next scan");
        }
      });
      debugPrint(
          "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE END ==========\n");
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

    debugPrint("🔨 BillingPage build() called");
    debugPrint(
        "  - Current salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");

    // Debug AppSettings during build
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    debugPrint("🎫 BUILD TIME APP SETTINGS:");
    debugPrint("  - appSettings: ${appSettingsProvider.appSettings}");
    if (appSettingsProvider.appSettings != null) {
      debugPrint(
          "  - discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}");
    }

    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);

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
                                _buildHeader(),
                                const Divider(thickness: 1),
                                _buildOrderHeader(
                                  size: size,
                                  barcodeController: barcodeController,
                                  quantityController: quantityController,
                                  unitPriceController: unitPriceController,
                                  selectedProductIdController:
                                      selectedProductIdController,
                                  productProvider: productProvider,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: _buildCartItemsTable(size),
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
                                                  _buildMobileNumberInput(
                                                      size: size,
                                                      mobileNumberTextController:
                                                          mobileNumberTextController),
                                                  const SizedBox(height: 10),
                                                  _buildQuickAccessIcons(),
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
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  _buildPaymentSummary(
                                                      compact: true),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildActionButtons(),
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
                        child: _buildSidebar(),
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

  Widget _buildSidebar() {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
      child: Stack(
        children: [
          Column(
            children: [
              // Tab headers with improved design
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSidebarTab = 0;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _selectedSidebarTab == 0
                                ? ColorManager.kPrimaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'billing.products'.tr,
                                style: TextStyle(
                                  color: _selectedSidebarTab == 0
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSidebarTab = 1;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _selectedSidebarTab == 1
                                ? ColorManager.kPrimaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'billing.orders'.tr,
                                style: TextStyle(
                                  color: _selectedSidebarTab == 1
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 50), // Space for toggle button
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: Container(
                  child: _selectedSidebarTab == 0
                      ? const SideBarProductList()
                      : _buildOrdersTab(),
                ),
              ),
            ],
          ),

          // Toggle button positioned at top-right
          Positioned(
            top: 10,
            right: 8,
            child: CustomRoundButton(
              title: "×",
              fct: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
              fontSize: 18,
              height: 35,
              width: 35,
              boxColor: ColorManager.kPrimaryColor,
              borderColor: ColorManager.kPrimaryColor,
              textColor: Colors.white,
              radius: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Saved Orders section with improved header
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        //   child: const Row(
        //     children: [
        //       Icon(
        //         Icons.bookmark_outline,
        //         size: 16,
        //         color: ColorManager.kPrimaryColor,
        //       ),
        //       SizedBox(width: 6),
        //       Text(
        //         'Saved Orders',
        //         style: TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w600,
        //           color: ColorManager.kPrimaryColor,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        // HorizontalSavedOrdersView in grid format
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: HorizontalSavedOrdersView(
              onOrderSelected: (orderId) {
                // Get the local provider
                final localProductProvider =
                    Provider.of<LocalProductProvider>(context, listen: false);

                // If we're editing an order and there are items in the cart, update that order
                if (localProductProvider.currentOrder != null &&
                    localProductProvider.cartItems.isNotEmpty) {
                  try {
                    // Update the current order being edited
                    localProductProvider.updateSavedOrder(
                      localProductProvider.currentOrder!.id,
                      customerName: selectedCustomer?.name,
                      customerPhone: selectedCustomerPhone ?? mobileNumberText,
                      comment: _commentController.text,
                      deliveryMethod: deliveryMethod,
                      deliveryDate: deliveryDate, // Pass deliveryDate
                      deliveryTime: deliveryTime, // Pass deliveryTime
                    );

                    // Show quick feedback
                    showScaffold(
                      context: context,
                      message: "billing.order_updated".tr,
                    );
                  } catch (e) {
                    debugPrint("Error updating current order: $e");
                  }
                } // If cart has items, save as new order
                else if (localProductProvider.cartItems.isNotEmpty) {
                  try {
                    localProductProvider.saveCurrentCartAsOrder(
                      deliveryDate: deliveryDate, // Pass deliveryDate
                      deliveryTime: deliveryTime, // Pass deliveryTime
                    );
                    showScaffold(
                      context: context,
                      message: "billing.order_saved".tr,
                    );
                  } catch (e) {
                    // Swallow exception if cart is empty
                  }
                }

                // Now load the selected order
                _loadSavedOrderForEditing(orderId);
              },
            ),
          ),
        ),

        // Divider with improved styling
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.shade300,
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Quick Access section with improved header

        // HorizontalProductViewLocal in grid format
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const HorizontalProductViewLocal(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final bool isEditingOrder = localProductProvider.currentOrder != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              isEditingOrder
                  ? '${'billing.edit_order'.tr} - '
                  : '${'billing.new_order'.tr} - ',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            Text(
              isEditingOrder
                  ? '#${localProductProvider.currentOrder!.orderNumber}'
                  : '#00000',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
          ],
        ),
        Row(
          children: [
            // Live Clock
            const LiveClock(),
            const SizedBox(width: 12),
            // Keyboard toggle button
            IconButton(

              icon: Icon(
                Provider.of<KeyboardProvider>(context).showKeyboardFeature
                    ? Icons.keyboard_hide
                    : Icons.keyboard,
                color:
                    Provider.of<KeyboardProvider>(context).showKeyboardFeature
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade600,
              ),
              tooltip:
                  Provider.of<KeyboardProvider>(context).showKeyboardFeature
                      ? 'billing.keyboard_hide'.tr
                      : 'billing.keyboard_show'.tr,
              onPressed: () {
                final keyboardProvider =
                    Provider.of<KeyboardProvider>(context, listen: false);
                if (keyboardProvider.showKeyboardFeature) {
                  keyboardProvider.featureOff();
                  keyboardProvider.clear();
                } else {
                  keyboardProvider.featureOn(); // or set type as needed
                }
              },
            ),
            // Font size toggle button
            Consumer<AppFontProvider>(
              builder: (context, fontProvider, child) {
                return IconButton(
                  icon: Icon(
                    Icons.text_fields,
                    color: fontProvider.fontSizeLevel > 0
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade600,
                  ),
                  tooltip: 'Font: ${fontProvider.fontSizeLevelName}',
                  onPressed: () {
                    fontProvider.cycleFontSize();
                  },
                );
              },
            ),
            // Sync button next to keyboard icon
            const SyncButton(
              showTooltip: true,
              showText: false,
            ),
            // Connectivity indicator
            const SizedBox(width: 0),
            _buildConnectivityIndicator(),
            // Show toggle button next to order number when sidebar is hidden
            if (!_isSidebarVisible) ...[
              const SizedBox(width: 12),
              CustomRoundButton(
                title: "☰",
                fct: () {
                  setState(() {
                    _isSidebarVisible = !_isSidebarVisible;
                  });
                },
                fontSize: 16,
                height: 32,
                width: 32,
                boxColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
                radius: 8,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConnectivityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _hasInternet
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasInternet ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasInternet ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: _hasInternet ? Colors.green : Colors.red,
          ),
          // const SizedBox(width: 4),
          // Text(
          //   _hasInternet ? 'Online' : 'Offline',
          //   style: TextStyle(
          //     fontSize: 12,
          //     fontWeight: FontWeight.w500,
          //     color: _hasInternet ? Colors.green : Colors.red,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader({
    required Size size,
    required TextEditingController barcodeController,
    required TextEditingController quantityController,
    required TextEditingController unitPriceController,
    required TextEditingController selectedProductIdController,
    required GridSelectionProvider productProvider,
  }) {
    return Consumer<AppSettingsProvider>(
        builder: (context, appSettingsProvider, child) {
      if (appSettingsProvider.appSettings == null) {
        return Container();
      }
      return SizedBox(
        height: size.height * 0.10,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                children: [
                  appSettingsProvider.appSettings!.barcodeSales
                      ? Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              autofocus:
                                  appSettingsProvider.appSettings!.barcodeSales,
                              controller: barcodeController,
                              focusNode: _barcodeNode,
                              readOnly:
                                  selectedProductNameController.text.isNotEmpty,
                              onSubmitted: (query) {
                                if (query != null && query.isNotEmpty) {
                                  processBarcode(query);
                                }
                              },
                              size: size,
                              hintText: 'billing.barcode_hint'.tr,
                            ),
                          ),
                        )
                      : Container(),
                  appSettingsProvider.appSettings!.barcodeSales &&
                          selectedProductNameController.text.isNotEmpty
                      ? Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              readOnly: true,
                              controller: selectedProductNameController,
                              onchanged: (query) {},
                              size: size,
                              hintText: 'billing.product_name_hint'.tr,
                            ),
                          ),
                        )
                      : Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProductAutocomplete(
                                autocompleteProductKey: _autocompleteProductKey,
                                autofocus: !appSettingsProvider
                                    .appSettings!.barcodeSales,
                                size: size,
                                onSelected: (GetProduct selectedProduct,
                                    Stock? selectedStock) async {
                                  // Product is already added to cart by ProductCartHelper
                                  // Clear fields and reset autocomplete for next product
                                  setState(() {
                                    _autocompleteProductKey = GlobalKey();
                                    quantityController.clear();
                                    barcodeController.clear();
                                    selectedProductIdController.clear();
                                    unitPriceController.clear();
                                    selectedProductNameController.clear();
                                  });
                                  // Focus the barcode/search field for next entry
                                  _focusTextField();
                                },
                                productList: productProvider.productList!,
                              ),
                            ],
                          ),
                        ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: buildColumnWidgetForTextFields(
                        controller: quantityController,
                        onchanged: (query) {},
                        size: size,
                        hintText: 'billing.quantity_hint'.tr,
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        onTap: () {
                          Provider.of<KeyboardProvider>(context, listen: false)
                              .show(
                            'number',
                            quantityController,
                            replaceOnFirstInput: true,
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: buildColumnWidgetForTextFields(
                        controller: unitPriceController,
                        onchanged: (query) {},
                        size: size,
                        focusNode: _unitPriceFocusNode,
                        hintText: 'billing.unit_price_hint'.tr,
                        keyboardType: TextInputType.number,
                        onTap: () {
                          Provider.of<KeyboardProvider>(context, listen: false)
                              .show(
                            'number',
                            unitPriceController,
                            replaceOnFirstInput: true,
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomRoundButton(
                              title: "billing.add_item".tr,
                              boxColor: ColorManager.kButtonGreen,
                              borderColor: ColorManager.kButtonGreen,
                              isLoading: isLoadingAddItem,
                              fct: () async {
                                setState(() {
                                  isLoadingAddItem = true; // Start loading
                                });
                                try {
                                  // Get the selected product from LocalProductProvider
                                  final localProductProvider =
                                      Provider.of<LocalProductProvider>(context,
                                          listen: false);
                                  final generalSettingsProvider =
                                      Provider.of<GeneralSettingsProvider>(
                                          context,
                                          listen: false);

                                  final selectedProduct =
                                      localProductProvider.selectedProduct;

                                  if (selectedProduct != null) {
                                    debugPrint("=== ADD ITEM DEBUG ===");
                                    debugPrint(
                                        "Product selected: ${selectedProduct.productName}");
                                    debugPrint(
                                        "Product ID: ${selectedProduct.productId}");
                                    debugPrint(
                                        "Product base price: ${selectedProduct.price?.price ?? 'null'}");
                                    debugPrint(
                                        "Product MRP: ${selectedProduct.mrp ?? 'null'}");
                                    debugPrint(
                                        "Product has ${selectedProduct.stock?.length ?? 0} stock entries");

                                    // Check if stock management is enabled
                                    bool stockEnabled = generalSettingsProvider
                                            .generalSettings?.stockEnabled ??
                                        false;
                                    debugPrint(
                                        "Stock management enabled: $stockEnabled");

                                    // Set the stock enabled status in LocalProductProvider
                                    localProductProvider
                                        .setStockEnabled(stockEnabled);

                                    if (!stockEnabled) {
                                      debugPrint(
                                          "Stock management disabled, adding product directly to cart...");

                                      // Add the selected product to the local cart without stock checking
                                      localProductProvider.addToCart(
                                          product: selectedProduct,
                                          quantity: num.tryParse(
                                            quantityController.text,
                                          ),
                                          price: double.tryParse(
                                            unitPriceController.text,
                                          ));

                                      showScaffold(
                                        context: context,
                                        message: 'billing.added_to_cart'.tr,
                                      );

                                      // Clear input fields if necessary
                                      setState(() {
                                        _autocompleteProductKey = GlobalKey();
                                        quantityController.clear();
                                        barcodeController.clear();
                                        selectedProductIdController.clear();
                                        unitPriceController.clear();
                                      });
                                      _focusTextField();
                                      debugPrint("=== END ADD ITEM DEBUG ===");
                                      return;
                                    }

                                    // Check if we have a selected stock from the autocomplete
                                    Stock? selectedStock =
                                        localProductProvider.selectedStock;
                                    debugPrint(
                                        "Selected stock from autocomplete: ${selectedStock?.id ?? 'null'}");

                                    if (selectedStock != null) {
                                      debugPrint(
                                          "Using pre-selected stock from autocomplete...");

                                      // 🔧 FIX: Prioritize user's custom typed price over stock price
                                      double customPrice = double.tryParse(
                                              unitPriceController.text) ??
                                          0;
                                      double stockPrice = double.tryParse(
                                              selectedStock.price ?? "0") ??
                                          0;
                                      double stockMrp = double.tryParse(
                                              selectedStock.mrp ?? "0") ??
                                          0;

                                      // Use custom price if user typed one, otherwise use stock price
                                      double finalPrice = customPrice > 0
                                          ? customPrice
                                          : stockPrice;

                                      // 🔧 FIX: Check if product already exists in cart with custom MRP
                                      double? finalMrp;
                                      final bool itemExistsInCart =
                                          localProductProvider.cartItems.any(
                                              (item) =>
                                                  item.product.productId ==
                                                      selectedProduct
                                                          .productId &&
                                                  (item.selectedStock?.id ==
                                                          selectedStock.id ||
                                                      (item.selectedStock ==
                                                              null &&
                                                          selectedStock ==
                                                              null)));

                                      if (itemExistsInCart) {
                                        // Item exists, don't pass MRP to preserve existing custom MRP
                                        finalMrp = null;
                                        debugPrint(
                                            "Product already in cart - preserving existing custom MRP");
                                      } else {
                                        // New item, use stock MRP
                                        finalMrp = stockMrp;
                                        debugPrint(
                                            "New product to cart - using stock MRP: $finalMrp");
                                      }

                                      debugPrint(
                                          "Adding to cart with pre-selected stock: CustomPrice=${customPrice}, StockPrice=${stockPrice}, FinalPrice=${finalPrice}, MRP=${finalMrp ?? 'preserved'}");

                                      // Add the selected product to the local cart with the pre-selected stock
                                      localProductProvider.addToCart(
                                        product: selectedProduct,
                                        quantity: num.tryParse(
                                            quantityController.text),
                                        price:
                                            finalPrice, // 🔧 FIX: Use custom price if available
                                        mrp:
                                            finalMrp, // 🔧 FIX: Use null to preserve existing custom MRP
                                        selectedStock: selectedStock,
                                      );

                                      showScaffold(
                                        context: context,
                                        message: 'billing.added_to_cart'.tr,
                                      );
                                    } else {
                                      debugPrint(
                                          "No pre-selected stock, using auto-selection logic...");

                                      // Let the addToCart method handle auto-selection for single stock
                                      localProductProvider.addToCart(
                                        product: selectedProduct,
                                        quantity: num.tryParse(
                                            quantityController.text),
                                        price: double.tryParse(
                                            unitPriceController.text),
                                      );

                                      showScaffold(
                                        context: context,
                                        message: 'billing.added_to_cart'.tr,
                                      );
                                    }

                                    // Clear input fields if necessary
                                    setState(() {
                                      _autocompleteProductKey = GlobalKey();
                                      quantityController.clear();
                                      barcodeController.clear();
                                      selectedProductIdController.clear();
                                      unitPriceController.clear();
                                    });
                                    _focusTextField();
                                    debugPrint("=== END ADD ITEM DEBUG ===");
                                  } else {
                                    showScaffoldError(
                                      context: context,
                                      message: "billing.no_product_selected".tr,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error adding item: $e');
                                  showScaffoldError(
                                    context: context,
                                    message: "billing.failed_add_item".tr,
                                  );
                                } finally {
                                  debugPrint('Finally adding item');
                                  setState(() {
                                    isLoadingAddItem = false; // End loading
                                  });
                                }
                              },
                              fontSize: FontSize.s14,
                              height: size.height * .07,
                              width: size.width / 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        BuildBoxShadowContainer(
                          height: size.height * .07,
                          width: 50,
                          circleRadius: 5,
                          child: InkWell(
                            onTap: () => {
                              setState(() {
                                _autocompleteProductKey = GlobalKey();
                                quantityController.clear();
                                barcodeController.clear();
                                selectedProductIdController.clear();
                                unitPriceController.clear();
                              }),
                              Provider.of<LocalProductProvider>(context,
                                      listen: false)
                                  .resetSelectedProduct(),
                              _focusTextField(),
                              showScaffold(
                                context: context,
                                message: 'billing.product_cleared'.tr,
                              )
                            },
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: WebsafeSvg.asset(
                                      ImageAssets.oderlistCloseIcon,
                                      width: 27,
                                      colorFilter: const ColorFilter.mode(
                                          ColorManager.kButtonRed,
                                          BlendMode.srcIn),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCartItemsTable(Size size) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        List<LocalCartItem> cartItems = localProductProvider.getCartItems();
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: true);
        final appSettings = appSettingsProvider.appSettings;
        final fontProvider =
            Provider.of<AppFontProvider>(context, listen: true);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  // Fixed header
                  Container(
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                    child: Row(
                      children: [
                        _buildHeaderCell('billing.table_serial'.tr,
                            flex: 1, alignment: Alignment.center),
                        _buildHeaderCell('billing.table_item_name'.tr,
                            flex: 3, alignment: Alignment.centerLeft),
                        _buildHeaderCell('billing.table_unit'.tr,
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('billing.table_qty'.tr,
                            flex: 2, alignment: Alignment.center),
                        if (appSettings?.showTaxRatePos == true)
                          _buildHeaderCell('billing.table_tax'.tr,
                              flex: 1, alignment: Alignment.centerLeft),
                        if (appSettings?.showMrpPos == true)
                          _buildHeaderCell('billing.table_mrp'.tr,
                              flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('billing.table_price'.tr,
                            flex: 1, alignment: Alignment.centerLeft),
                        if (appSettings?.showTaxPos == true)
                          _buildHeaderCell('billing.table_tax_amount'.tr,
                              flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('billing.table_total'.tr,
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('billing.table_actions'.tr,
                            flex: 1, alignment: Alignment.centerLeft),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return Container(
                              color: index % 2 == 0
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              child: Row(
                                children: [
                                  // Index Number
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        '${index + 1}',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          fontProvider.billingTableItemSize,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.center,
                                  ),

                                  // Item Name
                                  _buildContentCell(
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _showProductDetailsDialog(item),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Text(
                                                item.product.productName ??
                                                    'general.unknown'.tr,
                                                style: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  fontProvider
                                                      .billingTableItemSize,
                                                  0.21,
                                                  ColorManager.textColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Tooltip(
                                            message: 'billing.view_details'.tr,
                                            waitDuration: const Duration(
                                                milliseconds: 400),
                                            child: InkWell(
                                              onTap: () =>
                                                  _showProductDetailsDialog(
                                                      item),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: const Icon(
                                                Icons.info_outline,
                                                size: 16,
                                                color:
                                                    ColorManager.kPrimaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    flex: 3,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Unit
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        item.product.unit ?? '-',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          fontProvider.billingTableItemSize,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  // Qty
                                  _buildContentCell(
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: CompactQuantityControlLocal(
                                          productId: item.product.productId!,
                                          quantity: item.quantity.toDouble(),
                                          unitPrice: item.price.toString(),
                                          productUnit: item.product.unit,
                                          product: item.product,
                                          selectedStock: item.selectedStock,
                                        ),
                                      ),
                                    ),
                                    flex: 2,
                                    alignment: Alignment.center,
                                  ),

                                  // Tax Rate %
                                  if (appSettings?.showTaxRatePos == true)
                                    _buildContentCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: SizedBox(
                                          width: 60,
                                          child: TaxTextField(
                                            item: item,
                                            localProductProvider:
                                                localProductProvider,
                                          ),
                                        ),
                                      ),
                                      flex: 1,
                                      alignment: Alignment.centerLeft,
                                    ),

                                  // MRP
                                  if (appSettings?.showMrpPos == true)
                                    _buildContentCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: SizedBox(
                                          width: 70,
                                          child: MrpTextField(
                                            item: item,
                                            localProductProvider:
                                                localProductProvider,
                                          ),
                                        ),
                                      ),
                                      flex: 1,
                                      alignment: Alignment.centerLeft,
                                    ),

                                  // Price
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: PriceTextField(
                                          item: item,
                                          localProductProvider:
                                              localProductProvider,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Tax Amount
                                  if (appSettings?.showTaxPos == true)
                                    _buildContentCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: SizedBox(
                                          width: 60,
                                          child: Builder(
                                            builder: (context) {
                                              // Calculate tax amount: (price * quantity * taxRate) / (100 + taxRate)
                                              final double itemTotal =
                                                  (item.price ?? 0.0) *
                                                      item.quantity;
                                              final double taxRate =
                                                  item.taxRate ?? 0.0;
                                              final double taxAmount =
                                                  taxRate > 0
                                                      ? (itemTotal *
                                                          taxRate /
                                                          (100 + taxRate))
                                                      : 0.0;
                                              return Text(
                                                AmountHelper.formatAmount(
                                                    taxAmount),
                                                style: TextStyle(
                                                  fontSize: fontProvider
                                                      .billingTableItemSize,
                                                  color: Colors.black,
                                                ),
                                                textAlign: TextAlign.left,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      flex: 1,
                                      alignment: Alignment.centerLeft,
                                    ),

                                  // Total
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: Text(
                                          AmountHelper.formatAmount(
                                              (item.price! * item.quantity)),
                                          style: TextStyle(
                                              fontSize: fontProvider
                                                  .billingTableItemSize),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Actions
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: IconButton(
                                        icon: WebsafeSvg.asset(
                                          ImageAssets.oderlistCloseIcon,
                                          width: 15,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          localProductProvider.removeFromCart(
                                              item.product.productId!,
                                              item.selectedStock);
                                        },
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCell(String text,
      {required int flex, required Alignment alignment}) {
    final fontProvider = Provider.of<AppFontProvider>(context, listen: true);
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: alignment,
        child: Text(
          text,
          textAlign:
              alignment == Alignment.center ? TextAlign.center : TextAlign.left,
          style: buildCustomStyle(
            FontWeightManager.bold,
            fontProvider.billingTableHeaderSize,
            0.21,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildContentCell(Widget child,
      {required int flex, required Alignment alignment}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: alignment,
        child: child,
      ),
    );
  }

  // Show product details dialog for the given cart item using reusable widget
  void _showProductDetailsDialog(LocalCartItem item) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ProductDetailsDialog(
          product: item.product,
          unitPrice: item.price,
          mrp: item.mrp,
          quantity: item.quantity,
          selectedStock: item.selectedStock,
          isCompact: false,
          currency: currency,
        );
      },
    );
  }

  Widget _buildPaymentSummary({bool compact = false}) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: true);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    localProductProvider.cartTotal; // Call this to ensure priceSummary is set

    if (compact) {
      // Compact view: Only show Net amount, Discount, and Total
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          BuildPaymentRow(
            amount: "",
            title: "billing.payment_summary".tr,
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.21,
              ColorManager.kPrimaryColor,
            ),
            color: ColorManager.kPrimaryColor,
          ),
          const SizedBox(height: 5),
          BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
            title: "billing.net_amount".tr,
            color: ColorManager.textColor,
            titleWidget: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "billing.net_amount".tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s15,
                      0.18,
                      ColorManager.textColor,
                    ),
                  ),
                  TextSpan(
                    text: " ${"billing.incl_tax".tr}",
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s11, // Smaller font for "(incl. tax)"
                      0.18,
                      ColorManager.kGreyColor,
                    ),
                  ),
                ],
              ),
            ),
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s15,
              0.18,
              ColorManager.textColor,
            ),
          ),
          // Tax Amount (Optional based on toggle)
          if (Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.showTaxPos ==
              true)
            BuildPaymentRow(
              amount:
                  "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax)}",
              title: "billing.tax_amount".tr,
              color: ColorManager.textColor,
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                ColorManager.textColor,
              ),
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.18,
                ColorManager.textColor,
              ),
            ),

          // 📊 Dynamic Tax Breakdown
          if (Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.showTaxPos ==
              true)
            ...localProductProvider.taxBreakdown.entries.map((entry) {
              return BuildPaymentRow(
                amount: "$currency ${AmountHelper.formatAmount(entry.value)}",
                title: entry.key, // Tax Name (e.g. GST, VAT)
                color: ColorManager.textColor,
                firstRowTextStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12, // Smaller font for "(incl. tax)"
                  0.18,
                  ColorManager.kGreyColor,
                ),
                secondRowTextStyle: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.18,
                  ColorManager.kGreyColor,
                ),
              );
            }),

          (Provider.of<AppSettingsProvider>(context, listen: false)
                      .appSettings
                      ?.priceRoundOff ==
                  true)
              ? BuildPaymentRow(
                  amount:
                      "$currency ${AmountHelper.roundOffAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
                  title: "billing.discount".tr,
                  color: ColorManager.kButtonGreen,
                  firstRowTextStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                  secondRowTextStyle: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                )
              : BuildPaymentRow(
                  amount:
                      "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
                  title: "billing.discount".tr,
                  color: ColorManager.kButtonGreen,
                  firstRowTextStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                  secondRowTextStyle: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                ),

          const Divider(thickness: 2),
          BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.roundOffAmount(localProductProvider.cartTotal)}",
            title: "billing.total_payable".tr,
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.kPrimaryColor,
            ),
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.textColor,
            ),
            color: ColorManager.textColor,
          ),
        ],
      );
    }

    // Full view
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        BuildPaymentRow(
          amount: "",
          title: "billing.payment_summary".tr,
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        const SizedBox(
          height: 5,
        ),
        BuildPaymentRow(
          amount:
              "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
          title: "billing.net_amount".tr,
          color: ColorManager.textColor,
          titleWidget: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "billing.net_amount".tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s15,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
                TextSpan(
                  text: " ${"billing.incl_tax".tr}",
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11, // Smaller font for "(incl. tax)"
                    0.18,
                    ColorManager.kGreyColor,
                  ),
                ),
              ],
            ),
          ),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
        ),
        BuildPaymentRow(
          amount: "$currency 0.00",
          title: "billing.shipping".tr,
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount:
              "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
          title: "billing.discount".tr,
          color: ColorManager.textColor,
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax)}",
            title: "billing.tax_amount".tr,
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Center(
                  child: TaxDetailsDialog(
                    taxAmounts: taxNames,
                  ),
                );
              },
            );
          },
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount: "$currency ${_getFormattedTotal()}", // Use helper method
          title: "billing.total_payable".tr,
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          color: ColorManager.textColor,
        ),
      ],
    );
  }

  // Helper method to get formatted total
  String _getFormattedTotal() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);

    if (appSettingsProvider.appSettings?.priceRoundOff == true) {
      double roundedTotal = localProductProvider.getRoundedTotal(context);
      return AmountHelper.formatAmount(roundedTotal);
    }

    return AmountHelper.formatAmount(localProductProvider.cartTotal);
  }

  Widget _buildMobileNumberInput({
    required Size size,
    required TextEditingController mobileNumberTextController,
  }) {
    debugPrint("🖼️ _buildMobileNumberInput - Rendering customer field");
    debugPrint(
        "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
    debugPrint(
        "  - salesExecutivemobileNumberText != '': ${salesExecutivemobileNumberText != ""}");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
    debugPrint("  - isCustomerFound: $isCustomerFound");
    debugPrint(
        "  - Showing: ${salesExecutivemobileNumberText != "" ? "READ-ONLY field" : "AUTOCOMPLETE field"}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (salesExecutivemobileNumberText != "" &&
                    !_isCustomerManuallySelected &&
                    Provider.of<LocalProductProvider>(context, listen: false)
                            .currentOrder ==
                        null)
                ? Expanded(
                    child: buildColumnWidgetForTextFields(
                      controller: mobileNumberTextController,
                      readOnly: true,
                      size: size,
                      hintText: 'billing.phone_number_hint'.tr,
                    ),
                  )
                : Expanded(
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 0),
                      padding: const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width / 3,
                      child: Autocomplete<CustomerListModelData>(
                        key: _autocompletePhoneKey, // Set the key here
                        initialValue: TextEditingValue(
                            text: mobileNumberText?.isNotEmpty == true
                                ? mobileNumberText!
                                : ""), // Use mobileNumberText directly
                        optionsBuilder: (mobileNumberTextController) async {
                          debugPrint(
                              "🔍 Autocomplete optionsBuilder called with text: '${mobileNumberTextController.text}'");
                          // debugPrint(mobileNumberTextController.text);
                          if (mobileNumberTextController.text.isEmpty) {
                            setState(() {
                              isCustomerFound = false; // Reset validity
                              _highlightedCustomerIndex =
                                  null; // Reset highlighted index
                            });
                            return const Iterable<
                                CustomerListModelData>.empty();
                          }

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          // debugPrint("accessToken From AuthModel $accessToken");
                          // debugPrint(mobileNumberTextController.text);

                          try {
                            final response;
                            if (RegExp(r'^[0-9]+$')
                                .hasMatch(mobileNumberTextController.text)) {
                              response = await CustomerProvider()
                                  .findCustomerByPhone(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            } else {
                              response = await CustomerProvider()
                                  .findCustomerByName(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            }

                            if (response["status"] == "success") {
                              CustomerListModel customerListModel =
                                  CustomerListModel.fromJson(response);
                              List<CustomerListModelData>?
                                  filteredCustomerList = customerListModel.data;

                              if (mobileNumberTextController.text.length ==
                                      10 &&
                                  filteredCustomerList!.length == 1) {
                                setState(() {
                                  isCustomerFound = true;
                                });
                              } else {
                                setState(() {
                                  isCustomerFound = false;
                                });
                              }

                              _currentCustomerOptions =
                                  filteredCustomerList ?? [];
                              return filteredCustomerList!.isNotEmpty
                                  ? filteredCustomerList
                                  : const Iterable<
                                      CustomerListModelData>.empty();
                            } else {
                              // debugPrint('Error in response: ${response["message"]}');
                            }
                          } catch (error) {
                            // debugPrint('Exception caught: $error');
                          }
                          setState(() {
                            isCustomerFound = false;
                            _currentCustomerOptions = [];
                          });
                          return const Iterable<
                              CustomerListModelData>.empty(); // Return empty if no customers found
                        },
                        displayStringForOption:
                            (CustomerListModelData customer) =>
                                "${customer.name} ${customer.phone}",
                        onSelected: (CustomerListModelData selection) {
                          debugPrint(
                              "===== NORMAL CUSTOMER SELECTION START =====");
                          debugPrint("👤 CUSTOMER SELECTED:");
                          debugPrint("  - Customer ID: ${selection.id}");
                          debugPrint("  - Customer Name: ${selection.name}");
                          debugPrint("  - Customer Phone: ${selection.phone}");
                          debugPrint(
                              "  - Current salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - Current mobileNumberText: '$mobileNumberText'");
                          debugPrint(
                              "  - Current mobileNumberTextController.text: '${mobileNumberTextController.text}'");

                          // Update the global customer selection provider
                          Provider.of<CustomerSelectionProvider>(context,
                                  listen: false)
                              .setSelectedCustomer(selection);

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          // debugPrint("accessToken From AuthModel $accessToken");
                          Provider.of<CartProvider>(context, listen: false)
                              .fetchCartDataFromApi(
                                  customerId: selection.id ?? 0,
                                  accessToken: accessToken ?? '');

                          debugPrint("📝 BEFORE setState:");
                          debugPrint(
                              "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - mobileNumberText: '$mobileNumberText'");

                          setState(() {
                            mobileNumberText = "";
                            selectedCustomerID = selection.id!;
                            selectedCustomerPhone = selection.phone;
                            selectedCustomer = selection;
                            // **FIX: Update our class controller for consistency**
                            mobileNumberTextController.text =
                                "${selection.name} ${selection.phone}";
                            // Mark as manually selected
                            _isCustomerManuallySelected = true;
                            debugPrint(
                                "  - 🔒 Marked as manually selected (customer from list)");
                          });

                          debugPrint("📝 AFTER setState:");
                          debugPrint(
                              "  - mobileNumberText set to: '$mobileNumberText'");
                          debugPrint(
                              "  - selectedCustomerID: $selectedCustomerID");
                          debugPrint(
                              "  - selectedCustomerPhone: $selectedCustomerPhone");
                          debugPrint(
                              "  - salesExecutivemobileNumberText remains: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
                          debugPrint("  - isCustomerFound: $isCustomerFound");
                          debugPrint(
                              "===== NORMAL CUSTOMER SELECTION END =====");
                        },
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController autoCompleteController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted) {
                          debugPrint(
                              "🎨 fieldViewBuilder called - controller text: '${autoCompleteController.text}'");

                          // Store references to the Autocomplete's focusNode and controller for use in clear button
                          _autocompleteFocusNode = focusNode;
                          _autocompleteController = autoCompleteController;

                          // **FIX: Sync the autocomplete controller with our state**
                          if (mobileNumberText?.isNotEmpty == true &&
                              autoCompleteController.text != mobileNumberText) {
                            debugPrint(
                                "🔄 SYNC: Setting autocomplete controller text to: '$mobileNumberText'");
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (autoCompleteController.text !=
                                  mobileNumberText) {
                                autoCompleteController.text = mobileNumberText!;
                              }
                            });
                          }

                          // Ensure the text field retains focus and caret position when using the virtual keyboard
                          void _ensureFocus() {
                            if (!focusNode.hasFocus) {
                              focusNode.requestFocus();
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              autoCompleteController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: autoCompleteController.text.length),
                              );
                            });
                          }

                          // Prevent multiple identical listeners
                          autoCompleteController.removeListener(_ensureFocus);
                          autoCompleteController.addListener(_ensureFocus);

                          return KeyboardListener(
                            focusNode: _customerTextFieldFocus,
                            onKeyEvent: (KeyEvent event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  setState(() {
                                    if (_highlightedCustomerIndex == null) {
                                      _highlightedCustomerIndex = 0;
                                    } else if (_currentCustomerOptions
                                            .isNotEmpty &&
                                        _highlightedCustomerIndex! <
                                            _currentCustomerOptions.length -
                                                1) {
                                      _highlightedCustomerIndex =
                                          _highlightedCustomerIndex! + 1;
                                    }
                                  });
                                  // Scroll to show the highlighted item
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  setState(() {
                                    if (_highlightedCustomerIndex == null) {
                                      _highlightedCustomerIndex = 0;
                                    } else if (_highlightedCustomerIndex! > 0) {
                                      _highlightedCustomerIndex =
                                          _highlightedCustomerIndex! - 1;
                                    }
                                  });
                                  // Scroll to show the highlighted item
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.enter) {
                                  // Handle Enter key to select highlighted item
                                  if (_highlightedCustomerIndex != null &&
                                      _currentCustomerOptions.isNotEmpty &&
                                      _highlightedCustomerIndex! <
                                          _currentCustomerOptions.length) {
                                    // Get the selected customer
                                    final selectedCust =
                                        _currentCustomerOptions[
                                            _highlightedCustomerIndex!];

                                    // Process the selection - this should match the onSelected behavior
                                    String? accessToken =
                                        Provider.of<AuthModel>(context,
                                                listen: false)
                                            .token;
                                    Provider.of<CartProvider>(context,
                                            listen: false)
                                        .fetchCartDataFromApi(
                                            customerId: selectedCust.id ?? 0,
                                            accessToken: accessToken ?? '');

                                    // Update text field with selected customer info
                                    autoCompleteController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";
                                    mobileNumberTextController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";

                                    setState(() {
                                      mobileNumberText = "";
                                      selectedCustomerID = selectedCust.id!;
                                      selectedCustomerPhone =
                                          selectedCust.phone;
                                      selectedCustomer = selectedCust;
                                      isCustomerFound = true;
                                      _isCustomerManuallySelected =
                                          true; // Mark as manually selected
                                    });

                                    // Unfocus to close the dropdown
                                    focusNode.unfocus();
                                  }
                                }
                              }
                            },
                            child: TextField(
                              onTap: () {
                                // Select all text for quick replacement
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (autoCompleteController.text.isNotEmpty &&
                                      focusNode.hasFocus) {
                                    autoCompleteController.selection =
                                        TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          autoCompleteController.text.length,
                                    );
                                  }
                                });

                                Provider.of<KeyboardProvider>(context,
                                        listen: false)
                                    .show(
                                  'text',
                                  autoCompleteController,
                                  replaceOnFirstInput: true,
                                );
                              },
                              controller: autoCompleteController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'billing.enter_mobile_hint'.tr,
                                hintStyle: buildCustomStyle(
                                  FontWeight.w500,
                                  12,
                                  0.27,
                                  Colors.grey.withOpacity(.5),
                                ),
                                border: InputBorder.none,
                                isDense: true, // Makes the field more compact
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                suffixIconConstraints: const BoxConstraints(
                                    maxHeight: 25,
                                    maxWidth:
                                        30), // Constrains the suffix icon size
                                suffixIcon: (isCustomerFound ||
                                        selectedCustomerID != null)
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: ColorManager.kButtonGreen,
                                          size: 25,
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                debugPrint("📝 TextField onChanged: '$value'");
                                setState(() {
                                  mobileNumberText = value;
                                  selectedCustomerID = null;
                                  selectedCustomerPhone = null;
                                  selectedCustomer = null;
                                  _highlightedCustomerIndex = null;
                                  isCustomerFound = false;
                                  // **FIX: Also update our class controller for consistency**
                                  mobileNumberTextController.text = value;

                                  // Mark as manually selected if user is typing a phone number
                                  if (value.isNotEmpty && value.length >= 10) {
                                    _isCustomerManuallySelected = true;
                                    debugPrint(
                                        "  - 🔒 Marked as manually selected (phone entry): '$value'");
                                  } else if (value.isEmpty) {
                                    // Reset manual selection if field is cleared
                                    _isCustomerManuallySelected = false;
                                    debugPrint(
                                        "  - 🔓 Reset manual selection (field cleared)");
                                  }
                                });
                                debugPrint(
                                    "  - Set mobileNumberText: '$mobileNumberText'");
                                debugPrint("  - Cleared customer selection");
                              },
                              style: buildCustomStyle(
                                FontWeight.w500,
                                12,
                                0.27,
                                Colors.black.withOpacity(.5),
                              ),
                            ),
                          );
                        },
                        optionsViewBuilder: (BuildContext context,
                            AutocompleteOnSelected<CustomerListModelData>
                                onSelected,
                            Iterable<CustomerListModelData> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: Container(
                                width: MediaQuery.of(context).size.width / 3,
                                color: Colors.white,
                                constraints:
                                    const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  controller: _customerScrollController,
                                  padding: const EdgeInsets.all(8.0),
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final CustomerListModelData option =
                                        options.elementAt(index);
                                    final bool isHighlighted =
                                        _highlightedCustomerIndex == index;

                                    return MouseRegion(
                                      onEnter: (_) {
                                        setState(() {
                                          hoverMap[index] = true;
                                          _highlightedCustomerIndex = index;
                                        });
                                      },
                                      onExit: (_) {
                                        setState(() {
                                          hoverMap[index] = false;
                                        });
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          onSelected(option);
                                        },
                                        child: Container(
                                          color: isHighlighted
                                              ? Colors.blue.shade50
                                              : (hoverMap[index] == true
                                                  ? Colors.grey[200]
                                                  : Colors.white),
                                          child: ListTile(
                                            title: Text(
                                              "${option.name} ${option.phone}",
                                              style: buildCustomStyle(
                                                FontWeight.w500,
                                                12,
                                                0.27,
                                                isHighlighted
                                                    ? Colors.blue.shade800
                                                    : Colors.black
                                                        .withOpacity(.5),
                                              ),
                                            ),
                                            hoverColor: Colors.grey[200],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
            Row(
              children: [
                // Plus button - only show when no customer is selected
                if (selectedCustomerID == null && !isCustomerFound) ...[
                  BuildBoxShadowContainer(
                    height: size.height * .07,
                    width: 50,
                    circleRadius: 5,
                    child: InkWell(
                      onTap: () async {
                        debugPrint("ADD NEW CUSTOMER BUTTON PRESSED");
                        final result = await showAddCustomerModal(context, size,
                            mobileNumber: mobileNumberTextController.text);
                        if (result != null &&
                            result is Map &&
                            result['status'] == 'success') {
                          final createdPhone =
                              (result['phone'] ?? '').toString();
                          final createdName = (result['name'] ?? '').toString();
                          // Try to fetch the newly created customer by phone and auto-select
                          try {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            final response = await CustomerProvider()
                                .findCustomerByPhone(
                                    accessToken ?? '', createdPhone, context);
                            if (response != null &&
                                response['status'] == 'success') {
                              final listModel =
                                  CustomerListModel.fromJson(response);
                              final list = listModel.data ?? [];
                              if (list.isNotEmpty) {
                                final selection = list.first;
                                Provider.of<CustomerSelectionProvider>(context,
                                        listen: false)
                                    .setSelectedCustomer(selection);
                                setState(() {
                                  // Seed the Autocomplete with display text and rebuild it
                                  mobileNumberText =
                                      "${selection.name} ${selection.phone}";
                                  _autocompletePhoneKey = GlobalKey();

                                  selectedCustomerID = selection.id!;
                                  selectedCustomerPhone = selection.phone;
                                  selectedCustomer = selection;
                                  mobileNumberTextController.text =
                                      "${selection.name} ${selection.phone}";
                                  _isCustomerManuallySelected = true;
                                  isCustomerFound = true;
                                });
                              } else {
                                // Fallback: show name+phone from modal
                                setState(() {
                                  // Seed the Autocomplete and rebuild
                                  mobileNumberText =
                                      "$createdName $createdPhone".trim();
                                  _autocompletePhoneKey = GlobalKey();

                                  mobileNumberTextController.text =
                                      "$createdName $createdPhone".trim();
                                  _isCustomerManuallySelected = true;
                                  isCustomerFound = true;
                                });
                              }
                            }
                          } catch (e) {
                            // On any error, at least reflect the phone/name entered
                            setState(() {
                              mobileNumberText =
                                  "$createdName $createdPhone".trim();
                              _autocompletePhoneKey = GlobalKey();

                              mobileNumberTextController.text =
                                  "$createdName $createdPhone".trim();
                              _isCustomerManuallySelected = true;
                              isCustomerFound = true;
                            });
                          }
                        }
                      },
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          size: 27,
                          color: ColorManager.kButtonGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                      width: 10), // Spacing between plus and close buttons
                ],

                // Close button - always show
                BuildBoxShadowContainer(
                  height: size.height * .07,
                  width: 50,
                  circleRadius: 5,
                  child: InkWell(
                    onTap: () => {
                      debugPrint("❌ CLEAR CUSTOMER BUTTON PRESSED"),
                      debugPrint("  - Before clear:"),
                      debugPrint(
                          "    - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'"),
                      debugPrint("    - mobileNumberText: '$mobileNumberText'"),
                      debugPrint(
                          "    - mobileNumberTextController.text: '${mobileNumberTextController.text}'"),

                      // Clear the global customer selection provider
                      Provider.of<CustomerSelectionProvider>(context,
                              listen: false)
                          .clearSelectedCustomer(),

                      setState(() {
                        mobileNumberTextController.clear();
                        mobileNumberText = "";
                        selectedCustomerID = null;
                        selectedCustomerPhone = null;
                        selectedCustomer = null;
                        isCustomerFound = false;
                        salesExecutivemobileNumberText = "";
                        _isCustomerManuallySelected = false;
                        debugPrint(
                            "  - Reset manual selection (clear button pressed)");
                      }),

                      // Clear the autocomplete controller as well
                      // We need to do this after setState to ensure the fieldViewBuilder has access to the controller
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_autocompleteController != null) {
                          _autocompleteController!.clear();
                          debugPrint("  - Cleared autocomplete controller");
                        }
                      }),

                      debugPrint("  - After clear:"),
                      debugPrint(
                          "    - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'"),
                      debugPrint("    - mobileNumberText: '$mobileNumberText'"),
                      debugPrint(
                          "    - mobileNumberTextController.text: '${mobileNumberTextController.text}'"),

                      showScaffold(
                        context: context,
                        message: 'billing.customer_cleared'.tr,
                      ),

                      // Focus on customer autocomplete field after clearing
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_autocompleteFocusNode != null) {
                          FocusScope.of(context)
                              .requestFocus(_autocompleteFocusNode!);
                        } else {
                          // Fallback to customer text field focus if autocomplete focus node is not available
                          FocusScope.of(context)
                              .requestFocus(_customerTextFieldFocus);
                        }
                      })
                    },
                    child: Center(
                      child: WebsafeSvg.asset(
                        ImageAssets.oderlistCloseIcon,
                        width: 27,
                        colorFilter: const ColorFilter.mode(
                            ColorManager.kButtonRed, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // if (selectedCustomerID == null || !isCustomerFound) ...[
            //   const SizedBox(width: 10),
            //   BuildBoxShadowContainer(
            //     height: size.height * .07,
            //     width: 50,
            //     circleRadius: 5,
            //     child: InkWell(
            //       onTap: () => {},
            //       child: Center(
            //         child: WebsafeSvg.asset(
            //           ImageAssets.oderlistCloseIcon,
            //           width: 27,
            //           color: ColorManager.kButtonRed,
            //         ),
            //       ),
            //     ),
            //   ),
            // ],
          ],
        ),
        // Customer Balance Display
        if (selectedCustomer?.balance != null && _shouldShowCustomerBalance())
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 5.0),
            child: _buildCustomerBalance(selectedCustomer!.balance!),
          ),
      ],
    );
  }

  bool _shouldShowCustomerBalance() {
    // Don't show balance if no customer is selected
    if (selectedCustomer?.phone == null) {
      return false;
    }

    // Get app settings to check for default customer
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultCustomerPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";

    // Don't show balance if it's the default customer (by phone match)
    if (defaultCustomerPhone.isNotEmpty &&
        selectedCustomer!.phone == defaultCustomerPhone) {
      return false;
    }

    // Get current sales executive
    final salesExecutiveProvider =
        Provider.of<SalesExecutiveProvider>(context, listen: false);
    final currentExecutive = salesExecutiveProvider.getCurrentUser(context);

    // Don't show balance if selected customer's phone matches current sales executive's phone
    if (currentExecutive?.phone != null &&
        selectedCustomer!.phone == currentExecutive!.phone) {
      return false;
    }

    return true;
  }

  Widget _buildCustomerBalance(double balance) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';
    Color balanceColor;
    String balanceText;

    if (balance > 0) {
      balanceColor = Colors.green;
      balanceText = "+${balance.toStringAsFixed(2)}";
    } else if (balance < 0) {
      balanceColor = Colors.red;
      balanceText = balance.toStringAsFixed(2);
    } else {
      balanceColor = Colors.black;
      balanceText = balance.toStringAsFixed(2);
    }

    return Row(
      children: [
        Text(
          '${'billing.balance'.tr}: ',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.14,
            Colors.grey.shade600,
          ),
        ),
        Text(
          '$currency $balanceText',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.14,
            balanceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            text: 'billing.clear_cart'.tr,
            color: ColorManager.kButtonRed,
            onPressed: _clearCart,
            isLoading: isLoadingClearCart,
          ),
          _buildActionButton(
            text: 'billing.save_order'.tr,
            color: ColorManager.kButtonYellow,
            onPressed: _saveOrder,
            isLoading: isLoadingSaveOrder,
          ),
          if (_hasInternet) ...[
            _buildActionButton(
              text: 'billing.confirm_and_print'.tr,
              color: ColorManager.kButtonBlue,
              onPressed: _createOrderAndPrint,
              isLoading: isLoadingCreateOrder,
            ),
            if (Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings
                    ?.showConfirmOrderButton ??
                true)
              _buildActionButton(
                text: 'billing.confirm_order'.tr,
                color: ColorManager.kButtonGreen,
                onPressed: _confirmOrder,
                isLoading: isLoadingConfirmOrder,
              ),
          ],
          if (!_hasInternet) ...[
            _buildActionButton(
              text: 'billing.save_and_print'.tr,
              color: ColorManager.kButtonYellow,
              onPressed: _saveOrderAndPrint,
              isLoading: isLoadingSaveOrderAndPrint,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearCart() {
    debugPrint("Clear Cart pressed");
    setState(() {
      isLoadingClearCart = true; // Indicate that loading has started
    });
    try {
      // Clear local cart
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();

      // Clear UI state
      setState(() {
        coupenCodeTextController.clear();
        _transactionNumberController.clear();
        _paidAmountController.clear();
        _balanceAmount = 0;
        // Reset all payment methods to none
        _isCashSelected = false;
        _isCardSelected = false;
        _isUpiSelected = false;
        _isDebitSelected = false;
        _isCodSelected = false;
        _cashAmountController.clear();
        _cardAmountController.clear();
        _upiAmountController.clear();
        _codAmountController.clear();
        _debitAmountController.clear();
        _autocompleteProductKey = GlobalKey();
        quantityController.clear();
        barcodeController.clear();
        selectedProductIdController.clear();
        unitPriceController.clear();
        isCouponApplied = false;
        _hasOpenedPaymentModalOnce = false;
        _isCustomerManuallySelected = false;
        _toCustomerCreditEnabled = false;
        // Clear delivery date and time
        deliveryDate = null;
        deliveryTime = null;
        deliveryAddress = null;
        // Clear delivery comment and car number
        _commentController.clear();
        _carNumberController.clear();

        // Clear customer-related state completely
        mobileNumberText = "";
        selectedCustomerID = null;
        selectedCustomerPhone = null;
        selectedCustomer = null;
        isCustomerFound = false;
        salesExecutivemobileNumberText = "";
        mobileNumberTextController.clear();
        _autocompletePhoneKey = GlobalKey();
      });
      showScaffold(
        context: context,
        message: "billing.cart_cleared".tr,
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
        message: "billing.failed_clear_cart".tr,
      );
    } finally {
      setState(() {
        isLoadingClearCart = false;
      });
    }
  }

  Future<void> _saveOrder() async {
    setState(() {
      isLoadingSaveOrder = true; // Indicate that loading has started
    });
    debugPrint("Save Order pressed");
    try {
      if (Provider.of<LocalProductProvider>(context, listen: false)
          .cartItems
          .isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Debug: Log current cart items with custom pricing
      debugPrint("💾 LOCAL SAVE - Cart items with custom pricing:");
      for (var item in localProductProvider.cartItems) {
        debugPrint("  📦 ${item.product.productName}");
        debugPrint("    - Quantity: ${item.quantity}");
        debugPrint("    - Custom Price: ${item.price}");
        debugPrint("    - Custom MRP: ${item.mrp}");
        debugPrint("    - Stock ID: ${item.selectedStock?.id}");
      }

      // Validate that all items have valid pricing
      bool hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "billing.valid_prices".tr,
        );
        return;
      }

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;

      if (currentOrder != null) {
        // Update existing order
        debugPrint("💾 Updating existing order: ${currentOrder.orderNumber}");

        // Get payment method and data using multi-payment system
        Map<String, String> paymentData = _getPaymentMethodData();
        String paymentMethod = paymentData["paymentMethod"]!;
        String paidAmount = paymentData["paidAmount"]!;

        // Debug customer info being saved
        debugPrint("📝 UPDATING ORDER - Customer info:");
        debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
        debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
        debugPrint("  - mobileNumberText: '$mobileNumberText' 🔍");
        debugPrint("  - selectedCustomerID: $selectedCustomerID");
        debugPrint(
            "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave = selectedCustomerPhone ?? mobileNumberText;

        localProductProvider.updateSavedOrder(
          currentOrder.id,
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "saved",
          deliveryDate: deliveryDate, // Pass deliveryDate
          deliveryTime: deliveryTime, // Pass deliveryTime
          toCustomerCredit: _toCustomerCreditEnabled,
          // context: context, // Pass context
          address: deliveryAddress,
        );

        showScaffold(
          context: context,
          message: "billing.order_updated_success".tr,
        );
        // Centralized clear
        _clearCart();
      } else {
        // Save as new order
        debugPrint("💾 Saving as new order");

        // Debug customer info being saved
        debugPrint("📝 SAVING NEW ORDER - Customer info:");
        debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
        debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
        debugPrint("  - mobileNumberText: '$mobileNumberText' 🔍");
        debugPrint("  - selectedCustomerID: $selectedCustomerID");
        debugPrint(
            "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave = selectedCustomerPhone ?? mobileNumberText;

        // Determine payment method and data
        Map<String, String> paymentData = _getPaymentMethodData();
        String paymentMethod = paymentData["paymentMethod"]!;
        String paidAmount = paymentData["paidAmount"]!;

        localProductProvider.saveCurrentCartAsOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "saved",
          deliveryDate: deliveryDate,
          deliveryTime: deliveryTime,
          context: context, // Pass context
          toCustomerCredit: _toCustomerCreditEnabled,
          address: deliveryAddress,
        );

        showScaffold(
          context: context,
          message: "billing.order_saved_success".tr,
        );
        resetAutocomplete();
        _fetchCustomers();
        // Centralized clear
        _clearCart();
      }
    } catch (e) {
      debugPrint("Error saving order: $e");
      showScaffoldError(
        context: context,
        message: "billing.failed_save_order".tr,
      );
    } finally {
      setState(() {
        isLoadingSaveOrder = false;
      });
    }
  }

  void _saveOrderAndPrint() async {
    setState(() {
      isLoadingSaveOrderAndPrint = true; // Indicate that loading has started
    });
    debugPrint("Save Order and Print pressed");
    try {
      if (Provider.of<LocalProductProvider>(context, listen: false)
          .cartItems
          .isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      // Check if customer is selected
      if (selectedCustomerID == null && mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "billing.select_customer".tr,
        );
        // Auto-focus on customer field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_autocompleteFocusNode != null) {
            FocusScope.of(context).requestFocus(_autocompleteFocusNode!);
          } else {
            FocusScope.of(context).requestFocus(_customerTextFieldFocus);
          }
        });
        return;
      }

      // Auto-show payment modal if never opened
      if (!_hasOpenedPaymentModalOnce) {
        _showPaymentMethodModal(onAfterApply: _confirmOrder);
        return;
      }

      // Get selected payment methods (no longer required - can be empty)
      List<String> selectedPaymentMethods = _getSelectedPaymentMethods();

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Debug: Log current cart items with custom pricing
      debugPrint("💾 LOCAL SAVE AND PRINT - Cart items with custom pricing:");
      for (var item in localProductProvider.cartItems) {
        debugPrint("  📦 ${item.product.productName}");
        debugPrint("    - Quantity: ${item.quantity}");
        debugPrint("    - Custom Price: ${item.price}");
        debugPrint("    - Custom MRP: ${item.mrp}");
        debugPrint("    - Stock ID: ${item.selectedStock?.id}");
      }

      // Validate that all items have valid pricing
      bool hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "billing.valid_prices".tr,
        );
        return;
      }

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;
      SavedOrder? orderToUse;

      if (currentOrder != null) {
        // We're editing an existing order, move it to confirmed orders
        debugPrint(
            "💾 Moving existing order to confirmed: ${currentOrder.orderNumber}");
        orderToUse =
            localProductProvider.moveToConfirmedOrders(currentOrder.id);

        if (orderToUse != null) {
          showScaffold(
            context: context,
            message: "billing.order_moved_confirmed".tr,
          );
        } else {
          // If the order couldn't be moved (shouldn't happen), create a new confirmed order
          debugPrint("💾 Creating new confirmed order (fallback)");

          // **FIX**: Properly determine customer info for phone-only orders
          String? customerNameToSave = selectedCustomer?.name;
          String? customerPhoneToSave =
              selectedCustomerPhone ?? mobileNumberText;

          // Determine payment method and data using multi-payment JSON format
          List<String> selectedPaymentMethods = _getSelectedPaymentMethods();

          // Get payment method IDs from BillingProvider for consistency
          final billingProvider =
              Provider.of<BillingProvider>(context, listen: false);
          final cashId = billingProvider.cashPaymentMethodId ?? "CASH";
          final cardId = billingProvider.cardPaymentMethodId ?? "CARD";
          final upiId = billingProvider.upiPaymentMethodId ?? "UPI";
          final codId = billingProvider.codPaymentMethodId ?? "COD";
          // DEBIT is for customer credit/balance, not a standard payment method
          const debitId = "DEBIT";

          // Always use multi-payment JSON format for consistency with sync button
          Map<String, dynamic> multiPaymentData = {
            "methods": selectedPaymentMethods,
            "amounts": {
              cashId: _cashAmountController.text.isNotEmpty
                  ? _cashAmountController.text
                  : "0",
              cardId: _cardAmountController.text.isNotEmpty
                  ? _cardAmountController.text
                  : "0",
              upiId: _upiAmountController.text.isNotEmpty
                  ? _upiAmountController.text
                  : "0",
              debitId: _debitAmountController.text.isNotEmpty
                  ? _debitAmountController.text
                  : "0",
              codId: _codAmountController.text.isNotEmpty
                  ? _codAmountController.text
                  : "0",
            },
            "isMultiPayment": true
          };
          String paymentMethod = json.encode(multiPaymentData);
          String paidAmount = _getTotalPaidAmount().toString();

          orderToUse = localProductProvider.saveCurrentCartAsConfirmedOrder(
            customerName: customerNameToSave,
            customerPhone: customerPhoneToSave,
            comment: _commentController.text,
            deliveryMethod: deliveryMethod,
            // Include all API-compatible fields
            customerId: selectedCustomerID,
            paymentMethod: paymentMethod,
            paidAmount: paidAmount,
            balanceAmount: _balanceAmount.toString(),
            transactionId: _transactionNumberController.text,
            couponId: isCouponApplied ? coupenCodeTextController.text : null,
            deliveryMethodId: deliveryMethodId,
            carNumber: _carNumberController.text,
            status: "confirmed",
            deliveryDate: deliveryDate, // Pass deliveryDate
            deliveryTime: deliveryTime, // Pass deliveryTime
            toCustomerCredit: _toCustomerCreditEnabled,
            address: deliveryAddress,
          );

          showScaffold(
            context: context,
            message: "billing.order_saved_confirmed".tr,
          );
        }
      } else {
        // Create a new confirmed order
        debugPrint("💾 Creating new confirmed order");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave = selectedCustomerPhone ?? mobileNumberText;

        // Determine payment method and data using multi-payment JSON format
        List<String> selectedPaymentMethods = _getSelectedPaymentMethods();

        // Get payment method IDs from BillingProvider for consistency
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        final cashId = billingProvider.cashPaymentMethodId ?? "CASH";
        final cardId = billingProvider.cardPaymentMethodId ?? "CARD";
        final upiId = billingProvider.upiPaymentMethodId ?? "UPI";
        final codId = billingProvider.codPaymentMethodId ?? "COD";
        // DEBIT is for customer credit/balance, not a standard payment method
        const debitId = "DEBIT";

        // Always use multi-payment JSON format for consistency with sync button
        Map<String, dynamic> multiPaymentData = {
          "methods": selectedPaymentMethods,
          "amounts": {
            cashId: _cashAmountController.text.isNotEmpty
                ? _cashAmountController.text
                : "0",
            cardId: _cardAmountController.text.isNotEmpty
                ? _cardAmountController.text
                : "0",
            upiId: _upiAmountController.text.isNotEmpty
                ? _upiAmountController.text
                : "0",
            debitId: _debitAmountController.text.isNotEmpty
                ? _debitAmountController.text
                : "0",
            codId: _codAmountController.text.isNotEmpty
                ? _codAmountController.text
                : "0",
          },
          "isMultiPayment": true
        };
        String paymentMethod = json.encode(multiPaymentData);
        String paidAmount = _getTotalPaidAmount().toString();

        orderToUse = localProductProvider.saveCurrentCartAsConfirmedOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
          deliveryDate: deliveryDate, // Pass deliveryDate
          deliveryTime: deliveryTime, // Pass deliveryTime
          toCustomerCredit: _toCustomerCreditEnabled,
          address: deliveryAddress,
        );

        showScaffold(
          context: context,
          message: "billing.order_saved_confirmed_alt".tr,
        );
      }

      try {
        // Print the order that was just confirmed
        printFromSavedOrder(orderToUse);
      } catch (error) {
        debugPrint("Error printing saved order: ${error.toString()}");
      }
      resetAutocomplete();
      // Centralized clear
      _fetchCustomers();
      // Clear cart without restoring stock (order is confirmed)
      localProductProvider.clearCartAfterOrder();
      localProductProvider.clearCurrentOrder();
    } catch (error) {
      debugPrint(error.toString());
      showScaffoldError(
        context: context,
        message: "billing.failed_save_order".tr,
      );
    } finally {
      setState(() {
        isLoadingSaveOrderAndPrint = false;
      });
    }
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
        message: "billing.order_loaded_editing".tr,
      );
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "billing.failed_load_order".tr);
    }
  }

  void _createOrderAndPrint() async {
    // Check for internet connection before proceeding
    if (!_hasInternet) {
      showScaffoldError(
        context: context,
        message: "billing.no_internet_create".tr,
      );
      return; // Stop execution if no internet
    }
    debugPrint("Create Order and Print pressed");
    debugPrint("🚀 API REQUEST STARTING - Create Order and Print");

    // Auto-show payment modal if never opened
    if (!_hasOpenedPaymentModalOnce) {
      _showPaymentMethodModal(onAfterApply: _createOrderAndPrint);
      return;
    }

    setState(() {
      isLoadingCreateOrder = true;
    });
    try {
      if (selectedCustomerID == null && mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "billing.select_customer".tr,
        );
        // Auto-focus on customer field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_autocompleteFocusNode != null) {
            FocusScope.of(context).requestFocus(_autocompleteFocusNode!);
          } else {
            FocusScope.of(context).requestFocus(_customerTextFieldFocus);
          }
        });
        return;
      }

      // Get selected payment methods (no longer required - can be empty)
      List<String> selectedPaymentMethods = _getSelectedPaymentMethods();

      if (deliveryMethod == "Car Delivery" && _carNumberController.text == "") {
        showScaffoldError(
          context: context,
          message: "billing.enter_car_number".tr,
        );
        return;
      }

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      // debugPrint("accessToken From AuthModel $accessToken");
      final provider = Provider.of<CartProvider>(context, listen: false);
      int? cartId = provider.getCartIDForOrder;
      debugPrint("📦 Cart ID for order: $cartId");

      String paymentMethod = "";

      if (selectedPaymentMethods.contains("CASH")) {
        paymentMethod = "CASH";
      } else if (selectedPaymentMethods.contains("CARD")) {
        paymentMethod = "CARD";
      } else if (selectedPaymentMethods.contains("UPI")) {
        paymentMethod = "UPI";
      } else if (selectedPaymentMethods.contains("COD")) {
        paymentMethod = "COD";
      } else if (selectedPaymentMethods.contains("DEBIT")) {
        paymentMethod = "DEBIT";
      } else if (selectedPaymentMethods.contains("BALANCE")) {
        paymentMethod = "BALANCE";
      }
      debugPrint("💰 Payment Method: $paymentMethod");

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final cartItems = localProductProvider.cartItems;

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      // Validate that all items have valid pricing before API call
      bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
          item.price == null ||
          item.price! < 0 ||
          item.mrp == null ||
          item.mrp! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message:
              "Please ensure all items have valid prices and MRP before confirming order",
        );
        return;
      }

      List<Map<String, dynamic>> items = [];

      for (var item in cartItems) {
        debugPrint("📦 Order Item: ${item.product.productName}");
        debugPrint("  - Product ID: ${item.product.productId}");
        debugPrint("  - Quantity: ${item.quantity}");
        debugPrint("  - Custom Price: ${item.price}");
        debugPrint("  - Custom MRP: ${item.mrp}");
        debugPrint("  - Stock ID: ${item.selectedStock?.id}");

        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp, // 🔧 FIX: Include custom MRP in API call
          'stock_id': item
              .selectedStock?.id, // 🔧 FIX: Include stock_id for consistency
        });
      }

      debugPrint("📋 Order Items: ${items.length} products");
      debugPrint(
          "💵 Total Price: ${localProductProvider.priceSummary!.netTotal}");
      debugPrint("👤 Customer ID: $selectedCustomerID");
      debugPrint(
          "📱 Customer Phone: ${selectedCustomerPhone ?? mobileNumberText}");
      debugPrint(
          "💳 Payment Details - Paid: ${_paidAmountController.text}, Balance: $_balanceAmount");
      debugPrint("🚚 Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");

      final priceSummary = localProductProvider.priceSummary!;
      debugPrint(
          "🏷️ Discount Data - Flat: ${priceSummary.flatDiscount}, Percentage: ${priceSummary.percentageDiscount}, Total: ${priceSummary.discount}");

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: _transactionNumberController.text,
        totalPrice: priceSummary.netTotal.toString(),
        customerId: selectedCustomerID,
        customerPhone: selectedCustomerPhone ?? mobileNumberText,
        // Always use multi-payment format
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: selectedPaymentMethods,
        paidMethods: _getPaidMethods(),
        balanceAmount: _balanceAmount.toString(),
        comment: _commentController.text,
        deliveryMethodId: deliveryMethodId,
        carNumber: _carNumberController.text,
        status: "confirmed",
        deliveryDate: deliveryDate,
        deliveryTime: deliveryTime,
        // Include discount data
        couponId: isCouponApplied ? coupenCodeTextController.text : null,
        flatDiscount: priceSummary.flatDiscount,
        percentageDiscount: priceSummary.percentageDiscount,
        discountAmount: priceSummary.discount,
        toCustomerCredit: _toCustomerCreditEnabled,
        address: deliveryAddress,
      )
          .then((response) async {
        debugPrint(
            "✅ API RESPONSE - Create Order and Print: ${json.encode(response)}");
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "billing.order_saved_successfully".tr,
          );

          // Delete the current order if it exists in local storage
          if (localProductProvider.currentOrder != null) {
            localProductProvider
                .deleteSavedOrder(localProductProvider.currentOrder!.id);
          }

          // Clear cart without restoring stock (order is confirmed)
          localProductProvider.clearCartAfterOrder();

          try {
            String ordersId = response["order_number"].toString();
            String? accessToken =
                Provider.of<AuthModel>(context, listen: false).token;

            debugPrint(
                "🔍 Fetching order details for print - Order #$ordersId");
            final OrderDetailsresponse = await SalesProvider()
                .listOrderDetails(context, ordersId, accessToken ?? "");
            debugPrint("✅ Order details received for printing");

            OrderDetailsModel orderDetails =
                OrderDetailsModel.fromJson(OrderDetailsresponse);

            String? formattedTotal =
                orderDetails.data?.cart?.priceSummary?.netPayable?.toString() ??
                    orderDetails.data?.cart?.priceSummary?.netTotal.toString();
            String? savedTotal =
                orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

            String storeName = orderDetails.data!.cart!.storeName ?? "";
            String orderDate = orderDetails.data!.orderDate ?? "";

            // Extract new print details
            String? customerAlternatePhone =
                orderDetails.data?.customerDetails?.alternatePhone;
            String? paymentMethod =
                orderDetails.data?.paymentDetails?.paymentMethod ?? 'N/A';

            String? orderComment;
            if (orderDetails.data?.orderProps != null) {
              try {
                final commentProp = orderDetails.data!.orderProps!.firstWhere(
                  (prop) => prop.propsCode == "COMMENT",
                  orElse: () => OrderDetailsModelDataOrderProp(),
                );
                orderComment = commentProp.propsValue;
              } catch (e) {
                // ignore
              }
            }

            // Extract customer details
            String? customerName = orderDetails.data?.customerDetails?.name;
            String? customerPhone = orderDetails.data?.customerDetails?.phone;
            String? customerEmail = orderDetails.data?.customerDetails?.email;
            // Use helper to get address from order_props, fallback to customer details
            String? customerAddress =
                orderDetails.data?.getCustomerAddressFromProps() ??
                    orderDetails.data?.customerDetails?.address?.join(', ');

            // Calculate customer balance for print
            double? oldBalance = selectedCustomer?.balance;
            double totalPaid = _getTotalPaidAmount();
            double? currentBalance;
            if (oldBalance != null) {
              double cartTotal = double.tryParse(formattedTotal!) ?? 0.0;
              // Current balance = Old balance - (Cart Total - Amount Paid)
              // If customer paid less than cart total, their balance decreases (they owe more)
              // If customer paid more than cart total, their balance increases (they have credit)
              currentBalance = oldBalance - (cartTotal - totalPaid);
            }

            debugPrint(
                "🖨️ Navigating to print page for order #${orderDetails.data!.orderNumber}");
            debugPrint(
                "💰 Customer Old Balanceance: $oldBalance, Paid: $totalPaid, Current Balance: $currentBalance");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrintPage(
                  storeName: storeName,
                  cartItems: orderDetails.data!.cart!.cartItems!,
                  formattedTotal: formattedTotal!,
                  savedTotal: savedTotal!,
                  discountAmount:
                      orderDetails.data!.priceSummary?.discount?.toString() ??
                          "0.00",
                  orderDate: DateHelper.formatInputToDisplay(orderDate),
                  orderNumber: orderDetails.data!.orderNumber ?? "",
                  customerName: customerName,
                  customerPhone: customerPhone,
                  customerEmail: customerEmail,
                  customerAddress: customerAddress,
                  customerOldBalance: oldBalance,
                  customerCurrentBalance: currentBalance,
                  paidAmount: totalPaid > 0 ? totalPaid : null,
                  customerAlternatePhone: customerAlternatePhone,
                  paymentMethod: paymentMethod,
                  orderComment: orderComment,
                  isDefaultCustomer: Provider.of<CustomerSelectionProvider>(context, listen: false).isDefaultCustomer,
                  netExcTax: orderDetails.data!.cart!.priceSummary?.netExcTax?.toString(),
                ),
              ),
            );
          } catch (error) {
            debugPrint("❌ Error fetching order details for print: $error");
          }

          // Clear the mobile number after successful save
          setState(() {
            mobileNumberText = ""; // Clear the variable
            selectedCustomerID = null;
            selectedCustomerPhone = null;
            // Remove iconColor reset
            // iconColor = 1; // DELETE THIS LINE
            mobileNumberTextController.clear();
            quantityController.clear();
            barcodeController.clear();
            selectedProductIdController.clear();
            unitPriceController.clear();
            isCustomerFound = false;
            selectedCustomer = null;
            isCouponApplied = false;
            coupenCodeTextController.clear();
            _transactionNumberController.clear();
            _paidAmountController.clear();
            _balanceAmount = 0;
            _carNumberController.clear();
            _commentController.clear();
            deliveryDate = null;
            deliveryTime = null;
            deliveryAddress = null;
          });
          resetAutocomplete(
              shouldFetchCustomers:
                  false); // Preserve customer selection after confirming

          _clearCart();
          _fetchCustomers();
          _focusTextField();
        } else {
          debugPrint("❌ API ERROR - Create Order and Print failed");
          showScaffoldError(
            context: context,
            message: "billing.failed_save_order_api".tr,
            // message: "${addToOrderModel.message}",
          );
        }
      });
    } catch (error) {
      debugPrint("❌ EXCEPTION in _createOrderAndPrint: $error");
    } finally {
      // Set loading to false at the end of the function
      setState(() {
        isLoadingCreateOrder = false; // Indicate that loading has finished
      });
      debugPrint("🏁 Create Order and Print process completed");
    }
  }

  void _confirmOrder() async {
    // Check for internet connection before proceeding
    if (!_hasInternet) {
      showScaffoldError(
        context: context,
        message: "billing.no_internet".tr,
      );
      return; // Stop execution if no internet
    }
    debugPrint("Confirm Order pressed");
    debugPrint("🚀 API REQUEST STARTING - Confirm Order");

    // Auto-show payment modal if never opened
    if (!_hasOpenedPaymentModalOnce) {
      _showPaymentMethodModal(onAfterApply: _confirmOrder);
      return;
    }

    setState(() {
      isLoadingConfirmOrder = true;
    });
    try {
      if (selectedCustomerID == null && mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "billing.select_customer".tr,
        );
        // Auto-focus on customer field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_autocompleteFocusNode != null) {
            FocusScope.of(context).requestFocus(_autocompleteFocusNode!);
          } else {
            FocusScope.of(context).requestFocus(_customerTextFieldFocus);
          }
        });
        return;
      }

      // Get selected payment methods (no longer required - can be empty)
      List<String> selectedPaymentMethods = _getSelectedPaymentMethods();

      if (deliveryMethod == "Car Delivery" && _carNumberController.text == "") {
        showScaffoldError(
          context: context,
          message: "billing.enter_car_number".tr,
        );
        return;
      }

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      // debugPrint("accessToken From AuthModel $accessToken");
      final provider = Provider.of<CartProvider>(context, listen: false);
      int? cartId = provider.getCartIDForOrder;
      debugPrint("📦 Cart ID for order: $cartId");

      String paymentMethod = "";

      if (selectedPaymentMethods.contains("CASH")) {
        paymentMethod = "CASH";
      } else if (selectedPaymentMethods.contains("CARD")) {
        paymentMethod = "CARD";
      } else if (selectedPaymentMethods.contains("UPI")) {
        paymentMethod = "UPI";
      } else if (selectedPaymentMethods.contains("COD")) {
        paymentMethod = "COD";
      } else if (selectedPaymentMethods.contains("DEBIT")) {
        paymentMethod = "DEBIT";
      } else if (selectedPaymentMethods.contains("BALANCE")) {
        paymentMethod = "BALANCE";
      }
      debugPrint("💰 Payment Method: $paymentMethod");

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final cartItems = localProductProvider.cartItems;

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      // Validate that all items have valid pricing before API call
      bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
          item.price == null ||
          item.price! < 0 ||
          item.mrp == null ||
          item.mrp! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message:
              "Please ensure all items have valid prices and MRP before confirming order",
        );
        return;
      }

      List<Map<String, dynamic>> items = [];

      for (var item in cartItems) {
        debugPrint("📦 Order Item: ${item.product.productName}");
        debugPrint("  - Product ID: ${item.product.productId}");
        debugPrint("  - Quantity: ${item.quantity}");
        debugPrint("  - Custom Price: ${item.price}");
        debugPrint("  - Custom MRP: ${item.mrp}");
        debugPrint("  - Stock ID: ${item.selectedStock?.id}");

        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp, // 🔧 FIX: Include custom MRP in API call
          'stock_id': item.selectedStock?.id,
        });
      }

      debugPrint("📋 Order Items: ${items.length} products");
      debugPrint(
          "💵 Total Price: ${localProductProvider.priceSummary!.netTotal}");
      debugPrint("👤 Customer ID: $selectedCustomerID");
      debugPrint(
          "📱 Customer Phone: ${selectedCustomerPhone ?? mobileNumberText}");
      debugPrint(
          "💳 Payment Details - Paid: ${_paidAmountController.text}, Balance: $_balanceAmount");
      debugPrint("🚚 Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: _transactionNumberController.text,
        totalPrice: localProductProvider.priceSummary!.netTotal.toString(),
        customerId: selectedCustomerID,
        customerPhone: selectedCustomerPhone ?? mobileNumberText,
        // Always use multi-payment format
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: selectedPaymentMethods,
        paidMethods: _getPaidMethods(),
        balanceAmount: _balanceAmount.toString(),
        couponId: isCouponApplied ? coupenCodeTextController.text : null,
        comment: _commentController.text,
        deliveryMethodId: deliveryMethodId,
        carNumber: _carNumberController.text,
        status: "confirmed",
        deliveryDate: deliveryDate,
        deliveryTime: deliveryTime,
        // Include discount data
        flatDiscount: localProductProvider.priceSummary!.flatDiscount,
        percentageDiscount:
            localProductProvider.priceSummary!.percentageDiscount,
        discountAmount: localProductProvider.priceSummary!.discount,
        toCustomerCredit: _toCustomerCreditEnabled,
        address: deliveryAddress,
      )
          .then((response) {
        debugPrint("✅ API RESPONSE - Confirm Order: ${json.encode(response)}");
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "billing.order_confirmed_successfully".tr,
          );

          // Delete the current order if it exists in local storage
          if (localProductProvider.currentOrder != null) {
            localProductProvider
                .deleteSavedOrder(localProductProvider.currentOrder!.id);
          }

          // Clear cart without restoring stock (order is confirmed)
          localProductProvider.clearCartAfterOrder();

          // Clear the mobile number after successful save
          setState(() {
            mobileNumberText = ""; // Clear the variable
            selectedCustomerID = null;
            selectedCustomerPhone = null;
            // Remove iconColor reset
            // iconColor = 1; // DELETE THIS LINE
            mobileNumberTextController.clear();
            quantityController.clear();
            barcodeController.clear();
            selectedProductIdController.clear();
            unitPriceController.clear();
            isCustomerFound = false;
            selectedCustomer = null;
            isCouponApplied = false;
            coupenCodeTextController.clear();
            _transactionNumberController.clear();
            _paidAmountController.clear();
            _balanceAmount = 0;
            _carNumberController.clear();
            _commentController.clear();
            deliveryDate = null;
            deliveryTime = null;
            deliveryAddress = null;
          });
          resetAutocomplete(
              shouldFetchCustomers:
                  false); // Preserve customer selection after confirming

          _fetchCustomers();
          _clearCart();
        } else {
          debugPrint("❌ API ERROR - Confirm Order failed");
          showScaffoldError(
            context: context,
            message: "billing.order_failed".tr,
          );
        }
      });
      _focusTextField();
    } catch (error) {
      debugPrint("❌ EXCEPTION in _confirmOrder: $error");
    } finally {
      // Set loading to false at the end of the function
      setState(() {
        isLoadingConfirmOrder = false; // Indicate that loading has finished
      });
      debugPrint("🏁 Confirm Order process completed");
    }
  }

  // Multi-payment helper methods
  Map<String, String> _getPaymentMethodData() {
    List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
    String paymentMethod = "";
    String paidAmount = "";

    // Get payment method IDs from BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final cashId = billingProvider.cashPaymentMethodId ?? "CASH";
    final cardId = billingProvider.cardPaymentMethodId ?? "CARD";
    final upiId = billingProvider.upiPaymentMethodId ?? "UPI";
    final codId = billingProvider.codPaymentMethodId ?? "COD";

    if (selectedPaymentMethods.length > 1) {
      // Multi-payment: store as JSON with IDs as keys
      Map<String, dynamic> multiPaymentData = {
        "methods": selectedPaymentMethods,
        "amounts": {
          cashId: _cashAmountController.text.isNotEmpty
              ? _cashAmountController.text
              : "0",
          cardId: _cardAmountController.text.isNotEmpty
              ? _cardAmountController.text
              : "0",
          upiId: _upiAmountController.text.isNotEmpty
              ? _upiAmountController.text
              : "0",
          codId: _codAmountController.text.isNotEmpty
              ? _codAmountController.text
              : "0",
        },
        "isMultiPayment": true
      };
      paymentMethod = json.encode(multiPaymentData);
      paidAmount = _getTotalPaidAmount().toString();
    } else {
      // Single payment method
      if (selectedPaymentMethods.isNotEmpty) {
        paymentMethod = selectedPaymentMethods.first;
        // Check by comparing with the stored IDs
        if (paymentMethod == cashId) {
          paidAmount = _cashAmountController.text;
        } else if (paymentMethod == cardId) {
          paidAmount = _cardAmountController.text;
        } else if (paymentMethod == upiId) {
          paidAmount = _upiAmountController.text;
        } else if (paymentMethod == codId) {
          paidAmount = _codAmountController.text;
        } else {
          // Fallback for legacy string checks
          if (_isCashSelected) {
            paidAmount = _cashAmountController.text;
          } else if (_isCardSelected) {
            paidAmount = _cardAmountController.text;
          } else if (_isUpiSelected) {
            paidAmount = _upiAmountController.text;
          } else if (_isCodSelected) {
            paidAmount = _codAmountController.text;
          }
        }
      } else {
        // No payment method selected - leave empty
        paymentMethod = "";
        paidAmount = "0";
      }
    }

    return {
      "paymentMethod": paymentMethod,
      "paidAmount": paidAmount,
    };
  }

  // Helper method to calculate balance using the same logic as the modal
  double _calculateBalanceAmount() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
    double cartTotal = localProductProvider.cartTotal;

    // For balance calculation, only include actual cash payments (not debit/store credit)
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(_upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(_codAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount + codAmount;

    double balance = 0.0;

    if (_toCustomerCreditEnabled) {
      debugPrint(
          '🔛 BILLING PAGE: Toggle is ON - Calculating with customer credit consideration');

      double customerPrevBalance = selectedCustomer?.balance ?? 0.0;

      if (customerPrevBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalCollected - cartTotal;
        debugPrint(
            '💰 Transaction excess: $currency${transactionExcess.toStringAsFixed(2)}');

        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit =
              double.tryParse(_debitAmountController.text) ?? 0.0;

          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            debugPrint(
                '  - Clamped customer credit to transaction excess: $currency${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = transaction excess - customer credit
          balance = transactionExcess - actualCustomerCredit;
          debugPrint(
              '  - Balance = Transaction Excess ($currency${transactionExcess.toStringAsFixed(2)}) - Customer Credit ($currency${actualCustomerCredit.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
        } else {
          balance = 0.0;
          debugPrint('  - No transaction excess, balance = 0');
        }
      } else {
        // Customer has positive/zero balance - use Net Due logic
        debugPrint('💵 Customer has credit/zero balance - using Net Due logic');
        // Net Due = Purchase Total - Customer Previous Balance
        double netDue = cartTotal - customerPrevBalance;
        debugPrint('💰 Net Due calculation:');
        debugPrint(
            '  - Purchase Total: $currency${cartTotal.toStringAsFixed(2)}');
        debugPrint(
            '  - Customer Prev Balance: $currency${customerPrevBalance.toStringAsFixed(2)}');
        debugPrint('  - Net Due: $currency${netDue.toStringAsFixed(2)}');

        // Available balance = Total Collected - Net Due
        double availableBalance = totalCollected - netDue;
        debugPrint(
            '  - Total Collected: $currency${totalCollected.toStringAsFixed(2)}');
        debugPrint(
            '  - Available Balance: $currency${availableBalance.toStringAsFixed(2)}');

        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit =
              double.tryParse(_debitAmountController.text) ?? 0.0;

          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            debugPrint(
                '  - Clamped customer credit to available balance: $currency${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = available balance - customer credit
          balance = availableBalance - actualCustomerCredit;
          debugPrint(
              '  - Balance = Available Balance ($currency${availableBalance.toStringAsFixed(2)}) - Customer Credit ($currency${actualCustomerCredit.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
        } else {
          balance = 0.0;
          debugPrint('  - No available balance, balance = 0');
        }
      }
    } else {
      debugPrint('🔴 BILLING PAGE: Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      balance = totalCollected - cartTotal;
      debugPrint(
          '  - Balance = Total Collected ($currency${totalCollected.toStringAsFixed(2)}) - Cart Total ($currency${cartTotal.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
    }

    // Clamp balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (balance < 0) {
      debugPrint(
          '🚫 BILLING PAGE: Clamping negative balance ($currency${balance.toStringAsFixed(2)}) to 0 for UI display');
      balance = 0.0;
    }

    return balance;
  }

  void _updateBalanceAmount() {
    double balance = _calculateBalanceAmount();

    setState(() {
      _balanceAmount = balance;
    });
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(_upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(_codAmountController.text) ?? 0.0;
    // Note: We don't include debit/toCustomerCredit in total paid amount
    // as it represents money going to customer credit, not money collected
    return cashAmount + cardAmount + upiAmount + codAmount;
  }

  List<String> _getSelectedPaymentMethods() {
    List<String> methods = [];

    // Get payment method IDs from BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      // Use payment method ID if available, otherwise fallback to string
      methods.add(billingProvider.cashPaymentMethodId ?? "CASH");
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      methods.add(billingProvider.cardPaymentMethodId ?? "CARD");
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      methods.add(billingProvider.upiPaymentMethodId ?? "UPI");
    }
    if (_isCodSelected &&
        (double.tryParse(_codAmountController.text) ?? 0) > 0) {
      methods.add(billingProvider.codPaymentMethodId ?? "COD");
    }
    // if (_isDebitSelected &&
    //     (double.tryParse(_debitAmountController.text) ?? 0) > 0) {
    //   methods.add("DEBIT");
    // }
    return methods;
  }

  List<Map<String, dynamic>> _getPaidMethods() {
    List<Map<String, dynamic>> paidMethods = [];

    // Get payment method IDs from BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        // Use payment method ID if available, otherwise fallback to string
        "method": billingProvider.cashPaymentMethodId ?? "CASH",
        "amount": double.tryParse(_cashAmountController.text) ?? 0,
      });
    }

    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": billingProvider.cardPaymentMethodId ?? "CARD",
        "amount": double.tryParse(_cardAmountController.text) ?? 0,
      });
    }

    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": billingProvider.upiPaymentMethodId ?? "UPI",
        "amount": double.tryParse(_upiAmountController.text) ?? 0,
      });
    }

    if (_isCodSelected &&
        (double.tryParse(_codAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": billingProvider.codPaymentMethodId ?? "COD",
        "amount": double.tryParse(_codAmountController.text) ?? 0,
      });
    }

    // if (_isDebitSelected &&
    //     (double.tryParse(_debitAmountController.text) ?? 0) > 0) {
    //   paidMethods.add({
    //     "method": "DEBIT",
    //     "amount": double.tryParse(_debitAmountController.text) ?? 0,
    //   });
    // }
    return paidMethods;
  }

  Widget _buildQuickAccessIcons() {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final currency = appSettingsProvider.appSettings?.currency ?? '';
        double totalPaid = _getTotalPaidAmount();
        double cartTotal = localProductProvider.cartTotal;
        // For balance calculation, only include actual cash payments (not debit/store credit)
        double cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
        double cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;
        double upiAmount = double.tryParse(_upiAmountController.text) ?? 0.0;
        double codAmount = double.tryParse(_codAmountController.text) ?? 0.0;
        double actualCashPaid = cashAmount + cardAmount + upiAmount + codAmount;

        // Use the helper method for consistent balance calculation
        double balance = _calculateBalanceAmount();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 5),
                // Payment Method Icon
                _buildQuickAccessIcon(
                  icon: _getPaymentIcon(),
                  label: _getPaymentLabel(),
                  color: ColorManager.kPrimaryColor,
                  onTap: () => _showPaymentMethodModal(),
                ),
                const SizedBox(width: 12),
                // Delivery Method Icon
                _buildQuickAccessIcon(
                  icon: deliveryMethod == "Store Takeaway"
                      ? Icons.store
                      : deliveryMethod == "Car Delivery"
                          ? Icons.car_rental
                          : deliveryMethod == "Door Delivery"
                              ? Icons.doorbell_outlined
                              : Icons.local_shipping,
                  label: _getDeliveryMethodLabel(),
                  color: ColorManager.kButtonBlue,
                  onTap: () => _showDeliveryMethodModal(),
                ),
                const SizedBox(width: 12),
                // Coupon Icon
                Consumer<AppSettingsProvider>(
                    builder: (context, appSettingsProvider, child) {
                  // Debug logging for coupon button visibility
                  debugPrint('🎫 COUPON BUTTON DEBUG:');
                  debugPrint(
                      '  - appSettingsProvider.appSettings: ${appSettingsProvider.appSettings}');
                  if (appSettingsProvider.appSettings != null) {
                    debugPrint(
                        '  - discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}');
                    debugPrint(
                        '  - All app settings: ${appSettingsProvider.appSettings.toString()}');

                    // More detailed debugging
                    debugPrint(
                        '  - AppSettings runtimeType: ${appSettingsProvider.appSettings.runtimeType}');
                    debugPrint('  - AppSettings properties:');
                    try {
                      // Use reflection to see all properties
                      final settings = appSettingsProvider.appSettings!;
                      debugPrint(
                          '    - barcodeSales: ${settings.barcodeSales}');
                      debugPrint(
                          '    - discountAndCoupon: ${settings.discountAndCoupon}');
                      debugPrint(
                          '    - priceRoundOff: ${settings.priceRoundOff}');
                      // Add other properties you know exist
                    } catch (e) {
                      debugPrint('    - Error accessing properties: $e');
                    }
                  } else {
                    debugPrint('  - appSettings is NULL');
                  }

                  if (appSettingsProvider.appSettings == null ||
                      !appSettingsProvider.appSettings!.discountAndCoupon) {
                    debugPrint(
                        '  - ❌ Hiding coupon button (settings null or discountAndCoupon disabled)');
                    return Container();
                  }

                  debugPrint('  - ✅ Showing coupon button');
                  return _buildQuickAccessIcon(
                    icon: isCouponApplied
                        ? Icons.discount
                        : Icons.local_offer_outlined,
                    label: isCouponApplied
                        ? 'billing.applied_label'.tr
                        : 'billing.discount_label'.tr,
                    color: isCouponApplied
                        ? ColorManager.kButtonGreen
                        : ColorManager.kButtonYellow,
                    onTap: () => _showCouponModal(),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Payment Summary in minimized view
            Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${'billing.total_paid'.tr}: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s15,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        '$currency ${totalPaid.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.14,
                          ColorManager.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text(
                        '${'billing.balance'.tr}: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s15,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        '$currency ${balance.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.14,
                          balance > 0
                              ? ColorManager.kButtonGreen
                              : ColorManager.textColorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getPaymentIcon() {
    List<String> activeMethods = [];
    if (_isCashSelected) {
      activeMethods.add('Cash');
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      activeMethods.add('Card');
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      activeMethods.add('UPI');
    }
    if (_isCodSelected &&
        (double.tryParse(_codAmountController.text) ?? 0) > 0) {
      activeMethods.add('COD');
    }

    if (activeMethods.length > 1) {
      return Icons.account_balance_wallet; // Multiple payment methods
    } else if (activeMethods.contains('Cash')) {
      return Icons.payments;
    } else if (activeMethods.contains('Card')) {
      return Icons.credit_card;
    } else if (activeMethods.contains('UPI')) {
      return Icons.phone_android;
    } else if (activeMethods.contains('COD')) {
      return Icons.local_shipping;
    }
    return Icons.payment; // Default
  }

  String _getPaymentLabel() {
    List<String> activeMethods = [];
    if (_isCashSelected) {
      activeMethods.add('billing.cash'.tr);
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      activeMethods.add('billing.card'.tr);
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      activeMethods.add('billing.upi'.tr);
    }
    if (_isCodSelected &&
        (double.tryParse(_codAmountController.text) ?? 0) > 0) {
      activeMethods.add('billing.cod'.tr);
    }

    if (activeMethods.length > 1) {
      return 'billing.multi'.tr; // Multiple payment methods
    } else if (activeMethods.length == 1) {
      return activeMethods.first;
    }
    return 'billing.payment_tab'.tr; // Default
  }

  String _getDeliveryMethodLabel() {
    // Map delivery method names to translation keys
    switch (deliveryMethod) {
      case "Store Takeaway":
        return 'common.store_takeaway'.tr;
      case "Car Delivery":
        return 'common.car_delivery'.tr;
      case "Door Delivery":
        return 'common.door_delivery'.tr;
      case "Third Party Logistics":
        return 'common.third_party_logistics'.tr;
      default:
        return deliveryMethod.tr;
    }
  }

  Widget _buildQuickAccessIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        blurRadius: 4,
        circleRadius: 5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.14,
                color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodModal(
      {VoidCallback? onAfterApply, String? customButtonTitle}) {
    // _hasOpenedPaymentModalOnce = true; // Moved to onPaymentMethodSelected to ensure it only sets when user actually applies
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    // Prepare initial amounts
    String initialCash = _cashAmountController.text;
    String initialCard = _cardAmountController.text;
    String initialUpi = _upiAmountController.text;
    String initialCod = _codAmountController.text;
    String initialDebit = _debitAmountController.text;

    // Check if any amount is already entered
    bool hasAnyAmount = (double.tryParse(initialCash) ?? 0) > 0 ||
        (double.tryParse(initialCard) ?? 0) > 0 ||
        (double.tryParse(initialUpi) ?? 0) > 0 ||
        (double.tryParse(initialCod) ?? 0) > 0 ||
        (double.tryParse(initialDebit) ?? 0) > 0;

    // If no amount is entered yet, auto-fill the selected method with the full total
    if (!hasAnyAmount && localProductProvider.cartTotal > 0) {
      String totalStr = localProductProvider.cartTotal.toStringAsFixed(2);
      if (_isCashSelected) {
        initialCash = totalStr;
      } else if (_isCardSelected) {
        initialCard = totalStr;
      } else if (_isUpiSelected) {
        initialUpi = totalStr;
      } else if (_isCodSelected) {
        initialCod = totalStr;
      } else if (_isDebitSelected) {
        initialDebit = totalStr;
      } else {
        // Fallback: If nothing selected (shouldn't happen with defaults, but safety), default to Cash
        initialCash = totalStr;
        // We might need to set the flag too, but the modal takes initialIsCashSelected
      }
    }

    // Legacy fallback logic (kept for safety, though covered above)
    bool autoSelectCash = _isCashSelected;
    if (!_isCashSelected &&
        !_isCardSelected &&
        !_isUpiSelected &&
        !_isCodSelected &&
        !_isDebitSelected) {
      autoSelectCash = true;
      if (initialCash.isEmpty || double.tryParse(initialCash) == 0) {
        initialCash = localProductProvider.cartTotal.toStringAsFixed(2);
      }
    }

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: autoSelectCash,
        initialIsCardSelected: _isCardSelected,
        initialIsUpiSelected: _isUpiSelected,
        initialIsCodSelected: _isCodSelected,
        initialIsDebitSelected: _isDebitSelected,
        initialCashAmount: initialCash,
        initialCardAmount: initialCard,
        initialUpiAmount: initialUpi,
        initialCodAmount: initialCod,
        initialDebitAmount: initialDebit,
        initialTransactionNumber: _transactionNumberController.text,
        cartTotal: localProductProvider.cartTotal,
        customerPrevBalance: selectedCustomer?.balance ?? 0.0,
        onAfterApply: onAfterApply,
        customButtonTitle: customButtonTitle,
        onPaymentMethodSelected: (
          isCash,
          isCard,
          isUpi,
          isCod,
          isDebit,
          cashAmount,
          cardAmount,
          upiAmount,
          codAmount,
          debitAmount,
          transactionNumber,
          toCustomerCredit, {
          String? cashMethodId,
          String? cardMethodId,
          String? upiMethodId,
          String? codMethodId,
        }) {
          setState(() {
            _hasOpenedPaymentModalOnce = true; // Set flag here to indicate user manually made a selection (even if None)
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _isCodSelected = isCod;
            _isDebitSelected = isDebit;
            _cashAmountController.text = cashAmount;
            _cardAmountController.text = cardAmount;
            _upiAmountController.text = upiAmount;
            _codAmountController.text = codAmount;
            _debitAmountController.text = debitAmount;
            _transactionNumberController.text = transactionNumber;
            _toCustomerCreditEnabled = toCustomerCredit;

            // Update balance amount using the same calculation logic as the modal
            _updateBalanceAmount();
          });

          // Store payment method IDs in BillingProvider for later use
          final billingProvider =
              Provider.of<BillingProvider>(context, listen: false);
          billingProvider.updatePaymentFromModal(
            isCash: isCash,
            isCard: isCard,
            isUpi: isUpi,
            isCod: isCod,
            isDebit: isDebit,
            cashAmount: cashAmount,
            cardAmount: cardAmount,
            upiAmount: upiAmount,
            codAmount: codAmount,
            debitAmount: debitAmount,
            transactionNumber: transactionNumber,
            toCustomerCredit: toCustomerCredit,
            cashMethodId: cashMethodId,
            cardMethodId: cardMethodId,
            upiMethodId: upiMethodId,
            codMethodId: codMethodId,
          );
        },
      ),
    );
  }

  void _showDeliveryMethodModal() {
    showDialog(
      context: context,
      builder: (context) => DeliveryMethodModal(
        initialDeliveryMethod: deliveryMethod,
        initialDeliveryMethodId: deliveryMethodId,
        initialCarNumber: _carNumberController.text,
        initialComment: _commentController.text,
        initialDeliveryDate: deliveryDate,
        initialDeliveryTime: deliveryTime,
        initialAddress: deliveryAddress ?? "", // Pass initial address
        onDeliveryMethodSelected: (method, methodId, carNumber, comment,
            selectedDate, selectedTime, address) {
          setState(() {
            deliveryMethod = method;
            deliveryMethodId = methodId;
            _carNumberController.text = carNumber;
            _commentController.text = comment;
            deliveryDate = selectedDate;
            deliveryTime = selectedTime;
            deliveryAddress = address; // Update address
          });
        },
      ),
    );
  }

  void _showCouponModal() {
    debugPrint('🎫 _showCouponModal called');
    debugPrint(
        '  - Current app settings: ${Provider.of<AppSettingsProvider>(context, listen: false).appSettings}');
    debugPrint(
        '  - discountAndCoupon enabled: ${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.discountAndCoupon}');

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    showDialog(
      context: context,
      builder: (context) => CouponModal(
        subTotal: localProductProvider.subTotalBeforeDiscount,
        initialFlatDiscount: currentDiscounts['flatDiscount'],
        initialPercentageDiscount: currentDiscounts['percentageDiscount'],
        initialCouponCode: coupenCodeTextController.text,
        isCouponApplied: isCouponApplied,
        onCouponAction: (couponCode, shouldApply,
            {double? flatDiscount, double? percentageDiscount}) async {
          if (shouldApply) {
            // Apply coupon to API first if provided
            if (couponCode.isNotEmpty) {
              await _applyCoupon();
            }

            // Then apply manual discounts to local product provider
            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);
            localProductProvider.applyDiscount(
              flatDiscount: flatDiscount ?? 0.0,
              percentageDiscount: percentageDiscount ?? 0.0,
            );

            coupenCodeTextController.text = couponCode;

            setState(() {
              isCouponApplied = true;
            });
          } else {
            // Clear all discounts
            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);
            localProductProvider.clearDiscount();

            setState(() {
              isCouponApplied = false;
              coupenCodeTextController.clear();

              // Fetch the cart data again after removing the coupon
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;
              int? customerId =
                  Provider.of<AuthModel>(context, listen: false).userId;

              Provider.of<CartProvider>(context, listen: false)
                  .fetchCartDataFromApi(
                customerId: customerId!,
                accessToken: accessToken ?? '',
              );
            });
          }
        },
      ),
    );
  }

  Future<void> _applyCoupon() async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

    if (localProductProvider.priceSummary == null) {
      showScaffoldError(
        context: context,
        message: 'Cart is empty or data not available',
      );
      return;
    }

    double? totalAmount = localProductProvider.priceSummary!.netTotal;
    String couponCode = coupenCodeTextController.text;

    if (accessToken != null && totalAmount != null) {
      final result =
          await Provider.of<CartProvider>(context, listen: false).applyCoupon(
        totalAmount: totalAmount,
        couponCode: couponCode,
        accessToken: accessToken,
      );

      if (result != null) {
        // Check if the response indicates success
        if (result['success'] == true) {
          final couponData = result['data']['data'];
          double discountAmount = double.parse(couponData['discount_amount']
              .replaceAll(',', '')); // Convert discount amount to double
          double discountedTotal = totalAmount - discountAmount;

          // Update the price summary with the new values
          Provider.of<CartProvider>(context, listen: false).updatePriceSummary(
            discountAmount: discountAmount,
            discountedTotal: discountedTotal,
          );

          setState(() {
            isCouponApplied = true;
          });

          showScaffold(
            context: context,
            message: result['message'] ?? 'Coupon Applied Successfully',
          );
        } else {
          // Handle failure to apply coupon
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'Failed to Apply Coupon',
          );
        }
      } else {
        // Handle case where result is null
        showScaffoldError(
          context: context,
          message: 'billing.error_occurred'.tr,
        );
      }
    } else {
      // Handle unauthenticated state
      showScaffoldError(
          context: context, message: 'billing.not_authenticated'.tr);
    }
  }

  void resetAutocomplete({bool shouldFetchCustomers = true}) {
    debugPrint(
        "🔄 resetAutocomplete called - shouldFetchCustomers: $shouldFetchCustomers");
    debugPrint("  - _isCustomerManuallySelected: $_isCustomerManuallySelected");
    debugPrint("  - mobileNumberText: '$mobileNumberText'");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

    setState(() {
      _autocompleteProductKey = GlobalKey();
      isCustomerFound = false;

      // Only fetch customers if requested AND no customer was manually selected
      if (shouldFetchCustomers && !_isCustomerManuallySelected) {
        debugPrint(
            "  - Calling _fetchCustomers() because no manual selection detected");
        _fetchCustomers();
      } else if (shouldFetchCustomers && _isCustomerManuallySelected) {
        debugPrint(
            "  - Skipping _fetchCustomers() because customer was manually selected");
      }

      deliveryMethodId = _getDefaultDeliveryMethodId();

      // Find name for the ID
      String defaultName = "Store Takeaway";
      try {
        final deliveryMethodsProvider =
            Provider.of<DeliveryMethodsProvider>(context, listen: false);
        if (deliveryMethodsProvider.deliveryMethods.isNotEmpty) {
          final match = deliveryMethodsProvider.deliveryMethods.firstWhere(
              (m) => m.id == deliveryMethodId,
              orElse: () => deliveryMethodsProvider.deliveryMethods.first);
          defaultName = match.name;
        }
      } catch (e) {
        // fallback
      }
      deliveryMethod = defaultName;
      // Remove iconColor reset
      // iconColor = 1; // DELETE THIS LINE
    });
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  void printFromSavedOrder(SavedOrder savedOrder) {
    try {
      // Extract cart items from the saved order
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;

      // Convert SavedOrder items to the format expected by PrintPage
      for (var item in savedOrder.items) {
        // Calculate individual item values
        double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        double itemTotalPrice = itemPrice * item.quantity;

        // Add to totals for "You Saved" calculation
        totalMRP += itemMrp * item.quantity;
        netTotal += itemTotalPrice;

        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': itemMrp.toString(),
          'quantity': item.quantity.toString(),
          'unitPrice': itemPrice.toString(),
          'totalPrice': itemTotalPrice.toString(),
        });
      }

      // 🔧 FIX: Calculate "You Saved" using Option 3 approach
      double youSaved = totalMRP - netTotal;
      youSaved = youSaved > 0 ? youSaved : 0.0; // Ensure non-negative

      // Debug - check what's being sent
      debugPrint("🖨️ BILLING SAVE AND PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - You Saved: $youSaved");
      debugPrint("Sending ${cartItems.length} items to PrintPage");
      debugPrint(
          "Sample item: ${cartItems.isNotEmpty ? json.encode(cartItems[0]) : 'No items'}");

      // Get active store name
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final storeName = storeSession.activeStore?.storeName ?? "Store";

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: cartItems,
            formattedTotal: netTotal.toString(), // Use calculated net total
            savedTotal:
                youSaved.toString(), // 🔧 FIX: Use calculated "You Saved"
            discountAmount: savedOrder.flatDiscount != null ||
                    savedOrder.percentageDiscount != null
                ? ((savedOrder.flatDiscount ?? 0.0) +
                        ((savedOrder.percentageDiscount ?? 0.0) > 0
                            ? (savedOrder.total *
                                (savedOrder.percentageDiscount ?? 0.0) /
                                100)
                            : 0.0))
                    .toString()
                : "0.00",
            orderDate: savedOrder.createdAt,
            orderNumber: savedOrder.orderNumber,
            isFromLocalStorage: true,
            customerName: savedOrder.customerName,
            customerPhone: savedOrder.customerPhone,
            paymentMethod: savedOrder.paymentMethod,
            customerAlternatePhone: savedOrder.alternatePhone,
            orderComment: savedOrder.comment,
            paidAmount: (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0) > 0
                ? (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0)
                : null,
            // Balance info not available for offline saved orders
            // Check if this is a default customer based on the app settings
            isDefaultCustomer: _isDefaultCustomerPhone(savedOrder.customerPhone),
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error printing saved order: ${error.toString()}");
      showScaffoldError(
        context: context,
        message: "billing.failed_print_order".tr,
      );
    }
  }

  /// Helper method to check if a phone number matches the default customer phone from app settings
  bool _isDefaultCustomerPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  // Function to scroll to the highlighted customer in the dropdown
  void _scrollToHighlightedCustomer() {
    if (_highlightedCustomerIndex == null) return;

    // Calculate the offset to scroll to
    final double scrollOffset =
        _highlightedCustomerIndex! * _customerItemHeight;

    // Get the current scroll position and visible height
    final double currentScroll = _customerScrollController.offset;
    const double visibleHeight =
        180.0; // Approximate visible height of dropdown

    // Adding buffer space to ensure the item is fully visible
    const double bufferSpace = 4.0;

    // Check if item is already visible
    if (scrollOffset < currentScroll + bufferSpace) {
      // Item is above visible area or partially visible at the top - scroll up to it
      _customerScrollController.animateTo(
        scrollOffset > 0 ? scrollOffset - bufferSpace : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (scrollOffset + _customerItemHeight >
        currentScroll + visibleHeight - bufferSpace) {
      // Item is below visible area or partially visible at bottom - scroll down to it
      _customerScrollController.animateTo(
        scrollOffset - visibleHeight + _customerItemHeight + bufferSpace,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
    // If item is already fully visible, do nothing
  }

  // Function to handle sales executive changes
  void _onSalesExecutiveChanged() {
    debugPrint(
        "🔄 BILLING: Sales executive changed, updating default customer...");

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
    if (_isCustomerManuallySelected &&
        (selectedCustomerID != null || mobileNumberText?.isNotEmpty == true)) {
      debugPrint("🛡️ Customer manually selected, skipping reset");
      debugPrint("  - selectedCustomerID: $selectedCustomerID");
      debugPrint("  - mobileNumberText: '$mobileNumberText'");
      return;
    }

    // Clear current customer selection
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    // Reset billing page customer state
    setState(() {
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey(); // Reset autocomplete
      _isCustomerManuallySelected = false;
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
      deliveryMethod = "Store Takeaway";
      deliveryMethodId = _getDefaultDeliveryMethodId();

      // Clear all controllers
      coupenCodeTextController.clear();
      _transactionNumberController.clear();
      _paidAmountController.clear();
      _carNumberController.clear();
      _commentController.clear();

      deliveryDate = null;
      deliveryTime = null;

      // Reset other flags
      isCouponApplied = false;
      _balanceAmount = 0;

      // Clear product entry fields
      quantityController.clear();
      barcodeController.clear();
      selectedProductIdController.clear();
      unitPriceController.clear();
      selectedProductNameController.clear();

      // Reset autocomplete keys
      _autocompletePhoneKey = GlobalKey();
      _autocompleteProductKey = GlobalKey();
    });

    _onSalesExecutiveChanged();
    resetAutocomplete();
  }

  // Public method to save current order (for external calls)
  Future<void> saveCurrentOrder() async {
    debugPrint("===== PUBLIC SAVE CURRENT ORDER START =====");
    debugPrint("💾 BILLING: Public method called - saving current order...");
    debugPrint("📝 Current customer state:");
    debugPrint(
        "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
    debugPrint("  - mobileNumberText: '$mobileNumberText'");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
    debugPrint("  - selectedCustomerID: $selectedCustomerID");
    debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
    debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
    debugPrint("  - isCustomerFound: $isCustomerFound");
    debugPrint("  - Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");
    debugPrint("  - Comment: '${_commentController.text}'");
    debugPrint(
        "  - Cart Items: ${Provider.of<LocalProductProvider>(context, listen: false).cartItems.length}");
    await _saveOrder();
    debugPrint("===== PUBLIC SAVE CURRENT ORDER END =====");
  }

  void _onUserSwitched() {
    debugPrint("🔄 BILLING: User switched, updating default customer...");

    // Check if auto-assign is enabled in app settings
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final bool autoAssignEnabled =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomer ?? true;

    if (!autoAssignEnabled) {
      debugPrint(
          "🔧 APP SETTINGS: Auto-assign default customer is DISABLED, skipping user switch");
      return;
    }

    // Clear current customer selection
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    // Reset billing page customer state
    setState(() {
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey(); // Reset autocomplete
    });

    // Re-fetch customers to set new default based on new executive
    _fetchCustomers();
  }

  void _initializeDeliveryMethod() {
    // Set initial default values
    deliveryMethod = "Store Takeaway";
    deliveryMethodId = "11"; // Updated to match API response

    // Listen for delivery methods to be loaded and update default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);

      void updateDeliveryMethod() {
        if (!deliveryMethodsProvider.isLoading &&
            deliveryMethodsProvider.deliveryMethods.isNotEmpty) {
          // 1. Try App Settings Default
          final appSettingsDefault =
              appSettingsProvider.appSettings?.defaultDeliveryMethod;
          if (appSettingsDefault != null && appSettingsDefault.isNotEmpty) {
            try {
              // Try to match by name or ID
              final match = deliveryMethodsProvider.deliveryMethods.firstWhere(
                (m) =>
                    m.name.toLowerCase() == appSettingsDefault.toLowerCase() ||
                    m.id == appSettingsDefault,
              );

              // Only update if different to avoid unnecessary rebuilds
              if (deliveryMethod != match.name ||
                  deliveryMethodId != match.id) {
                setState(() {
                  deliveryMethod = match.name;
                  deliveryMethodId = match.id;
                });
                debugPrint(
                    "🚚 Set delivery method from AppSettings: ${match.name} (ID: ${match.id})");
              }
              return; // Found match in AppSettings, skip provider default
            } catch (e) {
              debugPrint(
                  "🚚 AppSettings default '$appSettingsDefault' not found in delivery methods");
            }
          }

          // 2. Fallback to DeliveryMethodsProvider default
          final defaultMethod = deliveryMethodsProvider.defaultDeliveryMethod;
          if (defaultMethod != null) {
            // Only update if different
            if (deliveryMethod != defaultMethod.name ||
                deliveryMethodId != defaultMethod.id) {
              setState(() {
                deliveryMethod = defaultMethod.name;
                deliveryMethodId = defaultMethod.id;
              });
              debugPrint(
                  "🚚 Updated default delivery method from Provider: ${defaultMethod.name} (ID: ${defaultMethod.id})");
            }
          }
        }
      }

      // Add listeners
      deliveryMethodsProvider.addListener(updateDeliveryMethod);
      appSettingsProvider.addListener(updateDeliveryMethod);

      // Initial check
      updateDeliveryMethod();
    });
  }

  void _initializePaymentMethod() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);

      void updatePaymentMethod() {
        setState(() {
          _applyDefaultPaymentMethod();
        });
      }

      appSettingsProvider.addListener(updatePaymentMethod);
      updatePaymentMethod();
    });
  }

  void _applyDefaultPaymentMethod() {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);

    // Only set default if no method is currently selected
    if (_isCashSelected ||
        _isCardSelected ||
        _isUpiSelected ||
        _isCodSelected ||
        _isDebitSelected) {
      return;
    }

    final defaultPayment =
        appSettingsProvider.appSettings?.defaultPaymentMethod;
    if (defaultPayment != null && defaultPayment.isNotEmpty) {
      debugPrint("💰 Applying default payment method: $defaultPayment");
      _isCashSelected = defaultPayment.toUpperCase() == 'CASH';
      _isCardSelected = defaultPayment.toUpperCase() == 'CARD';
      _isUpiSelected = defaultPayment.toUpperCase() == 'UPI';
      _isCodSelected = defaultPayment.toUpperCase() == 'COD';
    }
  }

  String _getDefaultDeliveryMethodId() {
    try {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);

      // 1. Check AppSettings
      final appSettingsDefault =
          appSettingsProvider.appSettings?.defaultDeliveryMethod;
      if (appSettingsDefault != null && appSettingsDefault.isNotEmpty) {
        try {
          final match = deliveryMethodsProvider.deliveryMethods.firstWhere((m) =>
              m.name.toLowerCase() == appSettingsDefault.toLowerCase() ||
              m.id == appSettingsDefault);
          return match.id;
        } catch (e) {
          // Not found
        }
      }

      final defaultMethod = deliveryMethodsProvider.defaultDeliveryMethod;
      return defaultMethod?.id ??
          "11"; // Fallback to Store Takeaway ID from API
    } catch (e) {
      return "11"; // Fallback to Store Takeaway ID from API
    }
  }
}
