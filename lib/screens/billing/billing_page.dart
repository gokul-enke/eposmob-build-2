import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/helpers/system_keyboard_policy.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_purchase_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/keyboard_focus_highlight_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/billing/utils/billing_focus_orders.dart';
import 'package:pos_machine/services/cash_drawer_service.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/services/quotation_print_service.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/checkout_footer.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/horizontal_saved_orders_view.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:pos_machine/widgets/customer_purchase_history_modal.dart';
import 'package:pos_machine/widgets/live_clock.dart';
import 'package:pos_machine/widgets/open_cash_drawer_button.dart';
import 'package:provider/provider.dart';

import 'package:websafe_svg/websafe_svg.dart';

// Import modals
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/screens/billing/widgets/checkout_modal.dart';
import 'package:pos_machine/screens/billing/widgets/payment_method_modal.dart';
import 'package:pos_machine/screens/billing/widgets/delivery_method_modal.dart';
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/price_fields.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';
import 'package:pos_machine/screens/billing/widgets/keyboard_shortcuts_help_dialog.dart';

enum CheckoutActionMode { confirm, save, quotation }

enum BillingPageMode { normal, quotation }

class _CartUnitMenuOption {
  final String value;
  final String label;

  const _CartUnitMenuOption({
    required this.value,
    required this.label,
  });
}

class BillingPage extends StatefulWidget {
  final BillingPageMode mode;

  const BillingPage({
    super.key,
    this.mode = BillingPageMode.normal,
  });

  @override
  State<BillingPage> createState() => BillingPageState();
}

