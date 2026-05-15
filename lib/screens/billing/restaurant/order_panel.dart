import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/cart_item_status.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_confirmation_dialog.dart';
import '../../../components/build_dialog_box.dart';
import '../../../components/build_round_button.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../screens/customers/add_customer_modal.dart';
import '../../../screens/billing/widgets/payment_method_modal.dart';
import '../../../providers/keyboard_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/billing/widgets/checkout_modal.dart';
import 'package:pos_machine/screens/print/print_kot.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/billing/restaurant_page.dart';

class OrderPanel extends StatefulWidget {
  final String? tableId;
  final bool isCompact;
  final Size screenSize;
  final VoidCallback onSendToKitchen; // New callback for send to kitchen
  final VoidCallback onNewOrder; // New callback for new order
  final VoidCallback
      onPrintOrder; // New callback for print order (send + print)
  final Function(dynamic)
      onOrderSelected; // New callback to update selected order
  final dynamic
      selectedOrderFromParent; // Add this to track parent's selected order
  final int? refreshCounter; // Add refresh counter
  final bool isLoadingSendToKitchen; // Loading state for Send to Kitchen button
  final bool isLoadingPrint; // Loading state for Print button
  final String?
      preselectedDeliveryMethodId; // Delivery method chosen from tables panel
  final String?
      preselectedDeliveryMethodName; // Name of preselected delivery method
  final bool allowCounterBilling;
  final bool isCounterBillingMode;

  const OrderPanel({
    super.key, // Add key parameter
    required this.tableId,
    this.isCompact = false,
    required this.screenSize,
    required this.onSendToKitchen, // Make it required
    required this.onNewOrder, // Make it required
    required this.onPrintOrder, // Make it required
    required this.onOrderSelected, // Make it required
    this.selectedOrderFromParent, // Add this parameter
    this.refreshCounter, // Add refresh counter parameter
    this.isLoadingSendToKitchen = false, // Add loading state parameter
    this.isLoadingPrint = false, // Add loading state parameter for print
    this.preselectedDeliveryMethodId, // Preselected delivery method from tables panel
    this.preselectedDeliveryMethodName, // Name of preselected delivery method
    this.allowCounterBilling = false,
    this.isCounterBillingMode = false,
  });

  @override
  State<OrderPanel> createState() => OrderPanelState();
}

class OrderPanelState extends State<OrderPanel> {
  dynamic _selectedOrder;
  List<dynamic> _savedOrders = [];
  List<SavedOrder> _localDrafts = [];
  bool _isLoadingOrders = false;
  bool _isLoadingOrderDetails = false;
  String? _error;
  final Set<String> _loadingCartItems =
      {}; // Track which cart items are being updated
  bool _isLoadingConfirm = false; // Loading state for Confirm button
  bool _isLoadingPrintKot =
      false; // Loading state for edit-order Print KOT button
  bool _isProcessingCheckout =
      false; // Loading state for footer checkout button
  String? _loadedLocalDraftId; // track currently loaded local draft
  bool _blockReselectAfterPlace = false; // Prevent reselect after order placed

  // Scroll + highlight for newly added items in edit-order view
  final ScrollController _editOrderScrollController = ScrollController();
  int?
      _highlightedCartItemProductId; // product ID to briefly highlight after add

  // Payment Method Variables
  bool _isCashSelected = false;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  bool _isCodSelected = false;
  bool _isDebitSelected = false;
  String _cashAmount = "";
  String _cardAmount = "";
  String _upiAmount = "";
  String _codAmount = "";
  String _debitAmount = "";
  String _transactionNumber = "";
  double _balanceAmount = 0.0;
  bool _toCustomerCreditEnabled = false;
  double _toCustomerCreditAmount = 0.0; // Store the actual credit amount
  String _orderComment = "";
  bool _hasOpenedPaymentModalOnce = false;
  String _deliveryMethod = "Store Takeaway";
  String _deliveryMethodId = "";
  String _deliveryAddress = "";
  String? _deliveryDate;
  String? _deliveryTime;
  double? _selectedDeliveryCharge;

  // Expose current comment to parent (RestaurantPage) for new order flow
  String get orderComment => _orderComment;
  String? get selectedCustomerNameForDraft => _selectedCustomer?.name;
  int? get selectedCustomerIdForDraft =>
      _selectedCustomer?.id ?? _selectedCustomerID;
  String? get selectedCustomerPhoneForDraft =>
      _selectedCustomer?.phone ?? _selectedCustomerPhone;
  String? get selectedCustomerTypeForDraft => _selectedCustomer?.customerType;
  String get deliveryMethodForDraft => _deliveryMethod;
  String get deliveryMethodIdForDraft => _deliveryMethodId.isNotEmpty
      ? _deliveryMethodId
      : _getDefaultDeliveryMethodId();
  String? get deliveryDateForDraft => _deliveryDate;
  String? get deliveryTimeForDraft => _deliveryTime;
  String? get deliveryAddressForDraft =>
      _deliveryAddress.isNotEmpty ? _deliveryAddress : null;
  double get deliveryChargeForDraft => _getDeliveryChargeForOrder();
  bool get toCustomerCreditForDraft => _toCustomerCreditEnabled;
  String? get transactionNumberForDraft =>
      _transactionNumber.isNotEmpty ? _transactionNumber : null;
  String? get couponIdForDraft => _couponCode.isNotEmpty ? _couponCode : null;
  String? get balanceAmountForDraft => _balanceAmount.toString();
  String? get paymentMethodForDraft =>
      _getLocalDraftPaymentData()['paymentMethod'];
  String? get paidAmountForDraft => _getLocalDraftPaymentData()['paidAmount'];

  // Customer Selection Variables
  CustomerListModelData? _selectedCustomer;
  int? _selectedCustomerID;
  String? _selectedCustomerPhone;
  List<CustomerListModelData> _customers = [];
  bool _customersInitialized = false;
  bool _isCustomerManuallySelected = false; // Flag to track manual override

  // Discount Variables
  bool _isCouponApplied = false;
  double _flatDiscount = 0.0;
  double _percentageDiscount = 0.0;
  String _couponCode = "";

  // Cart Item Status Variables (for Mark Served functionality)
  List<CartItemStatus> _availableStatuses = [];
  bool _isMarkingServed = false;

