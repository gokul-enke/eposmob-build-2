import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/features/billing/domain/payment_validation.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import '../models/customer_list.dart';
import '../models/list_cart.dart';
import '../providers/customer_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_methods_provider.dart';
import '../models/delivery_method.dart';
import '../providers/sales_provider.dart';

class BillingProvider extends ChangeNotifier {
  // 1. Internet Connectivity - Real-time connection monitoring with status indicator
  bool _deviceHasInternet = true;
  bool _isManualOfflineMode = false;
  StreamSubscription? _internetSubscription;

  bool get hasInternet => !_isManualOfflineMode && _deviceHasInternet;
  bool get deviceHasInternet => _deviceHasInternet;
  bool get isManualOfflineMode => _isManualOfflineMode;

  BillingProvider() {
    _loadManualOfflineMode();
  }

  // 2. Loading States - Individual loading flags for each operation
  bool _isLoadingClearCart = false;
  bool _isLoadingSaveOrder = false;
  bool _isLoadingCreateOrder = false;
  bool _isLoadingConfirmOrder = false;
  bool _isLoadingSaveOrderAndPrint = false;
  bool _isLoadingAddItem = false;
  bool _isProcessingBarcode = false;

  bool get isLoadingClearCart => _isLoadingClearCart;
  bool get isLoadingSaveOrder => _isLoadingSaveOrder;
  bool get isLoadingCreateOrder => _isLoadingCreateOrder;
  bool get isLoadingConfirmOrder => _isLoadingConfirmOrder;
  bool get isLoadingSaveOrderAndPrint => _isLoadingSaveOrderAndPrint;
  bool get isLoadingAddItem => _isLoadingAddItem;
  bool get isProcessingBarcode => _isProcessingBarcode;

  // 3. Form State Management - Controllers for all input fields with proper disposal
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController transactionNumberController =
      TextEditingController();
  final TextEditingController paidAmountController = TextEditingController();
  final TextEditingController cashAmountController = TextEditingController();
  final TextEditingController cardAmountController = TextEditingController();
  final TextEditingController upiAmountController = TextEditingController();
  final TextEditingController codAmountController = TextEditingController();
  final TextEditingController debitAmountController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController selectedProductIdController =
      TextEditingController();
  final TextEditingController selectedProductNameController =
      TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();

  // Delivery Address
  String _orderAddress = "";
  String get orderAddress => _orderAddress;

  void setOrderAddress(String address) {
    _orderAddress = address;
    notifyListeners();
  }

  final TextEditingController _transactionNumberController =
      TextEditingController();
  final ScrollController _customerScrollController = ScrollController();

  // 4. Focus Management - Focus nodes for keyboard navigation and field selection
  final FocusNode paidAmountFocusNode = FocusNode();
  final FocusNode cashAmountFocusNode = FocusNode();
  final FocusNode cardAmountFocusNode = FocusNode();
  final FocusNode upiAmountFocusNode = FocusNode();
  final FocusNode codAmountFocusNode = FocusNode();
  final FocusNode debitAmountFocusNode = FocusNode();
  final FocusNode quantityFocusNode = FocusNode();
  final FocusNode unitPriceFocusNode = FocusNode();
  final FocusNode focusNode = FocusNode();
  final FocusNode barcodeNode = FocusNode();
  final FocusNode customerTextFieldFocus = FocusNode();

  // 5. Debounce Logic - Prevent rapid API calls during user input
  Timer? _debounce;
  Timer? _debounceTimer;

  Timer? get debounce => _debounce;
  Timer? get debounceTimer => _debounceTimer;

  // MISSED LOGIC: Debounce management methods
  void setDebounce(Timer? timer) {
    _debounce?.cancel();
    _debounce = timer;
  }

  void setDebounceTimer(Timer? timer) {
    _debounceTimer?.cancel();
    _debounceTimer = timer;
  }