class BillingPageState extends State<BillingPage>
    with AutomaticKeepAliveClientMixin {
  bool get _isQuotationPage => widget.mode == BillingPageMode.quotation;

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
  GlobalKey<ProductAutocompleteState> _productAutocompleteKey = GlobalKey();

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
  bool isLoadingCreateNewOrder = false;
  bool isLoadingRestoreSavedOrder = false;
  bool isLoadingAddItem = false;
  bool _isProcessingBarcode = false;
  bool _isOrderActionInProgress = false;
  final ListQueue<String> _barcodeQueue = ListQueue<String>();
  bool _toCustomerCreditEnabled = false;
  bool _isResyncingProducts = false;

  // Add these variables for the new sidebar
  bool _isSidebarVisible = true;
  int _selectedSidebarTab =
      1; // 0 for products, 1 for orders/categories - default to orders tab
  double _sidebarWidthFraction = 0.26;
  bool _isSidebarResizeHandleHovered = false;
  bool _isSidebarResizing = false;

  static const double _sidebarResizeHandleWidth = 14;
  static const double _sidebarMinWidth = 250;
  static const double _sidebarMaxWidth = 420;
  static const double _mainContentMinWidth = 620;
  static const String _billingSidebarWidthPrefKey =
      'billing_sidebar_width_fraction';

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

  // Add flag to track if customer was manually selected
  bool _isCustomerManuallySelected = false;

  // Sidebar keyboard navigation state
  final FocusNode _sidebarFocusNode = FocusNode();
  bool _isSidebarKeyboardActive = false;
  int _sidebarFocusRequestId = 0;
  bool _isSidebarProductsTabFocused = false;
  bool _isSidebarOrdersTabFocused = false;
  bool _isClearEntryFocused = false;

  // Cart table keyboard navigation state
  final FocusNode _cartTableFocusNode = FocusNode();
  int? _cartTableFocusedRowIndex;
  int? _cartTableFocusedCellIndex;
  int _cartQuantityEditRequestId = 0;
  int _cartPriceEditRequestId = 0;
  int _cartQuantityRefreshRequestId = 0;
  String? _cartQuantityEditRequestKey;
  String? _cartPriceEditRequestKey;
  String? _cartQuantityRefreshRequestKey;
  String? _cartUnitMenuOpenRequestKey;
  num? _cartQuantityRefreshQuantity;
  bool _isCartUnitMenuOpen = false;
  final Map<String, LayerLink> _cartUnitMenuLayerLinks = <String, LayerLink>{};
  OverlayEntry? _cartUnitMenuOverlayEntry;
  List<_CartUnitMenuOption> _cartUnitMenuOptions =
      const <_CartUnitMenuOption>[];
  int _cartUnitMenuHighlightedIndex = 0;

  StreamSubscription<String>? _barcodeSubscription;

  String? deliveryDate;
  String? deliveryTime;
  String? deliveryAddress;
  double? _selectedDeliveryCharge;
  DateTime _quotationDate = DateTime.now();
  DateTime _quotationExpiryDate = DateTime.now().add(const Duration(days: 30));

  // Track last rehydrated order to avoid losing state on navigation
  String? _lastRehydratedOrderId;

  bool get _hasInternet =>
      Provider.of<BillingProvider>(context, listen: false).hasInternet;

  bool get _isOrderActionBusy =>
      _isOrderActionInProgress ||
      isLoadingClearCart ||
      isLoadingSaveOrder ||
      isLoadingCreateOrder ||
      isLoadingConfirmOrder ||
      isLoadingSaveOrderAndPrint ||
      isLoadingCreateNewOrder ||
      isLoadingRestoreSavedOrder;

  bool _beginOrderAction() {
    if (_isOrderActionInProgress) {
      return false;
    }
    _isOrderActionInProgress = true;
    return true;
  }

  void _endOrderAction() {
    _isOrderActionInProgress = false;
  }

  bool _shouldSuppressSystemKeyboard() {
    return SystemKeyboardPolicy.shouldSuppressForContext(
      context: context,
      fieldWantsVirtualKeyboardOnly: true,
    );
  }

  VoidCallback? _appSettingsDebugListener;
  VoidCallback? _generalSettingsListener;
  VoidCallback? _deliveryMethodListener;
  VoidCallback? _paymentMethodListener;

  void _syncStockEnabledSetting() {
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final stockEnabled =
        generalSettingsProvider.generalSettings?.stockEnabled ?? false;
    localProductProvider.setStockEnabled(stockEnabled);
  }

  @override
  void initState() {
    super.initState();
    _loadSidebarWidthPreference();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');
    _focusNode.addListener(_handleFocusChange);
    _cartTableFocusNode.addListener(_handleCartTableFocusChange);
    _paidAmountFocusNode
        .addListener(_handlePaidAmountFocusChange); // Add this line
    HardwareKeyboard.instance.addHandler(_onBillingHardwareKey);
    debugPrint(
        "⌨️ [BillingPage] HardwareKeyboard handler registered in initState");

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
    _hydrateCustomerListFromProviderCache();

    // After first frame, rehydrate UI from any saved order/discounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStockEnabledSetting();
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
        _enqueueBarcode(barcode);
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
      if (!mounted) return;

      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider.addListener(_onSalesExecutiveChanged);

      // Also listen for auth changes (more direct indicator of user switch)
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(_onUserSwitched);

      // Listen for app settings changes
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      _appSettingsDebugListener = () {
        debugPrint('🎫 APP SETTINGS CHANGED:');
        debugPrint('  - New appSettings: ${appSettingsProvider.appSettings}');
        if (appSettingsProvider.appSettings != null) {
          debugPrint(
              '  - New discountAndCoupon: ${appSettingsProvider.appSettings!.discountAndCoupon}');
        }
      };
      appSettingsProvider.addListener(_appSettingsDebugListener!);

      final generalSettingsProvider =
          Provider.of<GeneralSettingsProvider>(context, listen: false);
      _generalSettingsListener = _syncStockEnabledSetting;
      generalSettingsProvider.addListener(_generalSettingsListener!);
      _syncStockEnabledSetting();

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
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onBillingHardwareKey);
    debugPrint("⌨️ [BillingPage] HardwareKeyboard handler removed in dispose");
    _cartUnitMenuOverlayEntry?.remove();
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
    _cartTableFocusNode.dispose();
    _customerScrollController.dispose();

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

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final generalSettingsProvider =
          Provider.of<GeneralSettingsProvider>(context, listen: false);
      if (_appSettingsDebugListener != null) {
        appSettingsProvider.removeListener(_appSettingsDebugListener!);
      }
      if (_generalSettingsListener != null) {
        generalSettingsProvider.removeListener(_generalSettingsListener!);
      }
      if (_paymentMethodListener != null) {
        appSettingsProvider.removeListener(_paymentMethodListener!);
      }

      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      if (_deliveryMethodListener != null) {
        deliveryMethodsProvider.removeListener(_deliveryMethodListener!);
        appSettingsProvider.removeListener(_deliveryMethodListener!);
      }
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
    Provider.of<BillingProvider>(context, listen: false)
        .initConnectivityListener(
      onConnectivityChanged: (message) {
        if (!mounted) return;

        if (message.contains('No internet')) {
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
      },
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
                currentOrder.customerPhone!.isNotEmpty) ||
            (currentOrder.customerName != null &&
                currentOrder.customerName!.isNotEmpty)) {
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
          if (selectedCustomer!.name != null &&
              selectedCustomer!.name!.isNotEmpty) {
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

                final billingProvider =
                    Provider.of<BillingProvider>(context, listen: false);
                final cashId = billingProvider.cashPaymentMethodId ?? 'CASH';
                final cardId = billingProvider.cardPaymentMethodId ?? 'CARD';
                final upiId = billingProvider.upiPaymentMethodId ?? 'UPI';
                final codId = billingProvider.codPaymentMethodId ?? 'COD';

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

                if (hasMethodOrAmount(['CASH', cashId])) {
                  _isCashSelected = true;
                  _cashAmountController.text = firstAmount(['CASH', cashId]);
                }
                if (hasMethodOrAmount(['CARD', cardId])) {
                  _isCardSelected = true;
                  _cardAmountController.text = firstAmount(['CARD', cardId]);
                }
                if (hasMethodOrAmount(['UPI', upiId])) {
                  _isUpiSelected = true;
                  _upiAmountController.text = firstAmount(['UPI', upiId]);
                }
                if (hasMethodOrAmount(['DEBIT'])) {
                  _isDebitSelected = true;
                  _debitAmountController.text =
                      (amounts['DEBIT'] ?? '0').toString();
                }
                if (hasMethodOrAmount(['COD', codId])) {
                  _isCodSelected = true;
                  _codAmountController.text = firstAmount(['COD', codId]);
                }
              }
            } catch (e) {
              debugPrint("Error parsing payment JSON on rehydration: $e");
            }
          } else {
            // Single method
            final billingProvider =
                Provider.of<BillingProvider>(context, listen: false);
            final masterDataProvider =
                Provider.of<MasterDataProvider>(context, listen: false);

            final cashId = billingProvider.cashPaymentMethodId;
            final cardId = billingProvider.cardPaymentMethodId;
            final upiId = billingProvider.upiPaymentMethodId;
            final codId = billingProvider.codPaymentMethodId;

            String normalizedMethod = pm.toUpperCase();
            final int? methodId = int.tryParse(pm);
            if (methodId != null) {
              final resolved =
                  masterDataProvider.getPaymentMethodValue(methodId);
              if (resolved != null && resolved.isNotEmpty) {
                normalizedMethod = resolved.toUpperCase();
              }
            }

            bool isMethodMatch(List<String> candidates) {
              final upperCandidates = candidates
                  .map((c) => c.toUpperCase())
                  .toList(growable: false);
              return upperCandidates.contains(normalizedMethod) ||
                  upperCandidates.contains(pm.toUpperCase());
            }

            _isCashSelected =
                isMethodMatch(['CASH', if (cashId != null) cashId]);
            _isCardSelected =
                isMethodMatch(['CARD', if (cardId != null) cardId]);
            _isUpiSelected = isMethodMatch(['UPI', if (upiId != null) upiId]);
            _isDebitSelected = isMethodMatch(['DEBIT']);
            _isCodSelected = isMethodMatch(['COD', if (codId != null) codId]);

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
        _selectedDeliveryCharge = currentOrder.deliveryCharge;
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

        // Mark checkout payment step as completed when a saved order has payment data
        _hasOpenedPaymentModalOnce = _isCashSelected ||
            _isCardSelected ||
            _isUpiSelected ||
            _isCodSelected ||
            _isDebitSelected ||
            _toCustomerCreditEnabled ||
            (double.tryParse(_cashAmountController.text) ?? 0) > 0 ||
            (double.tryParse(_cardAmountController.text) ?? 0) > 0 ||
            (double.tryParse(_upiAmountController.text) ?? 0) > 0 ||
            (double.tryParse(_codAmountController.text) ?? 0) > 0 ||
            (double.tryParse(_debitAmountController.text) ?? 0) > 0;
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

  void _focusTextField() {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final barcodeSales = appSettingsProvider.appSettings?.barcodeSales ?? false;
    debugPrint(
        "⌨️ [BillingPage] _focusTextField called | barcodeSales=$barcodeSales | ${_focusDebugSummary()}");
    if (barcodeSales) {
      FocusScope.of(context).requestFocus(_barcodeNode);
    } else {
      // When barcode is disabled, focus the Search Product field
      _productAutocompleteKey.currentState?.requestFieldFocus();
    }
    selectedProductNameController.clear();
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
    debugPrint(
        "⌨️ [BillingPage] _focusTextField completed | ${_focusDebugSummary()}");
  }

  void _focusSearchProductField() {
    debugPrint(
        "⌨️ [BillingPage] _focusSearchProductField called | ${_focusDebugSummary()}");
    _productAutocompleteKey.currentState?.requestFieldFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _productAutocompleteKey.currentState?.requestFieldFocus();
    });
    selectedProductNameController.clear();
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
    debugPrint(
        "⌨️ [BillingPage] _focusSearchProductField completed | ${_focusDebugSummary()}");
  }

  void _focusBarcodeField() {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final barcodeSales = appSettingsProvider.appSettings?.barcodeSales ?? false;
    debugPrint(
        "⌨️ [BillingPage] _focusBarcodeField called | barcodeSales=$barcodeSales | ${_focusDebugSummary()}");
    if (barcodeSales) {
      FocusScope.of(context).requestFocus(_barcodeNode);
      selectedProductNameController.clear();
      Provider.of<LocalProductProvider>(context, listen: false)
          .resetSelectedProduct();
    } else {
      _focusSearchProductField();
    }
    debugPrint(
        "⌨️ [BillingPage] _focusBarcodeField completed | ${_focusDebugSummary()}");
  }

  String _focusDebugSummary() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusedWidget = primaryFocus?.context?.widget;
    return "pageHasFocus=${_focusNode.hasFocus}, "
        "pagePrimary=${_focusNode.hasPrimaryFocus}, "
        "barcodeHasFocus=${_barcodeNode.hasFocus}, "
        "customerHasFocus=${_customerTextFieldFocus.hasFocus}, "
        "primaryFocus=${primaryFocus?.debugLabel ?? primaryFocus}, "
        "primaryWidget=${focusedWidget?.runtimeType}";
  }

  void _restoreShortcutFocus(String reason) {
    debugPrint(
        "⌨️ [BillingPage] Restoring shortcut focus ($reason) | before: ${_focusDebugSummary()}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final barcodeSales =
          Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.barcodeSales ??
              false;
      if (barcodeSales) {
        FocusScope.of(context).requestFocus(_barcodeNode);
        debugPrint("⌨️ [BillingPage] Requested barcode focus after $reason");
      } else {
        _focusNode.requestFocus();
        debugPrint(
            "⌨️ [BillingPage] Requested page shortcut focus after $reason");
      }
      debugPrint(
          "⌨️ [BillingPage] Restoring shortcut focus ($reason) | after: ${_focusDebugSummary()}");
    });
  }

  bool _isBillingShortcutKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12 ||
        key == LogicalKeyboardKey.insert ||
        key == LogicalKeyboardKey.escape;
  }

  /// Returns true when the current key event is one of the Ctrl-modified
  /// shortcuts handled by this page (Ctrl+H/A/K/D/S/Q/P/U).
  bool _isBillingControlShortcut(LogicalKeyboardKey key) {
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    return key == LogicalKeyboardKey.keyH ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.keyU ||
        key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.keyS;
  }

  void _handleFocusChange() {
    debugPrint("⌨️ [BillingPage] Focus change | ${_focusDebugSummary()}");
    if (_focusNode.hasFocus) {
      // debugPrint('Focus gained');
    }
  }

  void _handleCartTableFocusChange() {
    // Always rebuild on cart-table focus changes so the orange focus ring
    // around the cart container appears on focus gain and disappears on
    // focus loss. The previous early-return only repainted on first gain
    // (when row index was null), leaving a stale ring after Tab left the
    // cart.
    if (!mounted) return;
    if (!_cartTableFocusNode.hasFocus) {
      _closeCartUnitMenu(refocusCart: false);
    }
    setState(() {
      if (_cartTableFocusNode.hasFocus) {
        _cartTableFocusedRowIndex ??= 0;
        _cartTableFocusedCellIndex ??= 0;
      }
      if (!_cartTableFocusNode.hasFocus) {
        _cartTableFocusedCellIndex = null;
      }
    });
  }

  bool _onBillingHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    // If any dialog/route is on top of this page, let it own the keyboard.
    final route = ModalRoute.of(context);
    final bool dialogIsOnTop = route != null && !route.isCurrent;
    debugPrint(
        "⌨️ [BillingPage] HW raw key=${event.logicalKey.debugName} | dialogOnTop=$dialogIsOnTop");
    if (dialogIsOnTop) {
      debugPrint(
          "⌨️ [BillingPage] HW key ${event.logicalKey.debugName} IGNORED (dialog on top)");
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isAltPressed &&
        _barcodeNode.hasFocus) {
      debugPrint(
          "⌨️ [BillingPage] Handling Tab from Barcode -> Search Product | ${_focusDebugSummary()}");
      _focusSearchProductField();
      return true;
    }

    final isAltCashDrawerShortcut = HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyD;
    if (!_isBillingShortcutKey(event.logicalKey) &&
        !_isBillingControlShortcut(event.logicalKey) &&
        !isAltCashDrawerShortcut) {
      return false;
    }
    debugPrint(
        "⌨️ [BillingPage] HW key ${event.logicalKey.debugName} | ${_focusDebugSummary()}");
    _handleKeyPress(event);
    return true;
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    debugPrint(
        "⌨️ [BillingPage] _handleKeyPress ${event.logicalKey.debugName} | ${_focusDebugSummary()}");

    try {
      // Handle Esc to exit sidebar keyboard mode
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isSidebarKeyboardActive) {
          debugPrint(
              "⌨️ [BillingPage] Handling Esc -> exit sidebar keyboard mode");
          setState(() {
            _isSidebarKeyboardActive = false;
          });
          _focusNode.requestFocus();
        } else {
          debugPrint(
              "⌨️ [BillingPage] Handling Esc -> focus Search Product field");
          _focusSearchProductField();
        }
        return;
      }

      // Always allow F12 even when text fields are focused
      if (event.logicalKey == LogicalKeyboardKey.f12) {
        debugPrint(
            "⌨️ [BillingPage] Handling F12 -> activate sidebar keyboard mode");
        setState(() {
          _isSidebarKeyboardActive = true;
          _selectedSidebarTab = _selectedSidebarTab == 0 ? 1 : 0;
          _sidebarFocusRequestId++;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sidebarFocusNode.requestFocus();
        });
        return;
      }

      // Ctrl-modified shortcuts (header toolbar replacements).
      if (HardwareKeyboard.instance.isControlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyA) {
          debugPrint("⌨️ [BillingPage] Handling Ctrl+A -> focus barcode field");
          _focusBarcodeField();
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyS) {
          debugPrint(
              "⌨️ [BillingPage] Handling Ctrl+S -> focus Search Product field");
          _focusSearchProductField();
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyH) {
          debugPrint("⌨️ [BillingPage] Handling Ctrl+H -> open shortcuts help");
          _openShortcutsHelpDialog();
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyK) {
          debugPrint(
              "⌨️ [BillingPage] Handling Ctrl+K -> toggle virtual keyboard");
          _toggleVirtualKeyboardFromShortcut();
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyD) {
          debugPrint(
              "⌨️ [BillingPage] Handling Ctrl+D -> focus cart table (item name)");
          _focusCartTable();
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyQ) {
          debugPrint("⌨️ [BillingPage] Handling Ctrl+Q -> edit cart quantity");
          _requestCartFieldEditFromShortcut(isQuantity: true);
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyU) {
          debugPrint("⌨️ [BillingPage] Handling Ctrl+U -> focus cart unit");
          _requestCartFieldEditFromShortcut(isQuantity: null);
          return;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyP) {
          debugPrint("⌨️ [BillingPage] Handling Ctrl+P -> edit cart price");
          _requestCartFieldEditFromShortcut(isQuantity: false);
          return;
        }
      }

      if (HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyD) {
        debugPrint("Handling Alt+D -> open cash drawer");
        unawaited(_openCashDrawerFromShortcut());
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.f1) {
        debugPrint("⌨️ [BillingPage] Handling F1 -> clear cart");
        _clearCart();
      } else if (event.logicalKey == LogicalKeyboardKey.f2) {
        debugPrint("⌨️ [BillingPage] Handling F2 -> open checkout confirm");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm);
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        debugPrint(
            "⌨️ [BillingPage] Handling F3 -> open checkout at Customer step");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm,
            initialStep: 0);
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        debugPrint(
            "⌨️ [BillingPage] Handling F4 -> open checkout at Delivery step");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm,
            initialStep: 1);
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        debugPrint(
            "⌨️ [BillingPage] Handling F5 -> open checkout at Payment step");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm,
            initialStep: 3);
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        debugPrint(
            "⌨️ [BillingPage] Handling F6 -> open checkout confirm & print");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm);
      } else if (event.logicalKey == LogicalKeyboardKey.f7) {
        debugPrint("⌨️ [BillingPage] Handling F7 -> create new order");
        _createNewOrder();
      } else if (event.logicalKey == LogicalKeyboardKey.f8) {
        debugPrint("⌨️ [BillingPage] Handling F8 -> open checkout save");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.save);
      } else if (event.logicalKey == LogicalKeyboardKey.f9) {
        debugPrint(
            "⌨️ [BillingPage] Handling F9 -> open checkout save & print");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.save);
      } else if (event.logicalKey == LogicalKeyboardKey.f10) {
        debugPrint(
            "⌨️ [BillingPage] Handling F10 -> open checkout at Discount step");
        _showCheckoutModal(
            actionMode: _isQuotationPage
                ? CheckoutActionMode.quotation
                : CheckoutActionMode.confirm,
            initialStep: 2);
      }
    } catch (e) {
      debugPrint("⌨️ [BillingPage] Error handling key press: $e");
      // debugPrint("Error handling key press: $e");
    }
  }

  /// Opens the keyboard-shortcuts help dialog. Triggered by Ctrl+H or by the
  /// help icon in the header toolbar.
  void _openShortcutsHelpDialog() {
    if (!mounted) return;
    KeyboardShortcutsHelpDialog.show(context);
  }

  /// Toggles the in-app virtual keyboard panel. Triggered by Ctrl+K.
  void _toggleVirtualKeyboardFromShortcut() {
    if (!mounted) return;
    final keyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);
    if (keyboardProvider.showKeyboardFeature) {
      keyboardProvider.featureOff();
      keyboardProvider.clear();
    } else {
      keyboardProvider.featureOn();
    }
  }

  /// Opens the cash drawer through [CashDrawerService]. Triggered by Alt+D.
  Future<void> _openCashDrawerFromShortcut() async {
    if (!mounted) return;
    try {
      await const CashDrawerService().openDrawer(context);
    } catch (e) {
      debugPrint("⌨️ [BillingPage] Cash drawer shortcut failed: $e");
    }
  }

  /// Triggers a full data sync via [SyncProvider]. Triggered by Ctrl+S.
  Future<void> _triggerSyncFromShortcut() async {
    if (!mounted) return;
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: 'No internet connection available for sync.',
      );
      return;
    }
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    if (syncProvider.isSyncing) return;
    if (syncProvider.hasError) {
      syncProvider.clearError();
    }
    try {
      await syncProvider.syncAllData(context);
    } catch (e) {
      debugPrint("⌨️ [BillingPage] Sync shortcut failed: $e");
    }
  }

  Future<void> processBarcode(String barcode) async {
    _enqueueBarcode(barcode);
  }

  void _enqueueBarcode(String barcode) {
    final sanitizedBarcode = barcode.trim();
    if (sanitizedBarcode.isEmpty) {
      return;
    }

    _barcodeQueue.addLast(sanitizedBarcode);
    _processNextBarcode();
  }

  Future<void> _processNextBarcode() async {
    if (!mounted || _isProcessingBarcode || _barcodeQueue.isEmpty) {
      return;
    }

    _isProcessingBarcode = true;
    final barcode = _barcodeQueue.removeFirst();

    try {
      await _processBarcodeInternal(barcode);
    } finally {
      _isProcessingBarcode = false;
      if (_barcodeQueue.isNotEmpty && mounted) {
        Future.microtask(_processNextBarcode);
      }
    }
  }

  Future<void> _processBarcodeInternal(String barcode) async {
    debugPrint(
        "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE START ==========");
    debugPrint("🔴 [BillingPage.processBarcode] Input barcode: '$barcode'");
    debugPrint(
        "🔴 [BillingPage.processBarcode] Barcode length: ${barcode.length}");
    debugPrint(
        "🔴 [BillingPage.processBarcode] _isProcessingBarcode: $_isProcessingBarcode");
    debugPrint(
        "🔴 [BillingPage.processBarcode] barcode.isEmpty: ${barcode.isEmpty}");

    // If input is empty, do nothing.
    if (barcode.isEmpty) {
      debugPrint("⚠️ [BillingPage.processBarcode] SKIPPING - Empty barcode");
      debugPrint(
          "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE END (SKIPPED) ==========\n");
      return;
    }

    debugPrint("✅ [BillingPage.processBarcode] Starting barcode processing...");
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
        final matchedSaleUnit = _findMatchingSaleUnit(product, query);

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
        } else if (matchedSaleUnit != null) {
          quantity = _resolveSaleUnitQuantity(matchedSaleUnit);
          debugPrint(
              "🔴 [BillingPage.processBarcode] Matched sale unit barcode:");
          debugPrint(
              "🔴 [BillingPage.processBarcode]   - Unit: ${matchedSaleUnit.unitName}");
          debugPrint(
              "🔴 [BillingPage.processBarcode]   - Conversion rate: ${matchedSaleUnit.conversionRate}");
          debugPrint(
              "🔴 [BillingPage.processBarcode]   - Base quantity to add: $quantity");
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

        final bool useSaleUnit = matchedSaleUnit != null &&
            _resolveSaleUnitQuantity(matchedSaleUnit) > 1;

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
          addToCartDirectly: true,
          customerId: selectedCustomerID,
          customerName: selectedCustomer?.name,
          selectedSaleUnit: useSaleUnit ? matchedSaleUnit : null,
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
      if (mounted) {
        setState(() {
          barcodeController.clear();
        });
      }
      debugPrint(
          "🔴 [BillingPage.processBarcode] ========== PROCESS BARCODE END ==========\n");
    }
  }

  SaleUnit? _findMatchingSaleUnit(GetProduct product, String barcode) {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return null;
    }

    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      final saleUnitBarcode = saleUnit.barcode?.trim() ?? '';
      if (saleUnitBarcode.isNotEmpty && saleUnitBarcode == normalizedBarcode) {
        return saleUnit;
      }
    }

    return null;
  }

  num _resolveSaleUnitQuantity(SaleUnit saleUnit) {
    final parsedRate = num.tryParse(saleUnit.conversionRate?.trim() ?? '');
    if (parsedRate == null || parsedRate <= 0) {
      return 1;
    }
    return parsedRate;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    context.watch<BillingProvider>().hasInternet;

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
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              // Main content
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (!_isSidebarVisible) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildMainContent(
                              size: size,
                              productProvider: productProvider,
                            ),
                          ),
                        ],
                      );
                    }

                    final double usableWidth = math.max(
                      constraints.maxWidth - _sidebarResizeHandleWidth,
                      0,
                    );
                    final double sidebarWidth = _getClampedSidebarWidth(
                      usableWidth,
                      usableWidth * _sidebarWidthFraction,
                    );
                    final double mainContentWidth = math.max(
                      usableWidth - sidebarWidth,
                      0,
                    );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: mainContentWidth,
                          child: _buildMainContent(
                            size: size,
                            productProvider: productProvider,
                            margin: const EdgeInsets.only(
                              left: 10,
                              top: 10,
                              bottom: 10,
                              right: 4,
                            ),
                          ),
                        ),
                        _buildSidebarResizeHandle(usableWidth),
                        SizedBox(
                          width: sidebarWidth,
                          child: _buildSidebar(
                            margin: const EdgeInsets.only(
                              left: 4,
                              top: 10,
                              bottom: 10,
                              right: 10,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent({
    required Size size,
    required GridSelectionProvider productProvider,
    EdgeInsetsGeometry margin = const EdgeInsets.only(
      left: 10,
      top: 10,
      bottom: 10,
      right: 10,
    ),
  }) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: BuildBoxShadowContainer(
        circleRadius: 10,
        margin: margin,
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
                  selectedProductIdController: selectedProductIdController,
                  productProvider: productProvider,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildCartItemsTable(size),
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
    );
  }

  double _getClampedSidebarWidth(double usableWidth, double desiredWidth) {
    final double minWidth = math.min(_sidebarMinWidth, usableWidth * 0.4);
    final double maxWidth = math.max(
      minWidth,
      math.min(
        _sidebarMaxWidth,
        usableWidth - _mainContentMinWidth,
      ),
    );

    return desiredWidth.clamp(minWidth, maxWidth).toDouble();
  }

  Future<void> _loadSidebarWidthPreference() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final savedFraction = await SharedPreferenceProvider()
          .getBillingSidebarWidthFraction(userId: authModel.userId);

      if (savedFraction == null ||
          !savedFraction.isFinite ||
          savedFraction <= 0) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _sidebarWidthFraction = savedFraction;
      });
    } catch (e) {
      debugPrint('Failed to load billing sidebar width preference: $e');
    }
  }

  Future<void> _saveSidebarWidthPreference() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      await SharedPreferenceProvider().saveBillingSidebarWidthFraction(
        _sidebarWidthFraction,
        userId: authModel.userId,
      );
    } catch (e) {
      debugPrint('Failed to save billing sidebar width preference: $e');
    }
  }

  Widget _buildSidebarResizeHandle(double usableWidth) {
    final bool isActive = _isSidebarResizeHandleHovered || _isSidebarResizing;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) {
        if (!mounted) return;
        setState(() {
          _isSidebarResizeHandleHovered = true;
        });
      },
      onExit: (_) {
        if (!mounted || _isSidebarResizing) return;
        setState(() {
          _isSidebarResizeHandleHovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          setState(() {
            _isSidebarResizing = true;
            _isSidebarResizeHandleHovered = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          final double currentWidth = _getClampedSidebarWidth(
              usableWidth, usableWidth * _sidebarWidthFraction);
          final double nextWidth = _getClampedSidebarWidth(
              usableWidth, currentWidth - details.delta.dx);

          setState(() {
            _sidebarWidthFraction = nextWidth / usableWidth;
          });
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isSidebarResizing = false;
          });
          unawaited(_saveSidebarWidthPreference());
        },
        onHorizontalDragCancel: () {
          setState(() {
            _isSidebarResizing = false;
            _isSidebarResizeHandleHovered = false;
          });
          unawaited(_saveSidebarWidthPreference());
        },
        child: SizedBox(
          width: _sidebarResizeHandleWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: isActive ? 6 : 2,
              height: isActive ? 120 : 72,
              decoration: BoxDecoration(
                color: isActive
                    ? ColorManager.kPrimaryColor.withOpacity(0.65)
                    : Colors.grey.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: ColorManager.kPrimaryColor.withOpacity(0.18),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar({
    EdgeInsetsGeometry margin = const EdgeInsets.only(
      top: 10,
      bottom: 10,
      right: 10,
    ),
  }) {
    final focusHighlightEnabled =
        context.watch<KeyboardFocusHighlightProvider>().enabled;
    return Focus(
      focusNode: _sidebarFocusNode,
      canRequestFocus: _isSidebarKeyboardActive,
      skipTraversal: !_isSidebarKeyboardActive,
      child: BuildBoxShadowContainer(
        circleRadius: 10,
        margin: margin,
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
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onFocusChange: (focused) {
                              setState(() {
                                _isSidebarProductsTabFocused = focused;
                              });
                            },
                            onTap: () {
                              setState(() {
                                _selectedSidebarTab = 0;
                                _sidebarFocusRequestId++;
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
                                border: Border.all(
                                  color: focusHighlightEnabled &&
                                          _isSidebarProductsTabFocused
                                      ? ColorManager.kPrimaryColor
                                      : Colors.transparent,
                                  width: focusHighlightEnabled &&
                                          _isSidebarProductsTabFocused
                                      ? 3
                                      : 1,
                                ),
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onFocusChange: (focused) {
                              setState(() {
                                _isSidebarOrdersTabFocused = focused;
                              });
                            },
                            onTap: () {
                              setState(() {
                                _selectedSidebarTab = 1;
                                _sidebarFocusRequestId++;
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
                                border: Border.all(
                                  color: focusHighlightEnabled &&
                                          _isSidebarOrdersTabFocused
                                      ? ColorManager.kPrimaryColor
                                      : Colors.transparent,
                                  width: focusHighlightEnabled &&
                                          _isSidebarOrdersTabFocused
                                      ? 3
                                      : 1,
                                ),
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
                      ),
                      const SizedBox(width: 50), // Space for toggle button
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: Container(
                    child: _selectedSidebarTab == 0
                        ? _buildProductTab()
                        : _buildOrdersTab(),
                  ),
                ),

                // NEW: Footer (fixed height, visible in both tabs)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildCheckoutFooter(),
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
      ),
    );
  }

  Widget _buildProductTab() {
    return Consumer2<LocalProductProvider, SyncProvider>(
      builder: (context, localProductProvider, syncProvider, child) {
        final bool hasProducts =
            localProductProvider.sellableProducts.isNotEmpty;
        final bool isLoading = localProductProvider.isLoading ||
            syncProvider.isSyncing ||
            _isResyncingProducts;

        if (hasProducts) {
          return SideBarProductList(
            autofocus: _isSidebarKeyboardActive && _selectedSidebarTab == 0,
            focusRequestId: _sidebarFocusRequestId,
            categorySectionInitiallyExpanded: false,
          );
        }

        if (isLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Resyncing products...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait while products are being loaded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                Text(
                  'No products loaded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try resyncing products. Check internet and tenant if this continues.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),
                CustomRoundButton(
                  title:
                      _isResyncingProducts ? 'Resyncing...' : 'Resync Products',
                  fct: _isResyncingProducts
                      ? () {}
                      : _resyncProductsFromEmptyState,
                  width: 170,
                  height: 36,
                  fontSize: 11,
                  boxColor: ColorManager.kPrimaryColor,
                  borderColor: ColorManager.kPrimaryColor,
                  textColor: Colors.white,
                  radius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resyncProductsFromEmptyState() async {
    if (_isResyncingProducts) return;

    setState(() {
      _isResyncingProducts = true;
    });

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      await localProductProvider.fetchProductsFromAPI(refresh: true);

      if (localProductProvider.sellableProducts.isEmpty) {
        await syncProvider.syncAllData(context);
      }

      if (!mounted) return;

      if (localProductProvider.sellableProducts.isEmpty) {
        showScaffoldError(
          context: context,
          message:
              'Resync finished but no products were returned. Check tenant/API key or internet.',
        );
      } else {
        showScaffold(
          context: context,
          message: 'Products resynced successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Failed to resync products: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResyncingProducts = false;
        });
      }
    }
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
              autofocus: _isSidebarKeyboardActive && _selectedSidebarTab == 1,
              focusRequestId: _sidebarFocusRequestId,
              isBusy: _isOrderActionBusy,
              onNewOrderPressed: _createNewOrder,
              onOrderSelected: (orderId) {
                if (_isOrderActionBusy) {
                  return;
                }

                final localProductProvider =
                    Provider.of<LocalProductProvider>(context, listen: false);

                final isSwitchingOrder =
                    localProductProvider.currentOrder?.id != orderId;
                if (isSwitchingOrder &&
                    localProductProvider.cartItems.isNotEmpty) {
                  try {
                    _saveCurrentCartAsDraft(localProductProvider);
                    showScaffold(
                      context: context,
                      message: "billing.order_saved".tr,
                    );
                  } catch (e) {
                    debugPrint("Error preserving current order: $e");
                  }
                }

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
            child: HorizontalProductViewLocal(
              autofocus: _isSidebarKeyboardActive && _selectedSidebarTab == 1,
              focusRequestId: _sidebarFocusRequestId,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: true);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: true).appSettings;
    final bool isEditingOrder = localProductProvider.currentOrder != null;
    final currentOrder = localProductProvider.currentOrder;
    final String compactOrderNumber = currentOrder?.orderNumber
            .replaceFirst(RegExp(r'^ORD-', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^0+'), '') ??
        '';
    final selectedHeaderCustomer =
        customerSelectionProvider.selectedCustomer ?? selectedCustomer;
    final fallbackCustomerName = selectedHeaderCustomer?.name ??
        currentOrder?.customerName ??
        currentOrder?.customerPhone;
    final bool showCustomerType = appSettings?.companyB2BEnabled ?? false;
    final bool showHeaderCustomerBalance = selectedHeaderCustomer != null &&
        !customerSelectionProvider.isDefaultCustomer &&
        !_isDefaultCustomerPhone(selectedHeaderCustomer.phone);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditingOrder ? '${'Edit'.tr} - ' : 'New'.tr,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s18, 0.25, ColorManager.textColor),
                  ),
                  if (isEditingOrder)
                    Text(
                      '#${compactOrderNumber.isEmpty ? currentOrder!.orderNumber : compactOrderNumber}',
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s18, 0.25, ColorManager.textColor),
                    ),
                ],
              ),
              if (fallbackCustomerName != null &&
                  fallbackCustomerName.trim().isNotEmpty)
                _buildHeaderCustomerDetails(
                  name: fallbackCustomerName,
                  balance: selectedHeaderCustomer?.balance,
                  showBalance: showHeaderCustomerBalance,
                  customerType: showCustomerType
                      ? selectedHeaderCustomer?.customerType
                      : null,
                ),
            ],
          ),
        ),
        // Header toolbar icons are intentionally excluded from keyboard
        // traversal — they have dedicated shortcuts (Ctrl+H, Ctrl+K, Ctrl+D,
        // Ctrl+S) and don't belong on the main Tab path.
        ExcludeFocus(
          excluding: true,
          child: Row(
            children: [
              // Live Clock
              const LiveClock(),
              const SizedBox(width: 12),
              // Keyboard shortcuts help button
              IconButton(
                icon: Icon(
                  Icons.help_outline,
                  color: Colors.grey.shade600,
                ),
                tooltip: 'Keyboard Shortcuts (Ctrl+H)',
                onPressed: () {
                  KeyboardShortcutsHelpDialog.show(context);
                },
              ),
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
              OpenCashDrawerButton(
                color: Colors.grey.shade600,
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
        ),
      ],
    );
  }

  Widget _buildHeaderCustomerDetails({
    required String? name,
    required double? balance,
    required bool showBalance,
    required String? customerType,
  }) {
    const int maxCustomerNameChars = 30;
    final String rawName =
        (name == null || name.trim().isEmpty) ? 'Customer' : name.trim();
    final String displayName = rawName.length > maxCustomerNameChars
        ? '${rawName.substring(0, maxCustomerNameChars)}...'
        : rawName;
    final String displayBalance = (balance ?? 0).toStringAsFixed(2);
    final Color balanceColor = (balance ?? 0) < 0
        ? Colors.red.shade600
        : (balance ?? 0) > 0
            ? Colors.green.shade700
            : Colors.grey.shade600;
    final String? displayCustomerType = customerType?.trim().isEmpty == true
        ? null
        : customerType?.trim().toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showCheckoutModal(
          actionMode: CheckoutActionMode.confirm,
          initialStep: 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ColorManager.kPrimaryColor.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 18,
                width: 18,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 12,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.16,
                    ColorManager.textColor,
                  ),
                ),
              ),
              if (showBalance) ...[
                Container(
                  height: 14,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  color: Colors.grey.shade300,
                ),
                Text(
                  'Bal $displayBalance',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.16,
                    balanceColor,
                  ),
                ),
              ],
              if (displayCustomerType != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: displayCustomerType == 'B2B'
                        ? Colors.green.shade100
                        : ColorManager.kPrimaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    displayCustomerType,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s9,
                      0.12,
                      displayCustomerType == 'B2B'
                          ? Colors.green.shade700
                          : ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
                      ? FocusTraversalOrder(
                          order: const NumericFocusOrder(
                              BillingFocusOrders.barcode),
                          child: Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: buildColumnWidgetForTextFields(
                                autofocus: appSettingsProvider
                                    .appSettings!.barcodeSales,
                                controller: barcodeController,
                                focusNode: _barcodeNode,
                                readOnly: selectedProductNameController
                                    .text.isNotEmpty,
                                onSubmitted: (query) {
                                  if (query != null && query.isNotEmpty) {
                                    processBarcode(query);
                                  }
                                },
                                size: size,
                                hintText: 'billing.barcode_hint'.tr,
                              ),
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
                      : FocusTraversalOrder(
                          order: const NumericFocusOrder(
                              BillingFocusOrders.searchProduct),
                          child: Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductAutocomplete(
                                  key: _productAutocompleteKey,
                                  autocompleteProductKey:
                                      _autocompleteProductKey,
                                  autofocus: !appSettingsProvider
                                      .appSettings!.barcodeSales,
                                  suppressSystemKeyboardOnAndroid: true,
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
                                    _focusSearchProductField();
                                  },
                                  productList: productProvider.productList!,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ExcludeFocus(
                    child: Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: buildColumnWidgetForTextFields(
                          controller: quantityController,
                          onchanged: (query) {},
                          size: size,
                          hintText: 'billing.quantity_hint'.tr,
                          focusNode: _quantityFocusNode,
                          useSystemKeyboard: !_shouldSuppressSystemKeyboard(),
                          keyboardType: TextInputType.number,
                          onTap: () {
                            Provider.of<KeyboardProvider>(context,
                                    listen: false)
                                .show(
                              'number',
                              quantityController,
                              replaceOnFirstInput: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  ExcludeFocus(
                    child: Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: buildColumnWidgetForTextFields(
                          controller: unitPriceController,
                          onchanged: (query) {},
                          size: size,
                          focusNode: _unitPriceFocusNode,
                          hintText: 'billing.unit_price_hint'.tr,
                          useSystemKeyboard: !_shouldSuppressSystemKeyboard(),
                          keyboardType: TextInputType.number,
                          onTap: () {
                            Provider.of<KeyboardProvider>(context,
                                    listen: false)
                                .show(
                              'number',
                              unitPriceController,
                              replaceOnFirstInput: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  ExcludeFocus(
                    child: Expanded(
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
                                    final localProductProvider =
                                        Provider.of<LocalProductProvider>(
                                            context,
                                            listen: false);

                                    final selectedProduct =
                                        localProductProvider.selectedProduct;

                                    if (selectedProduct != null) {
                                      final customPrice = double.tryParse(
                                          unitPriceController.text);
                                      final customQuantity =
                                          num.tryParse(quantityController.text);

                                      await ProductCartHelper
                                          .handleProductSelection(
                                        context: context,
                                        product: selectedProduct,
                                        quantity: customQuantity,
                                        customPrice: customPrice != null &&
                                                customPrice > 0
                                            ? customPrice
                                            : null,
                                      );

                                      // Clear input fields
                                      setState(() {
                                        _autocompleteProductKey = GlobalKey();
                                        quantityController.clear();
                                        barcodeController.clear();
                                        selectedProductIdController.clear();
                                        unitPriceController.clear();
                                      });
                                      _focusSearchProductField();
                                    } else {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            "billing.no_product_selected".tr,
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
                  ),
                  ExcludeFocus(
                    child: Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: context
                                            .watch<
                                                KeyboardFocusHighlightProvider>()
                                            .enabled &&
                                        _isClearEntryFocused
                                    ? ColorManager.kPrimaryColor
                                    : Colors.transparent,
                                width: context
                                            .watch<
                                                KeyboardFocusHighlightProvider>()
                                            .enabled &&
                                        _isClearEntryFocused
                                    ? 3
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: BuildBoxShadowContainer(
                              height: size.height * .07,
                              width: 50,
                              circleRadius: 5,
                              child: InkWell(
                                onFocusChange: (focused) {
                                  setState(() {
                                    _isClearEntryFocused = focused;
                                  });
                                },
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
                                  _focusSearchProductField(),
                                  showScaffold(
                                    context: context,
                                    message: 'billing.product_cleared'.tr,
                                  )
                                },
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                          ),
                        ],
                      ),
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

  double? _parseSaleUnitRate(SaleUnit saleUnit) {
    final rate = double.tryParse(saleUnit.conversionRate?.trim() ?? '');
    if (rate == null || rate <= 0) {
      return null;
    }
    return rate;
  }

  List<SaleUnit> _validSaleUnitsForCartItem(LocalCartItem item) {
    final uniqueSaleUnits = <int, SaleUnit>{};
    for (final saleUnit in item.product.saleUnits ?? const <SaleUnit>[]) {
      final id = saleUnit.id;
      if (id == null || _parseSaleUnitRate(saleUnit) == null) {
        continue;
      }
      uniqueSaleUnits[id] = saleUnit;
    }
    return uniqueSaleUnits.values.toList();
  }

  List<_CartUnitMenuOption> _cartUnitOptionsForItem(LocalCartItem item) {
    final saleUnits = _validSaleUnitsForCartItem(item);
    final baseUnit = item.product.unit?.trim();
    final baseLabel = baseUnit == null || baseUnit.isEmpty ? '-' : baseUnit;
    final options = <_CartUnitMenuOption>[
      _CartUnitMenuOption(value: 'base', label: baseLabel),
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
        _CartUnitMenuOption(
          value: saleUnitId.toString(),
          label: saleUnitLabel,
        ),
      );
    }
    return options;
  }

  String _selectedCartUnitValue(LocalCartItem item) {
    return item.saleUnitId == null ? 'base' : item.saleUnitId.toString();
  }

  void _closeCartUnitMenu({bool refocusCart = true}) {
    _cartUnitMenuOverlayEntry?.remove();
    _cartUnitMenuOverlayEntry = null;
    _cartUnitMenuOptions = const <_CartUnitMenuOption>[];
    _cartUnitMenuHighlightedIndex = 0;
    _isCartUnitMenuOpen = false;
    if (refocusCart && mounted) {
      _cartTableFocusNode.requestFocus();
    }
  }

  void _selectCartUnitOption({
    required LocalCartItem item,
    required LocalProductProvider localProductProvider,
    required String value,
  }) {
    _closeCartUnitMenu();
    if (item.product.productId == null) {
      return;
    }

    if (value == 'base') {
      if (item.saleUnitId == null) {
        return;
      }
      localProductProvider.changeCartItemSaleUnit(
        item.product.productId!,
        item.selectedStock,
        stockGroupIds: item.stockGroupIds,
        currentSaleUnitId: item.saleUnitId,
      );
      return;
    }

    if (value == item.saleUnitId?.toString()) {
      return;
    }

    final saleUnits = _validSaleUnitsForCartItem(item);
    SaleUnit? selectedSaleUnit;
    for (final saleUnit in saleUnits) {
      if (saleUnit.id?.toString() == value) {
        selectedSaleUnit = saleUnit;
        break;
      }
    }
    final selectedRate =
        selectedSaleUnit == null ? null : _parseSaleUnitRate(selectedSaleUnit);
    if (selectedSaleUnit == null || selectedRate == null) {
      return;
    }

    localProductProvider.changeCartItemSaleUnit(
      item.product.productId!,
      item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      currentSaleUnitId: item.saleUnitId,
      newSaleUnitId: selectedSaleUnit.id,
      newSaleUnitName: selectedSaleUnit.unitName,
      newSaleUnitConversionRate: selectedRate,
    );
  }

  void _openCartUnitMenu({
    required LocalCartItem item,
    required LocalProductProvider localProductProvider,
    required LayerLink layerLink,
  }) {
    final options = _cartUnitOptionsForItem(item);
    if (options.length <= 1 && item.saleUnitId == null) {
      return;
    }

    final selectedValue = _selectedCartUnitValue(item);
    final selectedIndex = options.indexWhere((option) {
      return option.value == selectedValue;
    });

    _closeCartUnitMenu(refocusCart: false);
    _cartUnitMenuOptions = options;
    _cartUnitMenuHighlightedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    _isCartUnitMenuOpen = true;

    _cartUnitMenuOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeCartUnitMenu(),
              ),
              CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 28),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int index = 0; index < options.length; index++)
                          InkWell(
                            onTap: () => _selectCartUnitOption(
                              item: item,
                              localProductProvider: localProductProvider,
                              value: options[index].value,
                            ),
                            child: Container(
                              height: 32,
                              width: double.infinity,
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: index == _cartUnitMenuHighlightedIndex
                                    ? ColorManager.kPrimaryColor
                                        .withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.vertical(
                                  top: index == 0
                                      ? const Radius.circular(8)
                                      : Radius.zero,
                                  bottom: index == options.length - 1
                                      ? const Radius.circular(8)
                                      : Radius.zero,
                                ),
                              ),
                              child: Text(
                                options[index].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s12,
                                  0.15,
                                  ColorManager.textColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_cartUnitMenuOverlayEntry!);
    _cartTableFocusNode.requestFocus();
  }

  Widget _buildCartUnitSelector({
    required LocalCartItem item,
    required LocalProductProvider localProductProvider,
    required TextStyle textStyle,
    required bool shouldAutoOpenFromShortcut,
  }) {
    final options = _cartUnitOptionsForItem(item);
    final canChangeUnit = options.length > 1 || item.saleUnitId != null;
    if (!canChangeUnit) {
      return Text(
        item.displayUnitName,
        style: textStyle,
        textAlign: TextAlign.left,
      );
    }

    final identityKey = _cartIdentityKey(item);
    final layerLink =
        _cartUnitMenuLayerLinks.putIfAbsent(identityKey, LayerLink.new);
    if (shouldAutoOpenFromShortcut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cartUnitMenuOpenRequestKey = null;
        _openCartUnitMenu(
          item: item,
          localProductProvider: localProductProvider,
          layerLink: layerLink,
        );
      });
    }

    return CompositedTransformTarget(
      link: layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _openCartUnitMenu(
            item: item,
            localProductProvider: localProductProvider,
            layerLink: layerLink,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                item.displayUnitName,
                style: textStyle,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: ColorManager.kPrimaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemsTable(Size size) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        List<LocalCartItem> cartItems = localProductProvider.getCartItems();
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: true);
        final appSettings = appSettingsProvider.appSettings;
        final customerSelectionProvider =
            Provider.of<CustomerSelectionProvider>(context, listen: true);
        final bool canShowPurchaseHistoryAction =
            appSettings?.showCustomerLastBuyedPriceList == true &&
                customerSelectionProvider.hasSelectedCustomer &&
                !customerSelectionProvider.isDefaultCustomer;
        final fontProvider =
            Provider.of<AppFontProvider>(context, listen: true);

        return LayoutBuilder(
          builder: (context, constraints) {
            final focusHighlightEnabled =
                context.watch<KeyboardFocusHighlightProvider>().enabled;
            final bool isCartTableFocused =
                focusHighlightEnabled && _cartTableFocusNode.hasFocus;
            final bool showCartContainerFocusRing =
                isCartTableFocused && _cartTableFocusedCellIndex == null;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                border: Border.all(
                  color: showCartContainerFocusRing
                      ? Colors.orange
                      : Colors.transparent,
                  width: showCartContainerFocusRing ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
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
                        if (appSettings?.itemCodeEnabled == true)
                          _buildHeaderCell('Item Code',
                              flex: 1, alignment: Alignment.centerLeft),
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
                    child: FocusTraversalOrder(
                      order:
                          const NumericFocusOrder(BillingFocusOrders.cartTable),
                      child: Focus(
                        focusNode: _cartTableFocusNode,
                        onKeyEvent: (FocusNode node, KeyEvent event) {
                          return _handleCartTableKey(
                              event, cartItems, localProductProvider);
                        },
                        // Cart cells (qty/price/mrp/tax/delete) remain
                        // click-focusable, but Tab traversal must NOT descend
                        // into them — the cart table is a single tab stop and
                        // arrow keys handle internal navigation.
                        child: Focus(
                          descendantsAreTraversable: false,
                          canRequestFocus: false,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: ScrollConfiguration(
                              behavior:
                                  ScrollConfiguration.of(context).copyWith(
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
                                  final bool isFocusedRow =
                                      isCartTableFocused &&
                                          _cartTableFocusedRowIndex == index;
                                  return Container(
                                    color: isFocusedRow
                                        ? Colors.orange.withOpacity(0.06)
                                        : index % 2 == 0
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
                                                fontProvider
                                                    .billingTableItemSize,
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
                                          _buildCartKeyboardCell(
                                            rowIndex: index,
                                            cellIndex: 0,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _showProductDetailsDialog(
                                                      item),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 2),
                                                      child: Text(
                                                        item.product
                                                                .productName ??
                                                            'general.unknown'
                                                                .tr,
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .regular,
                                                          fontProvider
                                                              .billingTableItemSize,
                                                          0.21,
                                                          ColorManager
                                                              .textColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Tooltip(
                                                    message:
                                                        'billing.view_details'
                                                            .tr,
                                                    waitDuration:
                                                        const Duration(
                                                            milliseconds: 400),
                                                    child: InkWell(
                                                      onTap: () =>
                                                          _showProductDetailsDialog(
                                                              item),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      child: const Icon(
                                                        Icons.info_outline,
                                                        size: 16,
                                                        color: ColorManager
                                                            .kPrimaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  if (canShowPurchaseHistoryAction) ...[
                                                    const SizedBox(width: 6),
                                                    Tooltip(
                                                      message:
                                                          'Customer purchase history',
                                                      waitDuration:
                                                          const Duration(
                                                              milliseconds:
                                                                  400),
                                                      child: InkWell(
                                                        onTap: () =>
                                                            _showCustomerPurchaseHistoryForCartItem(
                                                                item),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        child: const Icon(
                                                          Icons.history,
                                                          size: 16,
                                                          color: ColorManager
                                                              .kPrimaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          flex: 3,
                                          alignment: Alignment.centerLeft,
                                        ),

                                        // Item Code
                                        if (appSettings?.itemCodeEnabled ==
                                            true)
                                          _buildContentCell(
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Text(
                                                item.product.itemCode ?? '-',
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
                                            flex: 1,
                                            alignment: Alignment.centerLeft,
                                          ),

                                        // Unit
                                        _buildContentCell(
                                          _buildCartKeyboardCell(
                                            rowIndex: index,
                                            cellIndex: 1,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: _buildCartUnitSelector(
                                                item: item,
                                                localProductProvider:
                                                    localProductProvider,
                                                textStyle: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  fontProvider
                                                      .billingTableItemSize,
                                                  0.21,
                                                  ColorManager.textColor,
                                                ),
                                                shouldAutoOpenFromShortcut:
                                                    _cartUnitMenuOpenRequestKey ==
                                                        _cartIdentityKey(item),
                                              ),
                                            ),
                                          ),
                                          flex: 1,
                                          alignment: Alignment.centerLeft,
                                        ),
                                        // Qty
                                        _buildContentCell(
                                          _buildCartKeyboardCell(
                                            rowIndex: index,
                                            cellIndex: 2,
                                            child: Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child:
                                                    CompactQuantityControlLocal(
                                                  key: ValueKey(
                                                    'qty-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.stockGroupIds.join('_')}-${item.saleUnitId ?? 'base'}',
                                                  ),
                                                  productId:
                                                      item.product.productId!,
                                                  quantity:
                                                      item.quantity.toDouble(),
                                                  unitPrice:
                                                      item.price.toString(),
                                                  productUnit:
                                                      item.product.unit,
                                                  product: item.product,
                                                  cartItem: item,
                                                  selectedStock:
                                                      item.selectedStock,
                                                  editRequestId:
                                                      _cartQuantityEditRequestId,
                                                  editRequestKey:
                                                      _cartQuantityEditRequestKey,
                                                  onEditingComplete: () {
                                                    _cartTableFocusNode
                                                        .requestFocus();
                                                  },
                                                  refreshRequestId:
                                                      _cartQuantityRefreshRequestId,
                                                  refreshRequestKey:
                                                      _cartQuantityRefreshRequestKey,
                                                  refreshQuantity:
                                                      _cartQuantityRefreshQuantity,
                                                ),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: SizedBox(
                                                width: 70,
                                                child: MrpTextField(
                                                  key: ValueKey(
                                                    'mrp-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}',
                                                  ),
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
                                          _buildCartKeyboardCell(
                                            rowIndex: index,
                                            cellIndex: 3,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: SizedBox(
                                                width: 70,
                                                child: PriceTextField(
                                                  key: ValueKey(
                                                    'price-${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}',
                                                  ),
                                                  item: item,
                                                  localProductProvider:
                                                      localProductProvider,
                                                  editRequestId:
                                                      _cartPriceEditRequestId,
                                                  editRequestKey:
                                                      _cartPriceEditRequestKey,
                                                  onEditingComplete: () {
                                                    _cartTableFocusNode
                                                        .requestFocus();
                                                  },
                                                ),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                    (item.price! *
                                                        item.quantity)),
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
                                          _buildCartKeyboardCell(
                                            rowIndex: index,
                                            cellIndex: 4,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: IconButton(
                                                icon: WebsafeSvg.asset(
                                                  ImageAssets.oderlistCloseIcon,
                                                  width: 15,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  localProductProvider
                                                      .removeFromCart(
                                                    item.product.productId!,
                                                    item.selectedStock,
                                                    stockGroupIds:
                                                        item.stockGroupIds,
                                                    saleUnitId: item.saleUnitId,
                                                  );
                                                },
                                              ),
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

  void _focusCartTable() {
    debugPrint("⌨️ [BillingPage] Focusing cart table");
    _closeCartUnitMenu(refocusCart: false);
    setState(() {
      _cartTableFocusedRowIndex = 0;
      _cartTableFocusedCellIndex = 0;
    });
    _cartTableFocusNode.requestFocus();
  }

  void _requestCartFieldEditFromShortcut({required bool? isQuantity}) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final cartItems = localProductProvider.getCartItems();
    if (cartItems.isEmpty) return;

    final focusedIndex =
        (_cartTableFocusedRowIndex ?? 0).clamp(0, cartItems.length - 1).toInt();
    final item = cartItems[focusedIndex];

    setState(() {
      _cartTableFocusedRowIndex = focusedIndex;
      if (isQuantity == true) {
        _cartTableFocusedCellIndex = 2;
        _cartQuantityEditRequestKey = _cartIdentityKey(item);
        _cartQuantityEditRequestId++;
      } else if (isQuantity == false) {
        _cartTableFocusedCellIndex = 3;
        _cartPriceEditRequestKey = _cartIdentityKey(item);
        _cartPriceEditRequestId++;
      } else {
        _cartTableFocusedCellIndex = 1;
        _cartUnitMenuOpenRequestKey = _cartIdentityKey(item);
      }
    });
  }

  KeyEventResult _handleOpenCartUnitMenuKey({
    required KeyEvent event,
    required LocalCartItem item,
    required LocalProductProvider localProductProvider,
    required int cartLength,
  }) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final optionCount = _cartUnitMenuOptions.length;
      if (optionCount == 0) {
        _closeCartUnitMenu();
        return KeyEventResult.handled;
      }
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      _cartUnitMenuHighlightedIndex =
          (_cartUnitMenuHighlightedIndex + delta + optionCount) % optionCount;
      _cartUnitMenuOverlayEntry?.markNeedsBuild();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_cartUnitMenuOptions.isEmpty) {
        _closeCartUnitMenu();
        return KeyEventResult.handled;
      }
      final selectedIndex = _cartUnitMenuHighlightedIndex
          .clamp(0, _cartUnitMenuOptions.length - 1)
          .toInt();
      _selectCartUnitOption(
        item: item,
        localProductProvider: localProductProvider,
        value: _cartUnitMenuOptions[selectedIndex].value,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      _closeCartUnitMenu();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      _closeCartUnitMenu();
      return _handleCartTableTabKey(cartLength);
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _handleCartTableKey(
      KeyEvent event,
      List<LocalCartItem> cartItems,
      LocalProductProvider localProductProvider) {
    if (event is! KeyDownEvent || cartItems.isEmpty) {
      return KeyEventResult.ignored;
    }

    final focusedIndex =
        (_cartTableFocusedRowIndex ?? 0).clamp(0, cartItems.length - 1).toInt();
    final item = cartItems[focusedIndex];

    if (_isCartUnitMenuOpen) {
      return _handleOpenCartUnitMenuKey(
        event: event,
        item: item,
        localProductProvider: localProductProvider,
        cartLength: cartItems.length,
      );
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      return _handleCartTableTabKey(cartItems.length);
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_cartTableFocusedRowIndex == null) {
          _cartTableFocusedRowIndex = 0;
        } else if (_cartTableFocusedRowIndex! < cartItems.length - 1) {
          _cartTableFocusedRowIndex = _cartTableFocusedRowIndex! + 1;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_cartTableFocusedRowIndex == null) {
          _cartTableFocusedRowIndex = 0;
        } else if (_cartTableFocusedRowIndex! > 0) {
          _cartTableFocusedRowIndex = _cartTableFocusedRowIndex! - 1;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _cartTableFocusedCellIndex =
            ((_cartTableFocusedCellIndex ?? -1) + 1).clamp(0, 4).toInt();
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _cartTableFocusedCellIndex =
            ((_cartTableFocusedCellIndex ?? 0) - 1).clamp(0, 4).toInt();
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_cartTableFocusedCellIndex == 0) {
        _showProductDetailsDialog(item);
      } else if (_cartTableFocusedCellIndex == 1) {
        final identityKey = _cartIdentityKey(item);
        final layerLink = _cartUnitMenuLayerLinks[identityKey];
        if (layerLink != null) {
          _openCartUnitMenu(
            item: item,
            localProductProvider: localProductProvider,
            layerLink: layerLink,
          );
        }
      } else if (_cartTableFocusedCellIndex == 2) {
        setState(() {
          _cartQuantityEditRequestKey = _cartIdentityKey(item);
          _cartQuantityEditRequestId++;
        });
      } else if (_cartTableFocusedCellIndex == 3) {
        setState(() {
          _cartPriceEditRequestKey = _cartIdentityKey(item);
          _cartPriceEditRequestId++;
        });
      } else if (_cartTableFocusedCellIndex == 4) {
        _removeCartItemFromKeyboard(
            item, localProductProvider, cartItems.length);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete) {
      _removeCartItemFromKeyboard(item, localProductProvider, cartItems.length);
      return KeyEventResult.handled;
    }

    final character = event.character;
    final isIncreaseKey = character == '+' ||
        key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd;
    final isDecreaseKey = character == '-' ||
        key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract;
    final isHistoryKey = !HardwareKeyboard.instance.isControlPressed &&
        (key == LogicalKeyboardKey.keyH || character?.toLowerCase() == 'h');

    if (isIncreaseKey) {
      unawaited(_adjustCartItemQuantityFromKeyboard(item, 1));
      return KeyEventResult.handled;
    }

    if (isDecreaseKey) {
      unawaited(_adjustCartItemQuantityFromKeyboard(item, -1));
      return KeyEventResult.handled;
    }

    if (isHistoryKey) {
      unawaited(_showCustomerPurchaseHistoryForCartItem(item));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCartTableTabKey(int cartLength) {
    const int lastCellIndex = 4;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;
    final rowIndex = (_cartTableFocusedRowIndex ?? 0).clamp(0, cartLength - 1);
    final cellIndex = _cartTableFocusedCellIndex;

    if (isAltPressed) {
      if (cellIndex == null) {
        return KeyEventResult.ignored;
      }
      setState(() {
        if (cellIndex > 0) {
          _cartTableFocusedCellIndex = cellIndex - 1;
        } else if (rowIndex > 0) {
          _cartTableFocusedRowIndex = rowIndex - 1;
          _cartTableFocusedCellIndex = lastCellIndex;
        } else {
          _cartTableFocusedCellIndex = null;
        }
      });
      return KeyEventResult.handled;
    }

    if (cellIndex == null) {
      setState(() {
        _cartTableFocusedRowIndex = rowIndex;
        _cartTableFocusedCellIndex = 0;
      });
      return KeyEventResult.handled;
    }

    if (cellIndex < lastCellIndex) {
      setState(() {
        _cartTableFocusedCellIndex = cellIndex + 1;
      });
      return KeyEventResult.handled;
    }

    if (rowIndex < cartLength - 1) {
      setState(() {
        _cartTableFocusedRowIndex = rowIndex + 1;
        _cartTableFocusedCellIndex = 0;
      });
      return KeyEventResult.handled;
    }

    setState(() {
      _cartTableFocusedCellIndex = null;
    });
    return KeyEventResult.ignored;
  }

  void _removeCartItemFromKeyboard(LocalCartItem item,
      LocalProductProvider localProductProvider, int previousCartLength) {
    localProductProvider.removeFromCart(
      item.product.productId!,
      item.selectedStock,
      stockGroupIds: item.stockGroupIds,
      saleUnitId: item.saleUnitId,
    );
    setState(() {
      if (previousCartLength <= 1) {
        _cartTableFocusedRowIndex = null;
      } else {
        _cartTableFocusedRowIndex = (_cartTableFocusedRowIndex ?? 0)
            .clamp(0, previousCartLength - 2)
            .toInt();
      }
    });
  }

  Future<void> _adjustCartItemQuantityFromKeyboard(
      LocalCartItem item, num delta) async {
    final productId = item.product.productId;
    if (productId == null) return;

    final nextQuantity = item.quantity + delta;
    debugPrint(
      '🧮 [BillingPage] keyboard quantity adjust '
      'productId=$productId, current=${item.quantity}, '
      'delta=$delta, next=$nextQuantity',
    );
    final result = await CartQuantityStockHelper.syncCartItemQuantity(
      context: context,
      cartItem: item,
      newQuantity: nextQuantity,
    );
    debugPrint(
      '🧮 [BillingPage] keyboard quantity applied '
      'productId=$productId, applied=${result.appliedQuantity}, '
      'changed=${result.changed}, itemNow=${item.quantity}',
    );
    if (!mounted) return;
    setState(() {
      _cartQuantityRefreshRequestKey = _cartIdentityKey(item);
      _cartQuantityRefreshQuantity = result.appliedQuantity;
      _cartQuantityRefreshRequestId++;
    });
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

  Widget _buildCartKeyboardCell({
    required int rowIndex,
    required int cellIndex,
    required Widget child,
  }) {
    final focusHighlightEnabled =
        context.watch<KeyboardFocusHighlightProvider>().enabled;
    final isFocused = focusHighlightEnabled &&
        _cartTableFocusNode.hasFocus &&
        _cartTableFocusedRowIndex == rowIndex &&
        _cartTableFocusedCellIndex == cellIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        border: Border.all(
          color: isFocused ? Colors.orange : Colors.transparent,
          width: isFocused ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(5),
        color: isFocused ? Colors.orange.withOpacity(0.10) : Colors.transparent,
      ),
      child: child,
    );
  }

  String _cartIdentityKey(LocalCartItem item) {
    final groupKey = item.stockGroupIds.join('_');
    return '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-$groupKey-${item.saleUnitId ?? 'base'}';
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

  Future<void> _showCustomerPurchaseHistoryForCartItem(
      LocalCartItem item) async {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings?.showCustomerLastBuyedPriceList !=
        true) {
      showScaffoldError(
        context: context,
        message: 'Customer purchase history is disabled',
      );
      return;
    }

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    if (customerSelectionProvider.isDefaultCustomer) {
      showScaffoldError(
        context: context,
        message: 'Purchase history is not shown for the default customer',
      );
      return;
    }

    final int? customerId =
        customerSelectionProvider.selectedCustomerID ?? selectedCustomerID;
    final String? customerName =
        customerSelectionProvider.selectedCustomerName ??
            selectedCustomer?.name;
    final int? productId = item.product.productId;

    if (customerId == null || productId == null || customerName == null) {
      showScaffoldError(
        context: context,
        message: 'Select a customer to view purchase history',
      );
      return;
    }

    final String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Unable to load purchase history',
      );
      return;
    }

    try {
      final CustomerPurchaseHistory? purchaseHistory =
          await CustomerPurchaseProvider().getCustomerLastPurchases(
        accessToken: token,
        customerId: customerId,
        productId: productId,
      );

      if (!mounted) return;

      if (purchaseHistory == null ||
          !purchaseHistory.success ||
          purchaseHistory.data.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'No purchase history found for this product',
        );
        return;
      }

      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) => CustomerPurchaseHistoryModal(
          product: item.product,
          purchaseHistory: purchaseHistory.data.take(5).toList(),
          customerName: customerName,
        ),
      );

      if (!mounted || result == null || result['useCurrentPrice'] == true) {
        return;
      }

      final rawPrice = result['price'];
      final double? selectedPrice = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '');
      if (selectedPrice == null) {
        return;
      }

      Provider.of<LocalProductProvider>(context, listen: false).updateItemPrice(
        productId,
        item.selectedStock,
        selectedPrice,
        stockGroupIds: item.stockGroupIds,
        saleUnitId: item.saleUnitId,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load customer purchase history: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Unable to load purchase history',
      );
    }
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
                "$currency ${AmountHelper.formatAmount(_getEffectiveOrderTotal())}",
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

  /// Builds the checkout footer for the sidebar (similar to Restaurant Page)
  Widget _buildCheckoutFooter() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    // CRITICAL: Access cartTotal FIRST to trigger priceSummary recalculation
    final _ = localProductProvider.cartTotal;
    final footerPriceSummary = _getFooterPriceSummaryWithDeliveryCharge(
      localProductProvider.priceSummary,
    );

    return CheckoutFooter(
      priceSummary: footerPriceSummary,
      currency: currency,
      taxNames: taxNames,
      totalPaid: _getTotalPaidAmount(),
      balance: _balanceAmount,
      onTaxTap: () {
        // Show tax details dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tax Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: taxNames.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value}%'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds payment summary using the reusable CheckoutFooter widget
  /// This combines the payment summary with Total Paid and Balance information
  Widget _buildPaymentSummaryWithFooter() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    // CRITICAL: Access cartTotal FIRST to trigger priceSummary recalculation
    final _ = localProductProvider.cartTotal;
    final footerPriceSummary = _getFooterPriceSummaryWithDeliveryCharge(
      localProductProvider.priceSummary,
    );

    // Calculate total paid and balance
    double totalPaid = _getTotalPaidAmount();
    double balance = _calculateBalanceAmount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Payment Summary Title
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
        // Use the reusable CheckoutFooter widget
        CheckoutFooter(
          priceSummary: footerPriceSummary,
          currency: currency,
          taxNames: taxNames,
          totalPaid: totalPaid,
          balance: balance,
          onTaxTap: () {
            // Show tax details dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Tax Details'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: taxNames.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text('${entry.value}%'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          showTotalPaid:
              false, // We'll show this separately with quick access icons
          showBalance:
              false, // We'll show this separately with quick access icons
        ),
      ],
    );
  }

  PriceSummary? _getFooterPriceSummaryWithDeliveryCharge(
      PriceSummary? summary) {
    if (summary == null) {
      return null;
    }

    final deliveryCharge = _getDeliveryChargeForOrder();

    return PriceSummary(
      discount: summary.discount,
      netPayable: summary.netPayable + deliveryCharge,
      subTotal: summary.subTotal,
      totalTax: summary.totalTax,
      netTotal: summary.netTotal,
      flatDiscount: summary.flatDiscount,
      percentageDiscount: summary.percentageDiscount,
      originalSubTotal: summary.originalSubTotal,
    );
  }

  double _getEffectiveOrderTotal() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);

    final baseTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;

    final roundedOrBaseTotal =
        appSettingsProvider.appSettings?.priceRoundOff == true
            ? AmountHelper.roundOffAmount(baseTotal)
            : baseTotal;

    return roundedOrBaseTotal + _getDeliveryChargeForOrder();
  }

  // Helper method to get formatted total
  String _getFormattedTotal() {
    return AmountHelper.formatAmount(_getEffectiveOrderTotal());
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
                              readOnly: _shouldSuppressSystemKeyboard(),
                              showCursor: true,
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

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final isQuotationDraft =
        localProductProvider.currentOrder?.quotationId != null;
    debugPrint(
        "🧾 [BillingCustomer] Balance check phone=${selectedCustomer?.phone}, quotationDraft=$isQuotationDraft");

    // Get app settings to check for default customer
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultCustomerPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";

    // Don't show balance if it's the default customer (by phone match)
    if (!isQuotationDraft &&
        defaultCustomerPhone.isNotEmpty &&
        selectedCustomer!.phone == defaultCustomerPhone) {
      debugPrint(
          "🧾 [BillingCustomer] Hiding balance for automatic default phone=$defaultCustomerPhone");
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
    final disableActions = _isOrderActionBusy;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(BillingFocusOrders.clearCart),
              child: _buildActionButton(
                text: 'billing.clear_cart'.tr,
                color: ColorManager.kButtonRed,
                onPressed: _clearCart,
                isLoading: isLoadingClearCart,
                isDisabled: disableActions && !isLoadingClearCart,
                shortcutLabel: 'F1',
              ),
            ),
            if (!_isQuotationPage)
              FocusTraversalOrder(
                order: const NumericFocusOrder(BillingFocusOrders.saveOrder),
                child: _buildActionButton(
                  text: 'billing.save_order'.tr,
                  color: ColorManager.kButtonYellow,
                  onPressed: () =>
                      _showCheckoutModal(actionMode: CheckoutActionMode.save),
                  isLoading: isLoadingSaveOrder,
                  isDisabled: disableActions && !isLoadingSaveOrder,
                  shortcutLabel: 'F8',
                ),
              ),
            if (_isQuotationPage) ...[
              FocusTraversalOrder(
                order: const NumericFocusOrder(155.0),
                child: _buildActionButton(
                  text: 'Create Quotation',
                  color: Colors.teal.shade500,
                  onPressed: () => _showCheckoutModal(
                      actionMode: CheckoutActionMode.quotation),
                  isLoading: isLoadingSaveOrder,
                  isDisabled: disableActions && !isLoadingSaveOrder,
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(156.0),
                child: _buildActionButton(
                  text: 'Quotation List',
                  color: ColorManager.kPrimaryColor,
                  onPressed: () {
                    Get.find<SideBarController>().index.value = 87;
                  },
                  isLoading: false,
                  isDisabled: disableActions,
                ),
              ),
            ],
            if (!_isQuotationPage && _hasInternet) ...[
              FocusTraversalOrder(
                order:
                    const NumericFocusOrder(BillingFocusOrders.confirmAndPrint),
                child: _buildActionButton(
                  text: 'billing.confirm_and_print'.tr,
                  color: ColorManager.kButtonBlue,
                  onPressed: () => _showCheckoutModal(
                      actionMode: CheckoutActionMode.confirm),
                  isLoading: isLoadingCreateOrder,
                  isDisabled: disableActions && !isLoadingCreateOrder,
                  shortcutLabel: 'F6',
                ),
              ),
              if (Provider.of<AppSettingsProvider>(context, listen: false)
                      .appSettings
                      ?.showConfirmOrderButton ??
                  true)
                FocusTraversalOrder(
                  order:
                      const NumericFocusOrder(BillingFocusOrders.confirmOrder),
                  child: _buildActionButton(
                    text: 'billing.confirm_order'.tr,
                    color: ColorManager.kButtonGreen,
                    onPressed: () => _showCheckoutModal(
                        actionMode: CheckoutActionMode.confirm),
                    isLoading: isLoadingConfirmOrder,
                    isDisabled: disableActions && !isLoadingConfirmOrder,
                    shortcutLabel: 'F2',
                  ),
                ),
            ],
            if (!_isQuotationPage && !_hasInternet) ...[
              FocusTraversalOrder(
                order: const NumericFocusOrder(BillingFocusOrders.saveAndPrint),
                child: _buildActionButton(
                  text: 'billing.save_and_print'.tr,
                  color: ColorManager.kButtonYellow,
                  onPressed: () =>
                      _showCheckoutModal(actionMode: CheckoutActionMode.save),
                  isLoading: isLoadingSaveOrderAndPrint,
                  isDisabled: disableActions && !isLoadingSaveOrderAndPrint,
                  shortcutLabel: 'F9',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
    bool isDisabled = false,
    String? shortcutLabel,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          child: InkWell(
            onTap: (isLoading || isDisabled) ? null : onPressed,
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: isDisabled ? color.withOpacity(0.55) : color,
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          if (shortcutLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                shortcutLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _customerNameForOrder() => _trimToNull(selectedCustomer?.name);

  String? _customerPhoneForOrder() {
    return _trimToNull(selectedCustomerPhone) ??
        _trimToNull(selectedCustomer?.phone) ??
        _trimToNull(mobileNumberText) ??
        _trimToNull(mobileNumberTextController.text);
  }

  SavedOrder _saveCurrentCartAsDraft(
      LocalProductProvider localProductProvider) {
    final paymentData = _getPaymentMethodData();
    final customerNameToSave = _customerNameForOrder();
    final customerPhoneToSave = _customerPhoneForOrder();
    final customerIdToSave = selectedCustomerID ?? selectedCustomer?.id;
    final customerTypeToSave = selectedCustomer?.customerType;
    final couponIdToSave =
        isCouponApplied ? _trimToNull(coupenCodeTextController.text) : null;
    final currentOrder = localProductProvider.currentOrder;

    if (currentOrder != null) {
      localProductProvider.updateSavedOrder(
        currentOrder.id,
        customerName: customerNameToSave,
        customerPhone: customerPhoneToSave,
        comment: _commentController.text,
        deliveryMethod: deliveryMethod,
        customerId: customerIdToSave,
        paymentMethod: paymentData["paymentMethod"],
        paidAmount: paymentData["paidAmount"],
        balanceAmount: _balanceAmount.toString(),
        transactionId: _transactionNumberController.text,
        couponId: couponIdToSave,
        deliveryMethodId: deliveryMethodId,
        carNumber: _carNumberController.text,
        deliveryDate: deliveryDate,
        deliveryTime: deliveryTime,
        context: context,
        toCustomerCredit: _toCustomerCreditEnabled,
        address: deliveryAddress,
        deliveryCharge: _getDeliveryChargeForOrder(),
        customerType: customerTypeToSave,
      );
      return localProductProvider.findOrderById(currentOrder.id) ??
          currentOrder;
    }

    return localProductProvider.saveCurrentCartAsOrder(
      customerName: customerNameToSave,
      customerPhone: customerPhoneToSave,
      comment: _commentController.text,
      deliveryMethod: deliveryMethod,
      customerId: customerIdToSave,
      paymentMethod: paymentData["paymentMethod"],
      paidAmount: paymentData["paidAmount"],
      balanceAmount: _balanceAmount.toString(),
      transactionId: _transactionNumberController.text,
      couponId: couponIdToSave,
      deliveryMethodId: deliveryMethodId,
      carNumber: _carNumberController.text,
      status: "saved",
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      context: context,
      toCustomerCredit: _toCustomerCreditEnabled,
      address: deliveryAddress,
      deliveryCharge: _getDeliveryChargeForOrder(),
      customerType: customerTypeToSave,
    );
  }

  void _resetBillingWorkspaceUi({bool refocus = true}) {
    if (!mounted) return;

    setState(() {
      coupenCodeTextController.clear();
      _transactionNumberController.clear();
      _paidAmountController.clear();
      _balanceAmount = 0;
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
      selectedProductNameController.clear();
      isCouponApplied = false;
      _hasOpenedPaymentModalOnce = false;
      _isCustomerManuallySelected = false;
      _toCustomerCreditEnabled = false;
      deliveryDate = null;
      deliveryTime = null;
      deliveryAddress = null;
      _selectedDeliveryCharge = null;
      _commentController.clear();
      _carNumberController.clear();
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey();
      _lastRehydratedOrderId = null;
    });

    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();
    resetAutocomplete(shouldFetchCustomers: false);
    _applyDefaultCustomerFromCacheIfNeeded();
    if (refocus) {
      _focusTextField();
    }
  }

  void _clearOrderWorkspace({
    required LocalProductProvider localProductProvider,
    required bool preserveStockDeduction,
    bool providerCartAlreadyCleared = false,
    bool refocus = true,
  }) {
    if (!providerCartAlreadyCleared) {
      if (preserveStockDeduction) {
        localProductProvider.clearCartAfterOrder();
      } else {
        localProductProvider.clearCart();
      }
    }
    localProductProvider.clearCurrentOrder();
    _resetBillingWorkspaceUi(refocus: refocus);
  }

  Future<void> _clearCart() async {
    if (!_beginOrderAction()) {
      return;
    }

    debugPrint("Clear Cart pressed");
    setState(() {
      isLoadingClearCart = true; // Indicate that loading has started
    });
    try {
      // Clear local cart
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      _clearOrderWorkspace(
        localProductProvider: localProductProvider,
        preserveStockDeduction: false,
      );
      showScaffold(
        context: context,
        message: "billing.cart_cleared".tr,
      );
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
      _endOrderAction();
    }
  }

  Future<void> _saveOrder({bool shouldPrint = false}) async {
    if (!_beginOrderAction()) {
      return;
    }

    setState(() {
      isLoadingSaveOrder = true; // Indicate that loading has started
    });
    debugPrint("Save Order pressed");
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

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
      // bool hasInvalidPricing = localProductProvider.cartItems
      //     .any((item) => item.price == null || item.price! < 0);

      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message: "billing.valid_prices".tr,
      //   );
      //   return;
      // }

      _saveCurrentCartAsDraft(localProductProvider);
      _clearOrderWorkspace(
        localProductProvider: localProductProvider,
        preserveStockDeduction: false,
      );

      showScaffold(
        context: context,
        message: "billing.order_saved_success".tr,
      );
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
      _endOrderAction();
    }
  }

  Future<void> _saveOrderAndPrint() async {
    if (!_beginOrderAction()) {
      return;
    }

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

      // Check if customer is selected (consider pre-filled default text)
      final hasCustomer = selectedCustomerID != null ||
          (mobileNumberText?.isNotEmpty == true) ||
          (salesExecutivemobileNumberText?.isNotEmpty == true);
      if (!hasCustomer) {
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
        _showPaymentMethodModal(onAfterApply: _saveOrderAndPrint);
        return;
      }

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
      // bool hasInvalidPricing = localProductProvider.cartItems
      //     .any((item) => item.price == null || item.price! < 0);

      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message: "billing.valid_prices".tr,
      //   );
      //   return;
      // }

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;
      SavedOrder? orderToUse;

      if (currentOrder != null) {
        debugPrint(
            "💾 Promoting saved order to confirmed: ${currentOrder.orderNumber}");

        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave = selectedCustomerPhone ?? mobileNumberText;

        final paymentData = _getPaymentMethodData();
        final currentOrderId = currentOrder.id;
        localProductProvider.updateSavedOrder(
          currentOrderId,
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          customerId: selectedCustomerID,
          paymentMethod: paymentData["paymentMethod"],
          paidAmount: paymentData["paidAmount"],
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          deliveryDate: deliveryDate,
          deliveryTime: deliveryTime,
          toCustomerCredit: _toCustomerCreditEnabled,
          context: context,
          address: deliveryAddress,
          deliveryCharge: _getDeliveryChargeForOrder(),
          customerType: selectedCustomer?.customerType,
        );

        orderToUse = localProductProvider.moveToConfirmedOrders(currentOrderId);
        orderToUse ??= localProductProvider.saveCurrentCartAsConfirmedOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          customerId: selectedCustomerID,
          paymentMethod: paymentData["paymentMethod"],
          paidAmount: paymentData["paidAmount"],
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
          deliveryDate: deliveryDate,
          deliveryTime: deliveryTime,
          context: context,
          toCustomerCredit: _toCustomerCreditEnabled,
          address: deliveryAddress,
          deliveryCharge: _getDeliveryChargeForOrder(),
          customerType: selectedCustomer?.customerType,
        );

        showScaffold(
          context: context,
          message: "billing.order_saved_success".tr,
        );
      } else {
        debugPrint("💾 Creating new confirmed order for printing");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave = selectedCustomerPhone ?? mobileNumberText;

        final paymentData = _getPaymentMethodData();
        orderToUse = localProductProvider.saveCurrentCartAsConfirmedOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentData["paymentMethod"],
          paidAmount: paymentData["paidAmount"],
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
          deliveryDate: deliveryDate, // Pass deliveryDate
          deliveryTime: deliveryTime, // Pass deliveryTime
          context: context,
          toCustomerCredit: _toCustomerCreditEnabled,
          address: deliveryAddress,
          deliveryCharge: _getDeliveryChargeForOrder(),
          customerType: selectedCustomer?.customerType,
        );

        showScaffold(
          context: context,
          message: "billing.order_saved_success".tr,
        );
      }

      try {
        await printFromSavedOrder(orderToUse);
      } catch (error) {
        debugPrint("Error printing saved order: ${error.toString()}");
      }

      resetAutocomplete(shouldFetchCustomers: false);
      _clearOrderWorkspace(
        localProductProvider: localProductProvider,
        preserveStockDeduction: true,
      );
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
      _endOrderAction();
    }
  }

  Future<void> _createNewOrder() async {
    debugPrint(
        "⌨️ [BillingPage] _createNewOrder started | ${_focusDebugSummary()}");
    if (!_beginOrderAction()) {
      debugPrint(
          "⌨️ [BillingPage] _createNewOrder ignored because another action is in progress");
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingCreateNewOrder = true;
      });
    }

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isNotEmpty) {
        _saveCurrentCartAsDraft(localProductProvider);
      }

      _clearOrderWorkspace(
        localProductProvider: localProductProvider,
        preserveStockDeduction: false,
      );

      showScaffold(
        context: context,
        message: "common.create_new_order".tr,
      );
    } catch (error) {
      debugPrint(
          "⌨️ [BillingPage] Error creating new order: $error | ${_focusDebugSummary()}");
      debugPrint("Error creating new order: $error");
      showScaffoldError(
        context: context,
        message: "billing.failed_save_order".tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingCreateNewOrder = false;
        });
      }
      _endOrderAction();
      _restoreShortcutFocus('create new order');
      debugPrint(
          "⌨️ [BillingPage] _createNewOrder finished | ${_focusDebugSummary()}");
    }
  }

  // Function to load a saved order for editing
  void _loadSavedOrderForEditing(String orderId) async {
    if (!_beginOrderAction()) {
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingRestoreSavedOrder = true;
      });
    }

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      localProductProvider.loadOrderForEditing(orderId);
      _rehydrateFromProvider();

      showScaffold(
        context: context,
        message: "billing.order_loaded_editing".tr,
      );

      unawaited(_refreshPaymentMethodIdsThenRehydrate(orderId));
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "billing.failed_load_order".tr);
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRestoreSavedOrder = false;
        });
      }
      _endOrderAction();
    }
  }

  Future<void> _refreshPaymentMethodIdsThenRehydrate(String orderId) async {
    try {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);

      final methods = await masterDataProvider.fetchPaymentMethods();
      if (methods == null || !mounted) {
        return;
      }

      String? cashId, cardId, upiId, codId;
      for (var method in methods) {
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
      if (localProductProvider.currentOrder?.id == orderId) {
        _rehydrateFromProvider();
      }
    } catch (error) {
      debugPrint("Error refreshing payment methods for saved order: $error");
    }
  }

  Future<void> _createOrderAndPrint() async {
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

    if (!_beginOrderAction()) {
      return;
    }

    setState(() {
      isLoadingCreateOrder = true;
    });
    try {
      final hasCustomer = selectedCustomerID != null ||
          (mobileNumberText?.isNotEmpty == true) ||
          (salesExecutivemobileNumberText?.isNotEmpty == true);
      if (!hasCustomer) {
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
      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      // Validate that all items have valid pricing before API call
      // bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
      //     item.price == null ||
      //     item.price! < 0 ||
      //     item.mrp == null ||
      //     item.mrp! < 0);

      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message:
      //         "Please ensure all items have valid prices and MRP before confirming order",
      //   );
      //   return;
      // }

      final items = localProductProvider.buildOrderItemsPayload();

      for (final item in items) {
        debugPrint("📦 Order Item Payload: $item");
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
        deliveryCharge: _getDeliveryChargeForOrder(),
        quotationId: localProductProvider.currentOrder?.quotationId,
      )
          .then((response) async {
        debugPrint(
            "✅ API RESPONSE - Create Order and Print: ${json.encode(response)}");
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "billing.order_saved_successfully".tr,
          );
          _refreshCustomersInBackgroundAfterSale();

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

            // Extract payment breakdown (method -> amount mapping from API)
            Map<String, dynamic>? paymentBreakdown =
                orderDetails.data?.payments;

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
            String? customerVatNumber = orderDetails.data?.kycInfo?.vatNumber;
            String? customerCrNumber = orderDetails.data?.kycInfo?.crNumber;
            // Use helper to get address from order_props, fallback to customer details
            String? customerAddress =
                orderDetails.data?.getCustomerAddressForDisplay();

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
                "🖨️ Attempting auto-print for order #${orderDetails.data!.orderNumber}");
            debugPrint(
                "💰 Customer Old Balanceance: $oldBalance, Paid: $totalPaid, Current Balance: $currentBalance");

            Future<bool> printOnce() {
              return _printOrderDetailsWithFallback(
                storeName: storeName,
                cartItems: orderDetails.data!.cart!.cartItems!,
                formattedTotal: formattedTotal!,
                savedTotal: savedTotal,
                discountAmount:
                    orderDetails.data!.priceSummary?.discount?.toString() ??
                        "0.00",
                orderDate: orderDate,
                orderNumber: orderDetails.data!.orderNumber.toString(),
                tokenNumber: orderDetails.data?.tokenNumber,
                customerName: customerName,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                customerAddress: customerAddress,
                customerOldBalance: oldBalance,
                customerCurrentBalance: currentBalance,
                paidAmount: totalPaid > 0 ? totalPaid : null,
                customerAlternatePhone: customerAlternatePhone,
                customerVatNumber: customerVatNumber,
                customerCrNumber: customerCrNumber,
                customerType: selectedCustomer?.customerType,
                paymentMethod: paymentMethod,
                paymentBreakdown: paymentBreakdown,
                orderComment: orderComment,
                deliveryMethod:
                    orderDetails.data?.deliveryMethodName ?? deliveryMethod,
                isDefaultCustomer: Provider.of<CustomerSelectionProvider>(
                        context,
                        listen: false)
                    .isDefaultCustomer,
                netExcTax: orderDetails.data!.cart!.priceSummary?.netExcTax
                    ?.toString(),
              );
            }

            final autoPrintSuccess = await printOnce();
            await _maybePrintCustomerCopy(
              canPrompt: autoPrintSuccess,
              printAction: printOnce,
            );
          } catch (error) {
            debugPrint("❌ Error fetching order details for print: $error");
          }

          // Clear the mobile number after successful save
          setState(() {
            mobileNumberText = ""; // Clear the variable
            salesExecutivemobileNumberText = ""; // Clear default phone display
            selectedCustomerID = null;
            selectedCustomerPhone = null;
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
            _isCustomerManuallySelected = false;
            _hasOpenedPaymentModalOnce = false;
            _toCustomerCreditEnabled = false;
            _isCashSelected = false;
            _isCardSelected = false;
            _isUpiSelected = false;
            _isCodSelected = false;
            _isDebitSelected = false;
            _cashAmountController.clear();
            _cardAmountController.clear();
            _upiAmountController.clear();
            _codAmountController.clear();
            _debitAmountController.clear();
            _autocompletePhoneKey = GlobalKey();
          });
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .clearSelectedCustomer();
          resetAutocomplete(
              shouldFetchCustomers:
                  false); // Preserve customer selection after confirming

          _clearOrderWorkspace(
            localProductProvider: localProductProvider,
            preserveStockDeduction: true,
            providerCartAlreadyCleared: true,
          );
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
      _endOrderAction();
      debugPrint("🏁 Create Order and Print process completed");
    }
  }

  Future<void> _confirmOrder() async {
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

    if (!_beginOrderAction()) {
      return;
    }

    setState(() {
      isLoadingConfirmOrder = true;
    });
    try {
      final hasCustomer = selectedCustomerID != null ||
          (mobileNumberText?.isNotEmpty == true) ||
          (salesExecutivemobileNumberText?.isNotEmpty == true);
      if (!hasCustomer) {
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
      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "billing.add_items_to_cart".tr,
        );
        return;
      }

      // Validate that all items have valid pricing before API call
      // bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
      //     item.price == null ||
      //     item.price! < 0 ||
      //     item.mrp == null ||
      //     item.mrp! < 0);

      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message:
      //         "Please ensure all items have valid prices and MRP before confirming order",
      //   );
      //   return;
      // }

      final items = localProductProvider.buildOrderItemsPayload();

      for (final item in items) {
        debugPrint("📦 Order Item Payload: $item");
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
        deliveryCharge: _getDeliveryChargeForOrder(),
        quotationId: localProductProvider.currentOrder?.quotationId,
      )
          .then((response) async {
        debugPrint("✅ API RESPONSE - Confirm Order: ${json.encode(response)}");
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "billing.order_confirmed_successfully".tr,
          );
          _refreshCustomersInBackgroundAfterSale();

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
            salesExecutivemobileNumberText = ""; // Clear default phone display
            selectedCustomerID = null;
            selectedCustomerPhone = null;
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
            _isCustomerManuallySelected = false;
            _hasOpenedPaymentModalOnce = false;
            _toCustomerCreditEnabled = false;
            _isCashSelected = false;
            _isCardSelected = false;
            _isUpiSelected = false;
            _isCodSelected = false;
            _isDebitSelected = false;
            _cashAmountController.clear();
            _cardAmountController.clear();
            _upiAmountController.clear();
            _codAmountController.clear();
            _debitAmountController.clear();
            _autocompletePhoneKey = GlobalKey();
          });
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .clearSelectedCustomer();
          resetAutocomplete(
              shouldFetchCustomers:
                  false); // Preserve customer selection after confirming

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
      _endOrderAction();
      debugPrint("🏁 Confirm Order process completed");
    }
  }

  void _refreshCustomersInBackgroundAfterSale() {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final accessToken = authModel.token;

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint(
            "🔄 Skipping background customer refresh: access token unavailable");
        return;
      }

      unawaited(() async {
        try {
          debugPrint("🔄 Background customer refresh started after sale");
          await customerProvider.fetchCustomers(
            accessToken: accessToken,
            listAll: true,
          );

          final refreshedCustomers = customerProvider.allCustomers;
          if (!mounted ||
              refreshedCustomers == null ||
              refreshedCustomers.isEmpty) {
            return;
          }

          setState(() {
            customerList = List<CustomerListModelData>.from(refreshedCustomers);
          });
          debugPrint(
              "✅ Background customer refresh completed: ${refreshedCustomers.length} customers");
        } catch (error) {
          // Keep existing list on any failure.
          debugPrint("❌ Background customer refresh failed: $error");
        }
      }());
    } catch (error) {
      debugPrint("❌ Failed to start background customer refresh: $error");
    }
  }

  void _hydrateCustomerListFromProviderCache({
    bool applyDefaultCustomer = true,
  }) {
    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final cachedCustomers = customerProvider.allCustomers;
      if (cachedCustomers == null || cachedCustomers.isEmpty || !mounted) {
        return;
      }

      setState(() {
        customerList = List<CustomerListModelData>.from(cachedCustomers);
      });
      if (applyDefaultCustomer) {
        _applyDefaultCustomerFromCacheIfNeeded();
      }
      debugPrint(
          "📦 Hydrated customer cache from provider: ${cachedCustomers.length} customers");
    } catch (error) {
      debugPrint("❌ Failed to hydrate customer cache: $error");
    }
  }

  void _applyDefaultCustomerFromCacheIfNeeded() {
    if (!mounted) return;

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    if (localProductProvider.currentOrder != null) {
      return;
    }

    if (_isCustomerManuallySelected &&
        (selectedCustomerID != null || mobileNumberText?.isNotEmpty == true)) {
      return;
    }

    if (selectedCustomer != null ||
        selectedCustomerID != null ||
        (selectedCustomerPhone?.isNotEmpty ?? false)) {
      return;
    }

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final autoAssignEnabled =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomer ?? false;
    if (!autoAssignEnabled) return;

    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? '';
    if (defaultPhone.isEmpty) return;

    final customers = customerList;
    if (customers == null || customers.isEmpty) return;

    CustomerListModelData? matched;
    try {
      matched =
          customers.firstWhere((customer) => customer.phone == defaultPhone);
    } catch (_) {}

    if (matched != null) {
      setState(() {
        selectedCustomer = matched;
        selectedCustomerID = matched!.id;
        selectedCustomerPhone = matched.phone;
        salesExecutivemobileNumberText = matched.phone ?? '';
        mobileNumberText = matched.phone ?? '';
        mobileNumberTextController.text =
            '${matched.name ?? ''} ${matched.phone ?? ''}'.trim();
      });

      Provider.of<CustomerSelectionProvider>(context, listen: false)
          .setSelectedCustomer(matched, isDefault: true);
      return;
    }

    setState(() {
      salesExecutivemobileNumberText = defaultPhone;
      mobileNumberText = defaultPhone;
      mobileNumberTextController.text = defaultPhone;
      selectedCustomerID = null;
      selectedCustomerPhone = defaultPhone;
      selectedCustomer = null;
    });
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();
  }

  void _clearAutomaticDefaultCustomerForQuotation() {
    if (!mounted || _isCustomerManuallySelected) return;

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    if (localProductProvider.currentOrder?.quotationId != null) {
      debugPrint(
          "🧾 [BillingCustomer] Skip clearing customer: quotation draft ${localProductProvider.currentOrder?.quotationId}");
      return;
    }

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? '';

    final isAutoDefault = customerSelectionProvider.isDefaultCustomer ||
        (defaultPhone.isNotEmpty &&
            (selectedCustomerPhone == defaultPhone ||
                mobileNumberText == defaultPhone ||
                salesExecutivemobileNumberText == defaultPhone));
    debugPrint(
        "🧾 [BillingCustomer] Auto-default clear check isAutoDefault=$isAutoDefault, defaultPhone=$defaultPhone, selectedPhone=$selectedCustomerPhone, mobile=$mobileNumberText");
    if (!isAutoDefault) return;

    customerSelectionProvider.clearSelectedCustomer();
    setState(() {
      selectedCustomer = null;
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      mobileNumberText = '';
      salesExecutivemobileNumberText = '';
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey();
    });
  }

  /// Shows the checkout modal for customer selection, delivery, discount, and payment
  /// This is called when clicking Confirm Order or Confirm & Print buttons
  void _showCheckoutModal({
    CheckoutActionMode actionMode = CheckoutActionMode.confirm,
    int? initialStep,
  }) async {
    final isSaveMode = actionMode == CheckoutActionMode.save;
    final isQuotationMode = actionMode == CheckoutActionMode.quotation;
    bool checkoutActionTriggered = false;
    debugPrint(
        "⌨️ [BillingPage] _showCheckoutModal requested | mode=$actionMode | initialStep=$initialStep | ${_focusDebugSummary()}");
    if (_isOrderActionBusy) {
      debugPrint(
          "⌨️ [BillingPage] _showCheckoutModal ignored because order action is busy");
      return;
    }

    debugPrint(
        "⌨️ [BillingPage] Releasing focus before checkout modal | ${_focusDebugSummary()}");
    // Release global shortcut focus so modal text fields receive keyboard input reliably.
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    debugPrint(
        "⌨️ [BillingPage] Focus released before checkout modal | ${_focusDebugSummary()}");

    // Quotations should not silently inherit the billing default customer.
    _hydrateCustomerListFromProviderCache(
      applyDefaultCustomer: !isQuotationMode,
    );
    if (isQuotationMode) {
      _clearAutomaticDefaultCustomerForQuotation();
    } else {
      _applyDefaultCustomerFromCacheIfNeeded();
    }

    // Reload payment methods
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final methods = await masterDataProvider.fetchPaymentMethods();

    if (methods != null && mounted) {
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      String? cashId, cardId, upiId, codId;
      for (var m in methods) {
        final val = m.value.toUpperCase();
        if (val == 'CASH') {
          cashId = m.id.toString();
        } else if (val == 'CARD') {
          cardId = m.id.toString();
        } else if (val == 'UPI') {
          upiId = m.id.toString();
        } else if (val == 'COD') {
          codId = m.id.toString();
        }
      }
      billingProvider.updatePaymentMethodIds(
        cashId: cashId,
        cardId: cardId,
        upiId: upiId,
        codId: codId,
      );
    }

    final hasExistingPaymentState = _isCashSelected ||
        _isCardSelected ||
        _isUpiSelected ||
        _isCodSelected ||
        _isDebitSelected ||
        _toCustomerCreditEnabled ||
        (double.tryParse(_cashAmountController.text) ?? 0) > 0 ||
        (double.tryParse(_cardAmountController.text) ?? 0) > 0 ||
        (double.tryParse(_upiAmountController.text) ?? 0) > 0 ||
        (double.tryParse(_codAmountController.text) ?? 0) > 0 ||
        (double.tryParse(_debitAmountController.text) ?? 0) > 0;

    // Apply default payment method only when no existing/rehydrated payment state exists.
    // Quotations are estimates, so payment must stay unconfigured unless a future
    // explicit advance-payment flow is added.
    if (!isQuotationMode && !hasExistingPaymentState) {
      _applyDefaultPaymentMethod();
    }

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);

    CustomerListModelData? checkoutSelectedCustomer =
        selectedCustomer ?? customerSelectionProvider.selectedCustomer;
    final currentOrder = localProductProvider.currentOrder;
    final quotationCustomerPhoneForModal =
        currentOrder?.customerPhone?.trim().isNotEmpty == true
            ? currentOrder!.customerPhone
            : checkoutSelectedCustomer?.phone;
    final defaultCustomerPhone = Provider.of<AppSettingsProvider>(
          context,
          listen: false,
        ).appSettings?.autoAssignDefaultCustomerPhone.trim() ??
        '';
    final quotationCustomerIsDefault = currentOrder?.quotationId != null &&
        (customerSelectionProvider.isDefaultCustomer ||
            (defaultCustomerPhone.isNotEmpty &&
                quotationCustomerPhoneForModal?.trim() ==
                    defaultCustomerPhone));
    final requiresSavedQuotationCustomer = currentOrder?.quotationId != null &&
        (quotationCustomerIsDefault || checkoutSelectedCustomer?.id == null) &&
        ((currentOrder?.customerName?.trim().isNotEmpty ?? false) ||
            (checkoutSelectedCustomer?.name?.trim().isNotEmpty ?? false));
    debugPrint(
        "🧾 [CheckoutOpen] quotationId=${currentOrder?.quotationId}, customerId=${checkoutSelectedCustomer?.id}, customerName=${checkoutSelectedCustomer?.name}, customerPhone=${checkoutSelectedCustomer?.phone}, quotationPhone=$quotationCustomerPhoneForModal, quotationCustomerIsDefault=$quotationCustomerIsDefault, requireSavedCustomer=$requiresSavedQuotationCustomer");

    // Prefer richer customer data from loaded list when IDs match
    if (checkoutSelectedCustomer?.id != null && customerList != null) {
      try {
        checkoutSelectedCustomer = customerList!.firstWhere(
          (customer) => customer.id == checkoutSelectedCustomer!.id,
        );
      } catch (_) {}
    }

    // Check if delivery should be enabled (if methods exist)
    bool deliveryEnabled = deliveryMethodsProvider.deliveryMethods.isNotEmpty;

    debugPrint(
        "⌨️ [BillingPage] Opening checkout modal | mode=$actionMode | ${_focusDebugSummary()}");
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CheckoutModal(
          initialStep: initialStep,
          cartTotal: localProductProvider.priceSummary?.subTotal ??
              localProductProvider.cartTotal,
          availableCustomers: customerList ?? [],
          selectedCustomer: checkoutSelectedCustomer,
          hasOpenedPaymentModalOnce:
              isQuotationMode ? false : _hasOpenedPaymentModalOnce,

          // Delivery State
          enableDelivery: deliveryEnabled,
          deliveryMethod:
              deliveryMethod.isNotEmpty ? deliveryMethod : "Store Takeaway",
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          deliveryComment: _commentController.text,
          deliveryAddress: deliveryAddress ?? "",
          deliveryDate: deliveryDate,
          deliveryTime: deliveryTime,
          initialDeliveryCharge: _selectedDeliveryCharge ?? 0.0,
          onDeliveryUpdated:
              (method, methodId, carNo, comment, date, time, address) {
            setState(() {
              deliveryMethod = method;
              deliveryMethodId = methodId;
              _carNumberController.text = carNo;
              _commentController.text = comment;
              deliveryDate = date;
              deliveryTime = time;
              deliveryAddress = address;
            });
          },
          onDeliveryChargeUpdated: (deliveryCharge) {
            setState(() {
              _selectedDeliveryCharge = deliveryCharge;
            });
            _updateBalanceAmount();
          },

          // Payment State
          isCashSelected: isQuotationMode ? false : _isCashSelected,
          isCardSelected: isQuotationMode ? false : _isCardSelected,
          isUpiSelected: isQuotationMode ? false : _isUpiSelected,
          isCodSelected: isQuotationMode ? false : _isCodSelected,
          isDebitSelected: isQuotationMode ? false : _isDebitSelected,
          cashAmount: isQuotationMode ? '' : _cashAmountController.text,
          cardAmount: isQuotationMode ? '' : _cardAmountController.text,
          upiAmount: isQuotationMode ? '' : _upiAmountController.text,
          codAmount: isQuotationMode ? '' : _codAmountController.text,
          debitAmount: isQuotationMode ? '' : _debitAmountController.text,
          transactionNumber:
              isQuotationMode ? '' : _transactionNumberController.text,
          toCustomerCreditEnabled:
              isQuotationMode ? false : _toCustomerCreditEnabled,
          toCustomerCreditAmount: isQuotationMode
              ? 0.0
              : double.tryParse(_debitAmountController.text) ?? 0.0,
          cashMethodId: billingProvider.cashPaymentMethodId,
          cardMethodId: billingProvider.cardPaymentMethodId,
          upiMethodId: billingProvider.upiPaymentMethodId,
          codMethodId: billingProvider.codPaymentMethodId,

          // Discount State
          couponCode: coupenCodeTextController.text,
          flatDiscount:
              localProductProvider.getCurrentDiscount()['flatDiscount'] ?? 0.0,
          percentageDiscount:
              localProductProvider.getCurrentDiscount()['percentageDiscount'] ??
                  0.0,
          isCouponApplied: isCouponApplied,
          confirmButtonTitle: isQuotationMode
              ? 'Create Quotation'
              : (isSaveMode ? 'billing.save_order'.tr : 'Confirm'),
          printButtonTitle: isQuotationMode
              ? 'Create & Print Quote'
              : (isSaveMode ? 'billing.save_and_print'.tr : 'Confirm & Print'),
          requireCheckoutCompletion: !(isSaveMode || isQuotationMode),
          isQuotationMode: isQuotationMode,
          requireSavedCustomer: requiresSavedQuotationCustomer,
          quotationCustomerId: currentOrder?.quotationId == null
              ? null
              : currentOrder?.customerId,
          quotationCustomerIsDefault: quotationCustomerIsDefault,
          quotationCustomerName: currentOrder?.quotationId == null
              ? null
              : currentOrder?.customerName,
          quotationCustomerPhone: currentOrder?.quotationId == null
              ? null
              : quotationCustomerPhoneForModal,
          initialQuotationDate: _quotationDate,
          initialQuotationExpiryDate: _quotationExpiryDate,
          onQuotationDatesUpdated: (quotationDate, expiryDate) {
            _quotationDate = quotationDate;
            _quotationExpiryDate = expiryDate;
          },

          onCustomerSelected: (customer) {
            // Update global customer selection provider
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .setSelectedCustomer(customer);

            setState(() {
              selectedCustomerID = customer.id;
              selectedCustomerPhone = customer.phone;
              selectedCustomer = customer;
              mobileNumberText = "${customer.name} ${customer.phone}";
              mobileNumberTextController.text =
                  "${customer.name} ${customer.phone}";
              isCustomerFound = true;
              _isCustomerManuallySelected = true;
            });
          },
          onAddNewCustomer: (
            String searchQuery, {
            String? initialName,
            String? initialPhone,
          }) async {
            // Pass numeric search input as-is (including partial phone numbers)
            String phoneToPreFill = '';
            final normalizedSearchQuery = searchQuery.trim();
            if ((initialPhone ?? '').trim().isNotEmpty) {
              phoneToPreFill = initialPhone!.trim();
            } else if (normalizedSearchQuery.isNotEmpty &&
                RegExp(r'^[0-9]+$').hasMatch(normalizedSearchQuery)) {
              phoneToPreFill = normalizedSearchQuery;
            }
            debugPrint(
                "🧾 [CheckoutCustomer] Opening add customer modal prefillName=$initialName, prefillPhone=$phoneToPreFill, search=$searchQuery");

            final result = await showAddCustomerModal(
                context, MediaQuery.of(context).size,
                mobileNumber: phoneToPreFill, customerName: initialName);

            if (result != null && result['status'] == 'success') {
              final responseData = result['response']?['data'];
              final userData = responseData?['user'];
              final customerData = responseData?['customer'];

              final int? createdCustomerId =
                  int.tryParse(customerData?['id']?.toString() ?? '');
              final int? createdUserId =
                  int.tryParse(userData?['id']?.toString() ?? '');
              final int? createdCompanyId =
                  int.tryParse(customerData?['company_id']?.toString() ?? '');
              final int? createdStoreId =
                  int.tryParse(customerData?['store_id']?.toString() ?? '');
              final double? createdBalance =
                  double.tryParse(customerData?['balance']?.toString() ?? '0');

              // Fast path: create local customer object from add API response
              if (createdCustomerId != null) {
                final createdCustomer = CustomerListModelData(
                  id: createdCustomerId,
                  userId: createdUserId,
                  companyId: createdCompanyId,
                  storeId: createdStoreId,
                  name: (userData?['name'] ?? result['name'] ?? '').toString(),
                  email: userData?['email']?.toString(),
                  phone:
                      (userData?['phone'] ?? result['phone'] ?? '').toString(),
                  altPhone: customerData?['alt_phone']?.toString(),
                  gender: customerData?['gender']?.toString(),
                  dob: customerData?['dob']?.toString(),
                  balance: createdBalance,
                  paymentType: customerData?['payment_type']?.toString(),
                  customerType: customerData?['customer_type']?.toString(),
                );

                setState(() {
                  customerList ??= [];
                  customerList!.removeWhere((customer) =>
                      customer.id == createdCustomer.id ||
                      (customer.phone != null &&
                          customer.phone == createdCustomer.phone));
                  customerList!.insert(0, createdCustomer);
                });
                debugPrint(
                    "✅ [CheckoutCustomer] Created local customer id=${createdCustomer.id}, name=${createdCustomer.name}, phone=${createdCustomer.phone}");

                return createdCustomer;
              }

              final addedPhone = result['phone'];
              final normalizedAddedPhone =
                  addedPhone?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
                      '';
              if (normalizedAddedPhone.isNotEmpty && customerList != null) {
                final byPhone = customerList!.firstWhere(
                  (customer) {
                    final customerPhone =
                        customer.phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    return customerPhone == normalizedAddedPhone;
                  },
                  orElse: () => CustomerListModelData(),
                );
                if (byPhone.id != null) return byPhone;
              }
            }
            debugPrint(
                "⚠️ [CheckoutCustomer] Add customer finished without selectable customer");
            return null;
          },
          onDiscountApplied: (code, isApplied, flat, percent) {
            setState(() {
              isCouponApplied = isApplied;
              coupenCodeTextController.text = code;

              // Apply to provider
              if (isApplied) {
                localProductProvider.applyDiscount(
                  flatDiscount: flat,
                  percentageDiscount: percent,
                );
              } else {
                localProductProvider.clearDiscount();
              }
            });
          },
          onPaymentUpdated: (isCash, isCard, isUpi, isCod, isDebit, cash, card,
              upi, cod, debit, trans, toCredit,
              {cashMethodId, cardMethodId, upiMethodId, codMethodId}) {
            // Update payment state
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _isCodSelected = isCod;
            _isDebitSelected = isDebit;
            _cashAmountController.text = cash;
            _cardAmountController.text = card;
            _upiAmountController.text = upi;
            _codAmountController.text = cod;
            _debitAmountController.text = debit;
            _transactionNumberController.text = trans;
            _toCustomerCreditEnabled = toCredit;

            setState(() {
              _hasOpenedPaymentModalOnce =
                  true; // Mark as opened when payment is updated in modal
            });

            // Store payment method IDs in BillingProvider for later use
            billingProvider.updatePaymentFromModal(
              isCash: isCash,
              isCard: isCard,
              isUpi: isUpi,
              isCod: isCod,
              isDebit: isDebit,
              cashAmount: cash,
              cardAmount: card,
              upiAmount: upi,
              codAmount: cod,
              debitAmount: debit,
              transactionNumber: trans,
              toCustomerCredit: toCredit,
              cashMethodId: cashMethodId,
              cardMethodId: cardMethodId,
              upiMethodId: upiMethodId,
              codMethodId: codMethodId,
            );

            // Calculate total paid (excluding debit - it's store credit, not actual payment)
            double total = (double.tryParse(cash) ?? 0) +
                (double.tryParse(card) ?? 0) +
                (double.tryParse(upi) ?? 0) +
                (double.tryParse(cod) ?? 0);

            _paidAmountController.text = total.toStringAsFixed(2);
            _updateBalanceAmount();
          },
          onConfirmOrder: () async {
            checkoutActionTriggered = true;
            setState(() {
              if (isSaveMode || isQuotationMode) {
                isLoadingSaveOrder = true;
              } else {
                isLoadingConfirmOrder = true;
                _hasOpenedPaymentModalOnce = true;
              }
            });
            // Close modal after setting loading state
            if (mounted) Navigator.of(dialogContext).pop();
            if (isQuotationMode) {
              await _createQuotationFromCheckout(shouldPrint: false);
            } else if (isSaveMode) {
              await _saveOrder();
            } else {
              await _confirmOrder();
            }
          },
          onConfirmAndPrint: () async {
            checkoutActionTriggered = true;
            setState(() {
              if (isSaveMode || isQuotationMode) {
                isLoadingSaveOrderAndPrint = true;
              } else {
                isLoadingCreateOrder = true;
                _hasOpenedPaymentModalOnce = true;
              }
            });
            // Close modal after setting loading state
            if (mounted) Navigator.of(dialogContext).pop();
            if (isQuotationMode) {
              await _createQuotationFromCheckout(shouldPrint: true);
            } else if (isSaveMode) {
              await _saveOrderAndPrint();
            } else {
              await _createOrderAndPrint();
            }
          },
        );
      },
    );
    if (mounted && !checkoutActionTriggered) {
      setState(() {
        // Modal was dismissed (Esc/close) without triggering checkout action.
        isLoadingSaveOrder = false;
        isLoadingConfirmOrder = false;
        isLoadingSaveOrderAndPrint = false;
        isLoadingCreateOrder = false;
      });
    }
    debugPrint(
        "⌨️ [BillingPage] Checkout modal closed | mode=$actionMode | busy=$_isOrderActionBusy | ${_focusDebugSummary()}");
    _restoreShortcutFocus('checkout modal closed');
  }

  Future<void> _createQuotationFromCheckout({required bool shouldPrint}) async {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthModel>(context, listen: false);
    final customerProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final quotationsProvider =
        Provider.of<QuotationsProvider>(context, listen: false);
    final storeProvider =
        Provider.of<StoreSessionProvider>(context, listen: false);

    if (localProductProvider.cartItems.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please add items to quote first.',
      );
      setState(() {
        isLoadingSaveOrder = false;
        isLoadingSaveOrderAndPrint = false;
      });
      return;
    }
    final quoteCustomer = customerProvider.selectedCustomer ?? selectedCustomer;
    final quoteCustomerId = customerProvider.selectedCustomerID ??
        selectedCustomerID ??
        quoteCustomer?.id;
    final quoteCustomerName = quoteCustomer?.name?.trim();
    final quoteCustomerPhone =
        (customerProvider.selectedCustomerPhone ?? selectedCustomerPhone)
                    ?.trim()
                    .isNotEmpty ==
                true
            ? (customerProvider.selectedCustomerPhone ?? selectedCustomerPhone)
                ?.trim()
            : quoteCustomer?.phone?.trim();
    final hasExistingCustomer = quoteCustomerId != null;
    final hasInlineCustomer = quoteCustomerName?.isNotEmpty ?? false;

    if (!hasExistingCustomer && !hasInlineCustomer) {
      showScaffoldError(
        context: context,
        message: 'Please select or enter a customer before creating quotation.',
      );
      setState(() {
        isLoadingSaveOrder = false;
        isLoadingSaveOrderAndPrint = false;
      });
      return;
    }
    if (_quotationExpiryDate.isBefore(_quotationDate)) {
      showScaffoldError(
        context: context,
        message: 'Expiry date cannot be before quotation date.',
      );
      setState(() {
        isLoadingSaveOrder = false;
        isLoadingSaveOrderAndPrint = false;
      });
      return;
    }

    try {
      final deliveryMethodIdValue = int.tryParse(deliveryMethodId);
      final deliveryChargeValue = _getDeliveryChargeForOrder();
      final priceSummary = localProductProvider.priceSummary;
      final discountValue = priceSummary?.discount ?? 0.0;
      final payload = <String, dynamic>{
        if (hasExistingCustomer) ...{
          'customer_type': 'existing',
          'customer_id': quoteCustomerId,
        } else ...{
          'customer_type': 'new',
          'customer_name': quoteCustomerName,
          if (quoteCustomerPhone?.isNotEmpty ?? false)
            'customer_phone': quoteCustomerPhone,
        },
        'store_id': storeProvider.activeStore?.storeId,
        if (deliveryMethodIdValue != null)
          'delivery_method_id': deliveryMethodIdValue,
        if (deliveryChargeValue > 0) 'shipping_cost': deliveryChargeValue,
        'quotation_date': DateFormat('yyyy-MM-dd').format(_quotationDate),
        'expiry_date': DateFormat('yyyy-MM-dd').format(_quotationExpiryDate),
        if (discountValue > 0) 'discount': discountValue,
        'comment': _commentController.text, // Reusing delivery comment as note
        'items': localProductProvider.cartItems.map((item) {
          final productStockId = item.stockGroupIds.length == 1
              ? item.stockGroupIds.first
              : item.selectedStock?.id;
          final itemMap = <String, dynamic>{
            'product_id': item.product.productId,
            'quantity': item.hasSaleUnit ? item.displayQuantity : item.quantity,
            'price': item.hasSaleUnit ? item.displayPrice : item.price,
          };
          if (productStockId != null) {
            itemMap['product_stock_id'] = productStockId;
          }
          if (item.saleUnitId != null) {
            itemMap['product_sale_unit_id'] = item.saleUnitId;
          }
          return itemMap;
        }).toList(),
      };

      final response = await quotationsProvider.createQuotation(
        accessToken: authProvider.token ?? '',
        data: payload,
      );
      debugPrint(
          '🧾 BILLING QUOTATION CREATE RESPONSE: ${json.encode(response)}');

      if (mounted) {
        if (response['success'] == true || response['status'] == 'success') {
          showScaffold(
            context: context,
            message: 'Quotation created successfully!',
          );
          final now = DateTime.now();
          _quotationDate = now;
          _quotationExpiryDate = now.add(const Duration(days: 30));
          if (shouldPrint) {
            final quotationId = _extractCreatedQuotationId(response);
            debugPrint(
                '🧾 BILLING QUOTATION EXTRACTED ID FOR PRINT: $quotationId');
            if (quotationId == null) {
              showScaffoldError(
                context: context,
                message:
                    'Quotation created, but print failed because the API response did not include quotation id.',
              );
            } else {
              final details = await quotationsProvider.fetchQuotationDetails(
                accessToken: authProvider.token ?? '',
                quotationId: quotationId,
              );
              debugPrint(
                  '🧾 BILLING QUOTATION DETAILS FOR PRINT: ${_quotationDetailsDebugJson(details)}');
              if (!mounted) return;
              if (details == null) {
                showScaffoldError(
                  context: context,
                  message:
                      'Quotation created, but details could not be loaded for printing.',
                );
              } else {
                Future<bool> printOnce() => _printQuotationDetails(details);
                final autoPrintSuccess = await printOnce();
                await _maybePrintCustomerCopy(
                  canPrompt: autoPrintSuccess,
                  printAction: printOnce,
                );
              }
            }
          }
          _clearCart();
        } else {
          showScaffoldError(
            context: context,
            message: response['message'] ?? 'Failed to create quotation',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Failed to create quotation',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSaveOrder = false;
          isLoadingSaveOrderAndPrint = false;
        });
      }
    }
  }

  dynamic _extractCreatedQuotationId(Map<String, dynamic> response) {
    dynamic readPath(dynamic source, List<String> path) {
      dynamic current = source;
      for (final key in path) {
        if (current is! Map) return null;
        current = current[key];
      }
      return current;
    }

    final candidates = <dynamic>[
      response['quotation_id'],
      response['id'],
      readPath(response, ['data', 'quotation_id']),
      readPath(response, ['data', 'id']),
      readPath(response, ['data', 'quotation', 'id']),
      readPath(response, ['quotation', 'id']),
    ];

    final data = response['data'];
    if (data is int || data is String) {
      candidates.add(data);
    }

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return candidate;
    }
    return null;
  }

  Future<bool> _printQuotationDetails(QuotationDetailsData details) {
    return const QuotationPrintService().printQuotationDetails(
      context,
      details,
      customerOldBalance: selectedCustomer?.balance,
      paidAmount: null,
      paymentMethod: null,
      paymentBreakdown: null,
      customerType: selectedCustomer?.customerType,
      deliveryMethod: deliveryMethod,
      isDefaultCustomer:
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .isDefaultCustomer,
    );
  }

  Map<String, dynamic>? _quotationDetailsDebugJson(
      QuotationDetailsData? details) {
    if (details == null) return null;
    return {
      'id': details.id,
      'quotation_number': details.quotationNumber,
      'status': details.status,
      'customer': {
        'id': details.customer?.id,
        'name': details.customer?.name,
        'phone': details.customer?.phone,
      },
      'store': {
        'id': details.store?.id,
        'name': details.store?.name,
      },
      'quotation_date': details.quotationDate,
      'expiry_date': details.expiryDate,
      'sub_total': details.subTotal,
      'discount': details.discount,
      'tax': details.tax,
      'grand_total': details.grandTotal,
      'invoice_id': details.invoiceId,
      'items': (details.items ?? [])
          .map((item) => {
                'id': item.id,
                'product_id': item.productId,
                'product_name': item.productName,
                'category_id': item.categoryId,
                'category_name': item.categoryName,
                'unit': item.unit,
                'unit_price': item.unitPrice,
                'quantity': item.quantity,
                'tax_rate': item.taxRate,
                'tax_amount': item.taxAmount,
                'total_price': item.totalPrice,
              })
          .toList(),
    };
  }

  // Multi-payment helper methods
  Map<String, String> _getPaymentMethodData() {
    List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
    final List<String> selectedMethodsForStorage =
        List<String>.from(selectedPaymentMethods);
    String paymentMethod = "";
    String paidAmount = "";

    // Get payment method IDs from BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final cashId = billingProvider.cashPaymentMethodId ?? "CASH";
    final cardId = billingProvider.cardPaymentMethodId ?? "CARD";
    final upiId = billingProvider.upiPaymentMethodId ?? "UPI";
    final codId = billingProvider.codPaymentMethodId ?? "COD";
    const debitId = "DEBIT";

    final double debitAmount =
        double.tryParse(_debitAmountController.text) ?? 0;
    if (_toCustomerCreditEnabled && debitAmount > 0) {
      selectedMethodsForStorage.add(debitId);
    }

    if (selectedMethodsForStorage.isNotEmpty) {
      // Always store payment as multi-payment JSON (even when a single method is selected).
      // This keeps local-save and sync request bodies in the same structure.
      Map<String, dynamic> multiPaymentData = {
        "methods": selectedMethodsForStorage,
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
          debitId: debitAmount > 0 ? _debitAmountController.text : "0",
        },
        "isMultiPayment": true
      };
      paymentMethod = json.encode(multiPaymentData);
      paidAmount = _getTotalPaidAmount().toString();
    } else {
      // No payment method selected - leave empty
      paymentMethod = "";
      paidAmount = "0";
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
    final _ = localProductProvider.cartTotal;
    double cartTotal = _getEffectiveOrderTotal();

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

  double _getDeliveryChargeForOrder() {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final isDeliveryChargeEnabled =
        appSettingsProvider.appSettings?.freeDeliveryEnabled ?? false;

    if (!isDeliveryChargeEnabled) {
      return 0.0;
    }

    final minimumAmount = double.tryParse(
            appSettingsProvider.appSettings?.freeDeliveryMinimumAmount.trim() ??
                '') ??
        0.0;

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final netAmount = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;

    if (minimumAmount > 0 && netAmount >= minimumAmount) {
      return 0.0;
    }

    if (_selectedDeliveryCharge != null) {
      return _selectedDeliveryCharge!;
    }

    if (deliveryMethod.isEmpty) {
      return 0.0;
    }

    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if ((deliveryMethodId.isNotEmpty && method.id == deliveryMethodId) ||
          method.name == deliveryMethod) {
        return method.basePrice ?? 0.0;
      }
    }

    return 0.0;
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
    final paidMethods = <Map<String, dynamic>>[];

    // Get payment method IDs from BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final cashId = billingProvider.cashPaymentMethodId ?? "CASH";
    final cardId = billingProvider.cardPaymentMethodId ?? "CARD";
    final upiId = billingProvider.upiPaymentMethodId ?? "UPI";
    final codId = billingProvider.codPaymentMethodId ?? "COD";

    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": cashId,
        "amount": double.tryParse(_cashAmountController.text) ?? 0,
      });
    }

    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": cardId,
        "amount": double.tryParse(_cardAmountController.text) ?? 0,
      });
    }

    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": upiId,
        "amount": double.tryParse(_upiAmountController.text) ?? 0,
      });
    }

    if (_isCodSelected &&
        (double.tryParse(_codAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": codId,
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
    return PaymentHelper.normalizePaidMethodsForApi(
      paidMethods: paidMethods,
      balanceAmount: _balanceAmount,
      cashMethodId: cashId,
      codMethodId: codId,
    );
  }

  Widget _buildQuickAccessIcons() {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 5),
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
                // Payment Method Icon
                _buildQuickAccessIcon(
                  icon: _getPaymentIcon(),
                  label: _getPaymentLabel(),
                  color: ColorManager.kPrimaryColor,
                  onTap: () => _showPaymentMethodModal(),
                ),
              ],
            ),
            // Note: Total Paid and Balance are now shown in the sidebar footer
            // This matches the Restaurant Page layout
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
    final effectiveTotal = _getEffectiveOrderTotal();

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
    if (!hasAnyAmount && effectiveTotal > 0) {
      String totalStr = effectiveTotal.toStringAsFixed(2);
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
        initialCash = effectiveTotal.toStringAsFixed(2);
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
        cartTotal: effectiveTotal,
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
            _hasOpenedPaymentModalOnce =
                true; // Set flag here to indicate user manually made a selection (even if None)
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
            _selectedDeliveryCharge = null;
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
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

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

  void resetAutocomplete({bool shouldFetchCustomers = false}) {
    debugPrint(
        "🔄 resetAutocomplete called - shouldFetchCustomers: $shouldFetchCustomers");
    debugPrint("  - _isCustomerManuallySelected: $_isCustomerManuallySelected");
    debugPrint("  - mobileNumberText: '$mobileNumberText'");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

    setState(() {
      _autocompleteProductKey = GlobalKey();
      isCustomerFound = false;

      if (shouldFetchCustomers) {
        debugPrint(
            "  - Customer fetch from resetAutocomplete is disabled by design");
      }

      deliveryMethodId = _getDefaultDeliveryMethodId();
      _selectedDeliveryCharge = null;

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

  Future<bool> _confirmCustomerCopyPrint() async {
    return (await ConfirmationDialog.show(
          context: context,
          title: 'Print customer copy?',
          message: 'Do you want to print a customer copy now?',
          confirmText: 'Yes, print',
          cancelText: 'No',
        )) ??
        false;
  }

  Future<void> _maybePrintCustomerCopy({
    required bool canPrompt,
    required Future<bool> Function() printAction,
  }) async {
    if (!canPrompt || !mounted) return;

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final shouldDoublePrint =
        appSettingsProvider.appSettings?.posPrintDoubleBill ?? false;
    if (!shouldDoublePrint) return;

    final shouldPrintCustomerCopy = await _confirmCustomerCopyPrint();
    if (!shouldPrintCustomerCopy || !mounted) return;

    await printAction();
  }

  Future<bool> _printOrderDetailsWithFallback({
    required List<dynamic> cartItems,
    required String formattedTotal,
    String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    String? tokenNumber,
    bool isFromLocalStorage = false,
    String? storeName,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
    String? customerAlternatePhone,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
    String? paymentMethod,
    Map<String, dynamic>? paymentBreakdown,
    String? orderComment,
    String? deliveryMethod,
    bool isDefaultCustomer = false,
    String? netExcTax,
  }) async {
    if (!mounted) return false;

    final autoPrintSuccess = await PrintPage.autoPrint(
      context,
      storeName: storeName,
      cartItems: cartItems,
      formattedTotal: formattedTotal,
      savedTotal: savedTotal,
      discountAmount: discountAmount,
      orderDate: orderDate,
      orderNumber: orderNumber,
      tokenNumber: tokenNumber,
      isFromLocalStorage: isFromLocalStorage,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      customerOldBalance: customerOldBalance,
      customerCurrentBalance: customerCurrentBalance,
      paidAmount: paidAmount,
      customerAlternatePhone: customerAlternatePhone,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
      paymentMethod: paymentMethod,
      paymentBreakdown: paymentBreakdown,
      orderComment: orderComment,
      deliveryMethod: deliveryMethod,
      isDefaultCustomer: isDefaultCustomer,
      netExcTax: netExcTax,
    );

    if (!autoPrintSuccess && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: cartItems,
            formattedTotal: formattedTotal,
            savedTotal: savedTotal,
            discountAmount: discountAmount,
            orderDate: orderDate,
            orderNumber: orderNumber,
            tokenNumber: tokenNumber,
            isFromLocalStorage: isFromLocalStorage,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            customerOldBalance: customerOldBalance,
            customerCurrentBalance: customerCurrentBalance,
            paidAmount: paidAmount,
            customerAlternatePhone: customerAlternatePhone,
            customerVatNumber: customerVatNumber,
            customerCrNumber: customerCrNumber,
            customerType: customerType,
            paymentMethod: paymentMethod,
            paymentBreakdown: paymentBreakdown,
            orderComment: orderComment,
            deliveryMethod: deliveryMethod,
            isDefaultCustomer: isDefaultCustomer,
            netExcTax: netExcTax,
          ),
        ),
      );
    }

    return autoPrintSuccess;
  }

  Future<void> printFromSavedOrder(SavedOrder savedOrder) async {
    try {
      {
        final printService = const PrintService();
        Future<bool> printOnce() => printService.printSavedOrder(
              context,
              savedOrder,
            );

        final autoPrintSuccess = await printOnce();
        await _maybePrintCustomerCopy(
          canPrompt: autoPrintSuccess,
          printAction: printOnce,
        );
        return;
      }
/*
      // Extract cart items from the saved order
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;
      double totalTax = 0.0;

      // Convert SavedOrder items to the format expected by PrintPage
      for (var item in savedOrder.items) {
        // Calculate individual item values
        double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        double itemTotalPrice = itemPrice * item.quantity;
        double itemTax = (item.taxAmount ?? 0.0) * item.quantity;

        // Add to totals for "You Saved" calculation
        totalMRP += itemMrp * item.quantity;
        netTotal += itemTotalPrice;
        totalTax += itemTax;

        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': itemMrp.toString(),
          'quantity': item.quantity.toString(),
          'product_unit': item.product.unit ?? '',
          'unitPrice': itemPrice.toString(),
          'totalPrice': itemTotalPrice.toString(),
          'tax_amount': itemTax.toString(),
        });
      }

      // 🔧 FIX: Calculate "You Saved" using Option 3 approach
      double youSaved = totalMRP - netTotal;
      youSaved = youSaved > 0 ? youSaved : 0.0; // Ensure non-negative
      double netExcTax = netTotal - totalTax;

      // Debug - check what's being sent
      debugPrint("🖨️ BILLING SAVE AND PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - Total Tax: $totalTax");
      debugPrint("  - Net Exc Tax: $netExcTax");
      debugPrint("  - You Saved: $youSaved");
      debugPrint("Sending ${cartItems.length} items to PrintPage");
      debugPrint(
          "Sample item: ${cartItems.isNotEmpty ? json.encode(cartItems[0]) : 'No items'}");

      // Get active store name
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final storeName = storeSession.activeStore?.storeName ?? "Store";

      // Parse multi-payment JSON into human-readable names and breakdown
      final parsedPayment = PaymentHelper.parseLocalMultiPayment(
          context, savedOrder.paymentMethod);
      final String? displayPaymentMethod =
          parsedPayment?.paymentMethodDisplay ?? savedOrder.paymentMethod;
      final Map<String, dynamic>? paymentBreakdown =
          parsedPayment?.paymentBreakdown;

      Future<bool> printOnce() {
        return _printOrderDetailsWithFallback(
          storeName: storeName,
          cartItems: cartItems,
          formattedTotal: savedOrder.total.toString(),
          savedTotal: youSaved.toString(),
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
          paymentMethod: displayPaymentMethod,
          paymentBreakdown: paymentBreakdown,
          customerAlternatePhone: savedOrder.alternatePhone,
          customerVatNumber: savedOrder.customerVatNumber,
          customerCrNumber: savedOrder.customerCrNumber,
          customerType: savedOrder.customerType,
          orderComment: savedOrder.comment,
          deliveryMethod: savedOrder.deliveryMethod ?? deliveryMethod,
          paidAmount: (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0) > 0
              ? (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0)
              : null,
          isDefaultCustomer: _isDefaultCustomerPhone(savedOrder.customerPhone),
          netExcTax: netExcTax.toString(),
        );
      }

      final autoPrintSuccess = await printOnce();
      await _maybePrintCustomerCopy(
        canPrompt: autoPrintSuccess,
        printAction: printOnce,
      );
*/
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
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    if (localProductProvider.currentOrder?.quotationId != null) {
      debugPrint(
          "🧾 [BillingCustomer] Phone $phone is not treated as default because quotationId=${localProductProvider.currentOrder?.quotationId}");
      return false;
    }
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
    if (!mounted) return;
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

    // Do not fetch customers here. Customer list is refreshed on store selection
    // and in background after successful confirmed sale.
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
      _selectedDeliveryCharge = null;

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
    if (!mounted) return;
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

    // Do not fetch customers here. Customer list is refreshed on store selection
    // and in background after successful confirmed sale.
  }

  void _initializeDeliveryMethod() {
    // Set initial default values
    deliveryMethod = "Store Takeaway";
    deliveryMethodId = "11"; // Updated to match API response
    _selectedDeliveryCharge = null;

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

      _deliveryMethodListener = updateDeliveryMethod;

      // Add listeners
      deliveryMethodsProvider.addListener(_deliveryMethodListener!);
      appSettingsProvider.addListener(_deliveryMethodListener!);

      // Initial check
      updateDeliveryMethod();
    });
  }

  void _initializePaymentMethod() {
    if (_isQuotationPage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);

      void updatePaymentMethod() {
        setState(() {
          _applyDefaultPaymentMethod();
        });
      }

      _paymentMethodListener = updatePaymentMethod;

      appSettingsProvider.addListener(_paymentMethodListener!);
      updatePaymentMethod();
    });
  }

  void _applyDefaultPaymentMethod() {
    if (_isQuotationPage) {
      return;
    }

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
          final match = deliveryMethodsProvider.deliveryMethods.firstWhere(
              (m) =>
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