  @override
  void initState() {
    super.initState();
    _hydrateCustomerListFromProviderCache();
    _customersInitialized = true;

    // Apply preselected delivery method from tables panel if provided
    if (widget.preselectedDeliveryMethodId != null &&
        widget.preselectedDeliveryMethodId!.isNotEmpty) {
      _deliveryMethodId = widget.preselectedDeliveryMethodId!;
      _deliveryMethod =
          widget.preselectedDeliveryMethodName ?? 'Store Takeaway';
    }

    // Load saved orders and local drafts when the widget is first created with a tableId or delivery method
    if (widget.tableId != null ||
        (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchSavedOrders();
        _refreshLocalDrafts();
      });
    }
    // Fetch cart item statuses for Mark Served functionality
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCartItemStatuses();
    });
  }

  @override
  void dispose() {
    _editOrderScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Initialize customer list from provider cache once
    if (!_customersInitialized) {
      _customersInitialized = true;
      _hydrateCustomerListFromProviderCache();
    }

    // React when tableId or delivery method changes
    if (widget.tableId != oldWidget.tableId ||
        widget.preselectedDeliveryMethodId !=
            oldWidget.preselectedDeliveryMethodId) {
      if (widget.tableId != null ||
          (widget.preselectedDeliveryMethodId != null &&
              widget.preselectedDeliveryMethodId!.isNotEmpty)) {
        _fetchSavedOrders();
        _refreshLocalDrafts();
      } else {
        setState(() {
          _savedOrders = [];
          _localDrafts = [];
          _selectedOrder = null;
          _error = null;
          // Clear state synchronously to avoid nested setState
          _clearOrderEditingStateSync();
        });
        widget.onOrderSelected(null);
      }
    }

    // Update delivery method when preselected changes from parent (tables panel)
    if (widget.preselectedDeliveryMethodId !=
            oldWidget.preselectedDeliveryMethodId &&
        _selectedOrder == null) {
      if (widget.preselectedDeliveryMethodId != null &&
          widget.preselectedDeliveryMethodId!.isNotEmpty) {
        setState(() {
          _deliveryMethodId = widget.preselectedDeliveryMethodId!;
          _deliveryMethod =
              widget.preselectedDeliveryMethodName ?? 'Store Takeaway';
        });
      } else if (widget.preselectedDeliveryMethodId == null ||
          widget.preselectedDeliveryMethodId!.isEmpty) {
        // Cleared: reset to default
        setState(() {
          _deliveryMethodId = '';
          _deliveryMethod = 'Store Takeaway';
        });
      }
    }

    // Check if refresh counter has changed (indicating a refresh is needed)
    if (widget.refreshCounter != oldWidget.refreshCounter &&
        widget.refreshCounter != null &&
        _selectedOrder != null) {
      // Refresh the selected order details
      _refreshSelectedOrderAfterCartUpdate();
    }
  }

  Future<void> _fetchSavedOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _savedOrders = [];
      _selectedOrder = null;
      _error = null;
    });
    widget.onOrderSelected(null);

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    debugPrint(
        '🔄 _fetchSavedOrders: Sending request with tableId: ${widget.tableId}, deliveryMethodId: ${widget.preselectedDeliveryMethodId}');
    try {
      debugPrint('➡️ Calling CartProvider.listSavedOrders');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );
      debugPrint('✅ listSavedOrders Response: $response');
      if (response['status'] == 'success') {
        setState(() {
          _savedOrders = response['orders'];
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load saved orders';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching saved orders: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  // Public method to refresh saved orders from external calls
  void refreshSavedOrders() {
    if (widget.tableId != null || widget.preselectedDeliveryMethodId != null) {
      debugPrint(
          '🔄 External refresh of saved orders triggered for table: ${widget.tableId}, delivery: ${widget.preselectedDeliveryMethodId}');
      _fetchSavedOrders();
      _refreshLocalDrafts();
    }
  }

  // Public method to refresh saved orders silently (no loading spinner)
  Future<void> refreshSavedOrdersSilently() async {
    if (widget.tableId != null || widget.preselectedDeliveryMethodId != null) {
      debugPrint(
          '🔄 External silent refresh of saved orders triggered for table: ${widget.tableId}, delivery: ${widget.preselectedDeliveryMethodId}');
      await _refreshSavedOrdersSilently();
      _refreshLocalDrafts();
    }
  }

  /// Scroll to the bottom of the edit-order item list and briefly highlight
  /// the cart item for [productId] that has no status (newly added item).
  void scrollToAndHighlightNewItem(int productId) {
    if (!mounted) return;
    setState(() {
      _highlightedCartItemProductId = productId;
    });
    // Scroll to end after the frame redraws with the refreshed list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editOrderScrollController.hasClients) {
        _editOrderScrollController.animateTo(
          _editOrderScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
    // Remove highlight after 2.5 s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _highlightedCartItemProductId = null;
        });
      }
    });
  }

  void _hydrateCustomerListFromProviderCache() {
    if (!mounted) return;
    final customerProvider =
        Provider.of<CustomerProvider>(context, listen: false);
    final customersFromProvider = customerProvider.allCustomers ?? [];
    setState(() {
      _customers = List<CustomerListModelData>.from(customersFromProvider);
    });

    _applyDefaultCustomer();
    debugPrint(
        '🗂️ Restaurant order panel hydrated customers from provider cache: ${_customers.length}');
  }

  void _refreshCustomersInBackgroundAfterSale() {
    if (!mounted) return;
    debugPrint(
        '🔄 Refreshing customers in background after successful confirm (restaurant order panel)');

    Future.microtask(() async {
      try {
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final customerProvider =
            Provider.of<CustomerProvider>(context, listen: false);
        await customerProvider.fetchCustomers(
          accessToken: authModel.token ?? '',
          listAll: true,
        );

        if (!mounted) return;
        _hydrateCustomerListFromProviderCache();
      } catch (e) {
        debugPrint(
            '⚠️ Background customer refresh failed after confirm (restaurant order panel): $e');
      }
    });
  }

  Map<String, String?> _getLocalDraftPaymentData() {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final paymentAmounts = <String, String>{};
    final selectedMethods = <String>[];

    void addMethod(bool isSelected, String amountText, String methodId) {
      final amount = double.tryParse(amountText) ?? 0.0;
      if (!isSelected || amount <= 0) return;
      selectedMethods.add(methodId);
      paymentAmounts[methodId] = amount.toStringAsFixed(2);
    }

    addMethod(_isCashSelected, _cashAmount,
        billingProvider.cashPaymentMethodId ?? 'CASH');
    addMethod(_isCardSelected, _cardAmount,
        billingProvider.cardPaymentMethodId ?? 'CARD');
    addMethod(_isUpiSelected, _upiAmount,
        billingProvider.upiPaymentMethodId ?? 'UPI');
    addMethod(_isCodSelected, _codAmount,
        billingProvider.codPaymentMethodId ?? 'COD');
    addMethod(_isDebitSelected, _debitAmount, 'DEBIT');

    if (selectedMethods.isEmpty) {
      return {'paymentMethod': null, 'paidAmount': null};
    }

    final totalPaid = paymentAmounts.values.fold<double>(
      0.0,
      (sum, amount) => sum + (double.tryParse(amount) ?? 0.0),
    );

    return {
      // Always persist draft payment as multi-payment JSON so sync payloads stay consistent.
      'paymentMethod': json.encode({
        'methods': selectedMethods,
        'amounts': paymentAmounts,
        'isMultiPayment': true,
      }),
      'paidAmount': totalPaid.toStringAsFixed(2),
    };
  }

  String buildTaggedDraftComment(String tableId) {
    return _orderComment.trim();
  }

  String? _resolveStoredPaymentMethodName(String? storedMethod) {
    if (storedMethod == null || storedMethod.isEmpty) return null;

    final normalized = storedMethod.trim().toUpperCase();
    if (normalized == 'CASH' ||
        normalized == 'CARD' ||
        normalized == 'UPI' ||
        normalized == 'COD' ||
        normalized == 'DEBIT') {
      return normalized;
    }

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (storedMethod == billingProvider.cashPaymentMethodId) return 'CASH';
    if (storedMethod == billingProvider.cardPaymentMethodId) return 'CARD';
    if (storedMethod == billingProvider.upiPaymentMethodId) return 'UPI';
    if (storedMethod == billingProvider.codPaymentMethodId) return 'COD';
    if (normalized == 'DEBIT') return 'DEBIT';

    return null;
  }

  CustomerListModelData? _resolveDraftCustomer(SavedOrder order) {
    if (_customers.isEmpty) return null;

    for (final customer in _customers) {
      if (order.customerId != null && customer.id == order.customerId) {
        return customer;
      }
    }

    for (final customer in _customers) {
      if ((order.customerPhone?.isNotEmpty ?? false) &&
          customer.phone == order.customerPhone) {
        return customer;
      }
    }

    return null;
  }

  void _rehydrateLocalDraftMetadata(SavedOrder order) {
    final matchedCustomer = _resolveDraftCustomer(order);
    final parsedPayment =
        PaymentHelper.parseLocalMultiPayment(context, order.paymentMethod);
    final paymentBreakdown = parsedPayment?.paymentBreakdown;
    final paidAmount = double.tryParse(order.paidAmount ?? '') ?? 0.0;
    final singleMethodName = parsedPayment == null
        ? _resolveStoredPaymentMethodName(order.paymentMethod)
        : null;

    double amountFor(String methodName) {
      if (paymentBreakdown != null) {
        return double.tryParse(
                paymentBreakdown[methodName]?.toString() ?? '') ??
            0.0;
      }
      return singleMethodName == methodName ? paidAmount : 0.0;
    }

    final cashAmount = amountFor('CASH');
    final cardAmount = amountFor('CARD');
    final upiAmount = amountFor('UPI');
    final codAmount = amountFor('COD');
    final debitAmount = amountFor('DEBIT');

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    if (matchedCustomer != null) {
      customerSelectionProvider.setSelectedCustomer(
        matchedCustomer,
        isDefault: _isDefaultCustomerPhone(matchedCustomer.phone),
      );
    } else {
      customerSelectionProvider.clearSelectedCustomer();
      if (order.customerPhone?.isNotEmpty == true) {
        customerSelectionProvider.updateCustomerPhone(order.customerPhone!);
      }
    }

    setState(() {
      _selectedCustomer = matchedCustomer;
      _selectedCustomerID = matchedCustomer?.id ?? order.customerId;
      _selectedCustomerPhone = matchedCustomer?.phone ?? order.customerPhone;
      _isCustomerManuallySelected = order.customerId != null ||
          (order.customerPhone?.isNotEmpty ?? false);

      _orderComment = _cleanDraftComment(order.comment);
      _deliveryMethod = order.deliveryMethod ?? 'Store Takeaway';
      _deliveryMethodId =
          order.deliveryMethodId ?? _getDefaultDeliveryMethodId();
      _deliveryAddress = order.address ?? '';
      _deliveryDate = order.deliveryDate;
      _deliveryTime = order.deliveryTime;
      _selectedDeliveryCharge = order.deliveryCharge;

      _flatDiscount = order.flatDiscount ?? 0.0;
      _percentageDiscount = order.percentageDiscount ?? 0.0;
      _couponCode = order.couponId ?? '';
      _isCouponApplied = _flatDiscount > 0 ||
          _percentageDiscount > 0 ||
          _couponCode.isNotEmpty;

      _transactionNumber = order.transactionId ?? '';
      _balanceAmount = double.tryParse(order.balanceAmount ?? '') ?? 0.0;
      _toCustomerCreditEnabled = order.toCustomerCredit ?? false;
      _toCustomerCreditAmount = 0.0;

      _isCashSelected = cashAmount > 0;
      _cashAmount = cashAmount > 0 ? cashAmount.toStringAsFixed(2) : '';
      _isCardSelected = cardAmount > 0;
      _cardAmount = cardAmount > 0 ? cardAmount.toStringAsFixed(2) : '';
      _isUpiSelected = upiAmount > 0;
      _upiAmount = upiAmount > 0 ? upiAmount.toStringAsFixed(2) : '';
      _isCodSelected = codAmount > 0;
      _codAmount = codAmount > 0 ? codAmount.toStringAsFixed(2) : '';
      _isDebitSelected = debitAmount > 0;
      _debitAmount = debitAmount > 0 ? debitAmount.toStringAsFixed(2) : '';
      _hasOpenedPaymentModalOnce = _isCashSelected ||
          _isCardSelected ||
          _isUpiSelected ||
          _isCodSelected ||
          _isDebitSelected;
    });
  }

  bool _isDefaultCustomerPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? '';
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String? _resolveCustomerPhone({
    dynamic order,
    OrderDetailsModelData? orderDetails,
  }) {
    return _firstNonEmptyString([
      orderDetails?.customerDetails?.phone,
      _selectedCustomer?.phone,
      _selectedCustomerPhone,
      order is Map ? order['customer_phone'] : null,
      order is Map ? order['phone'] : null,
    ]);
  }

  String? _resolveCustomerName({
    dynamic order,
    OrderDetailsModelData? orderDetails,
  }) {
    return _firstNonEmptyString([
      orderDetails?.customerDetails?.name,
      _selectedCustomer?.name,
      order is Map ? order['customer_name'] : null,
      order is Map ? order['name'] : null,
    ]);
  }

  String? _resolveCustomerAlternatePhone(
      {OrderDetailsModelData? orderDetails}) {
    return _firstNonEmptyString([
      orderDetails?.customerDetails?.alternatePhone,
    ]);
  }

  /// Fetch cart item statuses for Mark Served functionality
  Future<void> _fetchCartItemStatuses() async {
    debugPrint('🚀 === FETCHING CART ITEM STATUSES (Restaurant) ===');
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      final response = await cartProvider.getCartItemStatuses(
        accessToken: authModel.token ?? '',
      );

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final statusResponse = CartItemStatusResponse.fromJson(response);
        setState(() {
          _availableStatuses = statusResponse.data;
        });

        debugPrint('✅ Fetched ${_availableStatuses.length} cart item statuses');
        for (var status in _availableStatuses) {
          debugPrint('   📊 ID: ${status.id}, Value: "${status.value}"');
        }
      } else {
        debugPrint(
            '❌ Failed to fetch cart item statuses: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Exception fetching cart item statuses: $e');
    }
  }

  /// Helper method to find status ID by value
  int? _findStatusIdByValue(String value) {
    if (_availableStatuses.isEmpty) {
      debugPrint('⚠️ No available statuses loaded yet');
      return null;
    }

    final status = _availableStatuses.firstWhere(
      (s) => s.value.toUpperCase() == value.toUpperCase(),
      orElse: () => CartItemStatus(id: 0, value: '', description: ''),
    );

    if (status.id == 0) {
      debugPrint('⚠️ Status value "$value" not found in available statuses');
      return null;
    }

    debugPrint('🔍 Found status ID ${status.id} for value "$value"');
    return status.id;
  }

  /// Mark all order items as SERVED
  Future<void> _markAllOrderItemsServed() async {
    if (_selectedOrder == null) return;

    final orderId = _selectedOrder['order_id'] ?? _selectedOrder['id'];
    final displayOrderId = _selectedOrder['order_number']?.toString() ??
        _selectedOrder['display_order_id']?.toString() ??
        orderId.toString();

    debugPrint('🚀 === MARKING ALL ORDER ITEMS AS SERVED ===');
    debugPrint('📦 Order ID: $orderId');

    final statusId = _findStatusIdByValue('SERVED');
    if (statusId == null) {
      showScaffoldError(context: context, message: 'Status "SERVED" not found');
      return;
    }

    setState(() {
      _isMarkingServed = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      final response = await cartProvider.updateAllOrderItemsStatus(
        orderId: orderId,
        statusId: statusId,
        accessToken: authModel.token ?? '',
      );

      debugPrint('📥 API Response: $response');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        debugPrint('✅ All order items updated to SERVED');

        // Refresh the saved orders to get updated statuses
        await _refreshSavedOrdersSilently();

        // Re-select the order to refresh details
        if (_selectedOrder != null) {
          final orderId = _selectedOrder['order_id'] ?? _selectedOrder['id'];
          final refreshedOrder = _savedOrders.firstWhere(
            (o) => (o['order_id'] ?? o['id']) == orderId,
            orElse: () => _selectedOrder,
          );
          setState(() {
            _selectedOrder = refreshedOrder;
          });
          widget.onOrderSelected(refreshedOrder);
        }

        if (mounted) {
          showScaffold(
            context: context,
            message: 'Order $displayOrderId items marked as SERVED',
          );
        }
      } else {
        debugPrint('❌ Failed to update all order items');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to mark items as served: ${response['message']}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception updating all order items: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error marking items as served: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingServed = false;
        });
      }
      debugPrint('🏁 === MARK ALL SERVED COMPLETED ===');
    }
  }

  /// Extracts and applies the default customer from app settings
  void _applyDefaultCustomer() {
    debugPrint("🔍 [DEBUG] Restaurant: _applyDefaultCustomer called");

    // Safeguard: if customer was manually selected or already partially entered, don't reset to default
    if (_isCustomerManuallySelected &&
        (_selectedCustomerID != null ||
            _selectedCustomerPhone?.isNotEmpty == true)) {
      debugPrint(
          "🛡️ [DEBUG] Restaurant: Customer manually selected (ID: $_selectedCustomerID, Phone: $_selectedCustomerPhone), skipping reset to default");
      return;
    }

    try {
      // Check if auto-assign is enabled in app settings
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final bool autoAssignEnabled =
          appSettingsProvider.appSettings?.autoAssignDefaultCustomer ?? false;

      debugPrint(
          "🔧 [DEBUG] Restaurant: Auto-assign enabled in settings: $autoAssignEnabled");

      if (!autoAssignEnabled) {
        debugPrint(
            "🔧 [DEBUG] APP SETTINGS: Auto-assign default customer is DISABLED for Restaurant");
        return;
      }

      if (_customers.isNotEmpty) {
        // Get the default customer phone from app settings
        final defaultPhone =
            appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ??
                "";

        debugPrint(
            "🔧 [DEBUG] Restaurant: Default customer phone from settings: '$defaultPhone'");

        if (defaultPhone.isNotEmpty) {
          try {
            final defaultCustomer = _customers.firstWhere(
              (customer) => customer.phone == defaultPhone,
            );
            debugPrint(
                "✅ [DEBUG] Found default customer for restaurant: ${defaultCustomer.name} (ID: ${defaultCustomer.id})");

            setState(() {
              _selectedCustomer = defaultCustomer;
              _selectedCustomerID = defaultCustomer.id;
              _selectedCustomerPhone = defaultCustomer.phone;
            });

            // Also update the global provider
            debugPrint("🔄 [DEBUG] Syncing with CustomerSelectionProvider...");
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .setSelectedCustomer(defaultCustomer, isDefault: true);
          } catch (e) {
            debugPrint(
                "⚠️ [DEBUG] No customer found in list of ${_customers.length} with phone '$defaultPhone' for restaurant");
          }
        } else {
          debugPrint("⚠️ [DEBUG] Default phone number is empty in AppSettings");
        }
      } else {
        debugPrint("⚠️ [DEBUG] Customer list is empty, cannot auto-assign");
      }
    } catch (e) {
      debugPrint('❌ [DEBUG] Error applying default customer: $e');
    }
  }

  void _showPaymentMethodModal({VoidCallback? onAfterApply}) {
    if (_selectedOrder == null) return;

    final List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);

    // Calculate effective total (discount + delivery charge)
    final rawOrderTotal = _calculateOrderTotal();
    final totalDiscountAmount =
        _flatDiscount + (rawOrderTotal * _percentageDiscount / 100);
    double orderTotal = _getEffectiveOrderTotal();

    debugPrint(
        '💰 Payment Modal - Cart items count: ${cartItems.length}, Discount: ${totalDiscountAmount.toStringAsFixed(2)}, Final Order Total: ${orderTotal.toStringAsFixed(2)}');

    final customerPrevBalance = _selectedCustomer?.balance ?? 0.0;

    // Auto-fill cash amount if no payment methods are currently selected
    String autoFillCashAmount = _cashAmount;
    bool autoSelectCash = _isCashSelected;

    // Check if any payment method is already selected
    bool hasSelection = _isCashSelected ||
        _isCardSelected ||
        _isUpiSelected ||
        _isCodSelected ||
        _isDebitSelected;

    // If no selection, check for default payment method from AppSettings
    if (!hasSelection) {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final defaultPayment =
          appSettingsProvider.appSettings?.defaultPaymentMethod;

      if (defaultPayment != null && defaultPayment.isNotEmpty) {
        debugPrint(
            '💰 Applying default payment method from AppSettings: $defaultPayment');
        switch (defaultPayment.toUpperCase()) {
          case 'CASH':
            _isCashSelected = true;
            break;
          case 'CARD':
            _isCardSelected = true;
            break;
          case 'UPI':
            _isUpiSelected = true;
            break;
          case 'COD':
            _isCodSelected = true;
            break;
        }
        hasSelection = true; // Now we have a selection
      }
    }

    // If still no selection (no default set), fallback to Cash
    if (!hasSelection) {
      _isCashSelected = true;
      autoSelectCash = true;
    }

    // Auto-fill amount logic:
    // If the selected method has no amount entered (is empty or 0), fill it with the total
    if (_isCashSelected &&
        (_cashAmount.isEmpty || double.tryParse(_cashAmount) == 0)) {
      autoFillCashAmount = orderTotal.toStringAsFixed(2);
      _cashAmount = autoFillCashAmount; // Update state immediately
      debugPrint('🔧 Auto-fill triggered for CASH: $autoFillCashAmount');
    } else if (_isCardSelected &&
        (_cardAmount.isEmpty || double.tryParse(_cardAmount) == 0)) {
      _cardAmount = orderTotal.toStringAsFixed(2);
      debugPrint('🔧 Auto-fill triggered for CARD: $_cardAmount');
    } else if (_isUpiSelected &&
        (_upiAmount.isEmpty || double.tryParse(_upiAmount) == 0)) {
      _upiAmount = orderTotal.toStringAsFixed(2);
      debugPrint('🔧 Auto-fill triggered for UPI: $_upiAmount');
    } else if (_isCodSelected &&
        (_codAmount.isEmpty || double.tryParse(_codAmount) == 0)) {
      _codAmount = orderTotal.toStringAsFixed(2);
      debugPrint('🔧 Auto-fill triggered for COD: $_codAmount');
    }

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: _isCashSelected,
        initialIsCardSelected: _isCardSelected,
        initialIsUpiSelected: _isUpiSelected,
        initialIsCodSelected: _isCodSelected,
        initialIsDebitSelected: _isDebitSelected,
        initialCashAmount: _cashAmount,
        initialCardAmount: _cardAmount,
        initialUpiAmount: _upiAmount,
        initialCodAmount: _codAmount,
        initialDebitAmount: _debitAmount,
        initialTransactionNumber: _transactionNumber,
        cartTotal: orderTotal,
        customerPrevBalance: customerPrevBalance,
        isDefaultCustomer:
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .isDefaultCustomer,
        onAfterApply: onAfterApply,
        onPaymentMethodSelected: (
          isCash,
          isCard,
          isUpi,
          isCod,
          isDebit,
          cash,
          card,
          upi,
          cod,
          debit,
          transaction,
          toCustomerCredit, {
          String? cashMethodId,
          String? cardMethodId,
          String? upiMethodId,
          String? codMethodId,
        }) {
          setState(() {
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _isCodSelected = isCod;
            _isDebitSelected = isDebit;
            _cashAmount = cash;
            _cardAmount = card;
            _upiAmount = upi;
            _codAmount = cod;
            _debitAmount = debit;
            _transactionNumber = transaction;
            _toCustomerCreditEnabled = toCustomerCredit;
            _hasOpenedPaymentModalOnce = true;
            // Capture the actual customer credit amount from the debit parameter
            _toCustomerCreditAmount = double.tryParse(debit) ?? 0.0;

            debugPrint('💳 Payment Method Updated:');
            debugPrint(
                '  - To Customer Credit Enabled: $_toCustomerCreditEnabled');
            debugPrint(
                '  - Customer Credit Amount: ${_toCustomerCreditAmount.toStringAsFixed(2)}');
            if (cashMethodId != null)
              debugPrint('  - Cash Method ID: $cashMethodId');
            if (cardMethodId != null)
              debugPrint('  - Card Method ID: $cardMethodId');
            if (upiMethodId != null)
              debugPrint('  - UPI Method ID: $upiMethodId');
            if (codMethodId != null)
              debugPrint('  - COD Method ID: $codMethodId');

            // Calculate balance
            final totalPaid = (double.tryParse(cash) ?? 0.0) +
                (double.tryParse(card) ?? 0.0) +
                (double.tryParse(upi) ?? 0.0) +
                (double.tryParse(cod) ?? 0.0);
            _balanceAmount = totalPaid - orderTotal;
          });

          // Store payment method IDs in BillingProvider for API use
          final billingProvider =
              Provider.of<BillingProvider>(context, listen: false);
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
            transactionNumber: transaction,
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

  void _showCustomerSelectionModal() {
    // Local state for search
    String searchQuery = '';
    List<CustomerListModelData> filteredCustomers = _customers;
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filter customers based on search query
          void filterCustomers(String query) {
            setModalState(() {
              searchQuery = query.toLowerCase();
              if (searchQuery.isEmpty) {
                filteredCustomers = _customers;
              } else {
                filteredCustomers = _customers.where((customer) {
                  final name = (customer.name ?? '').toLowerCase();
                  final phone = (customer.phone ?? '').toLowerCase();
                  return name.contains(searchQuery) ||
                      phone.contains(searchQuery);
                }).toList();
              }
            });
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 10,
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 650),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.people,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Select Customer',
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s18,
                                0.30,
                                const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterCustomers,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone number...',
                          hintStyle: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.21,
                            const Color(0xFF64748B),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      searchController.clear();
                                      filterCustomers('');
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.clear,
                                        color: Color(0xFF64748B),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s14,
                          0.21,
                          const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filteredCustomers.isEmpty &&
                              searchQuery.isNotEmpty)
                            // No search results
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No customers found',
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s16,
                                      0.21,
                                      const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try searching with different keywords',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s14,
                                      0.21,
                                      const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (filteredCustomers.isEmpty)
                            // No customers at all
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF64748B)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 48,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No customers found',
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s16,
                                      0.21,
                                      const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        // Check if search query is a 10-digit number
                                        String phoneToPreFill = '';
                                        if (searchQuery.length == 10 &&
                                            RegExp(r'^[0-9]+$')
                                                .hasMatch(searchQuery)) {
                                          phoneToPreFill = searchQuery;
                                        }
                                        showAddCustomerModal(context,
                                                MediaQuery.of(context).size,
                                                mobileNumber: phoneToPreFill)
                                            .then((result) async {
                                          if (result != null &&
                                              result['status'] == 'success') {
                                            final authModel =
                                                Provider.of<AuthModel>(context,
                                                    listen: false);
                                            final customerProvider =
                                                Provider.of<CustomerProvider>(
                                                    context,
                                                    listen: false);
                                            await customerProvider
                                                .fetchCustomers(
                                              accessToken:
                                                  authModel.token ?? '',
                                              listAll: true,
                                            );
                                            if (!mounted) return;
                                            _hydrateCustomerListFromProviderCache();

                                            // Find and auto-select the newly added customer by phone
                                            final addedPhone = result['phone'];
                                            final matchingCustomer =
                                                _customers.firstWhere(
                                              (customer) =>
                                                  customer.phone == addedPhone,
                                              orElse: () =>
                                                  CustomerListModelData(),
                                            );
                                            if (matchingCustomer.phone ==
                                                addedPhone) {
                                              setState(() {
                                                _selectedCustomer =
                                                    matchingCustomer;
                                                _selectedCustomerID =
                                                    matchingCustomer.id;
                                                _selectedCustomerPhone =
                                                    matchingCustomer.phone;
                                              });
                                            }
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB)
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.person_add,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Add New Customer',
                                              style: buildCustomStyle(
                                                FontWeightManager.semiBold,
                                                FontSize.s14,
                                                0.21,
                                                Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            // Customer list
                            Flexible(
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 320),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.all(8),
                                  itemCount: filteredCustomers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, index) {
                                    final customer = filteredCustomers[index];
                                    final isSelected =
                                        _selectedCustomer?.id == customer.id;

                                    // Highlight search terms
                                    String highlightedName =
                                        customer.name ?? 'Unknown';
                                    String highlightedPhone =
                                        customer.phone ?? '';

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedCustomer = customer;
                                            _selectedCustomerID = customer.id;
                                            _selectedCustomerPhone =
                                                customer.phone;
                                            _isCustomerManuallySelected =
                                                true; // Mark as manually selected
                                          });

                                          // Also update the global provider
                                          Provider.of<CustomerSelectionProvider>(
                                                  context,
                                                  listen: false)
                                              .setSelectedCustomer(customer);

                                          Navigator.of(context).pop();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF2563EB)
                                                    .withOpacity(0.1)
                                                : Colors.white,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF2563EB)
                                                  : Colors.grey.shade200,
                                              width: 1.5,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF2563EB)
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF2563EB)
                                                      : const Color(0xFF64748B),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    (customer.name ?? 'U')
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                                    style: buildCustomStyle(
                                                      FontWeightManager.bold,
                                                      FontSize.s14,
                                                      0.21,
                                                      Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      highlightedName,
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .semiBold,
                                                        FontSize.s14,
                                                        0.21,
                                                        isSelected
                                                            ? const Color(
                                                                0xFF2563EB)
                                                            : const Color(
                                                                0xFF1E293B),
                                                      ),
                                                    ),
                                                    if (highlightedPhone
                                                        .isNotEmpty)
                                                      Text(
                                                        highlightedPhone,
                                                        style: buildCustomStyle(
                                                          FontWeightManager
                                                              .medium,
                                                          FontSize.s12,
                                                          0.21,
                                                          const Color(
                                                              0xFF64748B),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (isSelected)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF059669),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Footer - Always show Add New Customer button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          // Check if search query is a 10-digit number
                          String phoneToPreFill = '';
                          if (searchQuery.length == 10 &&
                              RegExp(r'^[0-9]+$').hasMatch(searchQuery)) {
                            phoneToPreFill = searchQuery;
                          }
                          showAddCustomerModal(
                                  context, MediaQuery.of(context).size,
                                  mobileNumber: phoneToPreFill)
                              .then((result) async {
                            if (result != null &&
                                result['status'] == 'success') {
                              final authModel = Provider.of<AuthModel>(context,
                                  listen: false);
                              final customerProvider =
                                  Provider.of<CustomerProvider>(context,
                                      listen: false);
                              await customerProvider.fetchCustomers(
                                accessToken: authModel.token ?? '',
                                listAll: true,
                              );
                              if (!mounted) return;
                              _hydrateCustomerListFromProviderCache();

                              // Find and auto-select the newly added customer by phone
                              final addedPhone = result['phone'];
                              final matchingCustomer = _customers.firstWhere(
                                (customer) => customer.phone == addedPhone,
                                orElse: () => CustomerListModelData(),
                              );
                              if (matchingCustomer.phone == addedPhone) {
                                setState(() {
                                  _selectedCustomer = matchingCustomer;
                                  _selectedCustomerID = matchingCustomer.id;
                                  _selectedCustomerPhone =
                                      matchingCustomer.phone;
                                });
                              }
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_add,
                                color: Color(0xFF64748B),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add New Customer',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.21,
                                  const Color(0xFF64748B),
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
          );
        },
      ),
    );
  }

  // Helper method to check if any discount is applied
  bool _hasDiscount() {
    return _isCouponApplied ||
        _flatDiscount > 0.0 ||
        _percentageDiscount > 0.0 ||
        _couponCode.isNotEmpty;
  }

  void _showCouponModal() {
    // Calculate current order total for the modal
    double orderSubTotal = 0.0;
    if (_selectedOrder != null) {
      final List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);

      for (var item in cartItems) {
        final quantity =
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        final unitPrice = double.tryParse(item['unit_price']?.toString() ??
                item['price']?.toString() ??
                item['product_price']?.toString() ??
                '0') ??
            0.0;
        orderSubTotal += quantity * unitPrice;
      }

      if (orderSubTotal == 0.0 && _selectedOrder['grand_total'] != null) {
        orderSubTotal =
            double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
                0.0;
      }
    }

    // Create a wrapper that provides the LocalProductProvider interface for CouponModal
    showDialog(
      context: context,
      builder: (context) => RestaurantCouponModalWrapper(
        orderSubTotal: orderSubTotal,
        initialCouponCode: _couponCode,
        initialFlatDiscount: _flatDiscount,
        initialPercentageDiscount: _percentageDiscount,
        isCouponApplied: _isCouponApplied,
        onCouponAction: (couponCode, isApplied,
            {double? flatDiscount, double? percentageDiscount}) {
          setState(() {
            _couponCode = couponCode;
            _isCouponApplied = isApplied;
            _flatDiscount = flatDiscount ?? 0.0;
            _percentageDiscount = percentageDiscount ?? 0.0;

            // If clearing discount
            if (!isApplied) {
              _couponCode = "";
              _flatDiscount = 0.0;
              _percentageDiscount = 0.0;
            }
          });
        },
      ),
    );
  }

  // Method to refresh saved orders without clearing the selected order (for when editing)
  Future<void> refreshSavedOrdersKeepingSelection() async {
    final currentSelectedOrder = _selectedOrder; // Store current selection

    setState(() {
      _isLoadingOrders = true;
      _error = null;
      // Don't clear _selectedOrder and _savedOrders here
    });

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    debugPrint(
        '🔄 _refreshSavedOrdersKeepingSelection: Sending request with tableId: ${widget.tableId}');
    try {
      debugPrint('➡️ Calling CartProvider.listSavedOrders');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );
      debugPrint('✅ listSavedOrders Response: $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
            if (_blockReselectAfterPlace) {
              _selectedOrder = null;
              widget.onOrderSelected(null);
              debugPrint('✅ Skipping reselect after order placed');
              return;
            }
            final currentOrderId =
                currentSelectedOrder['id'] ?? currentSelectedOrder['order_id'];
            final updatedOrder = newOrders.firstWhere(
              (order) =>
                  order['id'] == currentOrderId ||
                  order['order_id'] == currentOrderId,
              orElse: () => null,
            );

            if (updatedOrder != null) {
              _selectedOrder = updatedOrder; // Update with fresh data
              widget.onOrderSelected(updatedOrder); // Notify parent widget
              _hasOpenedPaymentModalOnce =
                  false; // Reset payment modal flag when switching orders
              debugPrint('✅ Updated selected order with fresh data');
            } else {
              // Keep the current selection - don't clear it immediately
              // The order might just be processing on the server
              debugPrint(
                  '⚠️ Selected order not found in updated list, keeping current selection');
              // Only clear if we're sure the order is gone (you can add more logic here if needed)
            }
          }
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load saved orders';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching saved orders: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  // Silent refresh method for background updates (no loading spinner)
  Future<void> _refreshSavedOrdersSilently() async {
    final currentSelectedOrder = _selectedOrder; // Store current selection

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    debugPrint(
        '🔄 _refreshSavedOrdersSilently: Sending request with tableId: ${widget.tableId}');
    try {
      debugPrint('➡️ Calling CartProvider.listSavedOrders (silent)');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );
      debugPrint('✅ listSavedOrders Response (silent): $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
            if (_blockReselectAfterPlace) {
              _selectedOrder = null;
              widget.onOrderSelected(null);
              debugPrint('✅ Skipping reselect after order placed');
              return;
            }
            final currentOrderId =
                currentSelectedOrder['id'] ?? currentSelectedOrder['order_id'];
            final updatedOrder = newOrders.firstWhere(
              (order) =>
                  order['id'] == currentOrderId ||
                  order['order_id'] == currentOrderId,
              orElse: () => null,
            );

            if (updatedOrder != null) {
              _selectedOrder = updatedOrder; // Update with fresh data
              widget.onOrderSelected(updatedOrder); // Notify parent widget
              _hasOpenedPaymentModalOnce =
                  false; // Reset payment modal flag when switching orders
              debugPrint('✅ Updated selected order with fresh data (silent)');
            } else {
              debugPrint(
                  '⚠️ Selected order not found in updated list (silent)');
            }
          }
        });
      } else {
        debugPrint(
            '⚠️ Failed to refresh saved orders (silent): ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error in silent refresh: ${e.toString()}');
    }
  }

  Future<void> _fetchOrderDetails(dynamic order) async {
    setState(() {
      _isLoadingOrderDetails = true;
      _error = null;
    });

    try {
      debugPrint('🔄 _fetchOrderDetails: Processing saved order data.');
      debugPrint('📋 Order details: $order');

      // Clear previous order's customer and payment state to prevent contamination
      _clearOrderEditingState();

      _blockReselectAfterPlace = false;
      _selectedOrder = order; // Set the selected order directly
      widget.onOrderSelected(
          order); // Call the callback to update the parent widget

      // Load order-specific data if available
      _loadOrderSpecificData(order);
    } catch (e) {
      debugPrint('❌ _fetchOrderDetails Exception: ${e.toString()}');
      setState(() {
        _error = 'Error processing order details: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingOrderDetails = false;
      });
    }
  }

  // Clear customer and payment state when switching orders
  void _clearOrderEditingState() {
    debugPrint('🧹 Clearing previous order editing state...');
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();
    setState(() {
      // Clear customer selection
      _selectedCustomer = null;
      _selectedCustomerID = null;
      _selectedCustomerPhone = null;

      // Clear payment methods
      _isCashSelected = false;
      _isCardSelected = false;
      _isUpiSelected = false;
      _isCodSelected = false;
      _isDebitSelected = false;
      _cashAmount = "";
      _cardAmount = "";
      _upiAmount = '';
      _codAmount = "";
      _debitAmount = '';
      _orderComment = "";
      _transactionNumber = "";

      // Clear discount state
      _isCouponApplied = false;
      _flatDiscount = 0.0;
      _percentageDiscount = 0.0;
      _couponCode = "";

      // Reset balance and credit state
      _balanceAmount = 0.0;
      _toCustomerCreditEnabled = false;
      _toCustomerCreditAmount = 0.0;

      // Reset payment modal flag
      _hasOpenedPaymentModalOnce = false;

      // Reset delivery state
      _deliveryMethod = "Store Takeaway";
      _deliveryMethodId = "";
      _deliveryAddress = "";
      _deliveryDate = null;
      _deliveryTime = null;
      _selectedDeliveryCharge = null;
    });
    debugPrint('✅ Order editing state cleared');
  }

  // Sync variant without setState to avoid triggering extra rebuilds in lifecycle hooks
  void _clearOrderEditingStateSync() {
    debugPrint('🧹 Clearing previous order editing state...');
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();
    // Clear customer selection
    _selectedCustomer = null;
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;

    // Clear payment methods
    _isCashSelected = false;
    _isCardSelected = false;
    _isUpiSelected = false;
    _isCodSelected = false;
    _isDebitSelected = false;
    _cashAmount = "";
    _cardAmount = "";
    _upiAmount = '';
    _codAmount = "";
    _debitAmount = '';
    _orderComment = "";
    _transactionNumber = "";

    // Clear discount state
    _isCouponApplied = false;
    _flatDiscount = 0.0;
    _percentageDiscount = 0.0;
    _couponCode = "";

    // Reset balance and credit state
    _balanceAmount = 0.0;
    _toCustomerCreditEnabled = false;
    _toCustomerCreditAmount = 0.0;

    // Reset payment modal flag
    _hasOpenedPaymentModalOnce = false;

    // Reset delivery state
    _deliveryMethod = "Store Takeaway";
    _deliveryMethodId = "";
    _deliveryAddress = "";
    _deliveryDate = null;
    _deliveryTime = null;
    _selectedDeliveryCharge = null;

    debugPrint('✅ Order editing state cleared');
  }

  // Public method to reset payment modal flag (called from parent)
  void resetPaymentModalFlag() {
    setState(() {
      _hasOpenedPaymentModalOnce = false;
    });
  }

  // Public method to clear current order-level comment after save/send flows.
  void clearCurrentOrderComment() {
    if (!mounted) return;
    setState(() {
      _orderComment = '';
      _loadedLocalDraftId = null;
    });
  }

  // Load order-specific data (customer, payment, etc.) from the selected order
  void _loadOrderSpecificData(dynamic order) {
    debugPrint('📋 Loading order-specific data...');

    try {
      // Load customer information if available
      final customerId = order['customer_id'];
      final customerPhone = order['customer_phone'] ?? order['phone'];
      final customerSelectionProvider =
          Provider.of<CustomerSelectionProvider>(context, listen: false);

      if (customerId != null) {
        // Find customer in the list
        final customer = _customers.firstWhere(
          (c) => c.id == customerId,
          orElse: () => CustomerListModelData(
            id: customerId,
            phone: customerPhone,
            name: order['customer_name'] ?? 'Unknown Customer',
          ),
        );

        setState(() {
          _selectedCustomer = customer;
          _selectedCustomerID = customerId;
          _selectedCustomerPhone = customerPhone;
        });

        customerSelectionProvider.setSelectedCustomer(
          customer,
          isDefault: _isDefaultCustomerPhone(customerPhone?.toString()),
        );

        debugPrint(
            '✅ Loaded customer from order: ${customer.name} (${customer.phone})');
      } else {
        debugPrint(
            'ℹ️ No customer associated with this order. Applying default if applicable...');
        customerSelectionProvider.clearSelectedCustomer();
        _applyDefaultCustomer();
      }

      // Load payment method information if available
      final paymentMethod = order['payment_method'];
      final paidAmount = order['paid_amount']?.toString() ?? '';
      final transactionNumber =
          order['transaction_number'] ?? order['transaction_id'] ?? '';

      if (paymentMethod != null && paidAmount.isNotEmpty) {
        setState(() {
          _transactionNumber = transactionNumber;

          // Reset all payment methods first
          _isCashSelected = false;
          _isCardSelected = false;
          _isUpiSelected = false;
          _isCodSelected = false;
          _isDebitSelected = false;
          _cashAmount = '';
          _cardAmount = '';
          _upiAmount = '';
          _codAmount = '';
          _debitAmount = '';

          // Set the specific payment method
          switch (paymentMethod.toString().toUpperCase()) {
            case 'CASH':
              _isCashSelected = true;
              _cashAmount = paidAmount;
              break;
            case 'CARD':
              _isCardSelected = true;
              _cardAmount = paidAmount;
              break;
            case 'UPI':
              _isUpiSelected = true;
              _upiAmount = paidAmount;
              break;
            case 'COD':
              _isCodSelected = true;
              _codAmount = paidAmount;
              break;
            default:
              // Default to cash if payment method is unknown
              _isCashSelected = true;
              _cashAmount = paidAmount;
          }
        });

        debugPrint(
            '✅ Loaded payment method: $paymentMethod, Amount: $paidAmount');
      }

      // Load existing order-level comment from supported API shapes.
      setState(() {
        _orderComment = _extractOrderLevelComment(order) ?? '';
      });

      // Load delivery information if available
      final loadedDeliveryMethodId = order['delivery_method_id']?.toString() ??
          _getDefaultDeliveryMethodId();

      // Try name from order first; fall back to looking up by ID in the provider
      String loadedDeliveryMethodName =
          order['delivery_method_name']?.toString() ??
              order['delivery_method']?.toString() ??
              '';
      if (loadedDeliveryMethodName.isEmpty) {
        final deliveryMethodsProvider =
            Provider.of<DeliveryMethodsProvider>(context, listen: false);
        final match = deliveryMethodsProvider.deliveryMethods.firstWhere(
          (m) => m.id == loadedDeliveryMethodId,
          orElse: () => DeliveryMethod(
              id: loadedDeliveryMethodId, name: 'Store Takeaway'),
        );
        loadedDeliveryMethodName = match.name;
        debugPrint(
            '🚚 Resolved delivery method name from provider: $loadedDeliveryMethodName (id: $loadedDeliveryMethodId)');
      }
      final loadedDeliveryDate = order['delivery_date']?.toString();
      final loadedDeliveryTime = order['delivery_time']?.toString();
      final loadedDeliveryAddress = order['address']?.toString() ?? '';
      final loadedDeliveryCharge =
          double.tryParse(order['delivery_charge']?.toString() ?? '');

      setState(() {
        _deliveryMethodId = loadedDeliveryMethodId;
        _deliveryMethod = loadedDeliveryMethodName;
        _deliveryDate = loadedDeliveryDate;
        _deliveryTime = loadedDeliveryTime;
        _deliveryAddress = loadedDeliveryAddress;
        _selectedDeliveryCharge = loadedDeliveryCharge;
      });

      // Load discount information if available
      final flatDiscount = order['flat_discount'];
      final percentageDiscount = order['percentage_discount'];
      final couponCode = order['coupon_id'] ?? order['coupon_code'] ?? '';

      setState(() {
        _flatDiscount = double.tryParse(flatDiscount?.toString() ?? '0') ?? 0.0;
        _percentageDiscount =
            double.tryParse(percentageDiscount?.toString() ?? '0') ?? 0.0;
        _couponCode = couponCode;
        _isCouponApplied = _flatDiscount > 0 ||
            _percentageDiscount > 0 ||
            _couponCode.isNotEmpty;
      });

      if (_isCouponApplied) {
        debugPrint('✅ Loaded discount data:');
        debugPrint('   - Flat Discount: ${_flatDiscount.toStringAsFixed(2)}');
        debugPrint(
            '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
        debugPrint('   - Coupon Code: $_couponCode');
      }

      // Calculate balance amount
      final orderTotal =
          double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0.0;
      final totalPaid = double.tryParse(paidAmount) ?? 0.0;
      _balanceAmount = totalPaid - orderTotal;

      debugPrint('💰 Calculated balance: ${_balanceAmount.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('❌ Error loading order-specific data: $e');
    }

    debugPrint('✅ Order-specific data loading completed');
  }

  bool _hasPaymentMethod() {
    // Check if any payment method is selected AND has amount > 0
    final cashAmount = double.tryParse(_cashAmount) ?? 0;
    final cardAmount = double.tryParse(_cardAmount) ?? 0;
    final upiAmount = double.tryParse(_upiAmount) ?? 0;
    final codAmount = double.tryParse(_codAmount) ?? 0;
    final debitAmount = double.tryParse(_debitAmount) ?? 0;

    return (_isCashSelected && cashAmount > 0) ||
        (_isCardSelected && cardAmount > 0) ||
        (_isUpiSelected && upiAmount > 0) ||
        (_isCodSelected && codAmount > 0) ||
        (_isDebitSelected && debitAmount > 0);
  }

  // Comment editor dialog
  void _showCommentDialog() {
    final String initialComment = _orderComment.isNotEmpty
        ? _orderComment
        : (_extractOrderLevelComment(_selectedOrder) ?? '');
    final controller = TextEditingController(text: initialComment);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: BuildBoxShadowContainer(
            circleRadius: 12,
            color: Colors.white,
            width: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Comment',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.21,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Comment',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.21,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(
                      left: 15, right: 15, top: 8, bottom: 8),
                  height: 110,
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter order comment',
                      hintStyle: buildCustomStyle(
                        FontWeight.w500,
                        12,
                        0.27,
                        Colors.grey.withOpacity(.5),
                      ),
                      border: InputBorder.none,
                    ),
                    style: buildCustomStyle(
                      FontWeight.w500,
                      12,
                      0.27,
                      Colors.black.withOpacity(.8),
                    ),
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .show('text', controller, replaceOnFirstInput: false);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CustomRoundButton(
                        title: "Cancel",
                        fct: () => Navigator.of(context).pop(),
                        fontSize: FontSize.s14,
                        height: 45,
                        width: double.infinity,
                        boxColor: Colors.grey.shade600,
                        borderColor: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: CustomRoundButton(
                        title: "Save Comment",
                        fct: () {
                          setState(() {
                            _orderComment = controller.text.trim();
                          });
                          Navigator.of(context).pop();
                        },
                        fontSize: FontSize.s14,
                        height: 45,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Per-item comment dialog (works for both local cart items and saved order items)
  void _showItemCommentDialog(dynamic item, {required bool isLocal}) {
    String currentComment = '';
    if (isLocal) {
      currentComment = (item as LocalCartItem).comment ?? '';
    } else {
      currentComment = item['comment']?.toString() ?? '';
    }

    final controller = TextEditingController(text: currentComment);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Item Note',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
              ),
            ),
            if (currentComment.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626), size: 20),
                onPressed: () {
                  Navigator.of(dialogContext).pop('');
                },
                tooltip: 'Clear note',
              ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g., No ice, Extra spicy, Less sugar...',
            hintStyle: buildCustomStyle(FontWeightManager.regular, FontSize.s13,
                0.21, const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancel',
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                    0.21, const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s14, 0.21, Colors.white)),
          ),
        ],
      ),
    ).then((result) async {
      if (result == null) return; // Cancelled
      final comment = (result as String).isEmpty ? null : result;

      if (isLocal) {
        final cartItem = item as LocalCartItem;
        final localProductProvider =
            Provider.of<LocalProductProvider>(context, listen: false);
        localProductProvider.updateCartItemComment(
          cartItem.product.productId!,
          cartItem.selectedStock,
          comment,
          stockGroupIds: cartItem.stockGroupIds,
          saleUnitId: cartItem.saleUnitId,
        );
      } else {
        // For saved order items, persist comment via addToCartAPI with same payload + comment
        try {
          final authModel = Provider.of<AuthModel>(context, listen: false);
          final cartProvider =
              Provider.of<CartProvider>(context, listen: false);

          final customerId = _selectedOrder['cart']?['customer_id'] ??
              _selectedOrder['customer_id'] ??
              1;
          final orderCartId = int.tryParse(
              (_selectedOrder['cart']?['id'] ?? _selectedOrder['cart_id'])
                      ?.toString() ??
                  '');
          final productId = item['product_id'];
          final unitPrice = item['unit_price']?.toString() ??
              item['price']?.toString() ??
              item['product_price']?.toString();

          if (productId == null) {
            showScaffoldError(
              context: context,
              message: 'Product ID not found for item comment update.',
            );
            return;
          }

          debugPrint(
              '➡️ Calling CartProvider.addToCartAPI for item comment update');
          debugPrint(
              '📦 addToCartAPI Request Body: {customerId: $customerId, productId: $productId, quantity: 0, unitPrice: $unitPrice, cartId: $orderCartId, comment: $comment}');

          final response = await cartProvider.addToCartAPI(
            customerId: int.parse(customerId.toString()),
            productId: int.parse(productId.toString()),
            quantity: 0,
            unitPrice: unitPrice,
            comment: comment,
            accessToken: authModel.token ?? '',
            cartId: orderCartId,
          );

          if (isApiSuccess(response)) {
            setState(() {
              item['comment'] = comment ?? '';
            });
          } else {
            showScaffoldError(
              context: context,
              message: response?['message']?.toString() ??
                  'Failed to update item comment',
            );
          }
        } catch (e) {
          showScaffoldError(
            context: context,
            message: 'Failed to update item comment: ${e.toString()}',
          );
        }
      }
    });
  }

  // Default Delivery Method (mirror of BillingPage)
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
      return defaultMethod?.id ?? kFallbackDeliveryMethodId;
    } catch (e) {
      return kFallbackDeliveryMethodId;
    }
  }

  double _getDiscountedOrderTotalWithoutDelivery() {
    final orderTotal = _calculateOrderTotal();
    final totalDiscountAmount =
        _flatDiscount + (orderTotal * _percentageDiscount / 100);
    final discountedTotal = orderTotal - totalDiscountAmount;
    return discountedTotal < 0 ? 0.0 : discountedTotal;
  }

  bool _isfreeDeliveryMinimumAmount() {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    return settings?.freeDeliveryEnabled ?? false;
  }

  double _getFreeDeliveryMinimumAmount() {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final rawValue = settings?.freeDeliveryMinimumAmount.trim() ?? '';
    return double.tryParse(rawValue) ?? 0.0;
  }

  double _getDeliveryChargeForOrder() {
    if (!_isfreeDeliveryMinimumAmount()) {
      return 0.0;
    }

    final minimumAmount = _getFreeDeliveryMinimumAmount();
    final discountedTotal = _getDiscountedOrderTotalWithoutDelivery();
    if (minimumAmount > 0 && discountedTotal >= minimumAmount) {
      return 0.0;
    }

    if (_selectedDeliveryCharge != null) {
      return _selectedDeliveryCharge!;
    }

    final effectiveDeliveryMethodId = _deliveryMethodId.isNotEmpty
        ? _deliveryMethodId
        : _getDefaultDeliveryMethodId();

    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if ((effectiveDeliveryMethodId.isNotEmpty &&
              method.id == effectiveDeliveryMethodId) ||
          (_deliveryMethod.isNotEmpty && method.name == _deliveryMethod)) {
        return method.basePrice ?? 0.0;
      }
    }

    return 0.0;
  }

  double _getEffectiveOrderTotal() {
    return _getDiscountedOrderTotalWithoutDelivery() +
        _getDeliveryChargeForOrder();
  }

  Widget _buildPaymentSummary() {
    if (_selectedOrder == null) {
      return const SizedBox.shrink();
    }

    final List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);

    // Calculate order total dynamically from cart items
    double orderTotal = 0.0;
    for (var item in cartItems) {
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      final unitPrice = double.tryParse(item['unit_price']?.toString() ??
              item['price']?.toString() ??
              item['product_price']?.toString() ??
              '0') ??
          0.0;
      orderTotal += quantity * unitPrice;
    }

    // If we still have zero total, try getting it from order total as fallback
    if (orderTotal == 0.0 && _selectedOrder['grand_total'] != null) {
      orderTotal =
          double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
              0.0;
    }

    debugPrint(
        '💰 Payment Summary - Cart items count: ${cartItems.length}, Order Total: ${orderTotal.toStringAsFixed(2)}');

    final customerBalance = _selectedCustomer?.balance ?? 0.0;
    final cashAmount = double.tryParse(_cashAmount) ?? 0.0;
    final cardAmount = double.tryParse(_cardAmount) ?? 0.0;
    final upiAmount = double.tryParse(_upiAmount) ?? 0.0;
    final codAmount = double.tryParse(_codAmount) ?? 0.0;
    final totalPaidAmount = cashAmount + cardAmount + upiAmount + codAmount;

    debugPrint('\n🧮 === RESTAURANT PAGE BALANCE CALCULATION START ===');
    debugPrint('💰 Input Values:');
    debugPrint('  - Order Total: ${orderTotal.toStringAsFixed(2)}');
    debugPrint('  - Customer Balance: ${customerBalance.toStringAsFixed(2)}');
    debugPrint('  - Cash Amount: ${cashAmount.toStringAsFixed(2)}');
    debugPrint('  - Card Amount: ${cardAmount.toStringAsFixed(2)}');
    debugPrint('  - UPI Amount: ${upiAmount.toStringAsFixed(2)}');
    debugPrint('  - COD Amount: ${codAmount.toStringAsFixed(2)}');
    debugPrint('  - Total Paid Amount: ${totalPaidAmount.toStringAsFixed(2)}');
    debugPrint('  - To Customer Credit Enabled: $_toCustomerCreditEnabled');
    debugPrint(
        '  - Customer Credit Amount: ${_toCustomerCreditAmount.toStringAsFixed(2)}');

    // Calculate discount amounts
    final flatDiscountAmount = _flatDiscount;
    final percentageDiscountAmount = (orderTotal * _percentageDiscount / 100);
    final totalDiscountAmount = flatDiscountAmount + percentageDiscountAmount;
    final finalOrderTotalWithoutDelivery = orderTotal - totalDiscountAmount;
    final deliveryCharge = _getDeliveryChargeForOrder();
    final finalOrderTotal = finalOrderTotalWithoutDelivery + deliveryCharge;

    // Calculate balance using the same logic as billing_page.dart
    double cashBalance = 0.0;

    if (_toCustomerCreditEnabled && _selectedCustomer != null) {
      debugPrint(
          '🔛 RESTAURANT PAGE: Toggle is ON - Calculating with customer credit consideration');

      if (customerBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalPaidAmount - finalOrderTotal;
        debugPrint(
            '💰 Transaction excess: ${transactionExcess.toStringAsFixed(2)}');

        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = _toCustomerCreditAmount;

          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            debugPrint(
                '  - Clamped customer credit to transaction excess: ${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = transaction excess - customer credit
          cashBalance = transactionExcess - actualCustomerCredit;
          debugPrint(
              '  - Balance = Transaction Excess (${transactionExcess.toStringAsFixed(2)}) - Customer Credit (${actualCustomerCredit.toStringAsFixed(2)}) = ${cashBalance.toStringAsFixed(2)}');
        } else {
          cashBalance = 0.0;
          debugPrint('  - No transaction excess, balance = 0');
        }
      } else {
        // Customer has positive/zero balance - use Net Due logic
        debugPrint('💵 Customer has credit/zero balance - using Net Due logic');
        // Net Due = Final Order Total - Customer Previous Balance
        double netDue = finalOrderTotal - customerBalance;
        debugPrint('💰 Net Due calculation:');
        debugPrint('  - Purchase Total: ${finalOrderTotal.toStringAsFixed(2)}');
        debugPrint(
            '  - Customer Prev Balance: ${customerBalance.toStringAsFixed(2)}');
        debugPrint('  - Net Due: ${netDue.toStringAsFixed(2)}');

        // Available balance = Total Collected - Net Due
        double availableBalance = totalPaidAmount - netDue;
        debugPrint(
            '  - Total Collected: ${totalPaidAmount.toStringAsFixed(2)}');
        debugPrint(
            '  - Available Balance: ${availableBalance.toStringAsFixed(2)}');

        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = _toCustomerCreditAmount;

          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            debugPrint(
                '  - Clamped customer credit to available balance: ${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = available balance - customer credit
          cashBalance = availableBalance - actualCustomerCredit;
          debugPrint(
              '  - Balance = Available Balance (${availableBalance.toStringAsFixed(2)}) - Customer Credit (${actualCustomerCredit.toStringAsFixed(2)}) = ${cashBalance.toStringAsFixed(2)}');
        } else {
          cashBalance = 0.0;
          debugPrint('  - No available balance, balance = 0');
        }
      }
    } else {
      debugPrint(
          '🔴 RESTAURANT PAGE: Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      cashBalance = totalPaidAmount - finalOrderTotal;
      debugPrint(
          '  - Balance = Total Collected (${totalPaidAmount.toStringAsFixed(2)}) - Final Order Total (${finalOrderTotal.toStringAsFixed(2)}) = ${cashBalance.toStringAsFixed(2)}');
    }

    // Store the raw balance before clamping for comparison
    double rawBalance = cashBalance;

    // Clamp cash balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (cashBalance < 0) {
      debugPrint(
          '🚫 RESTAURANT PAGE: Clamping negative cash balance (${cashBalance.toStringAsFixed(2)}) to 0 for UI display');
      cashBalance = 0.0;
    }

    debugPrint('💵 Final cash balance: ${cashBalance.toStringAsFixed(2)}');
    debugPrint(
        '💵 Raw balance (before clamping): ${rawBalance.toStringAsFixed(2)}');
    debugPrint('🧮 === RESTAURANT PAGE BALANCE CALCULATION END ===\n');

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
    final netAmount = finalOrderTotal;
    const taxAmount = 0.0;
    final totalPayable = finalOrderTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            'Net Amount',
            '$currency ${netAmount.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'Tax',
            '$currency ${taxAmount.toStringAsFixed(2)}',
            color: const Color(0xFF7C8DB5),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFFE4E4ED)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total Payable',
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF3B82F6),
            isBold: true,
            large: true,
          ),
          _buildSummaryRow(
            'Total Paid',
            '$currency ${totalPaidAmount.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'Balance',
            '$currency ${cashBalance.toStringAsFixed(2)}',
            color: const Color(0xFF00C739),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount, {
    required Color color,
    bool isBold = false,
    bool large = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              isBold ? FontWeightManager.semiBold : FontWeightManager.regular,
              large ? FontSize.s18 : FontSize.s14,
              0.21,
              color,
            ),
          ),
          Text(
            amount,
            style: buildCustomStyle(
              isBold ? FontWeightManager.bold : FontWeightManager.semiBold,
              large ? FontSize.s18 : FontSize.s14,
              0.21,
              color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNonTableOrderContext = widget.tableId == null &&
        ((widget.preselectedDeliveryMethodId != null &&
                widget.preselectedDeliveryMethodId!.isNotEmpty) ||
            (widget.allowCounterBilling && widget.isCounterBillingMode));
    final hasOrderContext = widget.tableId != null ||
        (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty) ||
        (widget.allowCounterBilling && widget.isCounterBillingMode);

    if (!hasOrderContext) {
      return Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.table_restaurant,
                  size: widget.isCompact ? 48 : 64,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select a table to start order',
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    widget.isCompact ? FontSize.s14 : FontSize.s16,
                    0.21,
                    const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingOrders || _isLoadingOrderDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      // If the error is about no orders found, show the custom empty state instead
      if (_error!.toLowerCase().contains('no init status orders found') ||
          _error!.toLowerCase().contains('no orders found') ||
          _error!.toLowerCase().contains('no saved orders')) {
        if (isNonTableOrderContext) {
          return _buildCurrentCartView(const []);
        }
        return _buildSavedOrdersList();
      }
      // For other errors, show the error message
      return Center(child: Text('Error: $_error'));
    }

    if (_selectedOrder != null) {
      // Display order details (cart items)
      return _buildOrderDetailsView();
    } else {
      // Display current cart or saved orders
      return Consumer<LocalProductProvider>(
        builder: (context, localProductProvider, _) {
          final cartItems = localProductProvider.getCartItems();
          final hasCurrentCart = cartItems.isNotEmpty;

          if (hasCurrentCart) {
            // Show current cart items
            return _buildCurrentCartView(cartItems);
          } else {
            // No active cart: show pending list (and saved list only for table mode).
            return _buildSavedOrdersList();
          }
        },
      );
    }
  }

  Widget _buildCurrentCartView(List<LocalCartItem> cartItems) {
    // Use LocalProductProvider instead of CartProvider for current cart display
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final total = localProductProvider.cartTotal;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPanelHeader(
            'Current Order',
            Icons.shopping_cart,
            const Color(0xFF059669),
            totalPrice: total,
          ),
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: widget.isCompact ? 36 : 48,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items in current order',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s14 : FontSize.s16,
                              0.21,
                              const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : MouseRegion(
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
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, __) => Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (_, idx) {
                          final item = cartItems[idx];
                          return _buildCurrentCartItem(item, idx);
                        },
                      ),
                    ),
                  ),
          ),
          _buildCurrentCartActionButtons(cartItems),
        ],
      ),
    );
  }

  Widget _buildSavedOrdersList() {
    final isNonTableOrderContext = widget.tableId == null &&
        ((widget.preselectedDeliveryMethodId != null &&
                widget.preselectedDeliveryMethodId!.isNotEmpty) ||
            (widget.allowCounterBilling && widget.isCounterBillingMode));

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pending Orders Section (independent scroll)
          _buildPanelHeader(
              isNonTableOrderContext ? 'Saved Orders' : 'Pending Orders',
              Icons.pending_actions,
              const Color(0xFFD97706),
              itemCount: _localDrafts.length),
          Flexible(
            flex: 1,
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshLocalDrafts();
              },
              child: _localDrafts.isEmpty
                  ? ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.touch,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No pending orders',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    widget.isCompact
                                        ? FontSize.s12
                                        : FontSize.s13,
                                    0.21,
                                    const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : MouseRegion(
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
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                          itemCount: _localDrafts.length,
                          separatorBuilder: (_, __) => Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.grey.shade100,
                          ),
                          itemBuilder: (_, index) =>
                              _buildLocalDraftItem(_localDrafts[index]),
                        ),
                      ),
                    ),
            ),
          ),
          if (!isNonTableOrderContext) ...[
            const SizedBox(height: 8),
            // Saved Orders Section (independent scroll)
            _buildPanelHeader('Saved Orders', Icons.receipt, Colors.blue,
                itemCount: _savedOrders.length),
            Flexible(
              flex: 2,
              child: RefreshIndicator(
                onRefresh: () async {
                  await _fetchSavedOrders();
                  _refreshLocalDrafts();
                },
                child: _savedOrders.isEmpty
                    ? ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      widget.isCompact ? 12 : 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.add_shopping_cart,
                                          size: widget.isCompact ? 36 : 48,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'No orders found',
                                        textAlign: TextAlign.center,
                                        style: buildCustomStyle(
                                            FontWeightManager.bold,
                                            widget.isCompact
                                                ? FontSize.s16
                                                : FontSize.s18,
                                            0.21,
                                            const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add products from the menu\nto start a new order',
                                        textAlign: TextAlign.center,
                                        style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            widget.isCompact
                                                ? FontSize.s13
                                                : FontSize.s14,
                                            0.21,
                                            const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : MouseRegion(
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
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                            itemCount: _savedOrders.length,
                            separatorBuilder: (_, __) => Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              color: Colors.grey.shade100,
                            ),
                            itemBuilder: (context, index) {
                              final order = _savedOrders[index];
                              return _buildOrderListItem(order);
                            },
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderListItem(dynamic order) {
    // Calculate cart item statuses
    List<dynamic> cartItems = [];
    if (order['cart_items'] != null &&
        order['cart_items']['cart_items'] is List) {
      cartItems = order['cart_items']['cart_items'];
    } else if (order['cart_items'] is List) {
      cartItems = order['cart_items'];
    } else if (order['cart'] != null && order['cart']['cart_items'] is List) {
      cartItems = order['cart']['cart_items'];
    }

    int totalItems = cartItems.length;
    int servedItems = cartItems.where((item) {
      if (item is Map<String, dynamic> && item['status'] != null) {
        final status = item['status'].toString().toUpperCase();
        return status == 'SERVED' || status == 'COMPLETED';
      }
      return false;
    }).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _fetchOrderDetails(order), // Pass the entire order object
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${order['order_number']}',
                      style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          widget.isCompact ? FontSize.s13 : FontSize.s15,
                          0.21,
                          const Color(0xFF1E293B)),
                    ),
                  ),
                  Row(
                    children: [
                      // Print KOT button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _printSavedOrderKot(order, cartItems),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.print,
                              size: widget.isCompact ? 16 : 18,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$servedItems/$totalItems',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s11 : FontSize.s13,
                              0.21,
                              const Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (order['orderProps'] != null &&
                      order['orderProps']['TABLE'] != null)
                    Text(
                      order['orderProps']['TABLE']
                          .toString()
                          .replaceAll('"', ''), // Remove quotes if present
                      style: buildCustomStyle(
                          FontWeightManager.medium,
                          widget.isCompact ? FontSize.s11 : FontSize.s13,
                          0.21,
                          const Color(0xFF64748B)),
                    ),
                  Builder(
                    builder: (context) {
                      int itemCount = 0;
                      if (order['cart'] != null &&
                          order['cart']['cart_items'] != null) {
                        itemCount = order['cart']['cart_items'].length;
                      } else if (order['cart_items'] != null &&
                          order['cart_items']['cart_items'] != null) {
                        itemCount = order['cart_items']['cart_items'].length;
                      }

                      return Text(
                        'Items: $itemCount',
                        style: buildCustomStyle(
                            FontWeightManager.medium,
                            widget.isCompact ? FontSize.s11 : FontSize.s13,
                            0.21,
                            const Color(0xFF64748B)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Print KOT for new add-on items and pending cancel queue items.
  Future<void> _printNewKOT() async {
    debugPrint('🖨️ _printNewKOT() called');

    if (_selectedOrder == null) {
      debugPrint('❌ _printNewKOT: No order selected');
      showScaffoldError(
        context: context,
        message: 'Please select an order first',
      );
      return;
    }

    debugPrint(
        '📋 _printNewKOT: Selected order ID: ${_selectedOrder['id'] ?? _selectedOrder['order_id']}');

    // Get all cart items
    List<dynamic> allCartItems = _getCartItemsFromOrder(_selectedOrder);
    debugPrint('📦 _printNewKOT: Total cart items: ${allCartItems.length}');

    // Filter for items where status is null
    List<dynamic> newItems = allCartItems.where((item) {
      if (item is Map<String, dynamic>) {
        final status = item['status'];
        debugPrint(
            '🔍 Item: ${item['product_name'] ?? 'Unknown'}, Status: $status');
        return status == null;
      }
      return false;
    }).toList();

    final pendingCancelQueue =
        await _fetchPendingCancelKotItems(_selectedOrder);

    debugPrint('🆕 _printNewKOT: New items (status=null): ${newItems.length}');
    debugPrint(
        '🚫 _printNewKOT: Pending cancel items: ${pendingCancelQueue.length}');

    if (newItems.isEmpty && pendingCancelQueue.isEmpty) {
      debugPrint('⚠️ _printNewKOT: No pending add-on or cancel KOT items');
      showScaffoldError(
        context: context,
        message: 'No pending KOT items to print',
      );
      return;
    }

    if (newItems.isNotEmpty) {
      // Call API to update status for null items BEFORE printing
      debugPrint(
          '📡 [KOT STATUS UPDATE] ========== STARTING STATUS UPDATE ==========');
      debugPrint(
          '📡 [KOT STATUS UPDATE] Preparing to update ${newItems.length} items to START status');

      try {
        debugPrint('📡 [KOT STATUS UPDATE] Step 1: Getting providers...');
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        debugPrint('📡 [KOT STATUS UPDATE] Step 1: Providers obtained ✅');

        debugPrint('📡 [KOT STATUS UPDATE] Step 2: Parsing order ID...');
        final orderIdValue = _selectedOrder['id'] ?? _selectedOrder['order_id'];
        debugPrint(
            '📡 [KOT STATUS UPDATE] Step 2: order_id value = $orderIdValue');
        final orderId = int.tryParse(orderIdValue.toString());
        final accessToken = authModel.token ?? '';
        debugPrint(
            '📡 [KOT STATUS UPDATE] Step 2: Parsed orderId = $orderId ✅');
        debugPrint(
            '📡 [KOT STATUS UPDATE] Step 2: Access token length = ${accessToken.length} ✅');

        debugPrint('📡 [KOT STATUS UPDATE] Step 3: Checking orderId...');
        if (orderId != null) {
          debugPrint(
              '📡 [KOT STATUS UPDATE] Step 3: Order ID is valid, proceeding to API call...');
          debugPrint(
              '📡 [KOT STATUS UPDATE] API Params: order_id=$orderId, status=START, all=false');

          debugPrint(
              '📡 [KOT STATUS UPDATE] Step 4: Calling updateNullOrderItemsStatus...');
          final response = await cartProvider.updateNullOrderItemsStatus(
            orderId: orderId,
            accessToken: accessToken,
          );

          debugPrint('📡 [KOT STATUS UPDATE] Step 4: API call completed ✅');
          debugPrint('📥 [KOT STATUS UPDATE] Full response: $response');
          debugPrint(
              '📥 [KOT STATUS UPDATE] Response status: ${response['status']}');
          debugPrint(
              '📥 [KOT STATUS UPDATE] Response message: ${response['message'] ?? "No message"}');

          if (response['status'] == 'success') {
            debugPrint(
                '✅ [KOT STATUS UPDATE] SUCCESS! Items updated to START status');
            debugPrint('🔄 [KOT STATUS UPDATE] Refreshing order details...');
            await _refreshSelectedOrderAfterCartUpdate();
            debugPrint('✅ [KOT STATUS UPDATE] Order refresh completed');
          } else {
            debugPrint(
                '⚠️ [KOT STATUS UPDATE] FAILED! Status: ${response['status']}, Message: ${response['message']}');
          }
        } else {
          debugPrint(
              '❌ [KOT STATUS UPDATE] ERROR: Invalid order ID: $orderIdValue');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ [KOT STATUS UPDATE] EXCEPTION: $e');
        debugPrint('❌ [KOT STATUS UPDATE] Stack trace: $stackTrace');
      }

      debugPrint(
          '📡 [KOT STATUS UPDATE] ========== STATUS UPDATE COMPLETE ==========');
    }

    if (newItems.isNotEmpty) {
      debugPrint('🖨️ _printNewKOT: Printing add-on KOT...');
      await _printSavedOrderKot(
        _selectedOrder,
        newItems,
        kotType: 'add_on',
      );
    }

    if (pendingCancelQueue.isNotEmpty) {
      debugPrint('🖨️ _printNewKOT: Printing cancel KOT...');
      final cancelPrintItems = _buildCancelKotPrintItems(pendingCancelQueue);
      await _printSavedOrderKot(
        _selectedOrder,
        cancelPrintItems,
        kotType: 'cancel',
      );
    }
  }

  Future<void> _printNewKOTWithLoading() async {
    if (_isLoadingPrintKot) {
      return;
    }

    setState(() {
      _isLoadingPrintKot = true;
    });

    try {
      await _printNewKOT();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrintKot = false;
        });
      }
    }
  }

  String? _extractTokenNumber(dynamic order) {
    if (order is! Map) return null;

    String? tokenNumber = order['token_number']?.toString();
    if (tokenNumber == null || tokenNumber.isEmpty) {
      final propsMap = order['orderProps'];
      if (propsMap is Map && propsMap['ORDER_TOKEN_NUMBER'] != null) {
        tokenNumber = propsMap['ORDER_TOKEN_NUMBER']?.toString();
      }
    }
    if (tokenNumber == null || tokenNumber.isEmpty) {
      final propsList = order['order_props'];
      if (propsList is List) {
        try {
          final match = propsList.firstWhere(
            (e) =>
                (e is Map) &&
                (e['code'] ?? e['props_code'])?.toString().toUpperCase() ==
                    'ORDER_TOKEN_NUMBER',
            orElse: () => null,
          );
          if (match is Map &&
              (match['value'] ?? match['props_value']) != null) {
            tokenNumber = (match['value'] ?? match['props_value']).toString();
          }
        } catch (_) {}
      }
    }
    if (tokenNumber != null) {
      tokenNumber = tokenNumber.trim();
      if (tokenNumber.startsWith('"') && tokenNumber.endsWith('"')) {
        tokenNumber = tokenNumber.substring(1, tokenNumber.length - 1);
      }
    }

    return tokenNumber;
  }

  String? _resolveDeliveryMethodName(dynamic order) {
    if (order is! Map) return null;

    // Prefer direct API-provided name when available.
    final directName = order['delivery_method_name']?.toString().trim();
    if (directName != null &&
        directName.isNotEmpty &&
        directName.toLowerCase() != 'unknown') {
      return directName;
    }

    final fallbackName = order['delivery_method']?.toString().trim();
    if (fallbackName != null &&
        fallbackName.isNotEmpty &&
        fallbackName.toLowerCase() != 'unknown') {
      return fallbackName;
    }

    // If backend sends only delivery_method_id, resolve using cached provider list.
    final deliveryMethodId = order['delivery_method_id']?.toString().trim();
    if (deliveryMethodId == null ||
        deliveryMethodId.isEmpty ||
        deliveryMethodId.toLowerCase() == 'null') {
      return null;
    }

    try {
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      for (final method in deliveryMethodsProvider.deliveryMethods) {
        if (method.id == deliveryMethodId) {
          return method.name;
        }
      }
    } catch (_) {}

    return null;
  }

  bool _isDeliveryMethodName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') return false;

    try {
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      for (final method in deliveryMethodsProvider.deliveryMethods) {
        if (method.name.trim().toLowerCase() == normalized) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  List<dynamic> _extractPendingCancelKotItems(dynamic order) {
    if (order is! Map<String, dynamic>) {
      return [];
    }

    final directQueue = order['kot_cancel_queue'];
    if (directQueue is List) {
      return List<dynamic>.from(directQueue);
    }

    final propsMap = order['orderProps'];
    if (propsMap is Map && propsMap['KOT_CANCEL_QUEUE'] is List) {
      return List<dynamic>.from(propsMap['KOT_CANCEL_QUEUE']);
    }

    final propsList = order['order_props'];
    if (propsList is List) {
      for (final prop in propsList) {
        if (prop is! Map) continue;
        final code =
            (prop['props_code'] ?? prop['code'])?.toString().toUpperCase();
        if (code != 'KOT_CANCEL_QUEUE') continue;
        final value = prop['props_value'] ?? prop['value'];
        if (value is List) {
          return List<dynamic>.from(value);
        }
      }
    }

    return [];
  }

  Future<List<dynamic>> _fetchPendingCancelKotItems(dynamic order) async {
    final cachedQueue = _extractPendingCancelKotItems(order);
    if (cachedQueue.isNotEmpty) {
      return cachedQueue;
    }

    final orderIdValue = order['id'] ?? order['order_id'];
    final orderId = orderIdValue?.toString();
    if (orderId == null || orderId.isEmpty) {
      return [];
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final response = await cartProvider.getListOrderDetails(
        accessToken: authModel.token ?? '',
        orderId: orderId,
      );

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final orderDetails = response['order_details'];
        if (orderDetails is Map<String, dynamic>) {
          return _extractPendingCancelKotItems(orderDetails);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch pending cancel KOT items: $e');
    }

    return [];
  }

  double _parseKotQuantity(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatKotQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(3);
  }

  List<dynamic> _buildCancelKotPrintItems(List<dynamic> cancelQueueItems) {
    final groupedItems = <String, Map<String, dynamic>>{};

    for (final item in cancelQueueItems) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final productId = item['product_id']?.toString() ?? '';
      final productName = item['product_name']?.toString() ?? 'Unknown';
      final comment = item['comment']?.toString() ?? '';
      final variantKey = json.encode(item['variant_attributes']);
      final unitPrice = item['unit_price']?.toString() ?? '';
      final key =
          [productId, productName, comment, variantKey, unitPrice].join('|');

      final quantity =
          _parseKotQuantity(item['cancel_qty'] ?? item['quantity'] ?? 1);
      final eventId = item['event_id']?.toString();

      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = {
          ...item,
          'quantity': quantity,
          'product_name': 'CANCEL - $productName',
          'event_ids':
              eventId != null && eventId.isNotEmpty ? [eventId] : <String>[],
        };
        continue;
      }

      final existing = groupedItems[key]!;
      existing['quantity'] = _parseKotQuantity(existing['quantity']) + quantity;

      final existingEventIds =
          List<String>.from(existing['event_ids'] ?? const <String>[]);
      if (eventId != null &&
          eventId.isNotEmpty &&
          !existingEventIds.contains(eventId)) {
        existingEventIds.add(eventId);
      }
      existing['event_ids'] = existingEventIds;
    }

    return groupedItems.values.map((item) {
      final totalQuantity = _parseKotQuantity(item['quantity']);
      return {
        ...item,
        'quantity': _formatKotQuantity(totalQuantity),
      };
    }).toList();
  }

  List<String> _extractKotEventIds(List<dynamic> cartItems) {
    final eventIds = <String>[];
    final seenEventIds = <String>{};

    for (final item in cartItems) {
      if (item is! Map<String, dynamic>) continue;

      final rawEventId = item['event_id']?.toString().trim();
      if (rawEventId != null && rawEventId.isNotEmpty) {
        if (seenEventIds.add(rawEventId)) {
          eventIds.add(rawEventId);
        }
      }

      final groupedEventIds = item['event_ids'];
      if (groupedEventIds is List) {
        for (final groupedEventId in groupedEventIds) {
          final normalizedId = groupedEventId?.toString().trim();
          if (normalizedId == null || normalizedId.isEmpty) continue;
          if (seenEventIds.add(normalizedId)) {
            eventIds.add(normalizedId);
          }
        }
      }
    }

    return eventIds;
  }

  void _removeAcknowledgedKotEventsFromOrderCache({
    required dynamic order,
    required List<String> eventIds,
  }) {
    if (order is! Map<String, dynamic> || eventIds.isEmpty) {
      return;
    }

    List<dynamic> filterQueue(List<dynamic> queue) {
      return queue.where((entry) {
        if (entry is! Map) return true;
        final eventId = entry['event_id']?.toString();
        return eventId == null || !eventIds.contains(eventId);
      }).toList();
    }

    if (order['kot_cancel_queue'] is List) {
      order['kot_cancel_queue'] = filterQueue(order['kot_cancel_queue']);
    }

    final propsMap = order['orderProps'];
    if (propsMap is Map && propsMap['KOT_CANCEL_QUEUE'] is List) {
      propsMap['KOT_CANCEL_QUEUE'] = filterQueue(propsMap['KOT_CANCEL_QUEUE']);
    }

    final propsList = order['order_props'];
    if (propsList is List) {
      for (final prop in propsList) {
        if (prop is! Map) continue;
        final code =
            (prop['props_code'] ?? prop['code'])?.toString().toUpperCase();
        if (code != 'KOT_CANCEL_QUEUE') continue;
        final valueKey =
            prop.containsKey('props_value') ? 'props_value' : 'value';
        if (prop[valueKey] is List) {
          prop[valueKey] = filterQueue(prop[valueKey]);
        }
      }
    }

    if (!mounted) return;

    final currentOrderId = _selectedOrder?['id'] ?? _selectedOrder?['order_id'];
    final updatedOrderId = order['id'] ?? order['order_id'];
    if (currentOrderId == updatedOrderId) {
      setState(() {
        _selectedOrder = order;
      });
    }
  }

  Future<void> _acknowledgeKotPrintIfNeeded({
    required dynamic order,
    required List<String> eventIds,
  }) async {
    if (eventIds.isEmpty) {
      return;
    }

    final orderIdValue = order['id'] ?? order['order_id'];
    final orderId = int.tryParse(orderIdValue?.toString() ?? '');
    if (orderId == null) {
      debugPrint('⚠️ acknowledgeKotPrint skipped: invalid order ID');
      return;
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final response = await cartProvider.acknowledgeKotPrint(
      orderId: orderId,
      eventIds: eventIds,
      accessToken: authModel.token ?? '',
    );

    if (!mounted) return;

    final status = (response['status'] as String?)?.toLowerCase();
    if (status == 'success' || status == 'sucesss') {
      debugPrint('✅ KOT print acknowledged for events: $eventIds');
      _removeAcknowledgedKotEventsFromOrderCache(
        order: order,
        eventIds: eventIds,
      );
      Future.microtask(_refreshSavedOrdersSilently);
      return;
    }

    final message = response['message']?.toString() ??
        'KOT printed, but failed to acknowledge printed cancel events';
    debugPrint('❌ KOT print acknowledge failed: $message');
    showScaffoldError(
      context: context,
      message: message,
    );
  }

  // Print KOT for a saved order
  Future<void> _printSavedOrderKot(
    dynamic order,
    List<dynamic> cartItems, {
    String kotType = 'standard',
  }) async {
    debugPrint(
        '🖨️ _printSavedOrderKot() called with ${cartItems.length} items');

    // Get order number
    final orderNumber = order['order_number']?.toString() ?? 'Unknown';
    final tokenNumber = _extractTokenNumber(order);

    // Get table name
    String tableName = 'Unknown';
    bool showTableLabel = true;
    try {
      if (order['orderProps'] != null && order['orderProps']['TABLE'] != null) {
        tableName = order['orderProps']['TABLE'].toString().replaceAll('"', '');
      } else if (order['table'] != null) {
        final t = order['table'];
        if (t is Map && t['name'] != null) {
          tableName = t['name'].toString();
        } else if (t is String) {
          tableName = t;
        }
      }
    } catch (_) {}

    // For non-table orders, print delivery method details instead of table label.
    if (_isDeliveryMethodName(tableName)) {
      showTableLabel = false;
    }

    if (tableName.trim().isEmpty || tableName.toLowerCase() == 'unknown') {
      final deliveryMethodName = _resolveDeliveryMethodName(order);
      if (deliveryMethodName != null && deliveryMethodName.isNotEmpty) {
        tableName = 'Delivery Method: $deliveryMethodName';
        showTableLabel = false;
      } else {
        tableName = 'Order';
        showTableLabel = false;
      }
    }

    // Get current time
    final orderTime = DateHelper.getCurrentFormattedTimeWithAMPM();
    final kotEventIds = _extractKotEventIds(cartItems);

    // Build items list for KOT
    List<Map<String, dynamic>> printItems = [];
    for (var item in cartItems) {
      String productName = 'Unknown';
      String quantity = '1';
      String unitPrice = '0.00';
      String mrp = '0.00';
      String? itemNotes;

      if (item is Map<String, dynamic>) {
        // Try different keys for product name
        if (item['product'] != null &&
            item['product']['product_name'] != null) {
          productName = item['product']['product_name'].toString();
        } else if (item['product_name'] != null) {
          productName = item['product_name'].toString();
        } else if (item['name'] != null) {
          productName = item['name'].toString();
        }

        // Get quantity
        quantity = (item['quantity'] ?? item['cancel_qty'] ?? item['qty'] ?? 1)
            .toString();

        // Get Price and MRP
        double priceVal = double.tryParse((item['unit_price'] ??
                    item['price'] ??
                    item['product_price'] ??
                    0)
                .toString()) ??
            0.0;
        unitPrice = priceVal.toStringAsFixed(2);

        double mrpVal =
            double.tryParse((item['mrp'] ?? priceVal).toString()) ?? priceVal;
        mrp = mrpVal.toStringAsFixed(2);

        // Extract item-level notes/comments
        itemNotes = item['notes']?.toString();
        if (itemNotes == null || itemNotes.isEmpty) {
          itemNotes = item['comment']?.toString();
        }
        if (itemNotes == null || itemNotes.isEmpty) {
          final props = item['order_item_props'];
          if (props is List) {
            try {
              final noteProp = props.firstWhere(
                (p) =>
                    p is Map &&
                    p['code'] != null &&
                    (p['code'].toString().toUpperCase() == 'NOTES' ||
                        p['code'].toString().toUpperCase() == 'COMMENT'),
                orElse: () => null,
              );
              if (noteProp != null) {
                itemNotes = noteProp['value']?.toString();
              }
            } catch (_) {}
          }
        }

        if (itemNotes != null) {
          itemNotes = itemNotes.trim();
          if (itemNotes.startsWith('"') && itemNotes.endsWith('"')) {
            itemNotes = itemNotes.substring(1, itemNotes.length - 1);
          }
        }
      }

      printItems.add({
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'mrp': mrp,
        'rate': unitPrice,
        'notes': itemNotes, // Pass item notes
      });
    }

    // Get comment using robust extraction logic
    String? comment = order['comment']?.toString();
    comment ??= order['order_comment']?.toString();

    // From nested map: orderProps: { COMMENT: "..." }
    if (comment == null || comment.isEmpty) {
      final propsMap = order['orderProps'];
      if (propsMap is Map && propsMap['COMMENT'] != null) {
        comment = propsMap['COMMENT']?.toString();
      }
    }

    // From array: order_props: [{ code: COMMENT, value: "..." }]
    if (comment == null || comment.isEmpty) {
      final propsList = order['order_props'];
      if (propsList is List) {
        try {
          final match = propsList.firstWhere(
            (e) =>
                (e is Map) &&
                (e['code'] != null &&
                    e['code'].toString().toUpperCase() == 'COMMENT'),
            orElse: () => null,
          );
          if (match is Map && match['value'] != null) {
            comment = match['value']?.toString();
          }
        } catch (_) {}
      }
    }

    // Normalize: strip surrounding quotes
    if (comment != null) {
      comment = comment.trim();
      if (comment.startsWith('"') && comment.endsWith('"')) {
        comment = comment.substring(1, comment.length - 1);
      }
    }

    // Check if KOT print is enabled in app settings
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final enableKOTPrint =
        appSettingsProvider.appSettings?.enableKOTPrint ?? true;
    debugPrint('⚙️ _printSavedOrderKot: enableKOTPrint = $enableKOTPrint');

    if (enableKOTPrint) {
      debugPrint('🖨️ _printSavedOrderKot: Trying auto-print first');
      debugPrint(
          '📋 Order Number: $orderNumber, Table: $tableName, Items: ${printItems.length}');

      // Try auto-print with default printer first
      final success = await KotPrintPage.autoPrint(
        context,
        orderNumber: orderNumber,
        tokenNumber: tokenNumber,
        tableName: tableName,
        showTableLabel: showTableLabel,
        orderTime: orderTime,
        items: printItems,
        comment: comment,
        kotType: kotType,
        onPrintSuccess: kotEventIds.isEmpty
            ? null
            : () => _acknowledgeKotPrintIfNeeded(
                  order: order,
                  eventIds: kotEventIds,
                ),
      );

      // Only show print page if auto-print failed
      if (!success && mounted) {
        debugPrint(
            '🖨️ _printSavedOrderKot: Auto-print failed, showing print page');
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => KotPrintPage(
              orderNumber: orderNumber,
              tokenNumber: tokenNumber,
              tableName: tableName,
              showTableLabel: showTableLabel,
              orderTime: orderTime,
              items: printItems,
              comment: comment,
              kotType: kotType,
              onPrintSuccess: kotEventIds.isEmpty
                  ? null
                  : () => _acknowledgeKotPrintIfNeeded(
                        order: order,
                        eventIds: kotEventIds,
                      ),
            ),
          ),
        );
      }
    } else {
      debugPrint(
          '⚠️ _printSavedOrderKot: KOT printing is disabled in app settings');
      showScaffoldError(
        context: context,
        message: 'KOT printing is disabled in settings',
      );
    }
  }

  Color _statusColor(String? status) {
    // Normalize against kitchen_master ItemStatus colors
    // pending -> amber, preparing -> blue, ready -> green, served -> gray
    final s = (status ?? '').toUpperCase();
    switch (s) {
      case 'PENDING':
      case 'INIT':
      case 'NEW':
        return const Color(0xFFD97706); // amber
      case 'START':
      case 'PREPARING':
      case 'COOKING':
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB); // blue
      case 'READY':
        return const Color(0xFF059669); // green
      case 'SERVED':
      case 'COMPLETED':
        return const Color(0xFF6B7280); // gray
      case 'CANCELLED':
        return const Color(0xFFDC2626); // red (extra)
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusTextForDisplay(String? status) {
    final s = (status ?? '').toUpperCase();
    switch (s) {
      case 'PENDING':
      case 'INIT':
      case 'NEW':
        return 'NEW';
      case 'START':
      case 'PREPARING':
      case 'COOKING':
      case 'IN_PROGRESS':
        return 'STARTED';
      case 'READY':
        return 'READY';
      case 'SERVED':
      case 'COMPLETED':
        return 'SERVED';
      case 'CANCELLED':
        return 'CANCELLED';
      default:
        return s.isEmpty ? 'NEW' : s;
    }
  }

  Widget _buildOrderDetailsView() {
    // Get cart items from the saved order using helper
    List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);

    // Calculate current total from cart items (dynamic calculation)
    double total = 0.0;
    for (var item in cartItems) {
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      final unitPrice = double.tryParse(item['unit_price']?.toString() ??
              item['price']?.toString() ??
              item['product_price']?.toString() ??
              '0') ??
          0.0;
      total += quantity * unitPrice;
    }

    // If we still have zero total, try getting it from order total as fallback
    if (total == 0.0 && _selectedOrder['grand_total'] != null) {
      total =
          double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
              0.0;
    }

    debugPrint(
        '📊 Cart items count: ${cartItems.length}, Total: ${total.toStringAsFixed(2)}');

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPanelHeader(
            _selectedOrder['order_number'] != null
                ? 'Edit Order - ${_selectedOrder['order_number']}'
                : 'Edit Order',
            Icons.shopping_cart,
            const Color(0xFFD97706),
            showBackButton: true,
            onBackButtonPressed: () {
              setState(() {
                _selectedOrder = null;
                // Re-apply default customer when returning to current cart
                _applyDefaultCustomer();
              });
              widget.onOrderSelected(null);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _refreshSelectedOrderAfterCartUpdate();
              },
              child: cartItems.isEmpty
                  ? ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.touch,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF64748B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.shopping_cart_outlined,
                                  size: widget.isCompact ? 36 : 48,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No items in this order',
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    widget.isCompact
                                        ? FontSize.s14
                                        : FontSize.s16,
                                    0.21,
                                    const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : MouseRegion(
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
                        child: ListView.separated(
                          controller: _editOrderScrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                          itemCount: cartItems.length,
                          separatorBuilder: (_, __) => Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.grey.shade100,
                          ),
                          itemBuilder: (_, idx) {
                            final item = cartItems[idx];
                            return _buildSavedOrderItem(item, idx);
                          },
                        ),
                      ),
                    ),
            ),
          ),
          _buildSavedOrderActionButtons(cartItems),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(String title, IconData icon, Color color,
      {bool showBackButton = false,
      VoidCallback? onBackButtonPressed,
      double? totalPrice,
      int? itemCount,
      String? subtitle}) {
    return Container(
      padding: showBackButton
          ? const EdgeInsets.fromLTRB(0, 10, 12, 10)
          : EdgeInsets.all(widget.isCompact ? 10.0 : 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.05),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
              onPressed: onBackButtonPressed,
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: widget.isCompact ? 14 : 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      widget.isCompact ? FontSize.s14 : FontSize.s16,
                      0.30,
                      const Color(0xFF1E293B)),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        widget.isCompact ? FontSize.s11 : FontSize.s12,
                        0.21,
                        const Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          if (totalPrice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${totalPrice.toStringAsFixed(0)}',
                style: buildCustomStyle(
                    FontWeightManager.bold,
                    widget.isCompact ? FontSize.s14 : FontSize.s16,
                    0.23,
                    const Color(0xFF059669)),
              ),
            ),
          if (itemCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$itemCount',
                style: buildCustomStyle(
                    FontWeightManager.semiBold, FontSize.s12, 0.21, color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedOrderActionButtons(List<dynamic> cartItems) {
    final allItemsServed = cartItems.isNotEmpty &&
        cartItems.every((item) {
          if (item is Map<String, dynamic> && item['status'] != null) {
            final status = item['status'].toString().toUpperCase();
            return status == 'SERVED' || status == 'COMPLETED';
          }
          return false;
        });

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade100,
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // New Compact Summary
            _buildCompactOneLineSummary(),
            const SizedBox(height: 12),
            // Row: Print KOT and Confirm buttons
            Row(
              children: [
                // 1. Print KOT Button (Left Side)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          _isLoadingPrintKot ? null : _printNewKOTWithLoading,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: _isLoadingPrintKot
                              ? const Color(0xFFFFF7ED)
                              : Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isLoadingPrintKot
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 20,
                                  height: widget.isCompact ? 16 : 20,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD97706),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: const Color(0xFFD97706),
                                      size: widget.isCompact ? 16 : 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Print KOT',
                                      style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          widget.isCompact
                                              ? FontSize.s13
                                              : FontSize.s14,
                                          0.21,
                                          const Color(0xFFD97706)),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Confirm or Mark Served Button (Right Side)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: cartItems.isEmpty
                          ? null
                          : allItemsServed
                              ? (_isLoadingConfirm
                                  ? null
                                  : () => _showCheckoutModal())
                              : (_isMarkingServed
                                  ? null
                                  : () => _markAllOrderItemsServed()),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: cartItems.isEmpty
                              ? const Color(0xFF94A3B8)
                              : allItemsServed
                                  ? (_isLoadingConfirm
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF2563EB))
                                  : (_isMarkingServed
                                      ? const Color(0xFF94A3B8)
                                      : const Color(
                                          0xFF059669)), // Green for Mark Served
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: cartItems.isNotEmpty &&
                                  !_isLoadingConfirm &&
                                  !_isMarkingServed
                              ? [
                                  BoxShadow(
                                    color: (allItemsServed
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF059669))
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: (_isLoadingConfirm || _isMarkingServed)
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 20,
                                  height: widget.isCompact ? 16 : 20,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      allItemsServed
                                          ? Icons.check_circle
                                          : Icons.room_service,
                                      color: Colors.white,
                                      size: widget.isCompact ? 16 : 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      allItemsServed
                                          ? 'Confirm'
                                          : 'Mark Served',
                                      style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          widget.isCompact
                                              ? FontSize.s13
                                              : FontSize.s14,
                                          0.21,
                                          Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showCommentDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: widget.isCompact ? 44 : 48,
                      height: widget.isCompact ? 44 : 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: widget.isCompact ? 18 : 20,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOneLineSummary() {
    if (_selectedOrder == null) return const SizedBox.shrink();

    // Calculate totals (reuse logic from _buildPaymentSummary logic or similar)
    List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);
    double orderTotal = 0.0;
    for (var item in cartItems) {
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      final unitPrice = double.tryParse(item['unit_price']?.toString() ??
              item['price']?.toString() ??
              item['product_price']?.toString() ??
              '0') ??
          0.0;
      orderTotal += quantity * unitPrice;
    }
    if (orderTotal == 0.0 && _selectedOrder['grand_total'] != null) {
      orderTotal =
          double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
              0.0;
    }

    // Apply discounts
    double totalDiscountAmount =
        _flatDiscount + (orderTotal * _percentageDiscount / 100);
    double finalOrderTotal =
        (orderTotal - totalDiscountAmount) + _getDeliveryChargeForOrder();

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(
            'Net Amount',
            '$currency ${finalOrderTotal.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFFE4E4ED)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total Payable',
            '$currency ${finalOrderTotal.toStringAsFixed(2)}',
            color: const Color(0xFF3B82F6),
            isBold: true,
            large: true,
          ),
          _buildSummaryRow(
            'Total Paid',
            '$currency 0.00',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'Balance',
            '$currency ${finalOrderTotal.toStringAsFixed(2)}',
            color: const Color(0xFF00C739),
            isBold: true,
          ),
        ],
      ),
    );
  }

  String? _extractOrderLevelComment(dynamic order) {
    if (order is! Map) return null;

    String? comment = order['comment']?.toString();
    comment ??= order['order_comment']?.toString();

    if (comment == null || comment.isEmpty) {
      final propsMap = order['orderProps'];
      if (propsMap is Map && propsMap['COMMENT'] != null) {
        comment = propsMap['COMMENT']?.toString();
      }
    }

    if (comment == null || comment.isEmpty) {
      final propsList = order['order_props'];
      if (propsList is List) {
        try {
          final match = propsList.firstWhere(
            (e) =>
                (e is Map) &&
                (((e['code'] ?? e['props_code'])?.toString().toUpperCase() ??
                        '') ==
                    'COMMENT'),
            orElse: () => null,
          );
          if (match is Map &&
              (match['value'] ?? match['props_value']) != null) {
            comment = (match['value'] ?? match['props_value']).toString();
          }
        } catch (_) {}
      }
    }

    if (comment != null) {
      comment = comment.trim();
      if (comment.startsWith('"') && comment.endsWith('"')) {
        comment = comment.substring(1, comment.length - 1);
      }
    }

    return (comment == null || comment.isEmpty) ? null : comment;
  }

  void _showCheckoutModal({bool forCurrentCart = false}) {
    // Release any current focus so checkout modal text fields receive input cleanly.
    FocusManager.instance.primaryFocus?.unfocus();

    // Rehydrate latest cached customers before opening checkout so default
    // customer auto-selection is applied when data is already available.
    _hydrateCustomerListFromProviderCache();

    // Mark that payment modal opportunity has been given (via checkout dialog)
    setState(() {
      _hasOpenedPaymentModalOnce = false;
    });

    if (!mounted) return;

    // Sync LocalProductProvider cart with saved-order items only when confirming
    // an existing kitchen order. Current-cart checkout already uses that cart.
    if (!forCurrentCart) {
      _syncOrderItemsWithLocalCart();
    }

    // Keep checkout modal launch instant: do not block on payment-method API.
    // BillingProvider IDs will use already-cached values and can be refreshed
    // later by existing background/bootstrap flows if needed.

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.cartTotal; // Refresh priceSummary before modal totals.
    final checkoutCartTotal = forCurrentCart
        ? (localProductProvider.priceSummary?.subTotal ??
            localProductProvider.cartTotal)
        : _calculateOrderTotal();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final deliveryMethodsProvider =
            Provider.of<DeliveryMethodsProvider>(context, listen: false);
        final deliveryEnabled =
            deliveryMethodsProvider.deliveryMethods.isNotEmpty;

        return CheckoutModal(
          cartTotal: checkoutCartTotal,
          availableCustomers: _customers,
          selectedCustomer: _selectedCustomer,
          hasOpenedPaymentModalOnce: _hasOpenedPaymentModalOnce,

          // Delivery State
          enableDelivery: deliveryEnabled,
          deliveryMethod:
              _deliveryMethod.isNotEmpty ? _deliveryMethod : "Store Takeaway",
          deliveryMethodId: _deliveryMethodId.isNotEmpty
              ? _deliveryMethodId
              : _getDefaultDeliveryMethodId(),
          deliveryComment: _orderComment,
          deliveryAddress: _deliveryAddress,
          deliveryDate: _deliveryDate,
          deliveryTime: _deliveryTime,
          initialDeliveryCharge: _selectedDeliveryCharge ?? 0.0,
          onDeliveryUpdated:
              (method, methodId, carNo, comment, date, time, address) {
            setState(() {
              _deliveryMethod = method;
              _deliveryMethodId = methodId;
              _orderComment = comment;
              _deliveryDate = date;
              _deliveryTime = time;
              _deliveryAddress = address;
            });
          },
          onDeliveryChargeUpdated: (deliveryCharge) {
            setState(() {
              _selectedDeliveryCharge = deliveryCharge;
            });
          },

          // Payment State
          isCashSelected: _isCashSelected,
          isCardSelected: _isCardSelected,
          isUpiSelected: _isUpiSelected,
          isCodSelected: _isCodSelected,
          isDebitSelected: _isDebitSelected,
          cashAmount: _cashAmount,
          cardAmount: _cardAmount,
          upiAmount: _upiAmount,
          codAmount: _codAmount,
          debitAmount: _debitAmount,
          transactionNumber: _transactionNumber,
          toCustomerCreditEnabled: _toCustomerCreditEnabled,
          toCustomerCreditAmount: _toCustomerCreditAmount,

          // Discount State
          couponCode: _couponCode,
          flatDiscount: _flatDiscount,
          percentageDiscount: _percentageDiscount,
          isCouponApplied: _isCouponApplied,

          onCustomerSelected: (customer) {
            setState(() {
              _selectedCustomer = customer;
              _selectedCustomerID = customer.id;
              _selectedCustomerPhone = customer.phone;
              _isCustomerManuallySelected = true;
            });
            // Also update the global provider
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .setSelectedCustomer(customer);
          },
          onAddNewCustomer: (String searchQuery) async {
            // NOTE: Do not close the checkout dialog here. We will return the result.

            // Pass numeric search input as-is (including partial phone numbers)
            String phoneToPreFill = '';
            final normalizedSearchQuery = searchQuery.trim();
            if (normalizedSearchQuery.isNotEmpty &&
                RegExp(r'^[0-9]+$').hasMatch(normalizedSearchQuery)) {
              phoneToPreFill = normalizedSearchQuery;
            }
            final result = await showAddCustomerModal(
                context, MediaQuery.of(context).size,
                mobileNumber: phoneToPreFill);

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

              // Fast path: construct customer from add API response without full refetch
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
                  _customers.removeWhere((customer) =>
                      customer.id == createdCustomer.id ||
                      (customer.phone != null &&
                          customer.phone == createdCustomer.phone));
                  _customers.insert(0, createdCustomer);
                  _selectedCustomer = createdCustomer;
                  _selectedCustomerID = createdCustomer.id;
                  _selectedCustomerPhone = createdCustomer.phone;
                });

                return createdCustomer;
              }

              // Fallback: refresh provider cache and match by normalized phone
              final authModel = Provider.of<AuthModel>(context, listen: false);
              final customerProvider =
                  Provider.of<CustomerProvider>(context, listen: false);
              await customerProvider.fetchCustomers(
                accessToken: authModel.token ?? '',
                listAll: true,
              );
              if (!mounted) return null;
              _hydrateCustomerListFromProviderCache();
              final addedPhone = result['phone'];
              final normalizedAddedPhone =
                  addedPhone?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
                      '';

              if (normalizedAddedPhone.isNotEmpty) {
                final matchingCustomer = _customers.firstWhere(
                  (customer) {
                    final customerPhone =
                        customer.phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    return customerPhone == normalizedAddedPhone;
                  },
                  orElse: () => CustomerListModelData(),
                );

                if (matchingCustomer.id != null) {
                  setState(() {
                    _selectedCustomer = matchingCustomer;
                    _selectedCustomerID = matchingCustomer.id;
                    _selectedCustomerPhone = matchingCustomer.phone;
                  });
                  return matchingCustomer;
                }
              }
            }
            return null;
          },
          onDiscountApplied: (code, isApplied, flat, percent) {
            setState(() {
              _couponCode = code;
              _isCouponApplied = isApplied;
              _flatDiscount = flat;
              _percentageDiscount = percent;

              if (!isApplied) {
                _couponCode = "";
                _flatDiscount = 0.0;
                _percentageDiscount = 0.0;
              }
            });

            // Also update LocalProductProvider so the summary reflects the discount
            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);
            localProductProvider.applyDiscount(
              flatDiscount: _flatDiscount,
              percentageDiscount: _percentageDiscount,
            );
          },
          onPaymentUpdated: (isCash, isCard, isUpi, isCod, isDebit, cash, card,
              upi, cod, debit, trans, toCredit,
              {cashMethodId, cardMethodId, upiMethodId, codMethodId}) {
            setState(() {
              _isCashSelected = isCash;
              _isCardSelected = isCard;
              _isUpiSelected = isUpi;
              _isCodSelected = isCod;
              _isDebitSelected = isDebit;
              _cashAmount = cash;
              _cardAmount = card;
              _upiAmount = upi;
              _codAmount = cod;
              _debitAmount = debit;
              _transactionNumber = trans;
              _toCustomerCreditEnabled = toCredit;
              _toCustomerCreditAmount = double.tryParse(debit) ??
                  0.0; // Correctly update credit amount
              _hasOpenedPaymentModalOnce = true;
            });

            // Update provider
            final billingProvider =
                Provider.of<BillingProvider>(context, listen: false);
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
                codMethodId: codMethodId);
          },
          onConfirmOrder: () async {
            setState(() {
              _hasOpenedPaymentModalOnce = true;
              _isProcessingCheckout = true;
            });
            Navigator.of(dialogContext).pop();
            try {
              if (forCurrentCart) {
                await _confirmCurrentCart(printBill: false);
              } else {
                await _confirmOrder();
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isProcessingCheckout = false;
                });
              }
            }
          },
          onConfirmAndPrint: () async {
            setState(() {
              _hasOpenedPaymentModalOnce = true;
              _isProcessingCheckout = true;
            });
            Navigator.of(dialogContext).pop();
            try {
              if (forCurrentCart) {
                await _confirmCurrentCart(printBill: true);
              } else {
                await _confirmOrderAndPrintBill();
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isProcessingCheckout = false;
                });
              }
            }
          },
        );
      },
    );
  }

  double _calculateOrderTotal() {
    if (_selectedOrder == null) {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      return localProductProvider.cartTotal;
    }
    List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);
    double total = 0.0;
    for (var item in cartItems) {
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      final unitPrice = double.tryParse(item['unit_price']?.toString() ??
              item['price']?.toString() ??
              item['product_price']?.toString() ??
              '0') ??
          0.0;
      total += quantity * unitPrice;
    }
    if (total == 0.0 && _selectedOrder['grand_total'] != null) {
      total =
          double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
              0.0;
    }
    return total;
  }

  /// Syncs the order items with LocalProductProvider's cart
  /// This ensures the checkout modal shows correct totals based on order items
  void _syncOrderItemsWithLocalCart() {
    if (_selectedOrder == null) return;

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final List<dynamic> orderItems = _getCartItemsFromOrder(_selectedOrder);

      debugPrint('🔄 Syncing order items with LocalProductProvider cart...');
      debugPrint('   Order items count: ${orderItems.length}');

      // Clear the current cart first
      localProductProvider.clearCart();

      // Add each order item to the cart
      for (var item in orderItems) {
        final productId = int.tryParse(item['product_id']?.toString() ?? '0');
        if (productId == null || productId == 0) continue;

        // Find the product in the product list
        GetProduct? product;
        try {
          product = localProductProvider.products.firstWhere(
            (p) => p.productId == productId,
          );
        } catch (_) {
          debugPrint('⚠️ Product $productId not found in product list');
          continue;
        }

        if (product == null) continue;

        final quantity =
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        final unitPrice = double.tryParse(item['unit_price']?.toString() ??
                item['price']?.toString() ??
                item['product_price']?.toString() ??
                '0') ??
            0.0;

        // Find the stock entry if available
        Stock? selectedStock;
        if (item['stock_id'] != null) {
          final stockId = int.tryParse(item['stock_id'].toString());
          if (stockId != null && product.stock != null) {
            try {
              selectedStock = product.stock!.firstWhere((s) => s.id == stockId);
            } catch (_) {
              // Stock not found, use null
            }
          }
        }

        // Add to cart with the order's price and quantity
        localProductProvider.addToCart(
          product: product,
          quantity: quantity.toInt(),
          price: unitPrice > 0 ? unitPrice : null,
          selectedStock: selectedStock,
        );

        debugPrint(
            '   ✓ Added: ${product.productName} (Qty: $quantity, Price: $unitPrice)');
      }

      // Apply discounts from the order
      localProductProvider.applyDiscount(
        flatDiscount: _flatDiscount,
        percentageDiscount: _percentageDiscount,
      );

      debugPrint('✅ Order items synced with LocalProductProvider cart');
    } catch (e) {
      debugPrint('❌ Error syncing order items with cart: $e');
    }
  }

  // Wrapper method for quantity updates with loading state
  Future<void> _updateCartItemQuantityWithLoading(
      dynamic cartItem, double newQuantity, String action) async {
    final loadingKey = '${cartItem['id']}_$action';

    setState(() {
      _loadingCartItems.add(loadingKey);
    });

    try {
      await _updateCartItemQuantity(cartItem, newQuantity);
    } finally {
      if (mounted) {
        setState(() {
          _loadingCartItems.remove(loadingKey);
        });
      }
    }
  }

  // Wrapper method for cart item removal with loading state
  Future<void> _removeCartItemWithLoading(dynamic cartItem) async {
    final loadingKey = '${cartItem['id']}_remove';

    setState(() {
      _loadingCartItems.add(loadingKey);
    });

    try {
      await _removeCartItem(cartItem);
    } finally {
      if (mounted) {
        setState(() {
          _loadingCartItems.remove(loadingKey);
        });
      }
    }
  }

  Future<void> _updateCartItemQuantity(
      dynamic cartItem, double newQuantity) async {
    final currentQuantity =
        double.tryParse(cartItem['quantity'].toString()) ?? 0.0;

    if (newQuantity < 0) {
      // Don't allow negative quantities
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get customer ID from the order data (same logic as add menu item)
      final customerId = _selectedOrder['cart']?['customer_id'] ??
          _selectedOrder['customer_id'] ??
          1;
      final orderCartId = int.tryParse(
          (_selectedOrder['cart']?['id'] ?? _selectedOrder['cart_id'])
                  ?.toString() ??
              '');

      dynamic response;

      if (newQuantity > currentQuantity) {
        // Increment quantity - use addToCartAPI
        final deltaQuantity = (newQuantity - currentQuantity).toInt();
        final productId =
            cartItem['product_id']; // Assuming product_id is available
        final unitPrice = cartItem['unit_price']?.toString();

        if (productId == null) {
          showScaffoldError(
              context: context, message: 'Product ID not found for item.');
          return;
        }

        debugPrint('➡️ Calling CartProvider.addToCartAPI for increment');
        debugPrint(
            '📦 addToCartAPI Request Body: {customerId: $customerId, productId: $productId, quantity: $deltaQuantity, unitPrice: $unitPrice, cartId: $orderCartId}');
        debugPrint('🔍 Customer ID source: _selectedOrder data structure');

        response = await cartProvider.addToCartAPI(
          customerId: int.parse(customerId.toString()),
          productId: int.parse(productId.toString()),
          quantity: deltaQuantity,
          unitPrice: unitPrice,
          accessToken: authModel.token ?? '',
          cartId: orderCartId,
        );
        debugPrint('✅ addToCartAPI Response: $response');
      } else if (newQuantity <= currentQuantity) {
        // Decrement quantity or remove item (including 0) - use decrementCartItemQuantityAPI
        String actionType =
            newQuantity == 0 ? 'remove (set to 0)' : 'decrement';
        debugPrint(
            '➡️ Calling CartProvider.decrementCartItemQuantityAPI for $actionType');
        debugPrint(
            '📦 decrementCartItemQuantityAPI Request Body: {customerId: $customerId, cartItemId: ${cartItem['id']}, quantity: ${newQuantity.toInt()}, cartId: $orderCartId}');
        debugPrint('🔍 Customer ID source: _selectedOrder data structure');

        response = await cartProvider.decrementCartItemQuantityAPI(
          customerId: int.parse(customerId.toString()),
          productId:
              int.parse(cartItem['id'].toString()), // This is cart_item_id
          cartId: orderCartId,
          quantity: newQuantity.toInt(), // Can be 0 for removal
          accessToken: authModel.token ?? '',
        );
        debugPrint('✅ decrementCartItemQuantityAPI Response: $response');
      } else {
        // Quantity is the same, no action needed
        debugPrint(
            'Quantity is already ${newQuantity.toInt()}. No API call needed.');
        return;
      }

      // Update the UI optimistically first
      setState(() {
        // Find and update the cart item in the selected order
        List<dynamic> cartItemsList;
        if (_selectedOrder['cart'] != null &&
            _selectedOrder['cart']['cart_items'] != null) {
          cartItemsList = _selectedOrder['cart']['cart_items'];
        } else if (_selectedOrder['cart_items'] != null &&
            _selectedOrder['cart_items']['cart_items'] != null) {
          cartItemsList = _selectedOrder['cart_items']['cart_items'];
        } else {
          cartItemsList = [];
        }

        if (newQuantity == 0) {
          // Remove the item completely when quantity is 0
          cartItemsList.removeWhere(
              (item) => item['id'].toString() == cartItem['id'].toString());
        } else {
          // Update the quantity for non-zero values
          for (var item in cartItemsList) {
            if (item['id'].toString() == cartItem['id'].toString()) {
              item['quantity'] = newQuantity.toString();
              item['total_price'] =
                  (newQuantity * double.parse(item['unit_price'].toString()))
                      .toString();
              break;
            }
          }
        }
      });

      if (isApiSuccess(response)) {
        // Success - optimistic update was correct, just show success message
        String successMessage = newQuantity == 0
            ? 'Item removed successfully'
            : 'Item quantity updated successfully';

        showScaffold(
          context: context,
          message: successMessage,
        );

        // Only refresh the saved orders list in the background to update totals
        // without affecting the current view (silent refresh without loading spinner)
        final bool isIncrement = newQuantity > currentQuantity;
        final itemStatus = cartItem['status']?.toString();
        // Backend creates a NEW cart entry (status=null) whenever the existing
        // item already has ANY status — not just 'PREPARING' / 'COOKING' etc.
        // 'STARTED' also triggers this behaviour, so check for any non-null status.
        final itemAlreadyHasStatus =
            itemStatus != null && itemStatus.isNotEmpty;

        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (mounted) {
            await _refreshSavedOrdersSilently();
            // Scroll to and highlight the newly created item at the bottom.
            if (isIncrement && itemAlreadyHasStatus) {
              final productId = cartItem['product_id'];
              if (productId != null) {
                scrollToAndHighlightNewItem(int.parse(productId.toString()));
              }
            }
          }
        });
      } else {
        // Revert the optimistic update
        setState(() {
          List<dynamic> cartItemsList;
          if (_selectedOrder['cart'] != null &&
              _selectedOrder['cart']['cart_items'] != null) {
            cartItemsList = _selectedOrder['cart']['cart_items'];
          } else if (_selectedOrder['cart_items'] != null &&
              _selectedOrder['cart_items']['cart_items'] != null) {
            cartItemsList = _selectedOrder['cart_items']['cart_items'];
          } else {
            cartItemsList = [];
          }

          if (newQuantity == 0) {
            // If removal failed, re-add the item with original quantity
            bool itemExists = cartItemsList.any(
                (item) => item['id'].toString() == cartItem['id'].toString());
            if (!itemExists) {
              cartItemsList.add(cartItem); // Re-add the removed item
            }
          } else {
            // If quantity update failed, revert to original quantity
            for (var item in cartItemsList) {
              if (item['id'].toString() == cartItem['id'].toString()) {
                item['quantity'] = currentQuantity.toString();
                item['total_price'] = (currentQuantity *
                        double.parse(item['unit_price'].toString()))
                    .toString();
                break;
              }
            }
          }
        });

        String errorAction =
            newQuantity == 0 ? 'remove item' : 'update quantity';
        showScaffoldError(
          context: context,
          message:
              'Failed to $errorAction: ${response?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating cart item: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to update cart item: ${e.toString()}',
      );
    }
  }

  Future<void> _removeCartItem(dynamic cartItem) async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get customer ID from the order data (consistent with other methods)
      final customerId = _selectedOrder['cart']?['customer_id'] ??
          _selectedOrder['customer_id'] ??
          1;
      final orderCartId = int.tryParse(
          (_selectedOrder['cart']?['id'] ?? _selectedOrder['cart_id'])
                  ?.toString() ??
              '');

      debugPrint(
          '🗑️ Removing cart item (using unified API): Sending request with customerId: $customerId, cartItemId: ${cartItem['id']}');
      // Use the unified decrementCartItemQuantityAPI with quantity 0 for removal
      final response = await cartProvider.decrementCartItemQuantityAPI(
        customerId: int.parse(customerId.toString()),
        productId:
            int.parse(cartItem['id'].toString()), // Send cart_item_id here
        cartId: orderCartId,
        quantity: 0, // Set quantity to 0 for removal
        accessToken: authModel.token ?? '',
      );

      debugPrint('🗑️ Remove response (unified API): $response');

      // Update the UI optimistically first
      setState(() {
        // Remove the cart item from the selected order
        final cartItems = _selectedOrder['cart']['cart_items'] as List<dynamic>;
        cartItems.removeWhere(
            (item) => item['id'].toString() == cartItem['id'].toString());
      });

      if (isApiSuccess(response)) {
        // Success - optimistic update was correct, just show success message
        showScaffold(
          context: context,
          message: 'Item removed successfully',
        );

        // Only refresh the saved orders list in the background to update totals
        // without affecting the current view (silent refresh without loading spinner)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _refreshSavedOrdersSilently();
          }
        });
      } else {
        // Revert the optimistic update by refreshing saved orders silently
        await _refreshSavedOrdersSilently();

        showScaffoldError(
          context: context,
          message:
              'Failed to remove item: ${response?['message'] ?? 'Server returned error response'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing cart item: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to remove item: ${e.toString()}',
      );
    }
  }

  Future<void> _refreshOrderDetails() async {
    try {
      debugPrint('🔄 Refreshing order details by fetching saved orders...');

      // Instead of trying to fetch cart data directly,
      // refresh the saved orders list and find the current order
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );

      if (response['status'] == 'success') {
        final orders = response['orders'] as List<dynamic>;

        // Find the current order in the updated list
        final currentOrderId =
            _selectedOrder['id'] ?? _selectedOrder['order_id'];
        final updatedOrder = orders.firstWhere(
          (order) =>
              order['id'] == currentOrderId ||
              order['order_id'] == currentOrderId,
          orElse: () => null,
        );

        if (updatedOrder != null) {
          if (_blockReselectAfterPlace) {
            setState(() {
              _selectedOrder = null;
            });
            widget.onOrderSelected(null);
            debugPrint('✅ Skipping reselect after order placed');
            return;
          }
          setState(() {
            _selectedOrder = updatedOrder;
          });
          debugPrint('✅ Order details refreshed successfully');
        } else {
          debugPrint('⚠️ Could not find updated order in the list');
        }
      } else {
        debugPrint('⚠️ Failed to refresh saved orders: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing order details: ${e.toString()}');
      // As a fallback, try to refresh the saved orders list
      try {
        await _fetchSavedOrders();
      } catch (fallbackError) {
        debugPrint(
            '❌ Fallback refresh also failed: ${fallbackError.toString()}');
      }
    }
  }

  List<dynamic> _getCartItemsFromOrder(dynamic order) {
    debugPrint('📦 _getCartItemsFromOrder called');
    if (order == null) {
      debugPrint('❌ _getCartItemsFromOrder: Order is null');
      return [];
    }

    debugPrint(
        '🔍 _getCartItemsFromOrder: Available keys: ${order.keys.toList()}');

    if (order['cart_items'] != null) {
      debugPrint('✓ Found cart_items key');
      if (order['cart_items']['cart_items'] is List) {
        final items = order['cart_items']['cart_items'];
        debugPrint(
            '✓ Returning ${items.length} items from cart_items.cart_items');
        return items;
      } else if (order['cart_items'] is List) {
        final items = order['cart_items'];
        debugPrint('✓ Returning ${items.length} items from cart_items (List)');
        return items;
      }
    } else if (order['cart'] != null) {
      debugPrint('✓ Found cart key');
      if (order['cart']['cart_items'] is List) {
        final items = order['cart']['cart_items'];
        debugPrint('✓ Returning ${items.length} items from cart.cart_items');
        return items;
      } else if (order['cart']['items'] is List) {
        final items = order['cart']['items'];
        debugPrint('✓ Returning ${items.length} items from cart.items');
        return items;
      }
    } else if (order['items'] is List) {
      final items = order['items'];
      debugPrint('✓ Returning ${items.length} items from items');
      return items;
    } else if (order['order_items'] is List) {
      final items = order['order_items'];
      debugPrint('✓ Returning ${items.length} items from order_items');
      return items;
    }

    debugPrint('❌ _getCartItemsFromOrder: No cart items found');
    return [];
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
      await Navigator.push(
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

  Future<void> _confirmOrderAndPrintBill() async {
    if (_selectedOrder == null) return;

    if (!_hasOpenedPaymentModalOnce) {
      _showPaymentMethodModal(onAfterApply: _confirmOrderAndPrintBill);
      return;
    }

    // Capture order data before confirmation (in case it cleans up)
    final capturedOrder = _selectedOrder;

    // Confirm the order first, but don't close the view yet
    final success = await _confirmOrder(closeOnSuccess: false);

    if (success) {
      try {
        final orderNumber = capturedOrder['order_number']?.toString();
        if (orderNumber == null) {
          throw Exception("Order number not found");
        }

        final authModel = Provider.of<AuthModel>(context, listen: false);
        final accessToken = authModel.token;

        debugPrint(
            "🔍 Fetching order details for bill print - Order $orderNumber");
        final response = await SalesProvider().listOrderDetails(
          context,
          orderNumber,
          accessToken ?? "",
        );

        if (response != null) {
          OrderDetailsModel orderDetails = OrderDetailsModel.fromJson(response);

          String? formattedTotal =
              orderDetails.data?.cart?.priceSummary?.netPayable?.toString() ??
                  orderDetails.data?.cart?.priceSummary?.netTotal.toString();
          String? savedTotal =
              orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

          String storeName = orderDetails.data!.cart!.storeName ?? "";
          String orderDate = orderDetails.data!.orderDate ?? "";

          // Extract customer details
          String? customerName = _resolveCustomerName(
            order: capturedOrder,
            orderDetails: orderDetails.data,
          );
          String? customerPhone = _resolveCustomerPhone(
            order: capturedOrder,
            orderDetails: orderDetails.data,
          );
          String? customerEmail = orderDetails.data?.customerDetails?.email;
          String? customerAddress =
              orderDetails.data?.getCustomerAddressForDisplay();

          String? customerAlternatePhone = _resolveCustomerAlternatePhone(
            orderDetails: orderDetails.data,
          );
          String? paymentMethod =
              orderDetails.data?.paymentDetails?.paymentMethod;

          // Extract payment breakdown (method -> amount mapping from API)
          Map<String, dynamic>? paymentBreakdown = orderDetails.data?.payments;

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

          // Calculate customer balance for print
          double? oldBalance = _selectedCustomer?.balance;
          double totalPaid = 0.0;
          if (_isCashSelected) totalPaid += double.tryParse(_cashAmount) ?? 0.0;
          if (_isCardSelected) totalPaid += double.tryParse(_cardAmount) ?? 0.0;
          if (_isUpiSelected) totalPaid += double.tryParse(_upiAmount) ?? 0.0;

          double? currentBalance;
          if (oldBalance != null) {
            double cartTotal = double.tryParse(formattedTotal!) ?? 0.0;
            currentBalance = oldBalance - (cartTotal - totalPaid);
          }

          if (mounted) {
            debugPrint("🖨️ Attempting auto-print for order #$orderNumber");

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
                orderNumber: orderDetails.data!.orderNumber ?? "",
                tokenNumber: orderDetails.data?.tokenNumber,
                customerName: customerName,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                customerAddress: customerAddress,
                customerOldBalance: oldBalance,
                customerCurrentBalance: currentBalance,
                paidAmount: totalPaid > 0 ? totalPaid : null,
                customerAlternatePhone: customerAlternatePhone,
                paymentMethod: paymentMethod,
                paymentBreakdown: paymentBreakdown,
                orderComment: orderComment,
                deliveryMethod: orderDetails.data?.deliveryMethodName,
                isDefaultCustomer: _isDefaultCustomerPhone(customerPhone),
                netExcTax: orderDetails.data?.cart!.priceSummary?.netExcTax
                    ?.toString(),
              );
            }

            final autoPrintSuccess = await printOnce();
            await _maybePrintCustomerCopy(
              canPrompt: autoPrintSuccess,
              printAction: printOnce,
            );

            // After returning from print or successful auto-print, cleanup
            if (mounted) {
              setState(() {
                _blockReselectAfterPlace = true;
                _selectedOrder = null;
              });
              widget.onOrderSelected(null);
            }
          }
        }
      } catch (e) {
        debugPrint("❌ Error printing bill: $e");
        showScaffoldError(
            context: context, message: "Failed to print bill: $e");

        // Even if print fails, the order was confirmed, so cleanup
        if (mounted) {
          setState(() {
            _blockReselectAfterPlace = true;
            _selectedOrder = null;
          });
          widget.onOrderSelected(null);
        }
      }
    }
  }

  Future<void> _refreshSelectedOrderAfterCartUpdate() async {
    if (_selectedOrder == null) return;

    if (_blockReselectAfterPlace) {
      setState(() {
        _selectedOrder = null;
      });
      widget.onOrderSelected(null);
      debugPrint('✅ Skipping reselect after order placed');
      return;
    }

    debugPrint('🔄 Refreshing selected order after cart update...');

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Fetch updated saved orders
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );

      if (response['status'] == 'success') {
        final orders = response['orders'] as List<dynamic>;

        // Update the saved orders list
        setState(() {
          _savedOrders = orders;
        });

        // Find and update the currently selected order
        final currentOrderId =
            _selectedOrder['id'] ?? _selectedOrder['order_id'];
        final updatedOrder = orders.firstWhere(
          (order) =>
              order['id'] == currentOrderId ||
              order['order_id'] == currentOrderId,
          orElse: () => null,
        );

        if (updatedOrder != null) {
          setState(() {
            _selectedOrder = updatedOrder;
          });

          // Don't update parent to prevent loop - parent already knows about the refresh
          // widget.onOrderSelected(updatedOrder); // Commented out to prevent loop

          debugPrint(
              '✅ Selected order refreshed successfully after cart update');
        } else {
          debugPrint(
              '⚠️ Could not find updated order in the list after cart update');
        }
      } else {
        debugPrint(
            '⚠️ Failed to refresh saved orders after cart update: ${response['message']}');
      }
    } catch (e) {
      debugPrint(
          '❌ Error refreshing selected order after cart update: ${e.toString()}');
    }
  }

  List<String> _getSelectedPaymentMethodsForApi() {
    final methods = <String>[];
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    String methodId(String name, String? providerId) {
      return providerId ??
          masterDataProvider.getPaymentMethodId(name)?.toString() ??
          name;
    }

    if (_isCashSelected && (double.tryParse(_cashAmount) ?? 0) > 0) {
      methods.add(methodId('CASH', billingProvider.cashPaymentMethodId));
    }
    if (_isCardSelected && (double.tryParse(_cardAmount) ?? 0) > 0) {
      methods.add(methodId('CARD', billingProvider.cardPaymentMethodId));
    }
    if (_isUpiSelected && (double.tryParse(_upiAmount) ?? 0) > 0) {
      methods.add(methodId('UPI', billingProvider.upiPaymentMethodId));
    }
    if (_isCodSelected && (double.tryParse(_codAmount) ?? 0) > 0) {
      methods.add(methodId('COD', billingProvider.codPaymentMethodId));
    }

    return methods;
  }

  List<Map<String, dynamic>> _getPaidMethodsForApi(double balanceAmount) {
    final paidMethods = <Map<String, dynamic>>[];
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    String methodId(String name, String? providerId) {
      return providerId ??
          masterDataProvider.getPaymentMethodId(name)?.toString() ??
          name;
    }

    final cashId = methodId('CASH', billingProvider.cashPaymentMethodId);
    final cardId = methodId('CARD', billingProvider.cardPaymentMethodId);
    final upiId = methodId('UPI', billingProvider.upiPaymentMethodId);
    final codId = methodId('COD', billingProvider.codPaymentMethodId);

    void addPaidMethod(bool selected, String amountText, String method) {
      final amount = double.tryParse(amountText) ?? 0.0;
      if (!selected || amount <= 0) return;
      paidMethods.add({'method': method, 'amount': amount});
    }

    addPaidMethod(_isCashSelected, _cashAmount, cashId);
    addPaidMethod(_isCardSelected, _cardAmount, cardId);
    addPaidMethod(_isUpiSelected, _upiAmount, upiId);
    addPaidMethod(_isCodSelected, _codAmount, codId);

    return PaymentHelper.normalizePaidMethodsForApi(
      paidMethods: paidMethods,
      balanceAmount: balanceAmount > 0 ? balanceAmount : 0.0,
      cashMethodId: cashId,
      codMethodId: codId,
    );
  }

  double _getTotalPaidAmountFromState() {
    return (double.tryParse(_cashAmount) ?? 0.0) +
        (double.tryParse(_cardAmount) ?? 0.0) +
        (double.tryParse(_upiAmount) ?? 0.0) +
        (double.tryParse(_codAmount) ?? 0.0);
  }

  Map<String, dynamic> _orderResponseData(dynamic response) {
    if (response is Map<String, dynamic>) {
      final rawData = response['data'];
      if (rawData is Map) {
        return Map<String, dynamic>.from(rawData);
      }
      return Map<String, dynamic>.from(response);
    }
    if (response is Map) {
      final rawData = response['data'];
      if (rawData is Map) {
        return Map<String, dynamic>.from(rawData);
      }
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{};
  }

  Future<void> _printCurrentCartKot(
    String orderNumber,
    List<LocalCartItem> cartItems, {
    String? tokenNumber,
  }) async {
    final printItems = cartItems.map((item) {
      return {
        'productName': item.product.productName ?? '',
        'quantity': item.quantity.toString(),
        'unitPrice': item.price?.toStringAsFixed(2) ?? '0.00',
        'totalPrice': ((item.price ?? 0) * item.quantity).toStringAsFixed(2),
        'mrp': item.mrp?.toStringAsFixed(2) ??
            item.price?.toStringAsFixed(2) ??
            '0.00',
        if (item.comment != null && item.comment!.isNotEmpty)
          'notes': item.comment,
      };
    }).toList();

    final orderTime = DateHelper.getCurrentFormattedTimeWithAMPM();
    final tableName = _deliveryMethod.isNotEmpty
        ? _deliveryMethod
        : (widget.preselectedDeliveryMethodName ?? 'Store Takeaway');

    final success = await KotPrintPage.autoPrint(
      context,
      orderNumber: orderNumber,
      tokenNumber: tokenNumber,
      tableName: tableName,
      showTableLabel: false,
      orderTime: orderTime,
      items: printItems,
      comment: _orderComment.isNotEmpty ? _orderComment : null,
    );

    if (!success && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KotPrintPage(
            orderNumber: orderNumber,
            tokenNumber: tokenNumber,
            tableName: tableName,
            showTableLabel: false,
            orderTime: orderTime,
            items: printItems,
            comment: _orderComment.isNotEmpty ? _orderComment : null,
          ),
        ),
      );
    }
  }

  Future<String?> _printConfirmedCurrentCartBill(dynamic response) async {
    final responseData = _orderResponseData(response);
    final orderLookup = (responseData['order_number'] ??
            responseData['order_id'] ??
            responseData['orders_id'] ??
            (response is Map ? response['order_number'] : null) ??
            (response is Map ? response['order_id'] : null))
        ?.toString();

    if (orderLookup == null || orderLookup.isEmpty) {
      throw Exception('Order number not found for printing');
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final detailsResponse = await SalesProvider().listOrderDetails(
      context,
      orderLookup,
      authModel.token ?? '',
    );
    final orderDetails = OrderDetailsModel.fromJson(detailsResponse);
    final detailsData = orderDetails.data;
    final cart = detailsData?.cart;

    final formattedTotal = cart?.priceSummary?.netPayable?.toString() ??
        cart?.priceSummary?.netTotal.toString() ??
        _getEffectiveOrderTotal().toStringAsFixed(2);
    final savedTotal = cart?.priceSummary?.savedTotal.toString();
    final totalPaid = _getTotalPaidAmountFromState();
    final oldBalance = _selectedCustomer?.balance;
    double? currentBalance;
    if (oldBalance != null) {
      final cartTotal = double.tryParse(formattedTotal) ?? 0.0;
      currentBalance = oldBalance - (cartTotal - totalPaid);
    }

    Future<bool> printOnce() {
      return _printOrderDetailsWithFallback(
        storeName: cart?.storeName ?? '',
        cartItems: cart?.cartItems ?? const [],
        formattedTotal: formattedTotal,
        savedTotal: savedTotal,
        discountAmount: detailsData?.priceSummary?.discount?.toString() ??
            (detailsData?.cart?.priceSummary?.discount?.toString() ?? '0.00'),
        orderDate: detailsData?.orderDate ?? '',
        orderNumber: detailsData?.orderNumber?.toString() ?? orderLookup,
        tokenNumber: detailsData?.tokenNumber,
        customerName:
            detailsData?.customerDetails?.name ?? _selectedCustomer?.name,
        customerPhone:
            detailsData?.customerDetails?.phone ?? _selectedCustomerPhone,
        customerEmail: detailsData?.customerDetails?.email,
        customerAddress: detailsData?.getCustomerAddressForDisplay(),
        customerOldBalance: oldBalance,
        customerCurrentBalance: currentBalance,
        paidAmount: totalPaid > 0 ? totalPaid : null,
        customerAlternatePhone: detailsData?.customerDetails?.alternatePhone,
        customerVatNumber: detailsData?.kycInfo?.vatNumber,
        customerCrNumber: detailsData?.kycInfo?.crNumber,
        customerType: _selectedCustomer?.customerType,
        paymentMethod: detailsData?.paymentDetails?.paymentMethod,
        paymentBreakdown: detailsData?.payments,
        orderComment: _orderComment.isNotEmpty ? _orderComment : null,
        deliveryMethod: detailsData?.deliveryMethodName ?? _deliveryMethod,
        isDefaultCustomer: _isDefaultCustomerPhone(
          detailsData?.customerDetails?.phone ?? _selectedCustomerPhone,
        ),
        netExcTax: cart?.priceSummary?.netExcTax?.toString(),
      );
    }

    final autoPrintSuccess = await printOnce();
    await _maybePrintCustomerCopy(
      canPrompt: autoPrintSuccess,
      printAction: printOnce,
    );

    return detailsData?.tokenNumber;
  }

  void _resetCurrentCartCheckoutState() {
    setState(() {
      _selectedCustomer = null;
      _selectedCustomerID = null;
      _selectedCustomerPhone = null;
      _isCustomerManuallySelected = false;
      _orderComment = '';
      _cashAmount = '';
      _cardAmount = '';
      _upiAmount = '';
      _codAmount = '';
      _debitAmount = '';
      _transactionNumber = '';
      _balanceAmount = 0.0;
      _toCustomerCreditEnabled = false;
      _toCustomerCreditAmount = 0.0;
      _hasOpenedPaymentModalOnce = false;
      _flatDiscount = 0.0;
      _percentageDiscount = 0.0;
      _couponCode = '';
      _isCouponApplied = false;
      _loadedLocalDraftId = null;
    });
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();
    _applyDefaultCustomer();
  }

  Future<bool> _confirmCurrentCart({required bool printBill}) async {
    if (!widget.allowCounterBilling || !widget.isCounterBillingMode) {
      showScaffoldError(
        context: context,
        message: 'Quick counter billing is disabled',
      );
      return false;
    }

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final cartItems = List<LocalCartItem>.from(localProductProvider.cartItems);
    if (cartItems.isEmpty) {
      showScaffoldError(context: context, message: 'No items in cart');
      return false;
    }

    final customerPhone = _selectedCustomer?.phone ?? _selectedCustomerPhone;
    if (_selectedCustomerID == null &&
        _selectedCustomer?.id == null &&
        (customerPhone == null || customerPhone.isEmpty)) {
      showScaffoldError(context: context, message: 'Please select a customer');
      return false;
    }

    setState(() {
      _isLoadingConfirm = true;
    });

    try {
      localProductProvider.cartTotal; // Recalculate priceSummary.
      final priceSummary = localProductProvider.priceSummary;
      final netTotal = priceSummary?.netTotal ?? localProductProvider.cartTotal;
      final deliveryCharge = _getDeliveryChargeForOrder();
      final payableTotal = netTotal + deliveryCharge;
      final totalPaid = _getTotalPaidAmountFromState();
      final balanceAmount = totalPaid - payableTotal;
      final paymentMethods = _getSelectedPaymentMethodsForApi();
      final paidMethods = _getPaidMethodsForApi(balanceAmount);

      final items = cartItems.map((item) {
        return {
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp,
          'stock_id': item.selectedStock?.id,
          if (item.comment != null && item.comment!.isNotEmpty)
            'comment': item.comment,
        };
      }).toList();

      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final deliveryMethodId = _deliveryMethodId.isNotEmpty
          ? _deliveryMethodId
          : (widget.preselectedDeliveryMethodId?.isNotEmpty == true
              ? widget.preselectedDeliveryMethodId
              : _getDefaultDeliveryMethodId());

      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0,
        accessToken: authModel.token ?? '',
        transactionId: _transactionNumber,
        totalPrice: netTotal.toStringAsFixed(2),
        customerId: _selectedCustomer?.id ?? _selectedCustomerID,
        customerPhone: customerPhone,
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: paymentMethods,
        paidMethods: paidMethods,
        balanceAmount: balanceAmount.toStringAsFixed(2),
        couponId:
            _isCouponApplied && _couponCode.isNotEmpty ? _couponCode : null,
        comment: _orderComment.trim().isNotEmpty ? _orderComment.trim() : null,
        deliveryMethodId: deliveryMethodId,
        status: 'confirmed',
        deliveryDate: _deliveryDate,
        deliveryTime: _deliveryTime,
        flatDiscount: priceSummary?.flatDiscount,
        percentageDiscount: priceSummary?.percentageDiscount,
        discountAmount: priceSummary?.discount,
        toCustomerCredit: _toCustomerCreditEnabled,
        address: _deliveryAddress.isNotEmpty ? _deliveryAddress : null,
        deliveryCharge: deliveryCharge,
      );

      final responseData = _orderResponseData(response);
      final orderId = responseData['order_id'] ??
          responseData['orders_id'] ??
          (response is Map ? response['order_id'] : null);
      if (orderId == null && !isApiSuccess(response)) {
        showScaffoldError(
          context: context,
          message: response is Map
              ? (response['message']?.toString() ?? 'Failed to confirm order')
              : 'Failed to confirm order',
        );
        return false;
      }

      String? tokenNumber;
      if (printBill) {
        tokenNumber = await _printConfirmedCurrentCartBill(response);
      }

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      if (printBill &&
          (appSettingsProvider.appSettings?.enableKOTPrint ?? true)) {
        final orderNumber = (responseData['order_number'] ??
                (response is Map ? response['order_number'] : null) ??
                'ORD-$orderId')
            .toString();
        await _printCurrentCartKot(
          orderNumber,
          cartItems,
          tokenNumber: tokenNumber ?? _extractTokenNumber(responseData),
        );
      }

      _refreshCustomersInBackgroundAfterSale();
      deleteLoadedDraftIfAny();
      localProductProvider.clearCartAfterOrder();
      _resetCurrentCartCheckoutState();
      showScaffold(
        context: context,
        message: printBill
            ? 'Counter order confirmed and printed'
            : 'Counter order confirmed',
      );
      return true;
    } catch (e) {
      debugPrint('Error confirming counter order: $e');
      showScaffoldError(
        context: context,
        message: 'Failed to confirm counter order: ${e.toString()}',
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConfirm = false;
        });
      }
    }
  }

  Future<bool> _confirmOrder({bool closeOnSuccess = true}) async {
    if (_selectedOrder == null) {
      showScaffoldError(
        context: context,
        message: 'No order selected to confirm',
      );
      return false;
    }

    if (!_hasOpenedPaymentModalOnce) {
      _showPaymentMethodModal(
          onAfterApply: () => _confirmOrder(closeOnSuccess: closeOnSuccess));
      return false;
    }

    // Set loading state
    setState(() {
      _isLoadingConfirm = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get order details
      final orderId = _selectedOrder['id'] ?? _selectedOrder['order_id'];
      final orderNumber = _selectedOrder['order_number'];

      debugPrint('🔄 Confirming order: $orderNumber (ID: $orderId)');

      // Get order details for API call
      final customerId = _selectedCustomer?.id ??
          _selectedOrder['customer_id'] ??
          authModel.userId ??
          1;
      final customerPhone = _resolveCustomerPhone(order: _selectedOrder) ?? '';
      // Get order items to calculate subtotal
      final List<dynamic> cartItems = _getCartItemsFromOrder(_selectedOrder);

      double rawOrderTotal = 0.0;
      for (var item in cartItems) {
        final quantity =
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        final unitPrice = double.tryParse(item['unit_price']?.toString() ??
                item['price']?.toString() ??
                item['product_price']?.toString() ??
                '0') ??
            0.0;
        rawOrderTotal += quantity * unitPrice;
      }

      // Fallback to grand_total if items calculation is 0
      if (rawOrderTotal == 0.0) {
        rawOrderTotal =
            double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
                0.0;
      }

      final flatDiscountAmount = _flatDiscount;
      final percentageDiscountAmount =
          (rawOrderTotal * _percentageDiscount / 100);
      final totalDiscountAmount = flatDiscountAmount + percentageDiscountAmount;
      final finalOrderTotal =
          (rawOrderTotal - totalDiscountAmount) + _getDeliveryChargeForOrder();

      final totalPrice = finalOrderTotal.toString();
      final transactionId = _transactionNumber.isNotEmpty
          ? _transactionNumber
          : (_selectedOrder['transaction_number'] ?? '');
      final currentComment = _orderComment.trim();
      final selectedOrderComment =
          (_selectedOrder['comment']?.toString() ?? '').trim();
      final comment = currentComment.isNotEmpty
          ? currentComment
          : (selectedOrderComment.isNotEmpty ? selectedOrderComment : null);

      // Validate customer selection (mandatory)
      if ((_selectedCustomerID == null) &&
          (_selectedCustomer == null) &&
          (_selectedCustomerPhone == null ||
              _selectedCustomerPhone!.toString().isEmpty)) {
        showScaffoldError(
          context: context,
          message: 'Please select a customer',
        );
        if (mounted) {
          setState(() {
            _isLoadingConfirm = false;
          });
        }
        return false;
      }

      // Payment method selection is optional - no validation required
      // Just prepare the payment data if methods are selected

      // Prepare payment method data
      String? paymentMethod;
      String? paidAmount;
      List<String> paymentMethods = [];
      List<Map<String, dynamic>> paidMethods = [];

      if (_hasPaymentMethod()) {
        // Get payment method IDs from BillingProvider
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        final cashId = billingProvider.cashPaymentMethodId ?? 'CASH';
        final cardId = billingProvider.cardPaymentMethodId ?? 'CARD';
        final upiId = billingProvider.upiPaymentMethodId ?? 'UPI';
        final codId = billingProvider.codPaymentMethodId ?? 'COD';

        // Multi-payment handling with dynamic IDs (always send in multi format)
        List<String> selectedMethods = [];
        final cashAmountVal = double.tryParse(_cashAmount) ?? 0;
        final cardAmountVal = double.tryParse(_cardAmount) ?? 0;
        final upiAmountVal = double.tryParse(_upiAmount) ?? 0;
        final codAmountVal = double.tryParse(_codAmount) ?? 0;

        if (_isCashSelected && cashAmountVal > 0) selectedMethods.add(cashId);
        if (_isCardSelected && cardAmountVal > 0) selectedMethods.add(cardId);
        if (_isUpiSelected && upiAmountVal > 0) selectedMethods.add(upiId);
        if (_isCodSelected && codAmountVal > 0) selectedMethods.add(codId);

        if (selectedMethods.isNotEmpty) {
          paymentMethods = selectedMethods;

          final totalPaid =
              cashAmountVal + cardAmountVal + upiAmountVal + codAmountVal;
          paidAmount = totalPaid.toString();

          // Prepare raw paid methods, then normalize balance/change once.
          if (_isCashSelected && cashAmountVal > 0) {
            paidMethods.add({"method": cashId, "amount": cashAmountVal});
          }
          if (_isCardSelected && cardAmountVal > 0) {
            paidMethods.add({"method": cardId, "amount": cardAmountVal});
          }
          if (_isUpiSelected && upiAmountVal > 0) {
            paidMethods.add({"method": upiId, "amount": upiAmountVal});
          }
          if (_isCodSelected && codAmountVal > 0) {
            paidMethods.add({"method": codId, "amount": codAmountVal});
          }

          final orderAmount = double.tryParse(totalPrice) ?? 0.0;
          final balanceAmountVal = totalPaid - orderAmount;
          paidMethods = PaymentHelper.normalizePaidMethodsForApi(
            paidMethods: paidMethods,
            balanceAmount: balanceAmountVal > 0 ? balanceAmountVal : 0.0,
            cashMethodId: cashId,
            codMethodId: codId,
          );

          // Keep for logs only; API will use paymentMethods/paidMethods format
          paymentMethod =
              selectedMethods.length == 1 ? selectedMethods.first : null;
        }
      }

      // Calculate balance amount
      final totalPaid = double.tryParse(paidAmount ?? '0') ?? 0.0;
      final orderAmount = double.tryParse(totalPrice) ?? 0.0;
      final balanceAmount = (totalPaid - orderAmount).toString();

      debugPrint('📦 Order details for confirmation:');
      debugPrint('   - Customer ID: $customerId');
      debugPrint('   - Customer Phone: $customerPhone');
      debugPrint('   - Total Price: $totalPrice');
      debugPrint('   - Transaction ID: $transactionId');
      debugPrint('   - Payment Method: $paymentMethod');
      debugPrint('   - Paid Amount: $paidAmount');
      debugPrint('   - Balance Amount: $balanceAmount');
      debugPrint('🎫 Discount details for confirmation:');
      debugPrint(
          '   - Flat Discount: ${flatDiscountAmount.toStringAsFixed(2)}');
      debugPrint(
          '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
      debugPrint(
          '   - Total Discount Amount: ${totalDiscountAmount.toStringAsFixed(2)}');
      debugPrint('   - Coupon Code: $_couponCode');
      debugPrint('🔧 Payment Methods Details:');
      debugPrint('   - Payment Methods Array: $paymentMethods');
      debugPrint('   - Paid Methods Array: $paidMethods');
      debugPrint(
          '   - Is Cash Selected: $_isCashSelected (Amount: $_cashAmount)');
      debugPrint(
          '   - Is Card Selected: $_isCardSelected (Amount: $_cardAmount)');
      debugPrint('   - Is UPI Selected: $_isUpiSelected (Amount: $_upiAmount)');
      debugPrint('\n🚀 CALLING updateOrderAPI with these parameters:');
      debugPrint('   orderId: ${orderId.toString()}');
      debugPrint(
          '   accessToken: ${authModel.token != null ? "[PROVIDED]" : "[NULL]"}');
      debugPrint('   transactionId: $transactionId');
      debugPrint('   totalPrice: $totalPrice');
      debugPrint('   customerId: ${int.tryParse(customerId.toString())}');
      debugPrint('   customerPhone: $customerPhone');
      debugPrint('   paymentMethod: $paymentMethod');
      debugPrint('   paidAmount: $paidAmount');
      debugPrint('   balanceAmount: $balanceAmount');
      debugPrint('   paymentMethods: $paymentMethods');
      debugPrint('   paidMethods: $paidMethods');
      debugPrint('   status: "confirmed"');
      debugPrint('   comment: $comment');
      debugPrint(
          '   flatDiscount: ${_flatDiscount > 0 ? _flatDiscount : null}');
      debugPrint(
          '   percentageDiscount: ${_percentageDiscount > 0 ? _percentageDiscount : null}');
      debugPrint(
          '   discountAmount: ${totalDiscountAmount > 0 ? totalDiscountAmount : null}');
      debugPrint('\n📡 About to call updateOrderAPI...');

      // Call update order API with status "confirmed" and payment data
      final response = await cartProvider.updateOrderAPI(
        orderId: orderId.toString(),
        accessToken: authModel.token ?? '',
        transactionId: transactionId,
        totalPrice: totalPrice,
        customerId: int.tryParse(customerId.toString()),
        customerPhone: customerPhone,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        balanceAmount: balanceAmount,
        paymentMethods: paymentMethods.isNotEmpty ? paymentMethods : null,
        paidMethods: paidMethods.isNotEmpty ? paidMethods : null,
        status: 'confirmed',
        comment: comment,
        deliveryMethodId: _deliveryMethodId.isNotEmpty
            ? _deliveryMethodId
            : _getDefaultDeliveryMethodId(),
        address: _deliveryAddress.isNotEmpty ? _deliveryAddress : null,
        // Add discount parameters
        flatDiscount: _flatDiscount > 0 ? _flatDiscount : null,
        percentageDiscount:
            _percentageDiscount > 0 ? _percentageDiscount : null,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        toCustomerCredit: _toCustomerCreditEnabled,
        deliveryCharge: _getDeliveryChargeForOrder(),
      );

      debugPrint('\n📥 updateOrderAPI RESPONSE:');
      debugPrint('   Response: $response');
      debugPrint('   Response Type: ${response.runtimeType}');
      if (response is Map) {
        debugPrint('   Status: ${response['status']}');
        debugPrint('   Message: ${response['message']}');
        debugPrint('   Data: ${response['data']}');
      }
      debugPrint('✅ Confirm order response: $response');

      if (isApiSuccess(response)) {
        _refreshCustomersInBackgroundAfterSale();

        showScaffold(
          context: context,
          message: 'Order $orderNumber confirmed successfully!',
        );

        // Refresh saved orders to show updated status
        debugPrint('🔄 Refreshing saved orders after confirming order');
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchSavedOrders();

        // Delete the local draft so it no longer appears in Pending Orders
        deleteLoadedDraftIfAny();

        // Clear the cart to prevent auto-save from recreating a draft on table switch
        Provider.of<LocalProductProvider>(context, listen: false).clearCart();

        if (closeOnSuccess) {
          // Go back to orders list
          setState(() {
            _blockReselectAfterPlace = true;
            _selectedOrder = null;
          });
          widget.onOrderSelected(null);
        }
        return true;
      } else {
        showScaffoldError(
          context: context,
          message:
              'Failed to confirm order: ${response?['message'] ?? 'Unknown error'}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error confirming order: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to confirm order: ${e.toString()}',
      );
      return false;
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isLoadingConfirm = false;
        });
      }
    }
  }

  Future<void> _updateOrderStatus() async {
    try {
      // Update order status or perform any other order update logic
      showScaffold(
        context: context,
        message: 'Order updated successfully',
      );

      // Refresh saved orders to show updated status
      debugPrint('🔄 Refreshing saved orders after updating order status');
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchSavedOrders();

      // Go back to orders list
      setState(() => _selectedOrder = null);
      widget.onOrderSelected(null);
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to update order: ${e.toString()}',
      );
    }
  }

  Widget _buildCurrentCartItem(LocalCartItem cartItem, int index) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    final productName = cartItem.product.productName ?? 'Unknown Product';
    final quantity = cartItem.quantity;
    final unitPrice = cartItem.price ?? 0.0;
    final totalPrice = quantity * unitPrice;

    return Container(
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  productName,
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      widget.isCompact ? FontSize.s13 : FontSize.s15,
                      0.21,
                      const Color(0xFF1E293B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currency ${totalPrice.toStringAsFixed(2)}',
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s12,
                      0.21, const Color(0xFF059669)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit price and quantity info
          Row(
            children: [
              // Editable Price Trigger for Local Items (Blue Box style)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _showEditItemPriceDialog(cartItem, isLocal: true),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.withOpacity(0.05),
                    ),
                    child: Text(
                      '$currency ${unitPrice.toStringAsFixed(2)}',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          widget.isCompact ? FontSize.s11 : FontSize.s12,
                          0.21,
                          const Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),
              Text(
                ' × ${quantity.toStringAsFixed(0)}',
                style: buildCustomStyle(
                    FontWeightManager.medium,
                    widget.isCompact ? FontSize.s11 : FontSize.s12,
                    0.21,
                    const Color(0xFF64748B)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity controls with modern styling (for current cart, these will use local provider)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _updateCurrentCartItemQuantity(
                            cartItem, quantity - 1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.remove,
                            size: widget.isCompact ? 16 : 18,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: widget.isCompact ? 32 : 40,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toStringAsFixed(0),
                        style: buildCustomStyle(FontWeightManager.bold,
                            FontSize.s14, 0.21, const Color(0xFF1E293B)),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _updateCurrentCartItemQuantity(
                            cartItem, quantity + 1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            size: widget.isCompact ? 16 : 18,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartItem.comment != null && cartItem.comment!.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.isCompact ? 90 : 130,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cartItem.comment!,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.21,
                            const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  // Comment button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _showItemCommentDialog(cartItem, isLocal: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? Icons.chat
                              : Icons.chat_bubble_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: cartItem.comment != null &&
                                  cartItem.comment!.isNotEmpty
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Remove button with modern styling
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeCurrentCartItem(cartItem),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Footer actions for current cart (New Order flow)
  Widget _buildCurrentCartActionButtons(List<LocalCartItem> cartItems) {
    final showCounterCheckout =
        widget.allowCounterBilling && widget.isCounterBillingMode;
    final hasTableOrderContext = widget.tableId != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade100,
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCurrentCartSummaryCard(cartItems),
            const SizedBox(height: 12),
            // Top: Comment button (full width)
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCommentDialog(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: widget.isCompact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _orderComment.isNotEmpty
                                ? Icons.check_circle
                                : Icons.comment,
                            color: _orderComment.isNotEmpty
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                            size: widget.isCompact ? 14 : 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Comment',
                            style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                widget.isCompact ? FontSize.s13 : FontSize.s14,
                                0.21,
                                const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bottom row: table service actions or quick counter checkout.
            Row(
              children: showCounterCheckout
                  ? [
                      Expanded(
                        child: _buildCurrentCartFooterButton(
                          label: 'Clear',
                          color: const Color(0xFFDC2626),
                          isDisabled: cartItems.isEmpty,
                          onTap: () => _clearCurrentCart(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasTableOrderContext) ...[
                        Expanded(
                          child: _buildCurrentCartFooterButton(
                            label: 'Send',
                            color: const Color(0xFF2563EB),
                            isDisabled:
                                cartItems.isEmpty || widget.isLoadingPrint,
                            isLoading: widget.isLoadingPrint,
                            onTap: () => widget.onPrintOrder(),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _buildCurrentCartFooterButton(
                          label: 'Save',
                          color: const Color(0xFFEAB308),
                          isDisabled: cartItems.isEmpty,
                          onTap: () => _saveCurrentCartAsPending(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCurrentCartFooterButton(
                          label: 'Checkout',
                          color: const Color(0xFF059669),
                          isDisabled:
                              cartItems.isEmpty || _isProcessingCheckout,
                          isLoading: _isProcessingCheckout,
                          onTap: () => _showCheckoutModal(forCurrentCart: true),
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: _buildCurrentCartFooterButton(
                          label: 'Save',
                          color: const Color(0xFFEAB308),
                          isDisabled:
                              cartItems.isEmpty || widget.tableId == null,
                          onTap: () => _saveCurrentCartAsPending(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildCurrentCartFooterButton(
                          label: 'Send To Kitchen',
                          color: const Color(0xFF059669),
                          isDisabled:
                              cartItems.isEmpty || widget.isLoadingPrint,
                          isLoading: widget.isLoadingPrint,
                          onTap: () => widget.onPrintOrder(),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCartSummaryCard(List<LocalCartItem> cartItems) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    double netAmount = 0.0;
    for (final item in cartItems) {
      final unitPrice = item.price ?? 0.0;
      netAmount += unitPrice * item.quantity;
    }
    final totalPayable = netAmount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(
            'Net Amount',
            '$currency ${netAmount.toStringAsFixed(2)}',
            color: const Color(0xFF3F3F46),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFFE4E4ED)),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total Payable',
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF3B82F6),
            isBold: true,
            large: true,
          ),
          _buildSummaryRow(
            'Total Paid',
            '$currency 0.00',
            color: const Color(0xFF3F3F46),
          ),
          _buildSummaryRow(
            'Balance',
            '$currency ${totalPayable.toStringAsFixed(2)}',
            color: const Color(0xFF00C739),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCartFooterButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    final disabled = isDisabled || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.isCompact ? 44 : 48,
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFF94A3B8) : color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: widget.isCompact ? 16 : 20,
                    height: widget.isCompact ? 16 : 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            widget.isCompact ? FontSize.s12 : FontSize.s13,
                            0.21,
                            Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Methods for current cart operations
  Future<void> _updateCurrentCartItemQuantity(
      LocalCartItem cartItem, double newQuantity) async {
    if (newQuantity <= 0) {
      await _removeCurrentCartItem(cartItem);
      return;
    }

    try {
      debugPrint(
          '🔄 _updateCurrentCartItemQuantity: Updating quantity for ${cartItem.product.productName} to ${newQuantity.toInt()}');

      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        context: context,
        cartItem: cartItem,
        newQuantity: newQuantity,
      );

      if (result.changed) {
        showScaffold(
          context: context,
          message: 'Item quantity updated successfully',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to update quantity: ${e.toString()}',
      );
    }
  }

  Future<void> _removeCurrentCartItem(LocalCartItem cartItem) async {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      debugPrint(
          '🗑️ _removeCurrentCartItem: Removing ${cartItem.product.productName} from cart');

      // Use LocalProductProvider to remove the item
      localProductProvider.removeFromCart(
        cartItem.product.productId!,
        cartItem.selectedStock,
        stockGroupIds: cartItem.stockGroupIds,
        saleUnitId: cartItem.saleUnitId,
      );

      showScaffold(
        context: context,
        message: 'Item removed successfully',
      );
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to remove item: ${e.toString()}',
      );
    }
  }

  Future<void> _clearCurrentCart() async {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isNotEmpty) {
        debugPrint('🗑️ _clearCurrentCart: Clearing local cart');

        // Use LocalProductProvider to clear the cart
        localProductProvider.clearCart();
        setState(() {
          _orderComment = '';
          _loadedLocalDraftId = null;
        });

        showScaffold(
          context: context,
          message: 'Cart cleared successfully',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to clear cart: ${e.toString()}',
      );
    }
  }

  // Save current cart locally as a PENDING draft for the active table/delivery method
  Future<void> _saveCurrentCartAsPending() async {
    if (widget.tableId == null &&
        (widget.preselectedDeliveryMethodId == null ||
            widget.preselectedDeliveryMethodId!.isEmpty)) {
      showScaffoldError(
          context: context, message: 'Select a table or delivery method first');
      return;
    }

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final isNonTableOrderContext = widget.tableId == null &&
          (widget.preselectedDeliveryMethodId?.isNotEmpty == true ||
              (widget.allowCounterBilling && widget.isCounterBillingMode));

      debugPrint('📝 [_saveCurrentCartAsPending] START');
      debugPrint('📝 tableId: ${widget.tableId}');
      debugPrint(
          '📝 preselectedDeliveryMethodId: ${widget.preselectedDeliveryMethodId}');
      debugPrint('📝 isNonTableOrderContext: $isNonTableOrderContext');
      debugPrint('📝 cartItemsCount: ${localProductProvider.cartItems.length}');

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: 'No items in cart to save');
        return;
      }

      final paymentData = _getLocalDraftPaymentData();
      final draftComment = widget.tableId != null
          ? buildTaggedDraftComment(widget.tableId!)
          : _orderComment.trim();
      debugPrint('📝 draftComment: "$draftComment"');
      debugPrint('📝 deliveryMethodForDraft: $deliveryMethodForDraft');
      debugPrint('📝 deliveryMethodIdForDraft: $deliveryMethodIdForDraft');
      debugPrint('📝 selectedCustomerIdForDraft: $selectedCustomerIdForDraft');
      debugPrint('📝 paymentData: $paymentData');

      // If a local draft is loaded, update it instead of creating a new one
      if (_loadedLocalDraftId != null) {
        debugPrint('📝 Updating existing local draft $_loadedLocalDraftId');
        localProductProvider.updateSavedOrder(
          _loadedLocalDraftId!,
          customerName: selectedCustomerNameForDraft,
          customerPhone: selectedCustomerPhoneForDraft,
          comment: draftComment.isNotEmpty ? draftComment : null,
          deliveryMethod: deliveryMethodForDraft,
          customerId: selectedCustomerIdForDraft,
          paymentMethod: paymentData['paymentMethod'],
          paidAmount: paymentData['paidAmount'],
          balanceAmount: balanceAmountForDraft,
          transactionId: transactionNumberForDraft,
          couponId: couponIdForDraft,
          deliveryMethodId: deliveryMethodIdForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        showScaffold(context: context, message: 'Updated local draft');
      } else {
        debugPrint('📝 Creating new local draft');
        final saved = localProductProvider.saveCurrentCartAsOrder(
          customerName: selectedCustomerNameForDraft,
          customerPhone: selectedCustomerPhoneForDraft,
          comment: draftComment.isNotEmpty ? draftComment : null,
          deliveryMethod: deliveryMethodForDraft,
          customerId: selectedCustomerIdForDraft,
          paymentMethod: paymentData['paymentMethod'],
          paidAmount: paymentData['paidAmount'],
          balanceAmount: balanceAmountForDraft,
          transactionId: transactionNumberForDraft,
          couponId: couponIdForDraft,
          deliveryMethodId: deliveryMethodIdForDraft,
          status: 'pending',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        showScaffold(
            context: context,
            message: 'Saved local draft ${saved.orderNumber}');
      }

      // Clear cart and refresh local drafts
      localProductProvider.clearCart();
      setState(() {
        _loadedLocalDraftId = null;
        _orderComment = '';
      });
      _refreshLocalDrafts();
    } catch (e) {
      showScaffoldError(
          context: context,
          message: 'Failed to save local draft: ${e.toString()}');
    }
  }

  // Refresh local drafts from Hive filtered by table tag and pending status
  Future<void> _refreshLocalDrafts() async {
    // Reset manual selection flag when table changes context or drafts are refreshed
    _isCustomerManuallySelected = false;

    // Apply default customer logic for the current table context
    _applyDefaultCustomer();

    try {
      final localProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final drafts = localProvider.savedOrders.where((o) {
        final st = (o.status ?? '').toLowerCase();
        if (st != 'pending') return false;
        // Filter by table when a table is selected
        if (widget.tableId != null) {
          return o.tableId == widget.tableId;
        }
        // Filter by delivery method when no table is selected
        if (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty) {
          return o.tableId == null &&
              o.deliveryMethodId == widget.preselectedDeliveryMethodId;
        }
        return false;
      }).toList();
      setState(() {
        _localDrafts = drafts;
      });
    } catch (_) {}
  }

  // Delete local draft
  void _deleteLocalDraft(SavedOrder order) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.deleteSavedOrder(order.id);
    _refreshLocalDrafts();
  }

  // Local draft item card
  Widget _buildLocalDraftItem(SavedOrder order) {
    final int totalItems = order.items.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Load back to current cart for editing
          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);
          _loadedLocalDraftId = order.id;
          localProductProvider.loadOrderForEditing(order.id);
          _rehydrateLocalDraftMetadata(order);
          showCurrentOrderTab();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s13 : FontSize.s15,
                        0.21,
                        const Color(0xFF1E293B)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD97706).withOpacity(0.4)),
                        ),
                        child: Text(
                          'PENDING',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s10 : FontSize.s11,
                              0.21,
                              const Color(0xFFD97706)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalItems',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s11 : FontSize.s13,
                              0.21,
                              const Color(0xFF059669)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _deleteLocalDraft(order),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: widget.isCompact ? 16 : 18,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _cleanDraftComment(order.comment),
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        widget.isCompact ? FontSize.s11 : FontSize.s13,
                        0.21,
                        const Color(0xFF64748B)),
                  ),
                  Text(
                    'Items: $totalItems',
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        widget.isCompact ? FontSize.s11 : FontSize.s13,
                        0.21,
                        const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Safe comment cleaner: strips TABLE:<id> prefix without regex
  String _cleanDraftComment(String? comment) {
    final c = (comment ?? '').trim();
    if (c.startsWith('TABLE:')) {
      final parts = c.split('|');
      if (parts.length >= 2) {
        return parts.sublist(1).join('|').trim();
      } else {
        return '';
      }
    }
    return c;
  }

  // Public method called by parent after successful send
  void deleteLoadedDraftIfAny() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    if (_loadedLocalDraftId != null) {
      localProductProvider.deleteSavedOrder(_loadedLocalDraftId!);
      _loadedLocalDraftId = null;
    } else {
      // Fallback: clean up any pending drafts for the current context
      // (handles auto-saved drafts that were never tracked by _loadedLocalDraftId)
      final staleDrafts = localProductProvider.savedOrders.where((o) {
        if ((o.status ?? '').toLowerCase() != 'pending') return false;
        if (widget.tableId != null) {
          return o.tableId == widget.tableId;
        }
        if (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty) {
          return o.tableId == null &&
              o.deliveryMethodId == widget.preselectedDeliveryMethodId;
        }
        return false;
      }).toList();
      for (final draft in staleDrafts) {
        localProductProvider.deleteSavedOrder(draft.id);
      }
    }

    _refreshLocalDrafts();
  }

  Future<void> _updateSavedItemPrice(
      dynamic cartItem, String newPriceStr) async {
    final newPrice = double.tryParse(newPriceStr);
    if (newPrice == null || newPrice < 0) {
      showScaffoldError(context: context, message: 'Invalid price');
      return;
    }

    // Determine cartItemId
    final cartItemId = cartItem['id'];
    if (cartItemId == null) {
      showScaffoldError(context: context, message: 'Item ID not found');
      return;
    }

    setState(() {
      _loadingCartItems.add('${cartItemId}_price');
      // _isLoadingOrderDetails = true; // Removed full loader
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      debugPrint(
          '🔄 Updating saved item price: Item $cartItemId to $newPriceStr');

      final response = await cartProvider.updateCartItemPrice(
        cartItemId: int.parse(cartItemId.toString()),
        unitPrice: newPriceStr,
        accessToken: authModel.token ?? '',
        // Pass cartId and customerId if available/needed
        cartId: _selectedOrder['cart']?['id'] ?? _selectedOrder['cart_id'],
        customerId: _selectedOrder['customer_id'] ??
            _selectedOrder['cart']?['customer_id'],
      );

      if (isApiSuccess(response)) {
        debugPrint('✅ Price updated successfully');
        showScaffold(context: context, message: 'Price updated successfully');

        // Refresh the order to show new price
        await _refreshSelectedOrderAfterCartUpdate();
      } else {
        debugPrint('❌ Price update failed: ${response['message']}');
        showScaffoldError(
            context: context,
            message: response['message'] ?? 'Failed to update price');
      }
    } catch (e) {
      debugPrint('❌ Exception updating price: $e');
      showScaffoldError(context: context, message: 'Error updating price: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingCartItems.remove('${cartItemId}_price');
          // _isLoadingOrderDetails = false; // Removed full loader
        });
      }
    }
  }

  void _showEditItemPriceDialog(dynamic cartItem, {bool isLocal = false}) {
    final double price = isLocal
        ? (cartItem as LocalCartItem).price ?? 0.0
        : (double.tryParse((cartItem['unit_price'] ?? cartItem['price'] ?? 0)
                .toString()) ??
            0.0);

    final String productName = isLocal
        ? (cartItem as LocalCartItem).product.productName ?? 'Item'
        : (cartItem['product']?['name'] ?? cartItem['product_name'] ?? 'Item');

    final TextEditingController priceController =
        TextEditingController(text: price.toStringAsFixed(2));

    // Auto-select all text when dialog opens
    priceController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: priceController.text.length,
    );

    void handleUpdate() {
      Navigator.pop(context);
      final newPriceStr = priceController.text;
      final newPrice = double.tryParse(newPriceStr);

      if (newPrice != null && newPrice >= 0) {
        if (isLocal) {
          // Update Local Item
          final localItem = cartItem as LocalCartItem;
          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);
          localProductProvider.updateItemPrice(
            localItem.product.productId!,
            localItem.selectedStock,
            newPrice,
            stockGroupIds: localItem.stockGroupIds,
            saleUnitId: localItem.saleUnitId,
          );
        } else {
          // Update Saved Item
          _updateSavedItemPrice(cartItem, newPriceStr);
        }
      } else {
        showScaffoldError(context: context, message: 'Invalid price');
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.edit, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Edit Price',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18,
                    0.21, const Color(0xFF1E293B)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Current Price: ${price.toStringAsFixed(2)}',
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                    0.21, const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: priceController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => handleUpdate(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.21, const Color(0xFF1E293B)),
                decoration: InputDecoration(
                  labelText: 'New Unit Price',
                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                  prefixText: ' ',
                  prefixStyle: const TextStyle(
                      color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Provider.of<KeyboardProvider>(context, listen: false)
                      .show('numeric', priceController);
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s14, 0.21, const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Update',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s14, 0.21, Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedOrderItem(dynamic cartItem, int index) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

    final productName = cartItem['product']?['name'] ??
        cartItem['product_name'] ??
        cartItem['names']?[0]?['name'] ??
        'Unknown Product';
    final quantity = double.tryParse(cartItem['quantity'].toString()) ?? 0.0;
    final unitPrice = double.tryParse(cartItem['unit_price'].toString()) ?? 0.0;
    final totalPrice = double.tryParse(cartItem['total_price'].toString()) ??
        (quantity * unitPrice);

    final status = cartItem['status']?.toString();
    final statusUpper = (status ?? '').toUpperCase();
    final hasStarted = statusUpper == 'PREPARING' ||
        statusUpper == 'COOKING' ||
        statusUpper == 'IN_PROGRESS' ||
        statusUpper == 'READY' ||
        statusUpper == 'SERVED' ||
        statusUpper == 'COMPLETED';
    final isRemovable = !hasStarted;
    final statusText = _statusTextForDisplay(status);

    // Highlight newly added item: matches product ID and has no status yet
    final cartItemProductId = cartItem['product_id']?.toString() ??
        cartItem['product']?['id']?.toString();
    final isHighlighted = _highlightedCartItemProductId != null &&
        cartItemProductId == _highlightedCartItemProductId.toString() &&
        status == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFF059669).withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF059669) : Colors.grey.shade200,
          width: isHighlighted ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  productName,
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      widget.isCompact ? FontSize.s13 : FontSize.s15,
                      0.21,
                      const Color(0xFF1E293B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$currency ${totalPrice.toStringAsFixed(2)}',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          widget.isCompact ? FontSize.s12 : FontSize.s14,
                          0.21,
                          const Color(0xFF059669)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _statusColor(status).withOpacity(0.4)),
                    ),
                    child: Text(
                      statusText,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s10 : FontSize.s11,
                        0.21,
                        _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit price and quantity info
          Row(
            children: [
              // Editable Price for Saved Items (Tap to edit)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadingCartItems.contains('${cartItem['id']}_price')
                      ? null
                      : () =>
                          _showEditItemPriceDialog(cartItem, isLocal: false),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.withOpacity(0.05),
                    ),
                    child: _loadingCartItems.contains('${cartItem['id']}_price')
                        ? SizedBox(
                            width: widget.isCompact ? 16 : 18,
                            height: widget.isCompact ? 16 : 18,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2563EB),
                              ),
                            ),
                          )
                        : Text(
                            '$currency ${unitPrice.toStringAsFixed(2)}',
                            style: buildCustomStyle(
                                FontWeightManager.bold,
                                widget.isCompact ? FontSize.s11 : FontSize.s12,
                                0.21,
                                const Color(0xFF2563EB)),
                          ),
                  ),
                ),
              ),
              Text(
                ' × ${quantity.toStringAsFixed(0)}',
                style: buildCustomStyle(
                    FontWeightManager.medium,
                    widget.isCompact ? FontSize.s11 : FontSize.s12,
                    0.21,
                    const Color(0xFF64748B)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity controls with modern styling (for saved orders, these will use cart API)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                    .contains('${cartItem['id']}_decrease') ||
                                !isRemovable
                            ? null
                            : () => _updateCartItemQuantityWithLoading(
                                cartItem, quantity - 1, 'decrease'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_decrease')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFDC2626),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.remove,
                                  size: widget.isCompact ? 16 : 18,
                                  color: isRemovable
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                ),
                        ),
                      ),
                    ),
                    Container(
                      width: widget.isCompact ? 32 : 40,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toStringAsFixed(0),
                        style: buildCustomStyle(
                            FontWeightManager.bold,
                            widget.isCompact ? FontSize.s14 : FontSize.s16,
                            0.21,
                            const Color(0xFF1E293B)),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_increase')
                            ? null
                            : () => _updateCartItemQuantityWithLoading(
                                cartItem, quantity + 1, 'increase'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_increase')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF059669),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.add,
                                  size: widget.isCompact ? 16 : 18,
                                  color: const Color(0xFF059669),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Comment and Remove buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartItem['comment'] != null &&
                      cartItem['comment'].toString().isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.isCompact ? 90 : 130,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          cartItem['comment'].toString(),
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s11,
                            0.21,
                            const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  // Comment button for saved order item
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _showItemCommentDialog(cartItem, isLocal: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? Icons.chat
                              : Icons.chat_bubble_outline,
                          size: widget.isCompact ? 16 : 18,
                          color: (cartItem['comment'] != null &&
                                  cartItem['comment'].toString().isNotEmpty)
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  if (isRemovable) ...[
                    const SizedBox(width: 8),
                    // Remove button with modern styling
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_remove')
                            ? null
                            : () => _removeCartItemWithLoading(cartItem),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _loadingCartItems
                                  .contains('${cartItem['id']}_remove')
                              ? SizedBox(
                                  width: widget.isCompact ? 16 : 18,
                                  height: widget.isCompact ? 16 : 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFDC2626),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.delete_outline,
                                  size: widget.isCompact ? 16 : 18,
                                  color: const Color(0xFFDC2626),
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Public method to force switch to Current Order tab
  void showCurrentOrderTab() {
    setState(() {
      _selectedOrder = null;
      _isLoadingOrders = false;
      _isLoadingOrderDetails = false;
      _error = null;
      _orderComment = '';
      _loadedLocalDraftId = null;
    });
    widget.onOrderSelected(null);
  }
}