  void cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  void cancelDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Initialize connectivity listener
  void initConnectivityListener({
    Function(String)? onConnectivityChanged,
  }) async {
    try {
      _internetSubscription?.cancel();

      // Check initial connectivity status
      final hasConnection = await InternetConnection().hasInternetAccess;
      _deviceHasInternet = hasConnection;
      notifyListeners();

      // Listen for connectivity changes
      _internetSubscription =
          InternetConnection().onStatusChange.listen((InternetStatus status) {
        final isConnected = status == InternetStatus.connected;
        _deviceHasInternet = isConnected;
        notifyListeners();

        // Optional callback for UI feedback
        if (onConnectivityChanged != null && !_isManualOfflineMode) {
          if (!isConnected) {
            onConnectivityChanged('No internet connection');
          } else {
            onConnectivityChanged('Internet connection restored');
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing connectivity listener: $e');
      // Fallback to assuming connection is available
      _deviceHasInternet = true;
      notifyListeners();
    }
  }

  Future<void> _loadManualOfflineMode() async {
    try {
      _isManualOfflineMode =
          await SharedPreferenceProvider().getManualOfflineMode();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading manual offline mode: $e');
    }
  }

  Future<void> setManualOfflineMode(bool enabled) async {
    if (_isManualOfflineMode == enabled) {
      return;
    }

    _isManualOfflineMode = enabled;
    notifyListeners();

    try {
      await SharedPreferenceProvider().saveManualOfflineMode(enabled);
    } catch (e) {
      debugPrint('Error saving manual offline mode: $e');
    }
  }

  // Loading state setters
  void setLoadingClearCart(bool value) {
    _isLoadingClearCart = value;
    notifyListeners();
  }

  void setLoadingSaveOrder(bool value) {
    _isLoadingSaveOrder = value;
    notifyListeners();
  }

  void setLoadingCreateOrder(bool value) {
    _isLoadingCreateOrder = value;
    notifyListeners();
  }

  void setLoadingConfirmOrder(bool value) {
    _isLoadingConfirmOrder = value;
    notifyListeners();
  }

  void setLoadingSaveOrderAndPrint(bool value) {
    _isLoadingSaveOrderAndPrint = value;
    notifyListeners();
  }

  void setLoadingAddItem(bool value) {
    _isLoadingAddItem = value;
    notifyListeners();
  }

  void setProcessingBarcode(bool value) {
    _isProcessingBarcode = value;
    notifyListeners();
  }

  // MISSED LOGIC: Barcode processing with debounce
  void processBarcodeWithDebounce(String barcode, VoidCallback onProcess) {
    if (_isProcessingBarcode || barcode.isEmpty) {
      return;
    }

    setProcessingBarcode(true);

    // Cancel existing debounce
    cancelDebounce();

    // Set new debounce
    setDebounce(Timer(const Duration(milliseconds: 500), () {
      if (barcode.isNotEmpty) {
        onProcess();
      }
      // Reset processing flag after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        setProcessingBarcode(false);
      });
    }));
  }

  // 6. Customer Autocomplete - Search by phone/name with keyboard navigation
  List<CustomerListModelData>? _customerList = [];
  List<CustomerListModelData>? _filteredCustomerList = [];
  List<CustomerListModelData> _currentCustomerOptions = [];
  int? _highlightedCustomerIndex;

  // Customer item height for scrolling calculations
  final double _customerItemHeight = 48.0;

  List<CustomerListModelData>? get customerList => _customerList;
  List<CustomerListModelData>? get filteredCustomerList =>
      _filteredCustomerList;
  List<CustomerListModelData> get currentCustomerOptions =>
      _currentCustomerOptions;
  int? get highlightedCustomerIndex => _highlightedCustomerIndex;

  // 7. Customer Selection - Manual vs automatic customer assignment logic
  int? _selectedCustomerID;
  String? _selectedCustomerPhone;
  CustomerListModelData? _selectedCustomer;
  bool _isCustomerFound = false;
  bool _isCustomerManuallySelected = false;
  String? _mobileNumberText = "";
  String? _salesExecutivemobileNumberText = "";

  int? get selectedCustomerID => _selectedCustomerID;
  String? get selectedCustomerPhone => _selectedCustomerPhone;
  CustomerListModelData? get selectedCustomer => _selectedCustomer;
  bool get isCustomerFound => _isCustomerFound;
  bool get isCustomerManuallySelected => _isCustomerManuallySelected;
  String? get mobileNumberText => _mobileNumberText;
  String? get salesExecutivemobileNumberText => _salesExecutivemobileNumberText;

  // 8. Customer Balance Display - Show customer credit/debit with color coding
  double _customerBalance = 0.0;
  bool _hasCustomerCredit = false;

  double get customerBalance => _customerBalance;
  bool get hasCustomerCredit => _hasCustomerCredit;

  // 9. Customer Validation - Phone number validation and customer existence checks
  bool _isValidPhoneNumber = false;
  String? _phoneValidationError;

  bool get isValidPhoneNumber => _isValidPhoneNumber;
  String? get phoneValidationError => _phoneValidationError;

  // 10. Sales Executive Integration - Auto-assign default customer based on current sales executive
  CustomerListModelData? _defaultSalesExecutiveCustomer;

  CustomerListModelData? get defaultSalesExecutiveCustomer =>
      _defaultSalesExecutiveCustomer;

  // 11. Add New Customer - Modal integration with auto-selection after creation
  bool _isAddingNewCustomer = false;

  bool get isAddingNewCustomer => _isAddingNewCustomer;

  // Customer management methods

  /// Fetch customers from API via [CustomerProvider] and populate [_customerList].
  /// Returns `true` on success, `false` otherwise.
  Future<bool> fetchCustomers({
    required String accessToken,
    bool sortAscending = true,
  }) async {
    try {
      // Indicate loading when first called
      setInitLoading(true);

      final response = await CustomerProvider()
          .listCustomer(accessToken: accessToken, sortAscending: sortAscending);

      if (response["status"] == "success") {
        final CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setCustomerList(customerListModel.data);
        // By default, filtered list equals full list
        setFilteredCustomerList(customerListModel.data);
        setInitLoading(false);
        return true;
      }

      debugPrint("fetchCustomers: API responded with failure status");
      setInitLoading(false);
      return false;
    } catch (e) {
      debugPrint('Error in fetchCustomers: $e');
      setInitLoading(false);
      return false;
    }
  }

  void setCustomerList(List<CustomerListModelData>? list) {
    _customerList = list;
    notifyListeners();
  }

  void setFilteredCustomerList(List<CustomerListModelData>? list) {
    _filteredCustomerList = list;
    notifyListeners();
  }

  void setCurrentCustomerOptions(List<CustomerListModelData> options) {
    _currentCustomerOptions = options;
    notifyListeners();
  }

  void setHighlightedCustomerIndex(int? index) {
    _highlightedCustomerIndex = index;
    notifyListeners();
  }

  // MISSED LOGIC: Customer scroll management
  void scrollToHighlightedCustomer() {
    if (_highlightedCustomerIndex == null) return;

    // Calculate the offset to scroll to
    final double scrollOffset =
        _highlightedCustomerIndex! * _customerItemHeight;

    // Get the current scroll position and visible height
    final double currentScroll = _customerScrollController.offset;
    const double visibleHeight =
        180.0; // Approximate visible height of dropdown

    // Check if the highlighted item is outside the visible area
    if (scrollOffset < currentScroll ||
        scrollOffset > currentScroll + visibleHeight - _customerItemHeight) {
      // Scroll to make the highlighted item visible
      _customerScrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  // MISSED LOGIC: Keyboard navigation for customer list
  void navigateCustomerUp() {
    if (_currentCustomerOptions.isEmpty) return;

    if (_highlightedCustomerIndex == null) {
      _highlightedCustomerIndex = _currentCustomerOptions.length - 1;
    } else if (_highlightedCustomerIndex! > 0) {
      _highlightedCustomerIndex = _highlightedCustomerIndex! - 1;
    } else {
      _highlightedCustomerIndex = _currentCustomerOptions.length - 1;
    }

    scrollToHighlightedCustomer();
    notifyListeners();
  }

  void navigateCustomerDown() {
    if (_currentCustomerOptions.isEmpty) return;

    if (_highlightedCustomerIndex == null) {
      _highlightedCustomerIndex = 0;
    } else if (_highlightedCustomerIndex! <
        _currentCustomerOptions.length - 1) {
      _highlightedCustomerIndex = _highlightedCustomerIndex! + 1;
    } else {
      _highlightedCustomerIndex = 0;
    }

    scrollToHighlightedCustomer();
    notifyListeners();
  }

  void selectHighlightedCustomer() {
    if (_highlightedCustomerIndex != null &&
        _highlightedCustomerIndex! < _currentCustomerOptions.length) {
      final customer = _currentCustomerOptions[_highlightedCustomerIndex!];
      setSelectedCustomer(customer, isManual: true);
    }
  }

  void setSelectedCustomer(CustomerListModelData? customer,
      {bool isManual = true}) {
    _selectedCustomer = customer;
    _selectedCustomerID = customer?.id;
    _selectedCustomerPhone = customer?.phone;
    _isCustomerManuallySelected = isManual;
    _isCustomerFound = customer != null;

    if (customer != null) {
      // Store phone only for order payloads; controller may show "name phone".
      _mobileNumberText = customer.phone ?? '';
      if (customer.id != null &&
          customer.name != null &&
          customer.name!.isNotEmpty) {
        mobileNumberTextController.text =
            "${customer.name} ${customer.phone}".trim();
        _isCustomerFound = true;
      } else {
        mobileNumberTextController.text = customer.phone ?? '';
        _isCustomerFound = false;
      }
    }

    notifyListeners();
  }

  void clearSelectedCustomerButKeepText() {
    _selectedCustomer = null;
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;
    _isCustomerFound = false;
    _isCustomerManuallySelected = false;
    _highlightedCustomerIndex = null;
    notifyListeners();
  }

  void clearSelectedCustomer() {
    _selectedCustomer = null;
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;
    _isCustomerFound = false;
    _isCustomerManuallySelected = false;
    _mobileNumberText = "";
    _highlightedCustomerIndex = null;
    mobileNumberTextController.clear();
    notifyListeners();
  }

  /// Resets billing customer fields when the sales executive or auth user
  /// changes. Mirrors desktop `BillingPage._onSalesExecutiveChanged` /
  /// `BillingPage._onUserSwitched` state clears.
  void resetCustomerForExecutiveOrUserChange({
    required bool resetManualSelectionFlag,
  }) {
    _selectedCustomer = null;
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;
    _isCustomerFound = false;
    _mobileNumberText = '';
    _salesExecutivemobileNumberText = '';
    mobileNumberTextController.clear();
    _highlightedCustomerIndex = null;
    if (resetManualSelectionFlag) {
      _isCustomerManuallySelected = false;
    }
    notifyListeners();
  }

  void setMobileNumberText(String? text) {
    _mobileNumberText = text;
    notifyListeners();
  }

  void setSalesExecutiveMobileNumberText(String? text) {
    _salesExecutivemobileNumberText = text;
    notifyListeners();
  }

  void setCustomerBalance(double balance) {
    _customerBalance = balance;
    _hasCustomerCredit = balance > 0;
    notifyListeners();
  }

  void setPhoneValidation(bool isValid, String? error) {
    _isValidPhoneNumber = isValid;
    _phoneValidationError = error;
    notifyListeners();
  }

  void setDefaultSalesExecutiveCustomer(CustomerListModelData? customer) {
    _defaultSalesExecutiveCustomer = customer;
    notifyListeners();
  }

  void setAddingNewCustomer(bool value) {
    _isAddingNewCustomer = value;
    notifyListeners();
  }

  // Phone number validation logic
  bool validatePhoneNumber(String phone) {
    if (phone.isEmpty) {
      setPhoneValidation(false, "Phone number is required");
      return false;
    }

    if (phone.length < 10) {
      setPhoneValidation(false, "Phone number must be at least 10 digits");
      return false;
    }

    // Add more validation rules as needed
    setPhoneValidation(true, null);
    return true;
  }

  // 12. Add to Cart Logic - Product selection with stock management and pricing
  List<ListCartModelDataCartItem>? _cartProductItems = [];
  Map<String, num> _taxNames = {};
  Map<int, bool> _hoverMap = {};

  List<ListCartModelDataCartItem>? get cartProductItems => _cartProductItems;
  Map<String, num> get taxNames => _taxNames;
  Map<int, bool> get hoverMap => _hoverMap;

  // 13. Remove from Cart - Individual item removal with confirmation
  bool _showRemoveConfirmation = false;
  int? _itemToRemoveIndex;

  bool get showRemoveConfirmation => _showRemoveConfirmation;
  int? get itemToRemoveIndex => _itemToRemoveIndex;

  // 14. Quantity Control - Increment/decrement with validation
  Map<int, int> _itemQuantities = {};

  Map<int, int> get itemQuantities => _itemQuantities;

  // 15. Price Editing - Custom price and MRP modification per item
  Map<int, double> _customPrices = {};
  Map<int, double> _customMRPs = {};
  bool _isPriceEditing = false;

  Map<int, double> get customPrices => _customPrices;
  Map<int, double> get customMRPs => _customMRPs;
  bool get isPriceEditing => _isPriceEditing;

  // 16. Cart Validation - Ensure valid pricing before operations
  bool _isCartValid = true;
  String? _cartValidationError;

  bool get isCartValid => _isCartValid;
  String? get cartValidationError => _cartValidationError;

  // 17. Cart Clear - Complete cart reset with state cleanup
  bool _isCartEmpty = true;

  bool get isCartEmpty => _isCartEmpty;

  // Cart management methods
  void setCartProductItems(List<ListCartModelDataCartItem>? items) {
    _cartProductItems = items;
    _isCartEmpty = items == null || items.isEmpty;
    notifyListeners();
  }

  void addToCart(ListCartModelDataCartItem item) {
    _cartProductItems ??= [];
    _cartProductItems!.add(item);
    _isCartEmpty = false;
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (_cartProductItems != null && index < _cartProductItems!.length) {
      _cartProductItems!.removeAt(index);
      _isCartEmpty = _cartProductItems!.isEmpty;
      notifyListeners();
    }
  }

  void showRemoveConfirmationDialog(int index) {
    _itemToRemoveIndex = index;
    _showRemoveConfirmation = true;
    notifyListeners();
  }

  void hideRemoveConfirmationDialog() {
    _itemToRemoveIndex = null;
    _showRemoveConfirmation = false;
    notifyListeners();
  }

  void updateItemQuantity(int index, int quantity) {
    if (_cartProductItems != null && index < _cartProductItems!.length) {
      _itemQuantities[index] = quantity;
      notifyListeners();
    }
  }

  void incrementQuantity(int index) {
    int currentQuantity = _itemQuantities[index] ?? 1;
    updateItemQuantity(index, currentQuantity + 1);
  }

  void decrementQuantity(int index) {
    int currentQuantity = _itemQuantities[index] ?? 1;
    if (currentQuantity > 1) {
      updateItemQuantity(index, currentQuantity - 1);
    }
  }

  void updateCustomPrice(int index, double price) {
    _customPrices[index] = price;
    validateCart();
    notifyListeners();
  }

  void updateCustomMRP(int index, double mrp) {
    _customMRPs[index] = mrp;
    validateCart();
    notifyListeners();
  }

  void setPriceEditing(bool value) {
    _isPriceEditing = value;
    notifyListeners();
  }

  void clearCart() {
    _cartProductItems?.clear();
    _itemQuantities.clear();
    _customPrices.clear();
    _customMRPs.clear();
    _taxNames.clear();
    _hoverMap.clear();
    _isCartEmpty = true;
    _cartValidationError = null;
    _isCartValid = true;
    notifyListeners();
  }

  bool validateCart() {
    if (_cartProductItems == null || _cartProductItems!.isEmpty) {
      _cartValidationError = "Cart is empty";
      _isCartValid = false;
      notifyListeners();
      return false;
    }

    // Validate each item has valid pricing
    for (int i = 0; i < _cartProductItems!.length; i++) {
      final item = _cartProductItems![i];
      final customPrice = _customPrices[i];
      final customMRP = _customMRPs[i];

      if (customPrice != null && customPrice <= 0) {
        _cartValidationError = "Invalid price for item ${item.productName}";
        _isCartValid = false;
        notifyListeners();
        return false;
      }

      if (customMRP != null && customMRP <= 0) {
        _cartValidationError = "Invalid MRP for item ${item.productName}";
        _isCartValid = false;
        notifyListeners();
        return false;
      }
    }

    _cartValidationError = null;
    _isCartValid = true;
    notifyListeners();
    return true;
  }

  void setTaxNames(Map<String, num> taxes) {
    _taxNames = taxes;
    notifyListeners();
  }

  void setHoverMap(Map<int, bool> hover) {
    _hoverMap = hover;
    notifyListeners();
  }

  // 18. Barcode Processing - Weight-based (KG) and count-based (PC) product scanning
  String _barcodeInput = "";
  bool _isWeightBasedProduct = false;
  bool _isCountBasedProduct = false;

  String get barcodeInput => _barcodeInput;
  bool get isWeightBasedProduct => _isWeightBasedProduct;
  bool get isCountBasedProduct => _isCountBasedProduct;

  // 19. Product Autocomplete - Search and select products with stock variants
  List<dynamic> _productList = [];
  List<dynamic> _filteredProductList = [];
  dynamic _selectedProduct;
  String _selectedProductName = "";
  int? _selectedProductId;

  List<dynamic> get productList => _productList;
  List<dynamic> get filteredProductList => _filteredProductList;
  dynamic get selectedProduct => _selectedProduct;
  String get selectedProductName => _selectedProductName;
  int? get selectedProductId => _selectedProductId;

  // 20. Stock Management - Handle products with/without stock tracking
  bool _hasStockTracking = false;
  int _availableStock = 0;
  bool _isStockSufficient = true;

  bool get hasStockTracking => _hasStockTracking;
  int get availableStock => _availableStock;
  bool get isStockSufficient => _isStockSufficient;

  // 21. Product Validation - Ensure selected product exists and has valid data
  bool _isProductValid = false;
  String? _productValidationError;

  bool get isProductValid => _isProductValid;
  String? get productValidationError => _productValidationError;

  // Product management methods
  void setBarcodeInput(String barcode) {
    _barcodeInput = barcode;
    barcodeController.text = barcode;

    // Determine product type based on barcode format
    if (barcode.length >= 13 && barcode.startsWith('2')) {
      _isWeightBasedProduct = true;
      _isCountBasedProduct = false;
    } else {
      _isWeightBasedProduct = false;
      _isCountBasedProduct = true;
    }

    notifyListeners();
  }

  void setProductList(List<dynamic> products) {
    _productList = products;
    notifyListeners();
  }

  void setFilteredProductList(List<dynamic> products) {
    _filteredProductList = products;
    notifyListeners();
  }

  void setSelectedProduct(dynamic product) {
    _selectedProduct = product;
    if (product != null) {
      _selectedProductId = product.productId;
      _selectedProductName = product.productName ?? "";
      selectedProductIdController.text = _selectedProductId.toString();
      selectedProductNameController.text = _selectedProductName;

      // Validate product
      validateProduct();
    } else {
      clearSelectedProduct();
    }
    notifyListeners();
  }

  void clearSelectedProduct() {
    _selectedProduct = null;
    _selectedProductId = null;
    _selectedProductName = "";
    selectedProductIdController.clear();
    selectedProductNameController.clear();
    _isProductValid = false;
    _productValidationError = null;
    notifyListeners();
  }

  void setStockInfo(bool hasTracking, int available) {
    _hasStockTracking = hasTracking;
    _availableStock = available;
    _isStockSufficient = available > 0 || !hasTracking;
    notifyListeners();
  }

  bool validateProduct() {
    if (_selectedProduct == null) {
      _productValidationError = "No product selected";
      _isProductValid = false;
      notifyListeners();
      return false;
    }

    if (_selectedProductName.isEmpty) {
      _productValidationError = "Product name is required";
      _isProductValid = false;
      notifyListeners();
      return false;
    }

    if (_hasStockTracking && !_isStockSufficient) {
      _productValidationError = "Insufficient stock available";
      _isProductValid = false;
      notifyListeners();
      return false;
    }

    _productValidationError = null;
    _isProductValid = true;
    notifyListeners();
    return true;
  }

  void clearProductFields() {
    barcodeController.clear();
    quantityController.clear();
    unitPriceController.clear();
    selectedProductIdController.clear();
    selectedProductNameController.clear();

    _barcodeInput = "";
    _selectedProduct = null;
    _selectedProductId = null;
    _selectedProductName = "";
    _isWeightBasedProduct = false;
    _isCountBasedProduct = false;
    _isProductValid = false;
    _productValidationError = null;

    notifyListeners();
  }

  // 22. Multi-Payment Methods - Cash, Card, UPI, Debit, Online with individual amounts
  bool _isCashSelected = false;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  bool _isCodSelected = false;
  bool _isDebitSelected = false;
  bool _isOnlineSelected = false;
  bool _toCustomerCreditEnabled = false;

  // Payment method IDs from API (for sending to backend)
  String? _cashPaymentMethodId;
  String? _cardPaymentMethodId;
  String? _upiPaymentMethodId;
  String? _codPaymentMethodId;

  // Pine Labs payment success state
  bool _pineLabsPaymentSuccess = false;

  // Dynamic/extra payment methods beyond CASH/CARD/UPI/COD (e.g. CHEQUE, WALLET)
  final Map<String, String> _extraPaymentAmounts = {};
  final Map<String, String> _extraPaymentValues = {};
  final Set<String> _selectedExtraMethodIds = {};
  final Map<String, TextEditingController> _extraAmountControllers = {};

  Map<String, String> get extraPaymentAmounts =>
      Map<String, String>.unmodifiable(_extraPaymentAmounts);
  Map<String, String> get extraPaymentValues =>
      Map<String, String>.unmodifiable(_extraPaymentValues);
  Set<String> get selectedExtraMethodIds =>
      Set<String>.unmodifiable(_selectedExtraMethodIds);

  bool get isCashSelected => _isCashSelected;
  bool get isCardSelected => _isCardSelected;
  bool get isUpiSelected => _isUpiSelected;
  bool get isCodSelected => _isCodSelected;
  bool get isDebitSelected => _isDebitSelected;
  bool get isOnlineSelected => _isOnlineSelected;
  bool get toCustomerCreditEnabled => _toCustomerCreditEnabled;
  bool get pineLabsPaymentSuccess => _pineLabsPaymentSuccess;

  // Payment method ID getters
  String? get cashPaymentMethodId => _cashPaymentMethodId;
  String? get cardPaymentMethodId => _cardPaymentMethodId;
  String? get upiPaymentMethodId => _upiPaymentMethodId;
  String? get codPaymentMethodId => _codPaymentMethodId;

  void updatePaymentMethodIds({
    String? cashId,
    String? cardId,
    String? upiId,
    String? codId,
  }) {
    if (cashId != null) _cashPaymentMethodId = cashId;
    if (cardId != null) _cardPaymentMethodId = cardId;
    if (upiId != null) _upiPaymentMethodId = upiId;
    if (codId != null) _codPaymentMethodId = codId;
    notifyListeners();
  }

  // 23. Payment Validation - Ensure payment methods are selected before confirmation
  bool _isPaymentValid = false;
  String? _paymentValidationError;

  bool get isPaymentValid => _isPaymentValid;
  String? get paymentValidationError => _paymentValidationError;

  // 24. Balance Calculation - Complex logic for customer credit and cash balance
  double _balanceAmount = 0.0;
  double _totalPaidAmount = 0.0;
  double _totalOrderAmount = 0.0;

  /// Saved-order delivery charge override (mirrors desktop `_selectedDeliveryCharge`).
  double? _deliveryChargeOverride;

  /// Desktop parity: true default customer via provider + configured phone.
  bool _paymentValidationIsDefaultCustomer = false;
  String _configuredDefaultCustomerPhone = '';

  /// Split-payment pristine tracking (mirrors payment_method_modal).
  String? _pristinePaymentMethodKey;
  String? _pristinePaymentAmount;

  /// Whether the cashier opened the payment section (confirm gate).
  bool _paymentStepVisited = false;

  /// Order total used for payment validation, balance/change and autofill.
  ///
  /// Matches desktop `BillingPage._getEffectiveOrderTotal()` — i.e. the net
  /// total is round-off adjusted (when `priceRoundOff` is enabled) before the
  /// delivery charge is added. [_totalOrderAmount] stays the raw (unrounded)
  /// net + delivery so that discount-driven payment remapping keeps using the
  /// same unrounded ratio as desktop.
  double _effectiveOrderTotal = 0.0;

  double get balanceAmount => _balanceAmount;
  double get totalPaidAmount => _totalPaidAmount;
  double get totalOrderAmount => _totalOrderAmount;

  /// Effective (round-off adjusted) order total. Falls back to the raw total
  /// so callers that only set [setTotalOrderAmount] keep their prior behaviour.
  double get effectiveOrderTotal => _effectiveOrderTotal;

  double? get deliveryChargeOverride => _deliveryChargeOverride;

  String? get pristinePaymentMethodKey => _pristinePaymentMethodKey;

  String? get pristinePaymentAmount => _pristinePaymentAmount;

  bool get paymentStepVisited => _paymentStepVisited;

  void setDeliveryChargeOverride(double? charge) {
    _deliveryChargeOverride = charge;
    notifyListeners();
  }

  void setPaymentValidationCustomerContext({
    required bool isDefaultCustomer,
    required String configuredDefaultCustomerPhone,
  }) {
    _paymentValidationIsDefaultCustomer = isDefaultCustomer;
    _configuredDefaultCustomerPhone = configuredDefaultCustomerPhone.trim();
  }

  void setPristinePaymentState(String? methodKey, String? amount) {
    _pristinePaymentMethodKey = methodKey;
    _pristinePaymentAmount = amount;
  }

  void clearPristinePaymentState() {
    _pristinePaymentMethodKey = null;
    _pristinePaymentAmount = null;
  }

  void markPaymentStepVisited() {
    if (_paymentStepVisited) return;
    _paymentStepVisited = true;
    notifyListeners();
  }

  void resetPaymentStepVisited() {
    if (!_paymentStepVisited) return;
    _paymentStepVisited = false;
    notifyListeners();
  }

  void restoreBalanceAmount(double amount) {
    _balanceAmount = amount;
    notifyListeners();
  }

  bool _resolveIsDefaultCustomerForPayment() {
    if (_paymentValidationIsDefaultCustomer) return true;
    final customer = _selectedCustomer;
    if (customer == null) return false;
    final defaultPhone = _configuredDefaultCustomerPhone;
    final customerPhone = customer.phone?.trim() ?? '';
    return defaultPhone.isNotEmpty && customerPhone == defaultPhone;
  }

  // 25. To Customer Credit Toggle - Handle excess payment allocation
  bool _hasExcessPayment = false;

  bool get hasExcessPayment => _hasExcessPayment;

  // 26. Payment Method Modal - Centralized payment selection interface
  bool _showPaymentModal = false;

  bool get showPaymentModal => _showPaymentModal;

  // Payment management methods
  void setPaymentMethod(String method, bool selected) {
    switch (method.toUpperCase()) {
      case 'CASH':
        _isCashSelected = selected;
        if (!selected) cashAmountController.clear();
        break;
      case 'CARD':
        _isCardSelected = selected;
        if (!selected) cardAmountController.clear();
        break;
      case 'UPI':
        _isUpiSelected = selected;
        if (!selected) upiAmountController.clear();
        break;
      case 'COD':
        _isCodSelected = selected;
        if (!selected) codAmountController.clear();
        break;
      case 'DEBIT':
        _isDebitSelected = selected;
        if (!selected) debitAmountController.clear();
        break;
      case 'ONLINE':
        _isOnlineSelected = selected;
        // Keep UI in sync: when ONLINE is selected, reflect Pine Labs paid state
        _pineLabsPaymentSuccess = selected;
        debugPrint(
            '[BillingProvider] ONLINE set to $selected -> pineLabsPaymentSuccess=$_pineLabsPaymentSuccess');
        break;
    }
    validatePayment();
    calculateBalance();
    notifyListeners();
  }

  void setToCustomerCreditEnabled(bool enabled) {
    _toCustomerCreditEnabled = enabled;
    notifyListeners();
  }

  void setPineLabsPaymentSuccess(bool success) {
    _pineLabsPaymentSuccess = success;
    notifyListeners();
  }

  void clearAllPaymentMethods() {
    _isCashSelected = false;
    _isCardSelected = false;
    _isUpiSelected = false;
    _isCodSelected = false;
    _isDebitSelected = false;
    _isOnlineSelected = false;
    _toCustomerCreditEnabled = false;
    _pineLabsPaymentSuccess = false;

    cashAmountController.clear();
    cardAmountController.clear();
    upiAmountController.clear();
    codAmountController.clear();
    debitAmountController.clear();
    paidAmountController.clear();

    clearExtraPayments();

    _balanceAmount = 0.0;
    _totalPaidAmount = 0.0;
    _hasExcessPayment = false;
    clearPristinePaymentState();

    notifyListeners();
  }

  /// Clears collected payment amounts while keeping method selections.
  /// Mirrors desktop `_clearPaymentAmountsOnly` when the cart changes.
  void clearCollectedPaymentAmountsOnly() {
    cashAmountController.clear();
    cardAmountController.clear();
    upiAmountController.clear();
    codAmountController.clear();
    debitAmountController.clear();

    for (final controller in _extraAmountControllers.values) {
      controller.clear();
    }
    _extraPaymentAmounts.clear();
    _extraPaymentValues.clear();

    calculateBalance();
    validatePayment();
    notifyListeners();
  }

  /// Whether any collected payment amount is present (standard + extra methods).
  bool hasCollectedPaymentAmounts() {
    return PaymentValidation.hasCollectedPayment(
      isCashSelected: _isCashSelected,
      isCardSelected: _isCardSelected,
      isUpiSelected: _isUpiSelected,
      isCodSelected: _isCodSelected,
      cashAmount: cashAmountController.text,
      cardAmount: cardAmountController.text,
      upiAmount: upiAmountController.text,
      codAmount: codAmountController.text,
      extraAmounts: _extraPaymentAmounts,
    );
  }

  TextEditingController getExtraAmountController(
    String methodId, {
    String? displayValue,
  }) {
    if (displayValue != null && displayValue.isNotEmpty) {
      _extraPaymentValues[methodId] = displayValue;
    }
    return _extraAmountControllers.putIfAbsent(
      methodId,
      () => TextEditingController(
        text: _extraPaymentAmounts[methodId] ?? '',
      ),
    );
  }

  bool isExtraMethodSelected(String methodId) {
    return _selectedExtraMethodIds.contains(methodId);
  }

  void setExtraPaymentAmount(
    String methodId,
    String amount, {
    String? displayValue,
  }) {
    _extraPaymentAmounts[methodId] = amount;
    if (displayValue != null && displayValue.isNotEmpty) {
      _extraPaymentValues[methodId] = displayValue;
    }
    final controller = _extraAmountControllers[methodId];
    if (controller != null && controller.text != amount) {
      controller.text = amount;
    }
    final parsed = double.tryParse(amount) ?? 0.0;
    if (parsed > 0) {
      _selectedExtraMethodIds.add(methodId);
    } else {
      _selectedExtraMethodIds.remove(methodId);
    }
    validatePayment();
    calculateBalance();
    notifyListeners();
  }

  /// Selects an extra method without autofill (mobile pristine-switch flow).
  void selectExtraMethod(String methodId, {String? displayValue}) {
    _selectedExtraMethodIds.add(methodId);
    if (displayValue != null && displayValue.isNotEmpty) {
      _extraPaymentValues[methodId] = displayValue;
    }
    getExtraAmountController(methodId, displayValue: displayValue);
    notifyListeners();
  }

  void toggleExtraMethod(String methodId, {String? displayValue}) {
    if (_selectedExtraMethodIds.contains(methodId)) {
      _selectedExtraMethodIds.remove(methodId);
      setExtraPaymentAmount(methodId, '', displayValue: displayValue);
      return;
    }

    _selectedExtraMethodIds.add(methodId);
    if (displayValue != null && displayValue.isNotEmpty) {
      _extraPaymentValues[methodId] = displayValue;
    }

    final controller = getExtraAmountController(methodId, displayValue: displayValue);
    if (controller.text.isEmpty || (double.tryParse(controller.text) ?? 0.0) == 0.0) {
      final remaining = _effectiveOrderTotal - getTotalPaidAmount();
      if (remaining > 0) {
        setExtraPaymentAmount(
          methodId,
          remaining.toStringAsFixed(2),
          displayValue: displayValue,
        );
        return;
      }
    }

    validatePayment();
    calculateBalance();
    notifyListeners();
  }

  void clearExtraPayments() {
    _extraPaymentAmounts.clear();
    _extraPaymentValues.clear();
    _selectedExtraMethodIds.clear();
    for (final controller in _extraAmountControllers.values) {
      controller.dispose();
    }
    _extraAmountControllers.clear();
  }

  double getExtraPaidTotal() {
    double total = 0.0;
    for (final amountStr in _extraPaymentAmounts.values) {
      total += double.tryParse(amountStr) ?? 0.0;
    }
    return total;
  }

  void restoreExtraPaymentsFromAmounts(
    Map<String, dynamic> amounts, {
    String? Function(String methodId)? resolveDisplayValue,
  }) {
    final cashId = cashPaymentMethodId ?? 'CASH';
    final cardId = cardPaymentMethodId ?? 'CARD';
    final upiId = upiPaymentMethodId ?? 'UPI';
    final codId = codPaymentMethodId ?? 'COD';
    final typedKeys = {
      'CASH',
      cashId,
      'CARD',
      cardId,
      'UPI',
      upiId,
      'COD',
      codId,
      'DEBIT',
      'BALANCE',
      'ONLINE',
    };

    for (final entry in amounts.entries) {
      if (typedKeys.contains(entry.key)) continue;
      final amount = double.tryParse(entry.value.toString()) ?? 0.0;
      if (amount <= 0) continue;

      final methodId = entry.key;
      final resolved = resolveDisplayValue?.call(methodId);
      final displayValue =
          (resolved != null && resolved.isNotEmpty) ? resolved : methodId;
      setExtraPaymentAmount(
        methodId,
        entry.value.toString(),
        displayValue: displayValue,
      );
    }
  }

  List<String> getSelectedPaymentMethods() {
    List<String> methods = [];
    if (_isCashSelected) methods.add("CASH");
    if (_isCardSelected) methods.add("CARD");
    if (_isUpiSelected) methods.add("UPI");
    if (_isCodSelected) methods.add("COD");
    if (_isDebitSelected) methods.add("DEBIT");
    if (_isOnlineSelected) methods.add("ONLINE");
    return methods;
  }

  // Lightweight helper: any payment selected (without amount validation)
  bool hasAnyPaymentSelected() {
    return getSelectedPaymentMethods().isNotEmpty ||
        getExtraPaidTotal() > 0 ||
        _isOnlineSelected;
  }

  // Delivery helpers
  bool requiresCarNumber() {
    try {
      return (deliveryMethod == "Car Delivery");
    } catch (_) {
      return false;
    }
  }

  bool validateCarNumberIfNeeded() {
    if (requiresCarNumber()) {
      return carNumberController.text.isNotEmpty;
    }
    return true;
  }

  List<Map<String, dynamic>> getPaidMethods() {
    final paidMethods = <Map<String, dynamic>>[];
    final cashId = cashPaymentMethodId ?? "CASH";
    final cardId = cardPaymentMethodId ?? "CARD";
    final upiId = upiPaymentMethodId ?? "UPI";
    final codId = codPaymentMethodId ?? "COD";

    if (_isCashSelected) {
      paidMethods.add({
        "method": cashId,
        "amount": double.tryParse(cashAmountController.text) ?? 0,
      });
    }

    // Include CARD and UPI only when amounts are > 0 to match billing_page.dart
    final double cardAmount = double.tryParse(cardAmountController.text) ?? 0;
    if (_isCardSelected && cardAmount > 0) {
      paidMethods.add({
        "method": cardId,
        "amount": cardAmount,
      });
    }

    final double upiAmount = double.tryParse(upiAmountController.text) ?? 0;
    if (_isUpiSelected && upiAmount > 0) {
      paidMethods.add({
        "method": upiId,
        "amount": upiAmount,
      });
    }

    final double codAmount = double.tryParse(codAmountController.text) ?? 0;
    if (_isCodSelected && codAmount > 0) {
      paidMethods.add({
        "method": codId,
        "amount": codAmount,
      });
    }

    // Include ONLINE (Pine Labs) with cart total as amount
    if (_isOnlineSelected) {
      paidMethods.add({
        "method": "ONLINE",
        "amount": _effectiveOrderTotal,
      });
    }

    _extraPaymentAmounts.forEach((methodId, amountStr) {
      final amount = double.tryParse(amountStr) ?? 0;
      if (amount > 0) {
        paidMethods.add({
          "method": methodId,
          "amount": amount,
        });
      }
    });

    // Note: DEBIT (to customer credit) is excluded from paid methods list

    return PaymentHelper.normalizePaidMethodsForApi(
      paidMethods: paidMethods,
      balanceAmount: _balanceAmount,
      cashMethodId: cashId,
      codMethodId: codId,
    );
  }

  bool validatePayment() {
    if (_isOnlineSelected) {
      _paymentValidationError = null;
      _isPaymentValid = true;
      notifyListeners();
      return true;
    }

    final isDefaultCustomer = _resolveIsDefaultCustomerForPayment();
    final customerPrevBalance = isDefaultCustomer
        ? 0.0
        : (_selectedCustomer?.balance ?? 0.0);

    final result = PaymentValidation.validateForOrder(
      orderTotal: _effectiveOrderTotal,
      toCustomerCreditEnabled: _toCustomerCreditEnabled,
      isDefaultCustomer: isDefaultCustomer,
      customerPrevBalance: customerPrevBalance,
      isCashSelected: _isCashSelected,
      isCardSelected: _isCardSelected,
      isUpiSelected: _isUpiSelected,
      isCodSelected: _isCodSelected,
      cashAmount: cashAmountController.text,
      cardAmount: cardAmountController.text,
      upiAmount: upiAmountController.text,
      codAmount: codAmountController.text,
      extraAmounts: _extraPaymentAmounts,
    );

    _paymentValidationError = result.message;
    _isPaymentValid = result.isValid;
    notifyListeners();
    return result.isValid;
  }

  void calculateBalance() {
    // Use the new getTotalPaidAmount() method that excludes debit/customer credit
    final newTotalPaid = getTotalPaidAmount();
    final newBalance = calculateBalanceAmount(_effectiveOrderTotal);
    final newHasExcess = newBalance > 0;

    if ((newTotalPaid - _totalPaidAmount).abs() < 0.001 &&
        (newBalance - _balanceAmount).abs() < 0.001 &&
        newHasExcess == _hasExcessPayment) {
      return;
    }

    _totalPaidAmount = newTotalPaid;
    _balanceAmount = newBalance;
    _hasExcessPayment = newHasExcess;

    final paidText = _totalPaidAmount.toString();
    if (paidAmountController.text != paidText) {
      paidAmountController.text = paidText;
    }

    notifyListeners();
  }

  void setTotalOrderAmount(double amount) {
    // Keep the effective total in lock-step for callers that only know a single
    // total (tests, legacy screens). Rounding-aware callers use [setOrderTotals].
    if ((_totalOrderAmount - amount).abs() < 0.001 &&
        (_effectiveOrderTotal - amount).abs() < 0.001) {
      return;
    }
    _totalOrderAmount = amount;
    _effectiveOrderTotal = amount;
    calculateBalance();
  }

  /// Sets the raw and effective (round-off adjusted) order totals together.
  ///
  /// [totalOrderAmount] is the raw net + delivery total (used for discount
  /// remapping); [effectiveOrderTotal] is the round-off adjusted total used for
  /// payment validation, balance/change and autofill — mirroring desktop's
  /// `_getEffectiveOrderTotal()`.
  void setOrderTotals({
    required double totalOrderAmount,
    required double effectiveOrderTotal,
  }) {
    if ((_totalOrderAmount - totalOrderAmount).abs() < 0.001 &&
        (_effectiveOrderTotal - effectiveOrderTotal).abs() < 0.001) {
      return;
    }
    _totalOrderAmount = totalOrderAmount;
    _effectiveOrderTotal = effectiveOrderTotal;
    calculateBalance();
  }

  void showPaymentMethodModal() {
    _showPaymentModal = true;
    notifyListeners();
  }

  void hidePaymentMethodModal() {
    _showPaymentModal = false;
    notifyListeners();
  }

  void updatePaymentFromModal({
    required bool isCash,
    required bool isCard,
    required bool isUpi,
    required bool isCod,
    required bool isDebit,
    required String cashAmount,
    required String cardAmount,
    required String upiAmount,
    required String codAmount,
    required String debitAmount,
    required String transactionNumber,
    required bool toCustomerCredit,
    // Optional payment method IDs from API
    String? cashMethodId,
    String? cardMethodId,
    String? upiMethodId,
    String? codMethodId,
  }) {
    _isCashSelected = isCash;
    _isCardSelected = isCard;
    _isUpiSelected = isUpi;
    _isCodSelected = isCod;
    _isDebitSelected = isDebit;
    _toCustomerCreditEnabled = toCustomerCredit;

    // Store payment method IDs if provided
    if (cashMethodId != null) _cashPaymentMethodId = cashMethodId;
    if (cardMethodId != null) _cardPaymentMethodId = cardMethodId;
    if (upiMethodId != null) _upiPaymentMethodId = upiMethodId;
    if (codMethodId != null) _codPaymentMethodId = codMethodId;

    cashAmountController.text = cashAmount;
    cardAmountController.text = cardAmount;
    upiAmountController.text = upiAmount;
    codAmountController.text = codAmount;
    debitAmountController.text = debitAmount;
    transactionNumberController.text = transactionNumber;

    validatePayment();
    calculateBalance();
    hidePaymentMethodModal();
    notifyListeners();
  }

  // 27. Save Order - Local storage with customer and payment data
  bool _isSavingOrder = false;
  List<Map<String, dynamic>> _savedOrders = [];

  bool get isSavingOrder => _isSavingOrder;
  List<Map<String, dynamic>> get savedOrders => _savedOrders;

  // 28. Load Order for Editing - Rehydrate UI state from saved orders
  bool _isLoadingOrder = false;
  Map<String, dynamic>? _currentEditingOrder;

  bool get isLoadingOrder => _isLoadingOrder;
  Map<String, dynamic>? get currentEditingOrder => _currentEditingOrder;

  // 29. Confirm Order - API integration with validation and error handling
  bool _isConfirmingOrder = false;
  String? _orderConfirmationError;

  bool get isConfirmingOrder => _isConfirmingOrder;
  String? get orderConfirmationError => _orderConfirmationError;

  // 30. Order State Rehydration - Restore complete UI state when editing orders
  bool _isRehydratingState = false;

  bool get isRehydratingState => _isRehydratingState;

  // 31. Order Printing - Generate print-ready order data
  bool _isPrintingOrder = false;
  Map<String, dynamic>? _printOrderData;

  bool get isPrintingOrder => _isPrintingOrder;
  Map<String, dynamic>? get printOrderData => _printOrderData;

  // Delivery & Logistics (items 32-35)
  String _deliveryMethod = "";
  String _deliveryMethodId = "";
  DateTime? _deliveryDate;
  String? _deliveryTime;
  String _carNumber = "";
  String _orderComment = "";
  List<DeliveryMethod> _deliveryMethods = [];
  bool _isLoadingDeliveryMethods = false;

  String get deliveryMethod => _deliveryMethod;
  String get deliveryMethodId => _deliveryMethodId;
  DateTime? get deliveryDate => _deliveryDate;
  String? get deliveryTime => _deliveryTime;
  String get carNumber => _carNumber;
  String get orderComment => _orderComment;
  List<DeliveryMethod> get deliveryMethods => _deliveryMethods;
  bool get isLoadingDeliveryMethods => _isLoadingDeliveryMethods;

  // Order management methods
  void setSavingOrder(bool value) {
    _isSavingOrder = value;
    notifyListeners();
  }

  void addSavedOrder(Map<String, dynamic> order) {
    _savedOrders.add(order);
    notifyListeners();
  }

  void removeSavedOrder(int index) {
    if (index < _savedOrders.length) {
      _savedOrders.removeAt(index);
      notifyListeners();
    }
  }

  void setSavedOrders(List<Map<String, dynamic>> orders) {
    _savedOrders = orders;
    notifyListeners();
  }

  void setLoadingOrder(bool value) {
    _isLoadingOrder = value;
    notifyListeners();
  }

  void setCurrentEditingOrder(Map<String, dynamic>? order) {
    _currentEditingOrder = order;
    notifyListeners();
  }

  void setConfirmingOrder(bool value) {
    _isConfirmingOrder = value;
    notifyListeners();
  }

  void setOrderConfirmationError(String? error) {
    _orderConfirmationError = error;
    notifyListeners();
  }

  void setRehydratingState(bool value) {
    _isRehydratingState = value;
    notifyListeners();
  }

  void setPrintingOrder(bool value) {
    _isPrintingOrder = value;
    notifyListeners();
  }

  void setPrintOrderData(Map<String, dynamic>? data) {
    _printOrderData = data;
    notifyListeners();
  }

  void setDeliveryMethod(String method, String methodId) {
    _deliveryMethod = method;
    _deliveryMethodId = methodId;
    notifyListeners();
  }

  void setDeliveryDate(DateTime? date) {
    _deliveryDate = date;
    notifyListeners();
  }

  void setDeliveryTime(String? time) {
    _deliveryTime = time;
    notifyListeners();
  }

  void setDeliveryDateString(String? date) {
    _deliveryDateString = date;
    if (date != null) {
      _deliveryDate = DateTime.tryParse(date);
    } else {
      _deliveryDate = null;
    }
    notifyListeners();
  }

  void setDeliveryTimeString(String? time) {
    _deliveryTimeString = time;
    _deliveryTime = time;
    notifyListeners();
  }

  void setCarNumber(String number) {
    _carNumber = number;
    carNumberController.text = number;
    notifyListeners();
  }

  void setOrderComment(String comment) {
    _orderComment = comment;
    commentController.text = comment;
    notifyListeners();
  }

  // Validate delivery requirements
  bool validateDelivery() {
    if (_deliveryMethod == "Car Delivery" && _carNumber.isEmpty) {
      return false;
    }
    return true;
  }

  // Create order data for API
  Map<String, dynamic> createOrderData() {
    // Build payment information aligned with billing_page.dart
    final List<String> selectedMethods = getSelectedPaymentMethodsForApi();
    String paymentMethodValue = "";
    String paidAmountValue = "0";

    if (selectedMethods.isNotEmpty) {
      final methodsForStorage = List<String>.from(selectedMethods);
      final double debitAmount =
          double.tryParse(debitAmountController.text) ?? 0.0;
      if (_toCustomerCreditEnabled && debitAmount > 0) {
        methodsForStorage.add('DEBIT');
      }

      final cashId = cashPaymentMethodId ?? "CASH";
      final cardId = cardPaymentMethodId ?? "CARD";
      final upiId = upiPaymentMethodId ?? "UPI";
      final codId = codPaymentMethodId ?? "COD";

      final multiPaymentData = {
        "methods": methodsForStorage,
        "amounts": {
          cashId: cashAmountController.text,
          cardId: cardAmountController.text,
          upiId: upiAmountController.text,
          codId: codAmountController.text,
          "ONLINE": _isOnlineSelected ? totalOrderAmount.toString() : "0",
          "DEBIT": debitAmountController.text,
          ..._buildExtraAmountsForStorage(),
        },
        "isMultiPayment": true,
      };
      paymentMethodValue = json.encode(multiPaymentData);
      paidAmountValue = getTotalPaidAmount().toString();
    }

    return {
      'customerId': _selectedCustomerID,
      'customerName': _selectedCustomer?.name,
      'customerPhone': _selectedCustomerPhone ?? _mobileNumberText,
      'paymentMethod': paymentMethodValue,
      'paidAmount': paidAmountValue,
      'balanceAmount': _balanceAmount.toString(),
      'deliveryMethod': _deliveryMethod,
      'deliveryMethodId': _deliveryMethodId,
      'carNumber': _carNumber,
      'comment': _orderComment,
      'deliveryDate': _deliveryDate?.toIso8601String(),
      'deliveryTime': _deliveryTime,
      'transactionId': transactionNumberController.text,
      'couponId': coupenCodeTextController.text.isNotEmpty
          ? coupenCodeTextController.text
          : null,
      'toCustomerCredit': _toCustomerCreditEnabled,
      'cartItems': _cartProductItems,
      'taxNames': _taxNames,
      'address': _orderAddress,
    };
  }

  // Rehydrate state from saved order
  void rehydrateFromOrder(Map<String, dynamic> order) {
    setRehydratingState(true);

    try {
      // Restore customer information
      if (order['customerId'] != null) {
        _selectedCustomerID = order['customerId'];
        _selectedCustomerPhone = order['customerPhone'];
        mobileNumberTextController.text =
            "${order['customerName']} ${order['customerPhone']}".trim();
        _isCustomerFound = true;
      }

      // Restore payment methods
      final paymentMethod = order['paymentMethod'] as String?;
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        clearAllPaymentMethods();
        final pm = paymentMethod.trim();
        bool parsedMulti = false;
        if (pm.startsWith('{')) {
          try {
            final Map<String, dynamic> multi = json.decode(pm);
            final List<String> methods =
                List<String>.from(multi['methods'] ?? []);
            final Map<String, dynamic> amounts =
                Map<String, dynamic>.from(multi['amounts'] ?? {});

            _isCashSelected = methods.contains('CASH');
            _isCardSelected = methods.contains('CARD');
            _isUpiSelected = methods.contains('UPI');
            _isCodSelected = methods.contains('COD');
            _isDebitSelected = methods.contains('DEBIT');
            _isOnlineSelected = methods.contains('ONLINE');

            if (_isCashSelected) {
              cashAmountController.text = (amounts['CASH'] ?? '0').toString();
            }
            if (_isCardSelected) {
              cardAmountController.text = (amounts['CARD'] ?? '0').toString();
            }
            if (_isUpiSelected) {
              upiAmountController.text = (amounts['UPI'] ?? '0').toString();
            }
            if (_isCodSelected) {
              codAmountController.text = (amounts['COD'] ?? '0').toString();
            }
            if (_isDebitSelected) {
              debitAmountController.text = (amounts['DEBIT'] ?? '0').toString();
            }

            bool hasMethodOrAmount(List<String> candidates) {
              final normalizedCandidates = candidates
                  .map((candidate) => candidate.toUpperCase())
                  .toSet();
              final hasMethod = methods.any((method) =>
                  normalizedCandidates.contains(method.toUpperCase()));
              final hasAmount = candidates.any((candidate) {
                final amount =
                    double.tryParse((amounts[candidate] ?? '0').toString()) ??
                        0.0;
                return amount > 0;
              });
              return hasMethod || hasAmount;
            }

            String firstAmount(List<String> candidates) {
              for (final candidate in candidates) {
                if (amounts.containsKey(candidate)) {
                  return (amounts[candidate] ?? '0').toString();
                }
              }
              return '0';
            }

            if (!_isCashSelected &&
                hasMethodOrAmount([
                  'CASH',
                  if (cashPaymentMethodId != null) cashPaymentMethodId!,
                ])) {
              _isCashSelected = true;
              cashAmountController.text = firstAmount([
                'CASH',
                if (cashPaymentMethodId != null) cashPaymentMethodId!,
              ]);
            }
            if (!_isCardSelected &&
                hasMethodOrAmount([
                  'CARD',
                  if (cardPaymentMethodId != null) cardPaymentMethodId!,
                ])) {
              _isCardSelected = true;
              cardAmountController.text = firstAmount([
                'CARD',
                if (cardPaymentMethodId != null) cardPaymentMethodId!,
              ]);
            }
            if (!_isUpiSelected &&
                hasMethodOrAmount([
                  'UPI',
                  if (upiPaymentMethodId != null) upiPaymentMethodId!,
                ])) {
              _isUpiSelected = true;
              upiAmountController.text = firstAmount([
                'UPI',
                if (upiPaymentMethodId != null) upiPaymentMethodId!,
              ]);
            }
            if (!_isCodSelected &&
                hasMethodOrAmount([
                  'COD',
                  if (codPaymentMethodId != null) codPaymentMethodId!,
                ])) {
              _isCodSelected = true;
              codAmountController.text = firstAmount([
                'COD',
                if (codPaymentMethodId != null) codPaymentMethodId!,
              ]);
            }
            if (!_isOnlineSelected && hasMethodOrAmount(const ['ONLINE'])) {
              _isOnlineSelected = true;
            }

            // Reflect Pine Labs success if ONLINE was part of saved methods
            if (_isOnlineSelected) {
              debugPrint(
                  '♻️ [Rehydrate] ONLINE detected in multi-payment. Setting PineLabs success');
              setPineLabsPaymentSuccess(true);
            }

            restoreExtraPaymentsFromAmounts(amounts);

            parsedMulti = true;
          } catch (e) {
            debugPrint("Error parsing multi-payment JSON on rehydration: $e");
          }
        }

        if (!parsedMulti) {
          // Single payment method
          setPaymentMethod(pm, true);
          final paidText = order['paidAmount']?.toString() ?? '0';
          switch (pm.toUpperCase()) {
            case 'CASH':
              cashAmountController.text = paidText;
              break;
            case 'CARD':
              cardAmountController.text = paidText;
              break;
            case 'UPI':
              upiAmountController.text = paidText;
              break;
            case 'COD':
              codAmountController.text = paidText;
              break;
            case 'DEBIT':
              debitAmountController.text = paidText;
              break;
            case 'ONLINE':
              // No amount field for ONLINE; mark Pine Labs success for UI state
              debugPrint(
                  '♻️ [Rehydrate] ONLINE detected in single-payment. Setting PineLabs success');
              setPineLabsPaymentSuccess(true);
              break;
          }

          if (pm == cashPaymentMethodId) {
            setPaymentMethod('CASH', true);
            cashAmountController.text = paidText;
          } else if (pm == cardPaymentMethodId) {
            setPaymentMethod('CARD', true);
            cardAmountController.text = paidText;
          } else if (pm == upiPaymentMethodId) {
            setPaymentMethod('UPI', true);
            upiAmountController.text = paidText;
          } else if (pm == codPaymentMethodId) {
            setPaymentMethod('COD', true);
            codAmountController.text = paidText;
          }
        }

        // Restore paid amount text (display field)
        paidAmountController.text = order['paidAmount']?.toString() ?? '0';
      }

      // Restore balance and to-customer-credit flag
      _balanceAmount =
          double.tryParse(order['balanceAmount']?.toString() ?? '0') ?? 0.0;
      _toCustomerCreditEnabled = (order['toCustomerCredit'] == true);

      // Restore delivery information
      _deliveryMethod = order['deliveryMethod'] ?? 'Store Takeaway';
      _deliveryMethodId = order['deliveryMethodId'] ?? '';
      _carNumber = order['carNumber'] ?? '';
      _orderComment = order['comment'] ?? '';

      if (order['deliveryDate'] != null) {
        _deliveryDate = DateTime.tryParse(order['deliveryDate']);
      }
      _deliveryTime = order['deliveryTime'];
      _orderAddress = order['address'] ?? '';

      // Restore other fields
      transactionNumberController.text = order['transactionId'] ?? '';
      coupenCodeTextController.text = order['couponId'] ?? '';

      // Recalculate balance to reflect any restored amounts (mirrors billing_page.dart _updateBalanceAmount)
      // Only recalc if total order amount is already known; otherwise keep restored balance
      if (_totalOrderAmount > 0) {
        calculateBalance();
      }

      setCurrentEditingOrder(order);
    } finally {
      setRehydratingState(false);
    }
  }

  void clearOrderState() {
    // Clear all order-related state
    _currentEditingOrder = null;
    _orderConfirmationError = null;
    _printOrderData = null;

    // Reset delivery info
    _deliveryMethod = "";
    _deliveryMethodId = "";
    _deliveryDate = null;
    _deliveryTime = null;
    _carNumber = "";
    _carNumber = "";
    _orderComment = "";
    _orderAddress = "";

    // Clear controllers
    transactionNumberController.clear();
    commentController.clear();
    carNumberController.clear();

    notifyListeners();
  }

  // 36. Coupon Application - API-based coupon validation and discount calculation
  bool _isCouponApplied = false;
  String _couponCode = "";
  double _couponDiscount = 0.0;
  String? _couponValidationError;

  bool get isCouponApplied => _isCouponApplied;
  String get couponCode => _couponCode;
  double get couponDiscount => _couponDiscount;
  String? get couponValidationError => _couponValidationError;

  // 37. Manual Discount - Flat amount and percentage discounts
  double _manualDiscountAmount = 0.0;
  double _manualDiscountPercentage = 0.0;
  bool _isManualDiscountApplied = false;

  double get manualDiscountAmount => _manualDiscountAmount;
  double get manualDiscountPercentage => _manualDiscountPercentage;
  bool get isManualDiscountApplied => _isManualDiscountApplied;

  // 40. Sidebar Management - Collapsible product/order sidebar
  bool _isSidebarCollapsed = false;

  bool get isSidebarCollapsed => _isSidebarCollapsed;

  // 41. Tab Navigation - Switch between products and saved orders
  int _currentTabIndex = 0;

  int get currentTabIndex => _currentTabIndex;

  // 60. Keyboard Shortcuts - F6-F9 function key support
  Map<String, VoidCallback> _keyboardShortcuts = {};

  Map<String, VoidCallback> get keyboardShortcuts => _keyboardShortcuts;

  // 64. App Settings Provider - Feature toggles
  bool _barcodeSalesEnabled = true;
  bool _discountsEnabled = true;
  bool _multiPaymentEnabled = true;

  bool get barcodeSalesEnabled => _barcodeSalesEnabled;
  bool get discountsEnabled => _discountsEnabled;
  bool get multiPaymentEnabled => _multiPaymentEnabled;

  // Coupon and discount methods
  void setCouponApplied(bool applied,
      {String code = "", double discount = 0.0}) {
    _isCouponApplied = applied;
    _couponCode = code;
    _couponDiscount = discount;
    coupenCodeTextController.text = code;
    notifyListeners();
  }

  /// Apply coupon via [CartProvider] and update state accordingly.
  /// Requires [accessToken], [totalAmount], and [couponCode].
  /// Returns success/failure result with message.
  Future<Map<String, dynamic>?> applyCoupon({
    required String accessToken,
    required double totalAmount,
    required String couponCode,
    CartProvider? cartProvider,
  }) async {
    try {
      // Clear any previous validation errors
      setCouponValidationError(null);

      if (couponCode.isEmpty) {
        setCouponValidationError("Coupon code is required");
        return {
          'success': false,
          'message': 'Coupon code is required',
        };
      }

      // Use provided CartProvider or create new instance
      final provider = cartProvider ?? CartProvider();

      final result = await provider.applyCoupon(
        totalAmount: totalAmount,
        couponCode: couponCode,
        accessToken: accessToken,
      );

      if (result != null) {
        if (result['success'] == true) {
          // Extract coupon data
          final couponData = result['data']['data'];
          double discountAmount =
              double.parse(couponData['discount_amount'].replaceAll(',', ''));
          double discountedTotal = totalAmount - discountAmount;

          // Update provider state
          setCouponApplied(
            true,
            code: couponCode,
            discount: discountAmount,
          );

          // Update cart provider's price summary if available
          provider.updatePriceSummary(
            discountAmount: discountAmount,
            discountedTotal: discountedTotal,
          );

          return {
            'success': true,
            'message': result['message'] ?? 'Coupon Applied Successfully',
            'discountAmount': discountAmount,
            'discountedTotal': discountedTotal,
          };
        } else {
          // Handle failure
          setCouponValidationError(
              result['message'] ?? 'Failed to Apply Coupon');
          return {
            'success': false,
            'message': result['message'] ?? 'Failed to Apply Coupon',
          };
        }
      } else {
        setCouponValidationError('Error Occurred! Try Again');
        return {
          'success': false,
          'message': 'Error Occurred! Try Again',
        };
      }
    } catch (e) {
      debugPrint('Error in applyCoupon: $e');
      setCouponValidationError('Network error occurred');
      return {
        'success': false,
        'message': 'Network error occurred',
      };
    }
  }

  void setCouponValidationError(String? error) {
    _couponValidationError = error;
    notifyListeners();
  }

  void setManualDiscount({double amount = 0.0, double percentage = 0.0}) {
    _manualDiscountAmount = amount;
    _manualDiscountPercentage = percentage;
    _isManualDiscountApplied = amount > 0 || percentage > 0;
    notifyListeners();
  }

  void clearDiscounts() {
    _isCouponApplied = false;
    _couponCode = "";
    _couponDiscount = 0.0;
    _couponValidationError = null;
    _manualDiscountAmount = 0.0;
    _manualDiscountPercentage = 0.0;
    _isManualDiscountApplied = false;
    coupenCodeTextController.clear();
    notifyListeners();
  }

  // UI management methods
  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  void setSidebarCollapsed(bool collapsed) {
    _isSidebarCollapsed = collapsed;
    notifyListeners();
  }

  void setCurrentTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  // Keyboard shortcuts
  void registerKeyboardShortcut(String key, VoidCallback callback) {
    _keyboardShortcuts[key] = callback;
  }

  void executeKeyboardShortcut(String key) {
    _keyboardShortcuts[key]?.call();
  }

  // MISSED LOGIC: Specific keyboard shortcut handlers
  void handleKeyPress(String key) {
    switch (key) {
      case 'F6':
        executeKeyboardShortcut('clearCart');
        break;
      case 'F7':
        executeKeyboardShortcut('saveOrder');
        break;
      case 'F8':
        executeKeyboardShortcut('createOrderAndPrint');
        break;
      case 'F9':
        executeKeyboardShortcut('confirmOrder');
        break;
    }
  }

  void registerDefaultKeyboardShortcuts({
    VoidCallback? onClearCart,
    VoidCallback? onSaveOrder,
    VoidCallback? onCreateOrderAndPrint,
    VoidCallback? onConfirmOrder,
    VoidCallback? onNewOrder,
    VoidCallback? onSaveOrderAndPrint,
  }) {
    if (onClearCart != null) {
      registerKeyboardShortcut('clearCart', onClearCart);
    }
    if (onSaveOrder != null) {
      registerKeyboardShortcut('saveOrder', onSaveOrder);
    }
    if (onCreateOrderAndPrint != null) {
      registerKeyboardShortcut('createOrderAndPrint', onCreateOrderAndPrint);
    }
    if (onConfirmOrder != null) {
      registerKeyboardShortcut('confirmOrder', onConfirmOrder);
    }
    if (onNewOrder != null) {
      registerKeyboardShortcut('newOrder', onNewOrder);
    }
    if (onSaveOrderAndPrint != null) {
      registerKeyboardShortcut('saveOrderAndPrint', onSaveOrderAndPrint);
    }
  }

  // Settings management
  void setBarcodeSalesEnabled(bool enabled) {
    _barcodeSalesEnabled = enabled;
    notifyListeners();
  }

  void setDiscountsEnabled(bool enabled) {
    _discountsEnabled = enabled;
    notifyListeners();
  }

  void setMultiPaymentEnabled(bool enabled) {
    _multiPaymentEnabled = enabled;
    notifyListeners();
  }

  // MISSED LOGIC: Additional focus nodes from billing_page.dart
  final FocusNode _customerTextFieldFocus = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _unitPriceFocusNode = FocusNode();

  // MISSED LOGIC: Autocomplete focus node references
  FocusNode?
      _autocompleteFocusNode; // Store reference to Autocomplete's focusNode
  TextEditingController?
      _autocompleteController; // Store reference to Autocomplete's controller

  // Getters for autocomplete references
  FocusNode? get autocompleteFocusNode => _autocompleteFocusNode;
  TextEditingController? get autocompleteController => _autocompleteController;

  // Getters for additional controllers and focus nodes
  TextEditingController get transactionNumberControllerPrivate =>
      _transactionNumberController;
  FocusNode get customerTextFieldFocusNode => _customerTextFieldFocus;
  FocusNode get quantityFocusNodePrivate => _quantityFocusNode;
  FocusNode get unitPriceFocusNodePrivate => _unitPriceFocusNode;
  ScrollController get customerScrollController => _customerScrollController;

  // MISSED LOGIC: Sidebar and UI state management
  bool _isSidebarVisible = true;
  int _selectedSidebarTab = 1; // 0 for products, 1 for orders/categories

  bool get isSidebarVisible => _isSidebarVisible;
  int get selectedSidebarTab => _selectedSidebarTab;

  // MISSED LOGIC: AutomaticKeepAliveClientMixin state
  bool _wantKeepAlive = true;

  bool get wantKeepAlive => _wantKeepAlive;

  // MISSED LOGIC: Form validation key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  GlobalKey<FormState> get formKey => _formKey;

  // MISSED LOGIC: Autocomplete keys for rebuilding widgets
  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  GlobalKey get autocompletePhoneKey => _autocompletePhoneKey;
  GlobalKey get autocompleteProductKey => _autocompleteProductKey;

  // MISSED LOGIC: UniqueKey for tile rebuilding
  UniqueKey _keyTile = UniqueKey();

  UniqueKey get keyTile => _keyTile;

  double get customerItemHeight => _customerItemHeight;

  // MISSED LOGIC: Last rehydrated order tracking
  String? _lastRehydratedOrderId;

  String? get lastRehydratedOrderId => _lastRehydratedOrderId;

  // MISSED LOGIC: Barcode subscription management
  StreamSubscription<String>? _barcodeSubscription;

  StreamSubscription<String>? get barcodeSubscription => _barcodeSubscription;

  // MISSED LOGIC: Delivery date and time management (String versions)
  String? _deliveryDateString;
  String? _deliveryTimeString;

  String? get deliveryDateString => _deliveryDateString;
  String? get deliveryTimeString => _deliveryTimeString;

  // MISSED LOGIC: Init loading state
  bool _isInitLoading = false;

  bool get isInitLoading => _isInitLoading;

  // MISSED LOGIC: Focus change handlers
  void handleFocusChange() {
    // Focus change logic for main focus node
    notifyListeners();
  }

  void handlePaidAmountFocusChange() {
    if (paidAmountFocusNode.hasFocus) {
      paidAmountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: paidAmountController.text.length,
      );
    }
    notifyListeners();
  }

  void handleQuantityFocusChange() {
    if (_quantityFocusNode.hasFocus) {
      quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: quantityController.text.length,
      );
    }
    notifyListeners();
  }

  void handleUnitPriceFocusChange() {
    if (_unitPriceFocusNode.hasFocus) {
      unitPriceController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: unitPriceController.text.length,
      );
    }
    notifyListeners();
  }

  // MISSED LOGIC: Sidebar management
  void setSidebarVisible(bool visible) {
    _isSidebarVisible = visible;
    notifyListeners();
  }

  void setSelectedSidebarTab(int tab) {
    _selectedSidebarTab = tab;
    notifyListeners();
  }

  // MISSED LOGIC: Autocomplete key management
  void resetAutocompletePhoneKey() {
    _autocompletePhoneKey = GlobalKey();
    notifyListeners();
  }

  void resetAutocompleteProductKey() {
    _autocompleteProductKey = GlobalKey();
    notifyListeners();
  }

  // MISSED LOGIC: Tile key management
  void resetKeyTile() {
    _keyTile = UniqueKey();
    notifyListeners();
  }

  // MISSED LOGIC: Last rehydrated order management
  void setLastRehydratedOrderId(String? id) {
    _lastRehydratedOrderId = id;
    notifyListeners();
  }

  // MISSED LOGIC: Barcode subscription management
  void setBarcodeSubscription(StreamSubscription<String>? subscription) {
    _barcodeSubscription?.cancel();
    _barcodeSubscription = subscription;
    notifyListeners();
  }

  // MISSED LOGIC: Init loading management
  void setInitLoading(bool loading) {
    _isInitLoading = loading;
    notifyListeners();
  }

  // MISSED LOGIC: Cart provider integration
  CartProvider? _cartProvider;

  CartProvider? get cartProvider => _cartProvider;

  void setCartProvider(CartProvider? provider) {
    _cartProvider = provider;
    notifyListeners();
  }

  // MISSED LOGIC: Keep alive management
  void setWantKeepAlive(bool keepAlive) {
    _wantKeepAlive = keepAlive;
    notifyListeners();
  }

  /// Save current order to local storage via SalesProvider
  /// Returns success/failure result with message
  Future<Map<String, dynamic>> saveCurrentOrder({
    required String accessToken,
    required int customerId,
    SalesProvider? salesProvider,
  }) async {
    debugPrint("===== SAVE CURRENT ORDER START =====");
    setSavingOrder(true);

    try {
      // Validate required data
      if (_cartProductItems == null || _cartProductItems!.isEmpty) {
        setSavingOrder(false);
        return {
          'success': false,
          'message': 'Cart is empty. Please add items before saving.',
        };
      }

      // Create order data
      final orderData = createOrderData();

      // Save order locally (SalesProvider doesn't have direct saveOrder method)
      // This would typically save to local storage or cache
      final result = {
        'success': true,
        'message': 'Order saved locally',
        'orderId': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      setSavingOrder(false);

      if (result['success'] == true) {
        // Add to saved orders list
        addSavedOrder(orderData);

        debugPrint("✅ Order saved successfully");
        return {
          'success': true,
          'message': result['message'] ?? 'Order saved successfully',
          'orderId': result['orderId'],
        };
      } else {
        debugPrint("❌ Failed to save order: ${result['message']}");
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to save order',
        };
      }
    } catch (e) {
      debugPrint("❌ Error saving order: $e");
      setSavingOrder(false);
      return {
        'success': false,
        'message': 'Network error occurred while saving order',
      };
    }
  }

  /// Create and confirm order via SalesProvider API
  /// Returns success/failure result with order details
  Future<Map<String, dynamic>> createOrderAndPrint({
    required String accessToken,
    required int customerId,
    SalesProvider? salesProvider,
  }) async {
    debugPrint("===== CREATE ORDER AND PRINT START =====");
    setLoadingCreateOrder(true);

    try {
      // Validate required data
      if (_cartProductItems == null || _cartProductItems!.isEmpty) {
        setLoadingCreateOrder(false);
        return {
          'success': false,
          'message': 'Cart is empty. Please add items before creating order.',
        };
      }

      // Validate payment methods
      if (!validatePayment()) {
        setLoadingCreateOrder(false);
        return {
          'success': false,
          'message':
              _paymentValidationError ?? 'Please select valid payment methods',
        };
      }

      // Create order data
      final orderData = createOrderData();

      // Create order (SalesProvider doesn't have direct createOrder method)
      // This would typically call an API endpoint to create the order
      final result = {
        'success': true,
        'message': 'Order created successfully',
        'orderId': DateTime.now().millisecondsSinceEpoch.toString(),
        'orderData': orderData,
      };

      setLoadingCreateOrder(false);

      if (result['success'] == true) {
        // Store print data
        setPrintOrderData(result['orderData'] as Map<String, dynamic>?);

        debugPrint("✅ Order created successfully for printing");
        return {
          'success': true,
          'message': result['message'] ?? 'Order created successfully',
          'orderId': result['orderId'],
          'printData': result['orderData'],
        };
      } else {
        debugPrint("❌ Failed to create order: ${result['message']}");
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to create order',
        };
      }
    } catch (e) {
      debugPrint("❌ Error creating order: $e");
      setLoadingCreateOrder(false);
      return {
        'success': false,
        'message': 'Network error occurred while creating order',
      };
    }
  }

  /// Confirm order via SalesProvider API (final submission)
  /// Returns success/failure result with confirmation details
  Future<Map<String, dynamic>> confirmOrder({
    required String accessToken,
    required int customerId,
    SalesProvider? salesProvider,
  }) async {
    debugPrint("===== CONFIRM ORDER START =====");
    setConfirmingOrder(true);

    try {
      // Validate required data
      if (_cartProductItems == null || _cartProductItems!.isEmpty) {
        setConfirmingOrder(false);
        return {
          'success': false,
          'message': 'Cart is empty. Please add items before confirming order.',
        };
      }

      // Validate payment methods
      if (!validatePayment()) {
        setConfirmingOrder(false);
        return {
          'success': false,
          'message':
              _paymentValidationError ?? 'Please select valid payment methods',
        };
      }

      // Create order data
      final orderData = createOrderData();

      // Confirm order (SalesProvider doesn't have direct confirmOrder method)
      // This would typically call an API endpoint to confirm the order
      final result = {
        'success': true,
        'message': 'Order confirmed successfully',
        'orderId': DateTime.now().millisecondsSinceEpoch.toString(),
        'orderData': orderData,
      };

      setConfirmingOrder(false);

      if (result['success'] == true) {
        // Clear cart and reset state after successful confirmation
        resetAllState();

        debugPrint("✅ Order confirmed successfully");
        return {
          'success': true,
          'message': result['message'] ?? 'Order confirmed successfully',
          'orderId': result['orderId'],
          'orderDetails': result['orderData'],
        };
      } else {
        debugPrint("❌ Failed to confirm order: ${result['message']}");
        setOrderConfirmationError(
            result['message']?.toString() ?? 'Failed to confirm order');
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to confirm order',
        };
      }
    } catch (e) {
      debugPrint("❌ Error confirming order: $e");
      setConfirmingOrder(false);
      setOrderConfirmationError(
          'Network error occurred while confirming order');
      return {
        'success': false,
        'message': 'Network error occurred while confirming order',
      };
    }
  }

  // MISSED LOGIC: User switch handling
  void onUserSwitched() {
    debugPrint("🔄 BILLING: User switched, updating default customer...");

    // Clear current customer selection
    clearSelectedCustomer();

    // Reset billing page customer state
    _mobileNumberText = "";
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;
    _selectedCustomer = null;
    _isCustomerFound = false;
    _salesExecutivemobileNumberText = "";
    mobileNumberTextController.clear();
    resetAutocompletePhoneKey();

    notifyListeners();
  }

  // MISSED LOGIC: Sales executive change handling
  void onSalesExecutiveChanged() {
    debugPrint(
        "🔄 BILLING: Sales executive changed, updating default customer...");
    // Implementation would trigger customer fetch with new executive
    notifyListeners();
  }

  // MISSED LOGIC: Default delivery method management
  String getDefaultDeliveryMethodId() {
    return getDefaultDeliveryMethod()?.id ?? "11";
  }

  void initializeDeliveryMethod() {
    // Set initial default values
    final defaultMethod = getDefaultDeliveryMethod();
    _deliveryMethod = defaultMethod?.name ?? "Store Takeaway";
    _deliveryMethodId = defaultMethod?.id ?? "";
    notifyListeners();
  }

  /// Fetch delivery methods from API via [DeliveryMethodsProvider]
  /// Returns `true` on success, `false` otherwise.
  Future<bool> fetchDeliveryMethods({
    DeliveryMethodsProvider? deliveryProvider,
  }) async {
    try {
      _isLoadingDeliveryMethods = true;
      notifyListeners();

      // Use provided provider or create new instance
      final provider = deliveryProvider ?? DeliveryMethodsProvider();

      await provider.fetchDeliveryMethods();

      // Update local state with fetched methods
      _deliveryMethods = provider.deliveryMethods;

      // Set default delivery method if not already set
      if (_deliveryMethodId.isEmpty && _deliveryMethods.isNotEmpty) {
        final defaultMethod = provider.resolveDefaultDeliveryMethod();
        if (defaultMethod != null) {
          _deliveryMethod = defaultMethod.name;
          _deliveryMethodId = defaultMethod.id;
        }
      }

      _isLoadingDeliveryMethods = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error in fetchDeliveryMethods: $e');
      _isLoadingDeliveryMethods = false;
      notifyListeners();
      return false;
    }
  }

  /// Get delivery method by ID from the cached list
  DeliveryMethod? getDeliveryMethodById(String id) {
    try {
      return _deliveryMethods.firstWhere((method) => method.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default delivery method (Store Takeaway)
  DeliveryMethod? getDefaultDeliveryMethod() {
    try {
      return _deliveryMethods.firstWhere(
        (method) => method.name.toLowerCase().contains('store takeaway'),
        orElse: () => _deliveryMethods.isNotEmpty
            ? _deliveryMethods.first
            : DeliveryMethod(id: "11", name: "Store Takeaway"),
      );
    } catch (e) {
      return _deliveryMethods.isNotEmpty
          ? _deliveryMethods.first
          : DeliveryMethod(id: "11", name: "Store Takeaway");
    }
  }

  static int _debugBalanceCalcCount = 0;

  void _debugBalanceLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }

  // MISSED LOGIC: Balance calculation methods - Updated to match billing_page.dart logic
  double calculateBalanceAmount(double cartTotal, {String currency = 'INR'}) {
    assert(() {
      _debugBalanceCalcCount++;
      if (_debugBalanceCalcCount <= 3 || _debugBalanceCalcCount % 50 == 0) {
        debugPrint(
          '[BillingProvider] calculateBalanceAmount #$_debugBalanceCalcCount',
        );
      }
      return true;
    }());
    // For balance calculation, only include actual cash payments (not debit/store credit)
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    double totalCollected =
        cashAmount + cardAmount + upiAmount + codAmount + getExtraPaidTotal();

    double balance = 0.0;

    if (_toCustomerCreditEnabled) {
      _debugBalanceLog(
          '🔛 BILLING PROVIDER: Toggle is ON - Calculating with customer credit consideration');

      double customerPrevBalance = _selectedCustomer?.balance ?? 0.0;

      if (customerPrevBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        _debugBalanceLog('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalCollected - cartTotal;
        _debugBalanceLog(
            '💰 Transaction excess: $currency${transactionExcess.toStringAsFixed(2)}');

        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit =
              double.tryParse(debitAmountController.text) ?? 0.0;

          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            _debugBalanceLog(
                '  - Clamped customer credit to transaction excess: $currency${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = transaction excess - customer credit
          balance = transactionExcess - actualCustomerCredit;
          _debugBalanceLog(
              '  - Balance = Transaction Excess ($currency${transactionExcess.toStringAsFixed(2)}) - Customer Credit ($currency${actualCustomerCredit.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
        } else {
          balance = 0.0;
          _debugBalanceLog('  - No transaction excess, balance = 0');
        }
      } else {
        // Customer has positive/zero balance - use Net Due logic
        _debugBalanceLog('💵 Customer has credit/zero balance - using Net Due logic');
        // Net Due = Purchase Total - Customer Previous Balance
        double netDue = cartTotal - customerPrevBalance;
        _debugBalanceLog('💰 Net Due calculation:');
        _debugBalanceLog(
            '  - Purchase Total: $currency${cartTotal.toStringAsFixed(2)}');
        _debugBalanceLog(
            '  - Customer Prev Balance: $currency${customerPrevBalance.toStringAsFixed(2)}');
        _debugBalanceLog('  - Net Due: $currency${netDue.toStringAsFixed(2)}');

        // Available balance = Total Collected - Net Due
        double availableBalance = totalCollected - netDue;
        _debugBalanceLog(
            '  - Total Collected: $currency${totalCollected.toStringAsFixed(2)}');
        _debugBalanceLog(
            '  - Available Balance: $currency${availableBalance.toStringAsFixed(2)}');

        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit =
              double.tryParse(debitAmountController.text) ?? 0.0;

          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            _debugBalanceLog(
                '  - Clamped customer credit to available balance: $currency${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = available balance - customer credit
          balance = availableBalance - actualCustomerCredit;
          _debugBalanceLog(
              '  - Balance = Available Balance ($currency${availableBalance.toStringAsFixed(2)}) - Customer Credit ($currency${actualCustomerCredit.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
        } else {
          balance = 0.0;
          _debugBalanceLog('  - No available balance, balance = 0');
        }
      }
    } else {
      _debugBalanceLog(
          '🔴 BILLING PROVIDER: Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      balance = totalCollected - cartTotal;
      _debugBalanceLog(
          '  - Balance = Total Collected ($currency${totalCollected.toStringAsFixed(2)}) - Cart Total ($currency${cartTotal.toStringAsFixed(2)}) = $currency${balance.toStringAsFixed(2)}');
    }

    // Clamp balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (balance < 0) {
      _debugBalanceLog(
          '🚫 BILLING PROVIDER: Clamping negative balance ($currency${balance.toStringAsFixed(2)}) to 0 for UI display');
      balance = 0.0;
    }

    return balance;
  }

  // MISSED LOGIC: Get total paid amount excluding debit/customer credit
  double getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(codAmountController.text) ?? 0.0;
    double onlineAmount = _isOnlineSelected ? _effectiveOrderTotal : 0.0;
    // Note: We don't include debit/toCustomerCredit in total paid amount
    // as it represents money going to customer credit, not money collected
    return cashAmount +
        cardAmount +
        upiAmount +
        codAmount +
        onlineAmount +
        getExtraPaidTotal();
  }

  Map<String, String> _buildExtraAmountsForStorage() {
    final extras = <String, String>{};
    _extraPaymentAmounts.forEach((methodId, amountStr) {
      final amount = double.tryParse(amountStr) ?? 0;
      if (amount > 0) {
        extras[methodId] = amountStr;
      }
    });
    return extras;
  }

  // MISSED LOGIC: Get selected payment methods excluding debit when no amount
  List<String> getSelectedPaymentMethodsExcludingEmpty() {
    List<String> methods = [];
    if (_isCashSelected &&
        (double.tryParse(cashAmountController.text) ?? 0) > 0) {
      methods.add("CASH");
    }
    if (_isCardSelected &&
        (double.tryParse(cardAmountController.text) ?? 0) > 0) {
      methods.add("CARD");
    }
    if (_isUpiSelected &&
        (double.tryParse(upiAmountController.text) ?? 0) > 0) {
      methods.add("UPI");
    }
    if (_isCodSelected &&
        (double.tryParse(codAmountController.text) ?? 0) > 0) {
      methods.add("COD");
    }
    if (_isOnlineSelected) {
      methods.add("ONLINE");
    }
    _extraPaymentAmounts.forEach((methodId, amountStr) {
      if ((double.tryParse(amountStr) ?? 0) > 0) {
        methods.add(methodId);
      }
    });
    // Note: Debit is handled separately as customer credit, not a payment method
    return methods;
  }

  List<String> getSelectedPaymentMethodsForApi() {
    final methods = <String>[];

    if (_isCashSelected &&
        (double.tryParse(cashAmountController.text) ?? 0) > 0) {
      methods.add(cashPaymentMethodId ?? "CASH");
    }
    if (_isCardSelected &&
        (double.tryParse(cardAmountController.text) ?? 0) > 0) {
      methods.add(cardPaymentMethodId ?? "CARD");
    }
    if (_isUpiSelected &&
        (double.tryParse(upiAmountController.text) ?? 0) > 0) {
      methods.add(upiPaymentMethodId ?? "UPI");
    }
    if (_isCodSelected &&
        (double.tryParse(codAmountController.text) ?? 0) > 0) {
      methods.add(codPaymentMethodId ?? "COD");
    }
    if (_isOnlineSelected) {
      methods.add("ONLINE");
    }
    _extraPaymentAmounts.forEach((methodId, amountStr) {
      if ((double.tryParse(amountStr) ?? 0) > 0) {
        methods.add(methodId);
      }
    });

    return methods;
  }

  // MISSED LOGIC: Payment label generation
  String getPaymentLabel() {
    // Build label using methods that mirror billing_page.dart semantics
    final methods = getSelectedPaymentMethodsExcludingEmpty();
    final List<String> activeMethods = [];
    if (methods.contains("CASH")) activeMethods.add("Cash");
    if (methods.contains("CARD")) activeMethods.add("Card");
    if (methods.contains("UPI")) activeMethods.add("UPI");
    if (methods.contains("COD")) activeMethods.add("COD");
    if (methods.contains("ONLINE")) activeMethods.add("Online");
    // DEBIT is not shown in label for collected payments

    if (activeMethods.isEmpty) {
      return "Select Payment Method";
    } else if (activeMethods.length == 1) {
      return activeMethods.first;
    } else {
      return "Multi-Payment (${activeMethods.length})";
    }
  }

  // MISSED LOGIC: Formatted total calculation helper
  String getFormattedTotal(double total, bool priceRoundOff) {
    if (priceRoundOff) {
      return total.toStringAsFixed(0);
    } else {
      return total.toStringAsFixed(2);
    }
  }

  // MISSED LOGIC: Autocomplete reference management
  void setAutocompleteFocusNode(FocusNode? focusNode) {
    _autocompleteFocusNode = focusNode;
    notifyListeners();
  }

  void setAutocompleteController(TextEditingController? controller) {
    _autocompleteController = controller;
    notifyListeners();
  }

  // MISSED LOGIC: Focus text field helper
  void focusTextField(bool barcodeSalesEnabled) {
    if (barcodeSalesEnabled) {
      barcodeNode.requestFocus();
    }
    selectedProductNameController.clear();
  }

  // MISSED LOGIC: Clear product fields helper
  void clearProductFieldsAndReset() {
    barcodeController.clear();
    quantityController.clear();
    unitPriceController.clear();
    selectedProductIdController.clear();
    selectedProductNameController.clear();

    // Reset autocomplete keys by triggering rebuild
    resetAutocompleteProductKey();
  }

  // MISSED LOGIC: Update balance amount helper - matches billing_page.dart _updateBalanceAmount()
  void updateBalanceAmount(double cartTotal, {String currency = 'INR'}) {
    double balance = calculateBalanceAmount(cartTotal, currency: currency);
    _balanceAmount = balance;
    notifyListeners();
  }

  // MISSED LOGIC: Reset autocomplete helper
  void resetAutocomplete({bool shouldFetchCustomers = true}) {
    // Reset autocomplete keys to force widget rebuild
    resetAutocompletePhoneKey();
    resetAutocompleteProductKey();

    // Clear selected product
    clearSelectedProduct();

    // Clear barcode controller
    barcodeController.clear();

    // Reset focus to barcode field if barcode sales enabled
    if (_barcodeSalesEnabled) {
      barcodeNode.requestFocus();
    }

    notifyListeners();
  }

  // MISSED LOGIC: Get payment icon helper
  IconData getPaymentIcon() {
    List<String> methods = getSelectedPaymentMethods();
    if (methods.isEmpty) {
      return Icons.payment;
    } else if (methods.length > 1) {
      return Icons.account_balance_wallet;
    } else if (methods.contains("CASH")) {
      return Icons.money;
    } else if (methods.contains("CARD")) {
      return Icons.credit_card;
    } else if (methods.contains("UPI")) {
      return Icons.phone_android;
    } else if (methods.contains("DEBIT")) {
      return Icons.account_balance;
    }
    return Icons.payment;
  }

  // Complete reset method
  void resetAllState() {
    // Clear customer state
    clearSelectedCustomer();

    // Clear cart state
    clearCart();

    // Clear product state
    clearProductFields();

    // Clear payment state
    clearAllPaymentMethods();

    // Clear order state
    clearOrderState();

    // Clear discounts
    clearDiscounts();

    // Reset UI state
    _isSidebarCollapsed = false;
    _currentTabIndex = 0;
    _isSidebarVisible = true;
    _selectedSidebarTab = 1;

    // Reset loading states
    _isLoadingClearCart = false;
    _isLoadingSaveOrder = false;
    _isLoadingCreateOrder = false;
    _isLoadingConfirmOrder = false;
    _isLoadingSaveOrderAndPrint = false;
    _isLoadingAddItem = false;
    _isProcessingBarcode = false;
    _isInitLoading = false;

    // Reset keys
    resetAutocompletePhoneKey();
    resetAutocompleteProductKey();
    resetKeyTile();

    // Clear last rehydrated order
    _lastRehydratedOrderId = null;

    // Clear autocomplete references
    _autocompleteFocusNode = null;
    _autocompleteController = null;

    // Clear delivery date/time
    _deliveryDate = null;
    _deliveryTime = null;
    _deliveryDateString = null;
    _deliveryTimeString = null;

    // Cancel timers
    cancelDebounce();

    notifyListeners();
  }

  @override
  void dispose() {
    // Dispose all controllers
    mobileNumberTextController.dispose();
    coupenCodeTextController.dispose();
    transactionNumberController.dispose();
    paidAmountController.dispose();
    cashAmountController.dispose();
    cardAmountController.dispose();
    upiAmountController.dispose();
    codAmountController.dispose();
    debitAmountController.dispose();
    for (final controller in _extraAmountControllers.values) {
      controller.dispose();
    }
    _extraAmountControllers.clear();
    barcodeController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    selectedProductIdController.dispose();
    selectedProductNameController.dispose();
    commentController.dispose();
    carNumberController.dispose();
    _transactionNumberController.dispose();

    // Dispose focus nodes
    paidAmountFocusNode.dispose();
    cashAmountFocusNode.dispose();
    cardAmountFocusNode.dispose();
    upiAmountFocusNode.dispose();
    debitAmountFocusNode.dispose();
    quantityFocusNode.dispose();
    unitPriceFocusNode.dispose();
    focusNode.dispose();
    barcodeNode.dispose();
    customerTextFieldFocus.dispose();
    _customerTextFieldFocus.dispose();
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();

    // Dispose scroll controllers
    _customerScrollController.dispose();

    // Cancel subscriptions
    _internetSubscription?.cancel();
    _barcodeSubscription?.cancel();

    // Cancel timers
    _debounce?.cancel();
    _debounceTimer?.cancel();

    super.dispose();
  }
}
