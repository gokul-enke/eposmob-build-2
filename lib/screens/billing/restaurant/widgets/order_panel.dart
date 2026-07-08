import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/cart_item_status.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import '../../../../components/build_container_box.dart';
import '../../../../components/build_confirmation_dialog.dart';
import '../../../../components/build_dialog_box.dart';
import '../../../../components/build_round_button.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';
import '../../../../screens/customers/add_customer_modal.dart';
import '../../../../features/billing/presentation/widgets/payment_method_modal.dart';
import '../../../../providers/keyboard_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/checkout_modal.dart';
import 'package:pos_machine/screens/print/print_kot.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/billing/restaurant/utils/restaurant_helpers.dart';

part 'order_panel_current_cart.dart';
part 'order_panel_saved_order_item.dart';

enum OrderPanelTab { cart, saved, ongoing }

class OrderPanel extends StatefulWidget {
  final String? tableId;
  final bool isCompact;
  final Size screenSize;
  final VoidCallback onSendToKitchen; // New callback for send to kitchen
  final VoidCallback onNewOrder; // New callback for new order
  final VoidCallback
      onPrintOrder; // New callback for print order (send + print)
  final VoidCallback? onKotBill;
  final Function(dynamic)
      onOrderSelected; // New callback to update selected order
  final dynamic
      selectedOrderFromParent; // Add this to track parent's selected order
  final int? refreshCounter; // Add refresh counter
  final bool isLoadingSendToKitchen; // Loading state for Send to Kitchen button
  final bool isLoadingPrint; // Loading state for Print button
  final bool isLoadingKotBill;
  final String?
      preselectedDeliveryMethodId; // Delivery method chosen from tables panel
  final String?
      preselectedDeliveryMethodName; // Name of preselected delivery method
  final bool allowCounterBilling;
  final bool isCounterBillingMode;
  final ValueChanged<SavedOrder>? onLocalDraftLoaded;
  final VoidCallback? onLocalDraftSaved;
  final VoidCallback? onEditedOrderConfirmed;

  /// Store mode: hide the footer action buttons (Send Kitchen, KOT + BILL,
  /// Confirm, Print KOT, comment, ...) and show only the payment summary.
  final bool hideFooterActionButtons;

  /// Store mode: hide the "Ongoing" tab from the panel tab bar.
  final bool hideOngoingOrdersTab;
  final void Function({
    required bool isLoading,
    required bool printBill,
  })? onCheckoutActionLoadingChanged;

  const OrderPanel({
    super.key, // Add key parameter
    required this.tableId,
    this.isCompact = false,
    required this.screenSize,
    required this.onSendToKitchen, // Make it required
    required this.onNewOrder, // Make it required
    required this.onPrintOrder, // Make it required
    this.onKotBill,
    required this.onOrderSelected, // Make it required
    this.selectedOrderFromParent, // Add this parameter
    this.refreshCounter, // Add refresh counter parameter
    this.isLoadingSendToKitchen = false, // Add loading state parameter
    this.isLoadingPrint = false, // Add loading state parameter for print
    this.isLoadingKotBill = false,
    this.preselectedDeliveryMethodId, // Preselected delivery method from tables panel
    this.preselectedDeliveryMethodName, // Name of preselected delivery method
    this.allowCounterBilling = false,
    this.isCounterBillingMode = false,
    this.onLocalDraftLoaded,
    this.onLocalDraftSaved,
    this.onEditedOrderConfirmed,
    this.onCheckoutActionLoadingChanged,
    this.hideFooterActionButtons = false,
    this.hideOngoingOrdersTab = false,
  });

  @override
  State<OrderPanel> createState() => OrderPanelState();
}

class OrderPanelState extends State<OrderPanel> {
  dynamic _selectedOrder;
  List<dynamic> _savedOrders = [];
  List<SavedOrder> _localDrafts = [];
  bool _isLoadingOrders = false;
  bool _isLoadingOngoingOrders = false;
  bool _isLoadingOrderDetails = false;
  String? _error;
  final Set<String> _loadingCartItems =
      {}; // Track which cart items are being updated
  bool _isLoadingConfirm = false; // Loading state for Confirm button
  bool _isLoadingPrintKot =
      false; // Loading state for edit-order Print KOT button
  bool _isLoadingPreBill = false;
  String? _loadedLocalDraftId; // track currently loaded local draft
  bool _blockReselectAfterPlace = false; // Prevent reselect after order placed
  bool _showSavedOrdersView = false;
  bool _forceCounterCartView = false;
  OrderPanelTab _activeOrderPanelTab = OrderPanelTab.cart;
  bool _hasOpenedOngoingOrdersTab = false;
  int _lastObservedCartCount = 0;
  final FocusNode _orderPanelTabsFocusNode = FocusNode();
  final FocusNode _currentCartItemsFocusNode = FocusNode();
  final ScrollController _currentCartItemsScrollController = ScrollController();
  int _focusedOrderPanelTabIndex = 0;
  int? _focusedCurrentCartItemIndex;

  bool get _usesCounterOrderTabs =>
      widget.allowCounterBilling && widget.isCounterBillingMode;

  bool get _isSelectedDeliveryMethodDineIn {
    final selectedId = widget.preselectedDeliveryMethodId?.trim();
    final selectedName = widget.preselectedDeliveryMethodName?.trim();
    if ((selectedId == null || selectedId.isEmpty) &&
        (selectedName == null || selectedName.isEmpty)) {
      return false;
    }

    final deliveryMethods =
        Provider.of<DeliveryMethodsProvider>(context, listen: false)
            .deliveryMethods;

    DeliveryMethod? selectedMethod;
    for (final method in deliveryMethods) {
      if (selectedId != null &&
          selectedId.isNotEmpty &&
          method.id == selectedId) {
        selectedMethod = method;
        break;
      }
    }

    final code = selectedMethod?.code ?? '';
    final name = selectedMethod?.name ?? selectedName ?? '';
    return _normalizesAsDineIn(code) || _normalizesAsDineIn(name);
  }

  bool _normalizesAsDineIn(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'dinein';
  }

  bool get isViewingCounterListTab =>
      _usesCounterOrderTabs && _activeOrderPanelTab != OrderPanelTab.cart;

  bool get _skipCheckoutOnCounterConfirmAndPrint {
    if (!widget.allowCounterBilling || !widget.isCounterBillingMode) {
      return false;
    }
    return Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.skipCheckoutOnConfirmAndPrint ??
        false;
  }

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
  String _deliveryMethod = "";
  String _deliveryMethodId = "";
  String _deliveryAddress = "";
  String _carNumber = "";
  String? _deliveryDate;
  String? _deliveryTime;
  double? _selectedDeliveryCharge;

  // Expose current comment to parent (RestaurantPage) for new order flow
  String get orderComment => _orderComment;
  String? get loadedLocalDraftId => _loadedLocalDraftId;
  String? get selectedCustomerNameForDraft => _selectedCustomer?.name;
  int? get selectedCustomerIdForDraft =>
      _selectedCustomer?.id ?? _selectedCustomerID;
  String? get selectedCustomerPhoneForDraft =>
      _selectedCustomer?.phone ?? _selectedCustomerPhone;
  String? get selectedCustomerTypeForDraft => _selectedCustomer?.customerType;
  String get selectedDeliveryMethodForDraft => _deliveryMethod;
  String get selectedDeliveryMethodIdForDraft => _deliveryMethodId;
  String get deliveryMethodForDraft => _deliveryMethod;
  String get deliveryMethodIdForDraft => _deliveryMethodId.isNotEmpty
      ? _deliveryMethodId
      : _getDefaultDeliveryMethodId();
  String? get deliveryDateForDraft => _deliveryDate;
  String? get deliveryTimeForDraft => _deliveryTime;
  String? get deliveryAddressForDraft =>
      _deliveryAddress.isNotEmpty ? _deliveryAddress : null;
  String? get carNumberForDraft =>
      _carNumber.trim().isNotEmpty ? _carNumber.trim() : null;
  double get deliveryChargeForDraft => _getDeliveryChargeForOrder();
  bool get toCustomerCreditForDraft => _toCustomerCreditEnabled;
  String? get transactionNumberForDraft =>
      _transactionNumber.isNotEmpty ? _transactionNumber : null;
  String? get couponIdForDraft => _couponCode.isNotEmpty ? _couponCode : null;
  String? get balanceAmountForDraft => _balanceAmount.toString();
  String? get paymentMethodForDraft =>
      _getLocalDraftPaymentData()['paymentMethod'];
  String? get paidAmountForDraft => _getLocalDraftPaymentData()['paidAmount'];
  String? get selectedCustomerAlternatePhoneForDraft =>
      _firstNonEmptyString([_selectedCustomer?.altPhone]);
  String? get selectedCustomerVatNumberForDraft =>
      _extractCustomerKycValue(_selectedCustomer, 'VAT NUMBER');
  String? get selectedCustomerCrNumberForDraft =>
      _extractCustomerKycValue(_selectedCustomer, 'CR NUMBER');

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

    // Load saved orders and local drafts when the widget is first created with
    // a table/delivery context. Counter mode can show all local drafts before a
    // context is selected.
    if (widget.tableId != null ||
        (widget.preselectedDeliveryMethodId != null &&
            widget.preselectedDeliveryMethodId!.isNotEmpty) ||
        _usesCounterOrderTabs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.tableId != null ||
            (widget.preselectedDeliveryMethodId != null &&
                widget.preselectedDeliveryMethodId!.isNotEmpty)) {
          _fetchSavedOrders(
            showFullPanelLoader: _activeOrderPanelTab != OrderPanelTab.ongoing,
          );
        }
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
    _orderPanelTabsFocusNode.dispose();
    _currentCartItemsFocusNode.dispose();
    _currentCartItemsScrollController.dispose();
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
      if (_selectedOrder != null) {
        _applyCurrentContextToSelectedOrder();
        return;
      }

      setState(() {
        _showSavedOrdersView =
            _usesCounterOrderTabs && _activeOrderPanelTab != OrderPanelTab.cart;
      });
      if (widget.tableId != null ||
          (widget.preselectedDeliveryMethodId != null &&
              widget.preselectedDeliveryMethodId!.isNotEmpty) ||
          _usesCounterOrderTabs) {
        if (widget.tableId != null ||
            (widget.preselectedDeliveryMethodId != null &&
                widget.preselectedDeliveryMethodId!.isNotEmpty)) {
          _fetchSavedOrders(
            showFullPanelLoader: _activeOrderPanelTab != OrderPanelTab.ongoing,
          );
        }
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
          _deliveryMethod = '';
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

  void _applyCurrentContextToSelectedOrder() {
    setState(() {
      if (widget.tableId != null && widget.tableId!.isNotEmpty) {
        _deliveryMethodId = '';
        _deliveryMethod = '';
        if (_selectedOrder is Map) {
          _selectedOrder['table_id'] = widget.tableId;
          _selectedOrder['delivery_method_id'] = null;
          _selectedOrder['delivery_method_name'] = null;
          _selectedOrder['delivery_method'] = null;
          final orderProps = _selectedOrder['orderProps'];
          if (orderProps is Map) {
            orderProps['TABLE'] = widget.tableId;
          }
        }
      } else if (widget.preselectedDeliveryMethodId != null &&
          widget.preselectedDeliveryMethodId!.isNotEmpty) {
        _deliveryMethodId = widget.preselectedDeliveryMethodId!;
        _deliveryMethod =
            widget.preselectedDeliveryMethodName ?? 'Store Takeaway';
        if (_selectedOrder is Map) {
          _selectedOrder['table_id'] = null;
          _selectedOrder['delivery_method_id'] = _deliveryMethodId;
          _selectedOrder['delivery_method_name'] = _deliveryMethod;
          _selectedOrder['delivery_method'] = _deliveryMethod;
          final orderProps = _selectedOrder['orderProps'];
          if (orderProps is Map) {
            orderProps.remove('TABLE');
          }
        }
      }
    });
    widget.onOrderSelected(_selectedOrder);
  }

  Future<void> _fetchSavedOrders({
    bool showFullPanelLoader = true,
    bool ignoreContextFilter = false,
  }) async {
    setState(() {
      if (showFullPanelLoader) {
        _isLoadingOrders = true;
      } else {
        _isLoadingOngoingOrders = true;
      }
      _savedOrders = [];
      _selectedOrder = null;
      _error = null;
    });
    widget.onOrderSelected(null);

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final tableFilter = ignoreContextFilter ? null : widget.tableId;
    final deliveryMethodFilter = ignoreContextFilter
        ? null
        : (widget.tableId == null ? widget.preselectedDeliveryMethodId : null);

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ _fetchSavedOrders: Sending request with tableId: ${widget.tableId}, deliveryMethodId: ${widget.preselectedDeliveryMethodId}');
    try {
      debugPrint(
          'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.listSavedOrders');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: tableFilter,
        deliveryMethodId: deliveryMethodFilter,
      );
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ listSavedOrders Response: $response');
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
        if (showFullPanelLoader) {
          _isLoadingOrders = false;
        } else {
          _isLoadingOngoingOrders = false;
        }
      });
    }
  }

  // Public method to refresh saved orders from external calls
  void refreshSavedOrders() {
    if (widget.tableId != null ||
        widget.preselectedDeliveryMethodId != null ||
        _usesCounterOrderTabs) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ External refresh of saved orders triggered for table: ${widget.tableId}, delivery: ${widget.preselectedDeliveryMethodId}');
      if (widget.tableId != null ||
          (widget.preselectedDeliveryMethodId != null &&
              widget.preselectedDeliveryMethodId!.isNotEmpty)) {
        _fetchSavedOrders();
      }
      _refreshLocalDrafts();
    }
  }

  void focusOrderPanelTabs() {
    _focusedOrderPanelTabIndex = _tabIndexFor(_activeOrderPanelTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _orderPanelTabsFocusNode.requestFocus();
      setState(() {});
    });
  }

  void _focusCurrentCartItems(List<LocalCartItem> cartItems) {
    if (cartItems.isEmpty) return;
    setState(() {
      _focusedCurrentCartItemIndex =
          (_focusedCurrentCartItemIndex ?? 0).clamp(0, cartItems.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _currentCartItemsFocusNode.requestFocus();
      _scrollFocusedCurrentCartItemIntoView();
    });
  }

  int _tabIndexFor(OrderPanelTab tab) {
    return switch (tab) {
      OrderPanelTab.cart => 0,
      OrderPanelTab.saved => 1,
      OrderPanelTab.ongoing => 2,
    };
  }

  int get _maxOrderPanelTabIndex => widget.hideOngoingOrdersTab ? 1 : 2;

  OrderPanelTab _tabForIndex(int index) {
    return switch (index.clamp(0, _maxOrderPanelTabIndex)) {
      0 => OrderPanelTab.cart,
      1 => OrderPanelTab.saved,
      _ => OrderPanelTab.ongoing,
    };
  }

  KeyEventResult _handleOrderPanelTabsKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _focusedOrderPanelTabIndex =
            (_focusedOrderPanelTabIndex + 1).clamp(0, _maxOrderPanelTabIndex);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _focusedOrderPanelTabIndex =
            (_focusedOrderPanelTabIndex - 1).clamp(0, _maxOrderPanelTabIndex);
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _selectOrderPanelTab(_tabForIndex(_focusedOrderPanelTabIndex));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _tabForIndex(_focusedOrderPanelTabIndex) == OrderPanelTab.cart) {
      final cartItems = Provider.of<LocalProductProvider>(
        context,
        listen: false,
      ).getCartItems();
      _selectOrderPanelTab(OrderPanelTab.cart);
      _focusCurrentCartItems(cartItems);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCurrentCartItemsKey(
    KeyEvent event,
    List<LocalCartItem> cartItems,
  ) {
    if (event is! KeyDownEvent || cartItems.isEmpty) {
      return KeyEventResult.ignored;
    }
    final maxIndex = cartItems.length - 1;
    final currentIndex = (_focusedCurrentCartItemIndex ?? 0).clamp(0, maxIndex);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedCurrentCartItemIndex = (currentIndex + 1).clamp(0, maxIndex);
      });
      _scrollFocusedCurrentCartItemIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (currentIndex == 0) {
        focusOrderPanelTabs();
        return KeyEventResult.handled;
      }
      setState(() {
        _focusedCurrentCartItemIndex = (currentIndex - 1).clamp(0, maxIndex);
      });
      _scrollFocusedCurrentCartItemIntoView();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        event.character == '+') {
      final item = cartItems[currentIndex];
      _updateCurrentCartItemQuantity(item, item.quantity + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract ||
        event.character == '-') {
      final item = cartItems[currentIndex];
      _updateCurrentCartItemQuantity(item, item.quantity - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete) {
      _removeCurrentCartItem(cartItems[currentIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _showItemCommentDialog(cartItems[currentIndex], isLocal: true);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _scrollFocusedCurrentCartItemIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_currentCartItemsScrollController.hasClients ||
          _focusedCurrentCartItemIndex == null) {
        return;
      }
      final target = (_focusedCurrentCartItemIndex! * 150.0).clamp(
        0.0,
        _currentCartItemsScrollController.position.maxScrollExtent,
      );
      _currentCartItemsScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectOrderPanelTab(OrderPanelTab tab) {
    if (tab == OrderPanelTab.cart) {
      setState(() {
        _activeOrderPanelTab = OrderPanelTab.cart;
        _focusedOrderPanelTabIndex = 0;
        _showSavedOrdersView = false;
        _forceCounterCartView = true;
      });
      return;
    }

    if (tab == OrderPanelTab.saved) {
      _refreshLocalDrafts();
      setState(() {
        _activeOrderPanelTab = OrderPanelTab.saved;
        _focusedOrderPanelTabIndex = 1;
        _showSavedOrdersView = true;
        _forceCounterCartView = false;
      });
      return;
    }

    final shouldLoadAll = !_hasOpenedOngoingOrdersTab;
    setState(() {
      _activeOrderPanelTab = OrderPanelTab.ongoing;
      _focusedOrderPanelTabIndex = 2;
      _hasOpenedOngoingOrdersTab = true;
      _showSavedOrdersView = true;
      _forceCounterCartView = false;
    });
    _fetchSavedOrders(
      showFullPanelLoader: false,
      ignoreContextFilter: shouldLoadAll,
    );
  }

  String? _normalizeOrderLookupValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  bool _orderMatchesLookup(
    dynamic order,
    String? orderId,
    String? orderNumber,
  ) {
    if (order is! Map) return false;

    if (orderId != null) {
      final candidateIds = <dynamic>[
        order['order_id'],
        order['id'],
      ];
      final nestedOrder = order['order'];
      if (nestedOrder is Map) {
        candidateIds.add(nestedOrder['order_id']);
        candidateIds.add(nestedOrder['id']);
      }

      for (final id in candidateIds) {
        if (_normalizeOrderLookupValue(id) == orderId) return true;
      }
    }

    if (orderNumber != null) {
      final candidateNumbers = <dynamic>[
        order['order_number'],
        order['display_order_id'],
      ];
      final nestedOrder = order['order'];
      if (nestedOrder is Map) {
        candidateNumbers.add(nestedOrder['order_number']);
        candidateNumbers.add(nestedOrder['display_order_id']);
      }

      for (final number in candidateNumbers) {
        if (_normalizeOrderLookupValue(number) == orderNumber) return true;
      }
    }

    return false;
  }

  dynamic _findSavedOrderByLookup(String? orderId, String? orderNumber) {
    for (final order in _savedOrders) {
      if (_orderMatchesLookup(order, orderId, orderNumber)) {
        return order;
      }
    }
    return null;
  }

  bool _orderHasEditableShape(dynamic order) {
    if (order is! Map) return false;
    if (order['cart_items'] is List) return true;
    if (order['order_items'] is List) return true;
    if (order['items'] is List) return true;

    final cartItems = order['cart_items'];
    if (cartItems is Map && cartItems['cart_items'] is List) return true;

    final cart = order['cart'];
    if (cart is Map && (cart['cart_items'] is List || cart['items'] is List)) {
      return true;
    }

    return false;
  }

  Future<dynamic> _fetchOrderDetailsForLookup(
    String? orderId,
    String? orderNumber,
  ) async {
    final lookupOrderId = orderId ?? orderNumber;
    if (lookupOrderId == null) return null;

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final response = await cartProvider.getListOrderDetails(
        accessToken: authModel.token ?? '',
        orderId: lookupOrderId,
      );
      if (!mounted) return null;

      if ((response['status'] as String?)?.toLowerCase() != 'success') {
        debugPrint(
          '[Counter KOT] Order detail lookup failed: ${response['message']}',
        );
        return null;
      }

      final orderDetails = response['order_details'];
      if (orderDetails is Map) {
        setState(() {
          _savedOrders = [
            orderDetails,
            ..._savedOrders.where(
              (order) => !_orderMatchesLookup(order, orderId, orderNumber),
            ),
          ];
        });
        return orderDetails;
      }
    } catch (e) {
      debugPrint('[Counter KOT] Order detail lookup error: $e');
    }

    return null;
  }

  Future<bool> openCreatedOrderForEditing({
    String? orderId,
    String? orderNumber,
    dynamic seedOrder,
  }) async {
    final seedMap = seedOrder is Map ? seedOrder : null;
    final targetOrderId = _normalizeOrderLookupValue(orderId) ??
        _normalizeOrderLookupValue(seedMap?['order_id']) ??
        _normalizeOrderLookupValue(seedMap?['id']);
    final targetOrderNumber = _normalizeOrderLookupValue(orderNumber) ??
        _normalizeOrderLookupValue(seedMap?['order_number']) ??
        _normalizeOrderLookupValue(seedMap?['display_order_id']);

    if (targetOrderId == null && targetOrderNumber == null) {
      debugPrint(
        '[Counter KOT] Cannot open created order: missing order id/number',
      );
      return false;
    }

    debugPrint(
      '[Counter KOT] Opening created order id=$targetOrderId number=$targetOrderNumber',
    );

    if (!mounted) return false;
    setState(() {
      _activeOrderPanelTab = OrderPanelTab.ongoing;
      _focusedOrderPanelTabIndex = 2;
      _hasOpenedOngoingOrdersTab = true;
      _showSavedOrdersView = true;
      _forceCounterCartView = false;
    });

    dynamic orderToOpen =
        _findSavedOrderByLookup(targetOrderId, targetOrderNumber);
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 350),
      Duration(milliseconds: 900),
    ];

    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      if (orderToOpen != null) break;
      if (attempt > 0) {
        await Future.delayed(retryDelays[attempt]);
      }
      if (!mounted) return false;

      await _fetchSavedOrders(
        showFullPanelLoader: false,
        ignoreContextFilter: _usesCounterOrderTabs,
      );
      if (!mounted) return false;

      orderToOpen = _findSavedOrderByLookup(
        targetOrderId,
        targetOrderNumber,
      );
    }

    orderToOpen ??= await _fetchOrderDetailsForLookup(
      targetOrderId,
      targetOrderNumber,
    );
    if (orderToOpen == null && _orderHasEditableShape(seedOrder)) {
      orderToOpen = seedOrder;
    }

    if (orderToOpen == null) {
      debugPrint(
        '[Counter KOT] Created order was not found in ongoing orders',
      );
      return false;
    }

    await _fetchOrderDetails(orderToOpen);
    return true;
  }

  // Public method to refresh saved orders silently (no loading spinner)
  Future<void> refreshSavedOrdersSilently() async {
    if (widget.tableId != null ||
        widget.preselectedDeliveryMethodId != null ||
        _usesCounterOrderTabs) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ External silent refresh of saved orders triggered for table: ${widget.tableId}, delivery: ${widget.preselectedDeliveryMethodId}');
      if (widget.tableId != null ||
          (widget.preselectedDeliveryMethodId != null &&
              widget.preselectedDeliveryMethodId!.isNotEmpty)) {
        await _refreshSavedOrdersSilently();
      }
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€Ã¢â‚¬Å¡ÃƒÂ¯Ã‚Â¸Ã‚Â Restaurant order panel hydrated customers from provider cache: ${_customers.length}');
  }

  void _refreshCustomersInBackgroundAfterSale() {
    if (!mounted) return;
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Refreshing customers in background after successful confirm (restaurant order panel)');

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
            'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Background customer refresh failed after confirm (restaurant order panel): $e');
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

  CustomerListModelData? _buildDraftCustomerFallback(SavedOrder order) {
    final hasCustomerData = order.customerId != null ||
        (order.customerName?.trim().isNotEmpty ?? false) ||
        (order.customerPhone?.trim().isNotEmpty ?? false);
    if (!hasCustomerData) return null;

    final kyc = <Kyc>[];
    if (order.customerCrNumber?.trim().isNotEmpty ?? false) {
      kyc.add(Kyc(key: 'CR NUMBER', value: order.customerCrNumber!.trim()));
    }
    if (order.customerVatNumber?.trim().isNotEmpty ?? false) {
      kyc.add(Kyc(key: 'VAT NUMBER', value: order.customerVatNumber!.trim()));
    }

    return CustomerListModelData(
      id: order.customerId,
      name: order.customerName,
      phone: order.customerPhone,
      altPhone: order.alternatePhone,
      customerType: order.customerType,
      address: order.address,
      kyc: kyc.isNotEmpty ? kyc : null,
    );
  }

  String? _extractCustomerKycValue(
    CustomerListModelData? customer,
    String key,
  ) {
    if (customer?.kyc == null) return null;
    final normalizedKey = key.trim().toUpperCase();
    for (final item in customer!.kyc!) {
      if ((item.key ?? '').trim().toUpperCase() == normalizedKey) {
        final value = item.value?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  void _rehydrateLocalDraftMetadata(SavedOrder order) {
    final matchedCustomer =
        _resolveDraftCustomer(order) ?? _buildDraftCustomerFallback(order);
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

      _orderComment = this._cleanDraftComment(order.comment);
      _deliveryMethod = order.deliveryMethod ?? 'Store Takeaway';
      _deliveryMethodId =
          order.deliveryMethodId ?? _getDefaultDeliveryMethodId();
      _deliveryAddress = order.address ?? '';
      _carNumber = order.carNumber ?? '';
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
      _toCustomerCreditAmount = _toCustomerCreditEnabled ? debitAmount : 0.0;

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
    final customerPhone = phone?.trim() ?? '';
    if (customerPhone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone = appSettingsProvider
            .appSettings?.autoAssignDefaultCustomerPhone
            .trim() ??
        '';
    return defaultPhone.isNotEmpty && customerPhone == defaultPhone;
  }

  bool _isDefaultCustomer(CustomerListModelData? customer) {
    if (customer == null) return false;

    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final selectedCustomer = customerSelectionProvider.selectedCustomer;
    final customerPhone = customer.phone?.trim();
    final selectedPhone = selectedCustomer?.phone?.trim();

    if (customerSelectionProvider.isDefaultCustomer &&
        ((customer.id != null && selectedCustomer?.id == customer.id) ||
            (customerPhone?.isNotEmpty == true &&
                selectedPhone == customerPhone))) {
      return true;
    }

    return _isDefaultCustomerPhone(customer.phone);
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

  Map<dynamic, dynamic>? _asOrderMap(dynamic value) {
    return value is Map ? value : null;
  }

  dynamic _readOrderPath(dynamic source, List<String> path) {
    dynamic current = source;
    for (final key in path) {
      final map = _asOrderMap(current);
      if (map == null) return null;
      current = map[key];
    }
    return current;
  }

  String? _cleanOrderText(dynamic value) {
    final text = _firstNonEmptyString([value]);
    if (text == null) return null;
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      return text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  int? _parseOrderInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(_cleanOrderText(value) ?? '');
  }

  String? _extractOrderPropValue(dynamic order, String propCode) {
    final normalizedCode = propCode.trim().toUpperCase();
    final propsMap = _readOrderPath(order, ['orderProps']);
    if (propsMap is Map) {
      for (final entry in propsMap.entries) {
        if (entry.key.toString().trim().toUpperCase() == normalizedCode) {
          return _cleanOrderText(entry.value);
        }
      }
    }

    final propsList = _readOrderPath(order, ['order_props']);
    if (propsList is List) {
      for (final prop in propsList) {
        final propMap = _asOrderMap(prop);
        if (propMap == null) continue;
        final code = _cleanOrderText(propMap['props_code'] ?? propMap['code'])
            ?.toUpperCase();
        if (code != normalizedCode) continue;
        return _cleanOrderText(propMap['props_value'] ?? propMap['value']);
      }
    }

    return null;
  }

  int? _extractOrderCustomerId(dynamic order) {
    return _parseOrderInt(_firstNonEmptyString([
      _readOrderPath(order, ['customer_details', 'customer_id']),
      _readOrderPath(order, ['customer', 'customer_id']),
      _readOrderPath(order, ['customer', 'id']),
      _readOrderPath(order, ['cart', 'customer_id']),
      _readOrderPath(order, ['order', 'customer_details', 'customer_id']),
      _readOrderPath(order, ['order', 'customer_id']),
      _readOrderPath(order, ['customer_id']),
    ]));
  }

  String? _extractOrderCustomerPhone(dynamic order) {
    return _firstNonEmptyString([
      _readOrderPath(order, ['customer_details', 'phone']),
      _readOrderPath(order, ['customer', 'phone']),
      _readOrderPath(order, ['user', 'phone']),
      _readOrderPath(order, ['cart', 'customer_phone']),
      _readOrderPath(order, ['order', 'customer_details', 'phone']),
      _readOrderPath(order, ['order', 'customer_phone']),
      _readOrderPath(order, ['customer_phone']),
      _readOrderPath(order, ['phone']),
    ]);
  }

  String? _extractOrderCustomerName(dynamic order) {
    return _firstNonEmptyString([
      _readOrderPath(order, ['customer_details', 'name']),
      _readOrderPath(order, ['customer', 'name']),
      _readOrderPath(order, ['user', 'name']),
      _readOrderPath(order, ['order', 'customer_details', 'name']),
      _readOrderPath(order, ['order', 'customer_name']),
      _readOrderPath(order, ['customer_name']),
      _readOrderPath(order, ['name']),
    ]);
  }

  String? _extractOrderCustomerType(dynamic order) {
    return _firstNonEmptyString([
      _readOrderPath(order, ['customer_details', 'customer_type']),
      _readOrderPath(order, ['customer', 'customer_type']),
      _readOrderPath(order, ['order', 'customer_details', 'customer_type']),
      _readOrderPath(order, ['customer_type']),
    ]);
  }

  String? _extractOrderCustomerAlternatePhone(dynamic order) {
    return _firstNonEmptyString([
      _readOrderPath(order, ['customer_details', 'alternate_phone']),
      _readOrderPath(order, ['customer_details', 'alt_phone']),
      _readOrderPath(order, ['customer', 'alternate_phone']),
      _readOrderPath(order, ['customer', 'alt_phone']),
      _readOrderPath(order, ['order', 'customer_details', 'alternate_phone']),
      _readOrderPath(order, ['alternate_phone']),
      _readOrderPath(order, ['alt_phone']),
    ]);
  }

  String? _extractOrderCustomerAddress(dynamic order) {
    return _firstNonEmptyString([
      _readOrderPath(order, ['address']),
      _readOrderPath(order, ['delivery_address']),
      _extractOrderPropValue(order, 'CUSTOMER_ADDRESS'),
      _extractOrderPropValue(order, 'DELIVERY_ADDRESS'),
    ]);
  }

  CustomerListModelData? _findOrderCustomerInCache({
    required int? customerId,
    required String? customerPhone,
  }) {
    for (final customer in _customers) {
      if (customerId != null && customer.id == customerId) {
        return customer;
      }
    }
    for (final customer in _customers) {
      if ((customerPhone?.isNotEmpty ?? false) &&
          customer.phone == customerPhone) {
        return customer;
      }
    }
    return null;
  }

  CustomerListModelData _buildOrderCustomerFallback(dynamic order) {
    final kyc = <Kyc>[];
    final vatNumber = _firstNonEmptyString([
      _readOrderPath(order, ['kyc_info', 'vat_number']),
      _readOrderPath(order, ['customer', 'vat_number']),
      _readOrderPath(order, ['vat_number']),
    ]);
    final crNumber = _firstNonEmptyString([
      _readOrderPath(order, ['kyc_info', 'cr_number']),
      _readOrderPath(order, ['customer', 'cr_number']),
      _readOrderPath(order, ['cr_number']),
    ]);
    if (vatNumber != null) {
      kyc.add(Kyc(key: 'VAT NUMBER', value: vatNumber));
    }
    if (crNumber != null) {
      kyc.add(Kyc(key: 'CR NUMBER', value: crNumber));
    }

    return CustomerListModelData(
      id: _extractOrderCustomerId(order),
      name: _extractOrderCustomerName(order),
      phone: _extractOrderCustomerPhone(order),
      altPhone: _extractOrderCustomerAlternatePhone(order),
      customerType: _extractOrderCustomerType(order),
      address: _extractOrderCustomerAddress(order),
      kyc: kyc.isNotEmpty ? kyc : null,
    );
  }

  String? _extractOrderDeliveryMethodId(dynamic order) {
    final deliveryMethodMap = _asOrderMap(_readOrderPath(order, [
      'delivery_method',
    ]));
    return _firstNonEmptyString([
      _readOrderPath(order, ['delivery_method_id']),
      deliveryMethodMap?['id'],
      deliveryMethodMap?['delivery_method_id'],
      _readOrderPath(order, ['order', 'delivery_method_id']),
      _readOrderPath(order, ['cart', 'delivery_method_id']),
    ]);
  }

  String? _extractOrderDeliveryMethodName(dynamic order) {
    final deliveryMethodMap = _asOrderMap(_readOrderPath(order, [
      'delivery_method',
    ]));
    final directDeliveryMethod = deliveryMethodMap == null
        ? _readOrderPath(order, ['delivery_method'])
        : null;
    return _firstNonEmptyString([
      _readOrderPath(order, ['delivery_method_name']),
      deliveryMethodMap?['name'],
      deliveryMethodMap?['label'],
      directDeliveryMethod,
      _readOrderPath(order, ['order', 'delivery_method_name']),
      _readOrderPath(order, ['cart', 'delivery_method_name']),
    ]);
  }

  DeliveryMethod? _findDeliveryMethod({
    String? id,
    String? name,
  }) {
    final normalizedId = id?.trim();
    final normalizedName = name?.trim().toLowerCase();
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if (normalizedId != null &&
          normalizedId.isNotEmpty &&
          method.id == normalizedId) {
        return method;
      }
      if (normalizedName != null &&
          normalizedName.isNotEmpty &&
          (method.name.trim().toLowerCase() == normalizedName ||
              method.code?.trim().toLowerCase() == normalizedName)) {
        return method;
      }
    }
    return null;
  }

  void _writeNormalizedOrderField(
    dynamic order,
    String key,
    dynamic value,
  ) {
    final map = _asOrderMap(order);
    if (map == null || value == null) return;
    if (_cleanOrderText(map[key]) != null) return;
    map[key] = value;
  }

  String? _resolveCustomerPhone({
    dynamic order,
    OrderDetailsModelData? orderDetails,
  }) {
    return _firstNonEmptyString([
      orderDetails?.customerDetails?.phone,
      _selectedCustomer?.phone,
      _selectedCustomerPhone,
      order != null ? _extractOrderCustomerPhone(order) : null,
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
      order != null ? _extractOrderCustomerName(order) : null,
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
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã…Â¡Ã¢â€šÂ¬ === FETCHING CART ITEM STATUSES (Restaurant) ===');
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

        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Fetched ${_availableStatuses.length} cart item statuses');
        for (var status in _availableStatuses) {
          debugPrint(
              '   ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã…Â  ID: ${status.id}, Value: "${status.value}"');
        }
      } else {
        debugPrint(
            'ÃƒÂ¢Ã‚ÂÃ…â€™ Failed to fetch cart item statuses: ${response['message']}');
      }
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Exception fetching cart item statuses: $e');
    }
  }

  /// Helper method to find status ID by value
  int? _findStatusIdByValue(String value) {
    if (_availableStatuses.isEmpty) {
      debugPrint('ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â No available statuses loaded yet');
      return null;
    }

    final status = _availableStatuses.firstWhere(
      (s) => s.value.toUpperCase() == value.toUpperCase(),
      orElse: () => CartItemStatus(id: 0, value: '', description: ''),
    );

    if (status.id == 0) {
      debugPrint(
          'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Status value "$value" not found in available statuses');
      return null;
    }

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Found status ID ${status.id} for value "$value"');
    return status.id;
  }

  /// Mark all order items as SERVED
  Future<bool> _markAllOrderItemsServed() async {
    if (_selectedOrder == null) return false;

    final orderId = _selectedOrder['order_id'] ?? _selectedOrder['id'];
    final displayOrderId = _selectedOrder['order_number']?.toString() ??
        _selectedOrder['display_order_id']?.toString() ??
        orderId.toString();

    debugPrint('ÃƒÂ°Ã…Â¸Ã…Â¡Ã¢â€šÂ¬ === MARKING ALL ORDER ITEMS AS SERVED ===');
    debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ Order ID: $orderId');

    final statusId = _findStatusIdByValue('SERVED');
    if (statusId == null) {
      showScaffoldError(context: context, message: 'Status "SERVED" not found');
      return false;
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

      debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¥ API Response: $response');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ All order items updated to SERVED');

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
        return true;
      } else {
        debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Failed to update all order items');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to mark items as served: ${response['message']}',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Exception updating all order items: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error marking items as served: $e',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingServed = false;
        });
      }
      debugPrint('ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â === MARK ALL SERVED COMPLETED ===');
    }
  }

  /// Extracts and applies the default customer from app settings
  void _applyDefaultCustomer() {
    debugPrint(
        "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â [DEBUG] Restaurant: _applyDefaultCustomer called");

    // Safeguard: if customer was manually selected or already partially entered, don't reset to default
    if (_isCustomerManuallySelected &&
        (_selectedCustomerID != null ||
            _selectedCustomerPhone?.isNotEmpty == true)) {
      debugPrint(
          "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂºÃ‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â [DEBUG] Restaurant: Customer manually selected (ID: $_selectedCustomerID, Phone: $_selectedCustomerPhone), skipping reset to default");
      return;
    }

    try {
      // Check if auto-assign is enabled in app settings
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final bool autoAssignEnabled =
          appSettingsProvider.appSettings?.autoAssignDefaultCustomer ?? false;

      debugPrint(
          "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ [DEBUG] Restaurant: Auto-assign enabled in settings: $autoAssignEnabled");

      if (!autoAssignEnabled) {
        debugPrint(
            "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ [DEBUG] APP SETTINGS: Auto-assign default customer is DISABLED for Restaurant");
        return;
      }

      if (_customers.isNotEmpty) {
        // Get the default customer phone from app settings
        final defaultPhone =
            appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ??
                "";

        debugPrint(
            "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ [DEBUG] Restaurant: Default customer phone from settings: '$defaultPhone'");

        if (defaultPhone.isNotEmpty) {
          try {
            final defaultCustomer = _customers.firstWhere(
              (customer) => customer.phone == defaultPhone,
            );
            debugPrint(
                "ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ [DEBUG] Found default customer for restaurant: ${defaultCustomer.name} (ID: ${defaultCustomer.id})");

            setState(() {
              _selectedCustomer = defaultCustomer;
              _selectedCustomerID = defaultCustomer.id;
              _selectedCustomerPhone = defaultCustomer.phone;
            });

            // Also update the global provider
            debugPrint(
                "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ [DEBUG] Syncing with CustomerSelectionProvider...");
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .setSelectedCustomer(defaultCustomer, isDefault: true);
          } catch (e) {
            debugPrint(
                "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â [DEBUG] No customer found in list of ${_customers.length} with phone '$defaultPhone' for restaurant");
          }
        } else {
          debugPrint(
              "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â [DEBUG] Default phone number is empty in AppSettings");
        }
      } else {
        debugPrint(
            "ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â [DEBUG] Customer list is empty, cannot auto-assign");
      }
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ [DEBUG] Error applying default customer: $e');
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Payment Modal - Cart items count: ${cartItems.length}, Discount: ${totalDiscountAmount.toStringAsFixed(2)}, Final Order Total: ${orderTotal.toStringAsFixed(2)}');

    final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer);
    final customerPrevBalance =
        isDefaultCustomer ? 0.0 : (_selectedCustomer?.balance ?? 0.0);

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
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Applying default payment method from AppSettings: $defaultPayment');
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
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ Auto-fill triggered for CASH: $autoFillCashAmount');
    } else if (_isCardSelected &&
        (_cardAmount.isEmpty || double.tryParse(_cardAmount) == 0)) {
      _cardAmount = orderTotal.toStringAsFixed(2);
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ Auto-fill triggered for CARD: $_cardAmount');
    } else if (_isUpiSelected &&
        (_upiAmount.isEmpty || double.tryParse(_upiAmount) == 0)) {
      _upiAmount = orderTotal.toStringAsFixed(2);
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ Auto-fill triggered for UPI: $_upiAmount');
    } else if (_isCodSelected &&
        (_codAmount.isEmpty || double.tryParse(_codAmount) == 0)) {
      _codAmount = orderTotal.toStringAsFixed(2);
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ Auto-fill triggered for COD: $_codAmount');
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
        isDefaultCustomer: isDefaultCustomer,
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
          Map<String, String>? extraMethodAmounts,
          Map<String, String>? extraMethodValues,
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

            debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â³ Payment Method Updated:');
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

            // Match billing_page.dart: balance is cash returned after customer credit.
            _balanceAmount = _calculateBalanceAmount();
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ _refreshSavedOrdersKeepingSelection: Sending request with tableId: ${widget.tableId}');
    try {
      debugPrint(
          'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.listSavedOrders');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ listSavedOrders Response: $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
            if (_blockReselectAfterPlace) {
              _selectedOrder = null;
              widget.onOrderSelected(null);
              debugPrint(
                  'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Skipping reselect after order placed');
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
              debugPrint(
                  'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Updated selected order with fresh data');
            } else {
              // Keep the current selection - don't clear it immediately
              // The order might just be processing on the server
              debugPrint(
                  'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Selected order not found in updated list, keeping current selection');
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ _refreshSavedOrdersSilently: Sending request with tableId: ${widget.tableId}');
    try {
      debugPrint(
          'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.listSavedOrders (silent)');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
        deliveryMethodId:
            widget.tableId == null ? widget.preselectedDeliveryMethodId : null,
      );
      debugPrint(
          'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ listSavedOrders Response (silent): $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
            if (_blockReselectAfterPlace) {
              _selectedOrder = null;
              widget.onOrderSelected(null);
              debugPrint(
                  'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Skipping reselect after order placed');
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
              debugPrint(
                  'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Updated selected order with fresh data (silent)');
            } else {
              debugPrint(
                  'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Selected order not found in updated list (silent)');
            }
          }
        });
      } else {
        debugPrint(
            'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Failed to refresh saved orders (silent): ${response['message']}');
      }
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error in silent refresh: ${e.toString()}');
    }
  }

  Future<void> _fetchOrderDetails(dynamic order) async {
    setState(() {
      _isLoadingOrderDetails = true;
      _error = null;
    });

    try {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ _fetchOrderDetails: Processing saved order data.');
      debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã¢â‚¬Â¹ Order details: $order');

      // Clear previous order's customer and payment state to prevent contamination
      _clearOrderEditingState();

      _blockReselectAfterPlace = false;
      _selectedOrder = order; // Set the selected order directly
      widget.onOrderSelected(
          order); // Call the callback to update the parent widget

      // Load order-specific data if available
      _loadOrderSpecificData(order);
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ _fetchOrderDetails Exception: ${e.toString()}');
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
    debugPrint('ÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Â¹ Clearing previous order editing state...');
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
      _deliveryMethod = "";
      _deliveryMethodId = "";
      _deliveryAddress = "";
      _carNumber = "";
      _deliveryDate = null;
      _deliveryTime = null;
      _selectedDeliveryCharge = null;
    });
    debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Order editing state cleared');
  }

  // Sync variant without setState to avoid triggering extra rebuilds in lifecycle hooks
  void _clearOrderEditingStateSync() {
    debugPrint('ÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Â¹ Clearing previous order editing state...');
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
    _deliveryMethod = "";
    _deliveryMethodId = "";
    _deliveryAddress = "";
    _carNumber = "";
    _deliveryDate = null;
    _deliveryTime = null;
    _selectedDeliveryCharge = null;

    debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Order editing state cleared');
  }

  // Public method to reset payment modal flag (called from parent)
  void resetPaymentModalFlag() {
    setState(() {
      _hasOpenedPaymentModalOnce = false;
    });
  }

  void resetActiveOrderContext() {
    _clearOrderEditingState();
    if (!mounted) return;
    setState(() {
      _loadedLocalDraftId = null;
      _activeOrderPanelTab =
          _usesCounterOrderTabs ? OrderPanelTab.saved : _activeOrderPanelTab;
      _showSavedOrdersView = _usesCounterOrderTabs || _showSavedOrdersView;
      _forceCounterCartView = false;
    });
  }

  // Public method to clear current order-level comment after save/send flows.
  void clearCurrentOrderComment() {
    if (!mounted) return;
    setState(() {
      _orderComment = '';
    });
  }

  // Load order-specific data (customer, payment, etc.) from the selected order
  void _loadOrderSpecificData(dynamic order) {
    debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã¢â‚¬Â¹ Loading order-specific data...');

    try {
      // Load customer information if available
      final customerId = _extractOrderCustomerId(order);
      final customerPhone = _extractOrderCustomerPhone(order);
      final customerName = _extractOrderCustomerName(order);
      final customerSelectionProvider =
          Provider.of<CustomerSelectionProvider>(context, listen: false);

      if (customerId != null ||
          (customerPhone?.isNotEmpty ?? false) ||
          (customerName?.isNotEmpty ?? false)) {
        final customer = _findOrderCustomerInCache(
              customerId: customerId,
              customerPhone: customerPhone,
            ) ??
            _buildOrderCustomerFallback(order);

        setState(() {
          _selectedCustomer = customer;
          _selectedCustomerID = customer.id ?? customerId;
          _selectedCustomerPhone = customer.phone ?? customerPhone;
          _isCustomerManuallySelected = true;
        });

        customerSelectionProvider.setSelectedCustomer(
          customer,
          isDefault: _isDefaultCustomerPhone(customer.phone ?? customerPhone),
        );
        _writeNormalizedOrderField(order, 'customer_id', customer.id);
        _writeNormalizedOrderField(order, 'customer_name', customer.name);
        _writeNormalizedOrderField(order, 'customer_phone', customer.phone);

        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Loaded customer from order: ${customer.name} (${customer.phone})');
      } else {
        debugPrint(
            'ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¹ÃƒÂ¯Ã‚Â¸Ã‚Â No customer associated with this order. Applying default if applicable...');
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
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Loaded payment method: $paymentMethod, Amount: $paidAmount');
      }

      // Load existing order-level comment from supported API shapes.
      setState(() {
        _orderComment = _extractOrderLevelComment(order) ?? '';
      });

      // Load delivery information if available
      final extractedDeliveryMethodId = _extractOrderDeliveryMethodId(order);
      final extractedDeliveryMethodName =
          _extractOrderDeliveryMethodName(order);
      final matchedDeliveryMethod = _findDeliveryMethod(
        id: extractedDeliveryMethodId,
        name: extractedDeliveryMethodName,
      );
      final loadedDeliveryMethodId = extractedDeliveryMethodId ??
          matchedDeliveryMethod?.id ??
          _getDefaultDeliveryMethodId();

      String loadedDeliveryMethodName = extractedDeliveryMethodName ??
          matchedDeliveryMethod?.name ??
          (extractedDeliveryMethodId?.isNotEmpty == true
              ? extractedDeliveryMethodId!
              : null) ??
          _getDefaultDeliveryMethod().name;
      if (loadedDeliveryMethodName.isEmpty) {
        final deliveryMethodsProvider =
            Provider.of<DeliveryMethodsProvider>(context, listen: false);
        final match = deliveryMethodsProvider.deliveryMethods.firstWhere(
          (m) => m.id == loadedDeliveryMethodId,
          orElse: () => _getDefaultDeliveryMethod(),
        );
        loadedDeliveryMethodName = match.name;
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã…Â¡Ã…Â¡ Resolved delivery method name from provider: $loadedDeliveryMethodName (id: $loadedDeliveryMethodId)');
      }
      _writeNormalizedOrderField(
        order,
        'delivery_method_id',
        loadedDeliveryMethodId,
      );
      _writeNormalizedOrderField(
        order,
        'delivery_method_name',
        loadedDeliveryMethodName,
      );
      final loadedDeliveryDate = order['delivery_date']?.toString();
      final loadedDeliveryTime = order['delivery_time']?.toString();
      final loadedDeliveryAddress = _extractOrderCustomerAddress(order) ?? '';
      final loadedCarNumber = order['car_number']?.toString() ?? '';
      final loadedDeliveryCharge =
          double.tryParse(order['delivery_charge']?.toString() ?? '');

      setState(() {
        _deliveryMethodId = loadedDeliveryMethodId;
        _deliveryMethod = loadedDeliveryMethodName;
        _deliveryDate = loadedDeliveryDate;
        _deliveryTime = loadedDeliveryTime;
        _deliveryAddress = loadedDeliveryAddress;
        _carNumber = loadedCarNumber;
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
        debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Loaded discount data:');
        debugPrint('   - Flat Discount: ${_flatDiscount.toStringAsFixed(2)}');
        debugPrint(
            '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
        debugPrint('   - Coupon Code: $_couponCode');
      }

      // Match billing_page.dart: balance is cash returned after customer credit.
      _balanceAmount = _calculateBalanceAmount();

      widget.onOrderSelected(order);

      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Calculated balance: ${_balanceAmount.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error loading order-specific data: $e');
    }

    debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Order-specific data loading completed');
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
          variantId: cartItem.variantId,
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
              'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.addToCartAPI for item comment update');
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ addToCartAPI Request Body: {customerId: $customerId, productId: $productId, quantity: 0, unitPrice: $unitPrice, cartId: $orderCartId, comment: $comment}');

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

  DeliveryMethod _getDefaultDeliveryMethod() {
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    final appSettingsDefault =
        Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.defaultDeliveryMethod
            .trim();

    return deliveryMethodsProvider.resolveDefaultDeliveryMethod(
          appSettingsDefault: appSettingsDefault,
        ) ??
        DeliveryMethod(id: kFallbackDeliveryMethodId, name: 'Store Takeaway');
  }

  // Default Delivery Method (mirror of BillingPage)
  String _getDefaultDeliveryMethodId() {
    try {
      return _getDefaultDeliveryMethod().id;
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
    if (_selectedOrder == null) {
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Payment Summary - Cart items count: ${cartItems.length}, Order Total: ${orderTotal.toStringAsFixed(2)}');

    final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer);
    final customerBalance =
        isDefaultCustomer ? 0.0 : (_selectedCustomer?.balance ?? 0.0);
    final cashAmount = double.tryParse(_cashAmount) ?? 0.0;
    final cardAmount = double.tryParse(_cardAmount) ?? 0.0;
    final upiAmount = double.tryParse(_upiAmount) ?? 0.0;
    final codAmount = double.tryParse(_codAmount) ?? 0.0;
    final totalPaidAmount = cashAmount + cardAmount + upiAmount + codAmount;

    debugPrint(
        '\nÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Â® === RESTAURANT PAGE BALANCE CALCULATION START ===');
    debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Input Values:');
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

    if (_toCustomerCreditEnabled &&
        _selectedCustomer != null &&
        !isDefaultCustomer) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Âº RESTAURANT PAGE: Toggle is ON - Calculating with customer credit consideration');

      if (customerBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â³ Customer has debt - using transaction excess logic');
        final transactionExcess = totalPaidAmount - finalOrderTotal;
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Transaction excess: ${transactionExcess.toStringAsFixed(2)}');

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
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Âµ Customer has credit/zero balance - using Net Due logic');
        // Net Due = Final Order Total - Customer Previous Balance
        double netDue = finalOrderTotal - customerBalance;
        debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â° Net Due calculation:');
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
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â´ RESTAURANT PAGE: Toggle is OFF - Using simple calculation');
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
          'ÃƒÂ°Ã…Â¸Ã…Â¡Ã‚Â« RESTAURANT PAGE: Clamping negative cash balance (${cashBalance.toStringAsFixed(2)}) to 0 for UI display');
      cashBalance = 0.0;
    }

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Âµ Final cash balance: ${cashBalance.toStringAsFixed(2)}');
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Âµ Raw balance (before clamping): ${rawBalance.toStringAsFixed(2)}');
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã‚Â§Ã‚Â® === RESTAURANT PAGE BALANCE CALCULATION END ===\n');

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
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                isBold ? FontWeightManager.semiBold : FontWeightManager.regular,
                large ? FontSize.s16 : FontSize.s14,
                0.21,
                color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: buildCustomStyle(
                  isBold ? FontWeightManager.bold : FontWeightManager.semiBold,
                  large ? FontSize.s18 : FontSize.s14,
                  0.21,
                  color,
                ),
              ),
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
        if (_usesCounterOrderTabs &&
            _activeOrderPanelTab == OrderPanelTab.cart) {
          return Consumer<LocalProductProvider>(
            builder: (context, localProductProvider, _) {
              final cartItems = localProductProvider.getCartItems();
              return _buildCurrentCartView(cartItems);
            },
          );
        }
        if (_showSavedOrdersView) {
          return _buildSavedOrdersList();
        }
        if (isNonTableOrderContext) {
          return Consumer<LocalProductProvider>(
            builder: (context, localProductProvider, _) {
              final cartItems = localProductProvider.getCartItems();
              return _buildCurrentCartView(cartItems);
            },
          );
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
          final currentCartCount = cartItems.length;

          if (_usesCounterOrderTabs) {
            if (_activeOrderPanelTab != OrderPanelTab.cart &&
                currentCartCount > _lastObservedCartCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _activeOrderPanelTab = OrderPanelTab.cart;
                  _showSavedOrdersView = false;
                  _forceCounterCartView = true;
                });
              });
            }
            _lastObservedCartCount = currentCartCount;

            if (_activeOrderPanelTab == OrderPanelTab.cart) {
              return _buildCurrentCartView(cartItems);
            }
            return _buildSavedOrdersList();
          }

          // If user is on Saved Orders view and starts a fresh cart again,
          // auto-return to Current Order view.
          if (_showSavedOrdersView &&
              currentCartCount > _lastObservedCartCount) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _showSavedOrdersView = false;
                _forceCounterCartView = true;
              });
            });
          }
          _lastObservedCartCount = currentCartCount;

          final shouldShowCounterCart = _usesCounterOrderTabs &&
              !_showSavedOrdersView &&
              _forceCounterCartView;

          if ((hasCurrentCart && !_showSavedOrdersView) ||
              shouldShowCounterCart) {
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
    if (cartItems.isEmpty) {
      _focusedCurrentCartItemIndex = null;
    } else if ((_focusedCurrentCartItemIndex ?? 0) >= cartItems.length) {
      _focusedCurrentCartItemIndex = cartItems.length - 1;
    }

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
          _usesCounterOrderTabs
              ? _buildOrderPanelTabsHeader()
              : _buildPanelHeader(
                  'Cart',
                  Icons.shopping_cart,
                  const Color(0xFF059669),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _refreshLocalDrafts();
                          _fetchSavedOrders();
                          setState(() => _showSavedOrdersView = true);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: Text(
                          'Ongoing Orders',
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              widget.isCompact ? FontSize.s11 : FontSize.s12,
                              0.21,
                              const Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ),
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
                      child: Focus(
                        focusNode: _currentCartItemsFocusNode,
                        onKeyEvent: (node, event) =>
                            _handleCurrentCartItemsKey(event, cartItems),
                        child: ListView.separated(
                          controller: _currentCartItemsScrollController,
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
                            return this._buildCurrentCartItem(item, idx);
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          this._buildCurrentCartActionButtons(cartItems),
        ],
      ),
    );
  }

  Widget _buildSavedOrdersList() {
    final isNonTableOrderContext = widget.tableId == null &&
        ((widget.preselectedDeliveryMethodId != null &&
                widget.preselectedDeliveryMethodId!.isNotEmpty) ||
            (widget.allowCounterBilling && widget.isCounterBillingMode));

    if (_usesCounterOrderTabs) {
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
            _buildOrderPanelTabsHeader(),
            Expanded(
              child: _activeOrderPanelTab == OrderPanelTab.ongoing
                  ? _buildOngoingOrdersContent()
                  : _buildLocalDraftsContent(),
            ),
          ],
        ),
      );
    }

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
          // Saved Orders Section (local drafts, independent scroll)
          _buildPanelHeader(_usesCounterOrderTabs ? 'Orders' : 'Saved Orders',
              Icons.pending_actions, const Color(0xFFD97706),
              showBackButton: !_usesCounterOrderTabs && _showSavedOrdersView,
              onBackButtonPressed: () {
            setState(() => _showSavedOrdersView = false);
          },
              itemCount: _usesCounterOrderTabs ? null : _localDrafts.length,
              trailing: null),
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
                                'No saved orders',
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
                              this._buildLocalDraftItem(_localDrafts[index]),
                        ),
                      ),
                    ),
            ),
          ),
          if (!isNonTableOrderContext) ...[
            const SizedBox(height: 8),
            // Ongoing Orders Section (backend orders, independent scroll)
            _buildPanelHeader('Ongoing Orders', Icons.receipt, Colors.blue,
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

  Widget _buildLocalDraftsContent() {
    return RefreshIndicator(
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
                        'No saved orders',
                        style: buildCustomStyle(
                            FontWeightManager.medium,
                            widget.isCompact ? FontSize.s12 : FontSize.s13,
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
                      this._buildLocalDraftItem(_localDrafts[index]),
                ),
              ),
            ),
    );
  }

  Widget _buildOngoingOrdersContent() {
    if (_isLoadingOngoingOrders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchSavedOrders(showFullPanelLoader: false);
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
                        padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                        child: Text(
                          'No ongoing orders',
                          textAlign: TextAlign.center,
                          style: buildCustomStyle(
                              FontWeightManager.medium,
                              widget.isCompact ? FontSize.s12 : FontSize.s13,
                              0.21,
                              const Color(0xFF64748B)),
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
    debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printNewKOT() called');

    if (_selectedOrder == null) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ _printNewKOT: No order selected');
      showScaffoldError(
        context: context,
        message: 'Please select an order first',
      );
      return;
    }

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã¢â‚¬Â¹ _printNewKOT: Selected order ID: ${_selectedOrder['id'] ?? _selectedOrder['order_id']}');

    // Get all cart items
    List<dynamic> allCartItems = _getCartItemsFromOrder(_selectedOrder);
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ _printNewKOT: Total cart items: ${allCartItems.length}');

    // Filter for items where status is null
    List<dynamic> newItems = allCartItems.where((item) {
      if (item is Map<String, dynamic>) {
        final status = item['status'];
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Item: ${item['product_name'] ?? 'Unknown'}, Status: $status');
        return status == null;
      }
      return false;
    }).toList();

    final pendingCancelQueue =
        await _fetchPendingCancelKotItems(_selectedOrder);

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬Â Ã¢â‚¬Â¢ _printNewKOT: New items (status=null): ${newItems.length}');
    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã…Â¡Ã‚Â« _printNewKOT: Pending cancel items: ${pendingCancelQueue.length}');

    if (newItems.isEmpty && pendingCancelQueue.isEmpty) {
      debugPrint(
          'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â _printNewKOT: No pending add-on or cancel KOT items');
      showScaffoldError(
        context: context,
        message: 'No pending KOT items to print',
      );
      return;
    }

    if (newItems.isNotEmpty) {
      // Call API to update status for null items BEFORE printing
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] ========== STARTING STATUS UPDATE ==========');
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Preparing to update ${newItems.length} items to START status');

      try {
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 1: Getting providers...');
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 1: Providers obtained ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦');

        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 2: Parsing order ID...');
        final orderIdValue = _selectedOrder['id'] ?? _selectedOrder['order_id'];
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 2: order_id value = $orderIdValue');
        final orderId = int.tryParse(orderIdValue.toString());
        final accessToken = authModel.token ?? '';
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 2: Parsed orderId = $orderId ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦');
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 2: Access token length = ${accessToken.length} ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦');

        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 3: Checking orderId...');
        if (orderId != null) {
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 3: Order ID is valid, proceeding to API call...');
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] API Params: order_id=$orderId, status=START, all=false');

          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 4: Calling updateNullOrderItemsStatus...');
          final response = await cartProvider.updateNullOrderItemsStatus(
            orderId: orderId,
            accessToken: accessToken,
          );

          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] Step 4: API call completed ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦');
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¥ [KOT STATUS UPDATE] Full response: $response');
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¥ [KOT STATUS UPDATE] Response status: ${response['status']}');
          debugPrint(
              'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¥ [KOT STATUS UPDATE] Response message: ${response['message'] ?? "No message"}');

          if (response['status'] == 'success') {
            debugPrint(
                'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ [KOT STATUS UPDATE] SUCCESS! Items updated to START status');
            debugPrint(
                'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ [KOT STATUS UPDATE] Refreshing order details...');
            await _refreshSelectedOrderAfterCartUpdate();
            debugPrint(
                'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ [KOT STATUS UPDATE] Order refresh completed');
          } else {
            debugPrint(
                'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â [KOT STATUS UPDATE] FAILED! Status: ${response['status']}, Message: ${response['message']}');
          }
        } else {
          debugPrint(
              'ÃƒÂ¢Ã‚ÂÃ…â€™ [KOT STATUS UPDATE] ERROR: Invalid order ID: $orderIdValue');
        }
      } catch (e, stackTrace) {
        debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ [KOT STATUS UPDATE] EXCEPTION: $e');
        debugPrint(
            'ÃƒÂ¢Ã‚ÂÃ…â€™ [KOT STATUS UPDATE] Stack trace: $stackTrace');
      }

      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ [KOT STATUS UPDATE] ========== STATUS UPDATE COMPLETE ==========');
    }

    if (newItems.isNotEmpty) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printNewKOT: Printing add-on KOT...');
      await _printSavedOrderKot(
        _selectedOrder,
        newItems,
        kotType: 'add_on',
      );
    }

    if (pendingCancelQueue.isNotEmpty) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printNewKOT: Printing cancel KOT...');
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
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Failed to fetch pending cancel KOT items: $e');
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
      debugPrint(
          'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â acknowledgeKotPrint skipped: invalid order ID');
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
      debugPrint(
          'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ KOT print acknowledged for events: $eventIds');
      _removeAcknowledgedKotEventsFromOrderCache(
        order: order,
        eventIds: eventIds,
      );
      Future.microtask(_refreshSavedOrdersSilently);
      return;
    }

    final message = response['message']?.toString() ??
        'KOT printed, but failed to acknowledge printed cancel events';
    debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ KOT print acknowledge failed: $message');
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printSavedOrderKot() called with ${cartItems.length} items');

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
    debugPrint(
        'ÃƒÂ¢Ã…Â¡Ã¢â€žÂ¢ÃƒÂ¯Ã‚Â¸Ã‚Â _printSavedOrderKot: enableKOTPrint = $enableKOTPrint');

    if (enableKOTPrint) {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printSavedOrderKot: Trying auto-print first');
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã¢â‚¬Â¹ Order Number: $orderNumber, Table: $tableName, Items: ${printItems.length}');

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
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â _printSavedOrderKot: Auto-print failed, showing print page');
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
          'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â _printSavedOrderKot: KOT printing is disabled in app settings');
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
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã…Â  Cart items count: ${cartItems.length}, Total: ${total.toStringAsFixed(2)}');

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
                            return this._buildSavedOrderItem(item, idx);
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

  Widget _buildOrderPanelTabsHeader() {
    Widget segment({
      required String label,
      required IconData icon,
      required OrderPanelTab tab,
      required int count,
      required bool showIcon,
    }) {
      final selected = _activeOrderPanelTab == tab;
      final focused = _orderPanelTabsFocusNode.hasFocus &&
          _focusedOrderPanelTabIndex == _tabIndexFor(tab);
      final foreground = selected ? Colors.white : const Color(0xFF64748B);
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: selected ? null : () => _selectOrderPanelTab(tab),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? const Color(0xFFF59E0B) : Colors.transparent,
                  width: focused ? 2 : 0,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Icon(icon, size: 15, color: foreground),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s11 : FontSize.s12,
                        0.21,
                        foreground,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.18)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count.toString(),
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s10,
                          0.21,
                          selected ? Colors.white : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final cartCount = Provider.of<LocalProductProvider>(context, listen: false)
        .cartItems
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcon = constraints.maxWidth >= 370;

        return Container(
          padding: EdgeInsets.all(widget.isCompact ? 10.0 : 12.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B82F6).withOpacity(0.05),
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
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Focus(
              focusNode: _orderPanelTabsFocusNode,
              onKeyEvent: (node, event) => _handleOrderPanelTabsKey(event),
              child: Row(
                children: [
                  segment(
                    label: 'Cart',
                    icon: Icons.shopping_cart_rounded,
                    tab: OrderPanelTab.cart,
                    count: cartCount,
                    showIcon: showIcon,
                  ),
                  segment(
                    label: 'Saved',
                    icon: Icons.receipt_long_rounded,
                    tab: OrderPanelTab.saved,
                    count: _localDrafts.length,
                    showIcon: showIcon,
                  ),
                  if (!widget.hideOngoingOrdersTab)
                    segment(
                      label: 'Ongoing',
                      icon: Icons.fact_check_rounded,
                      tab: OrderPanelTab.ongoing,
                      count: _savedOrders.length,
                      showIcon: showIcon,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelHeader(String title, IconData icon, Color color,
      {bool showBackButton = false,
      VoidCallback? onBackButtonPressed,
      double? totalPrice,
      int? itemCount,
      String? subtitle,
      Widget? trailing}) {
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
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
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final showPreBillButton = widget.allowCounterBilling &&
        widget.isCounterBillingMode &&
        (appSettings?.enableKotBillButton ?? false);
    final useCompactActionLabels = showPreBillButton;

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
            if (!widget.hideFooterActionButtons) ...[
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
                                      Text(
                                        useCompactActionLabels
                                            ? 'KOT'
                                            : 'Print KOT',
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
                  if (showPreBillButton) ...[
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: cartItems.isEmpty || _isLoadingPreBill
                              ? null
                              : _printSelectedOngoingOrderBillWithLoading,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: widget.isCompact ? 44 : 48,
                            decoration: BoxDecoration(
                              color: _isLoadingPreBill
                                  ? const Color(0xFFF5F1FF)
                                  : Colors.white,
                              border: Border.all(
                                color: const Color(0xFF7C3AED),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _isLoadingPreBill
                                  ? SizedBox(
                                      width: widget.isCompact ? 16 : 20,
                                      height: widget.isCompact ? 16 : 20,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF7C3AED),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          useCompactActionLabels
                                              ? 'BILL'
                                              : 'Pre-Bill',
                                          style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            widget.isCompact
                                                ? FontSize.s13
                                                : FontSize.s14,
                                            0.21,
                                            const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                                      Text(
                                        allItemsServed
                                            ? 'Confirm'
                                            : (useCompactActionLabels
                                                ? 'Serve'
                                                : 'Mark Served'),
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

  Future<void> _showCheckoutModal({
    bool forCurrentCart = false,
    bool offlineSaveAndPrint = false,
    CheckoutModalMode mode = CheckoutModalMode.checkout,
    int? initialStep,
    String? title,
  }) async {
    if (mode == CheckoutModalMode.checkout && _isLoadingConfirm) {
      return;
    }

    // Release any current focus so checkout modal text fields receive input cleanly.
    FocusManager.instance.primaryFocus?.unfocus();

    // Rehydrate latest cached customers before opening checkout so default
    // customer auto-selection is applied when data is already available.
    _hydrateCustomerListFromProviderCache();

    // Mark that payment modal opportunity has been given (via checkout dialog)
    if (mode == CheckoutModalMode.checkout) {
      setState(() {
        _hasOpenedPaymentModalOnce = false;
      });
    }

    if (!mounted) return;

    // Sync LocalProductProvider cart with saved-order items only when confirming
    // an existing kitchen order. Current-cart checkout already uses that cart.
    if (!forCurrentCart && mode == CheckoutModalMode.checkout) {
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
    final shouldNotifyParentCheckoutLoading =
        forCurrentCart || offlineSaveAndPrint;

    await showDialog(
      context: context,
      barrierDismissible: mode == CheckoutModalMode.selectionOnly,
      builder: (dialogContext) {
        final deliveryMethodsProvider =
            Provider.of<DeliveryMethodsProvider>(context, listen: false);
        final deliveryEnabled =
            deliveryMethodsProvider.deliveryMethods.isNotEmpty;
        final defaultDeliveryMethod = _getDefaultDeliveryMethod();
        final shouldSeedDeliveryDefault = mode == CheckoutModalMode.checkout ||
            (mode == CheckoutModalMode.selectionOnly && initialStep == 1);
        final modalDeliveryMethod = _deliveryMethodId.isNotEmpty
            ? _deliveryMethod
            : shouldSeedDeliveryDefault
                ? defaultDeliveryMethod.name
                : "";
        final modalDeliveryMethodId = _deliveryMethodId.isNotEmpty
            ? _deliveryMethodId
            : shouldSeedDeliveryDefault
                ? defaultDeliveryMethod.id
                : "";

        return CheckoutModal(
          mode: mode,
          title: title ??
              (offlineSaveAndPrint ? 'Save Offline Order' : 'Finalize Order'),
          initialStep: initialStep,
          cartTotal: checkoutCartTotal,
          availableCustomers: _customers,
          selectedCustomer: _selectedCustomer,
          hasOpenedPaymentModalOnce: _hasOpenedPaymentModalOnce,
          confirmButtonTitle: offlineSaveAndPrint ? 'Save' : 'Confirm',
          printButtonTitle:
              offlineSaveAndPrint ? 'Save & Print' : 'Confirm & Print',

          // Delivery State
          enableDelivery: deliveryEnabled,
          deliveryMethod: modalDeliveryMethod,
          deliveryMethodId: modalDeliveryMethodId,
          deliveryComment: _orderComment,
          deliveryAddress: _deliveryAddress,
          deliveryDate: _deliveryDate,
          deliveryTime: _deliveryTime,
          carNumber: _carNumber,
          initialDeliveryCharge: _selectedDeliveryCharge ?? 0.0,
          onDeliveryUpdated:
              (method, methodId, carNo, comment, date, time, address) {
            setState(() {
              _deliveryMethod = method;
              _deliveryMethodId = methodId;
              _carNumber = carNo;
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
          onAddNewCustomer: (
            String searchQuery, {
            String? initialName,
            String? initialPhone,
          }) async {
            // NOTE: Do not close the checkout dialog here. We will return the result.

            // Pass numeric search input as-is (including partial phone numbers)
            String phoneToPreFill = '';
            final normalizedSearchQuery = searchQuery.trim();
            if ((initialPhone ?? '').trim().isNotEmpty) {
              phoneToPreFill = initialPhone!.trim();
            } else if (normalizedSearchQuery.isNotEmpty &&
                RegExp(r'^[0-9]+$').hasMatch(normalizedSearchQuery)) {
              phoneToPreFill = normalizedSearchQuery;
            }
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
              {cashMethodId,
              cardMethodId,
              upiMethodId,
              codMethodId,
              extraMethodAmounts,
              extraMethodValues}) {
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
            if (mode == CheckoutModalMode.selectionOnly) {
              Navigator.of(dialogContext).pop();
              return;
            }
            setState(() {
              _hasOpenedPaymentModalOnce = true;
            });
            if (shouldNotifyParentCheckoutLoading) {
              widget.onCheckoutActionLoadingChanged?.call(
                isLoading: true,
                printBill: false,
              );
            }
            Navigator.of(dialogContext).pop();
            try {
              if (offlineSaveAndPrint) {
                await _saveCurrentCartAsConfirmedAndPrint(printBill: false);
              } else if (forCurrentCart) {
                await _confirmCurrentCart(printBill: false);
              } else {
                await _confirmOrder();
              }
            } finally {
              if (shouldNotifyParentCheckoutLoading) {
                widget.onCheckoutActionLoadingChanged?.call(
                  isLoading: false,
                  printBill: false,
                );
              }
              if (mounted) {
                setState(() {});
              }
            }
          },
          onConfirmAndPrint: () async {
            if (mode == CheckoutModalMode.selectionOnly) {
              Navigator.of(dialogContext).pop();
              return;
            }
            setState(() {
              _hasOpenedPaymentModalOnce = true;
            });
            if (shouldNotifyParentCheckoutLoading) {
              widget.onCheckoutActionLoadingChanged?.call(
                isLoading: true,
                printBill: true,
              );
            }
            Navigator.of(dialogContext).pop();
            try {
              if (offlineSaveAndPrint) {
                await _saveCurrentCartAsConfirmedAndPrint(printBill: true);
              } else if (forCurrentCart) {
                await _confirmCurrentCart(printBill: true);
              } else {
                await _confirmOrderAndPrintBill();
              }
            } finally {
              if (shouldNotifyParentCheckoutLoading) {
                widget.onCheckoutActionLoadingChanged?.call(
                  isLoading: false,
                  printBill: true,
                );
              }
              if (mounted) {
                setState(() {});
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

      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Syncing order items with LocalProductProvider cart...');
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
          debugPrint(
              'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Product $productId not found in product list');
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
            '   ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Added: ${product.productName} (Qty: $quantity, Price: $unitPrice)');
      }

      // Apply discounts from the order
      localProductProvider.applyDiscount(
        flatDiscount: _flatDiscount,
        percentageDiscount: _percentageDiscount,
      );

      debugPrint(
          'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Order items synced with LocalProductProvider cart');
    } catch (e) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error syncing order items with cart: $e');
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

        debugPrint(
            'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.addToCartAPI for increment');
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ addToCartAPI Request Body: {customerId: $customerId, productId: $productId, quantity: $deltaQuantity, unitPrice: $unitPrice, cartId: $orderCartId}');
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Customer ID source: _selectedOrder data structure');

        response = await cartProvider.addToCartAPI(
          customerId: int.parse(customerId.toString()),
          productId: int.parse(productId.toString()),
          quantity: deltaQuantity,
          unitPrice: unitPrice,
          accessToken: authModel.token ?? '',
          cartId: orderCartId,
        );
        debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ addToCartAPI Response: $response');
      } else if (newQuantity <= currentQuantity) {
        // Decrement quantity or remove item (including 0) - use decrementCartItemQuantityAPI
        String actionType =
            newQuantity == 0 ? 'remove (set to 0)' : 'decrement';
        debugPrint(
            'ÃƒÂ¢Ã…Â¾Ã‚Â¡ÃƒÂ¯Ã‚Â¸Ã‚Â Calling CartProvider.decrementCartItemQuantityAPI for $actionType');
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ decrementCartItemQuantityAPI Request Body: {customerId: $customerId, cartItemId: ${cartItem['id']}, quantity: ${newQuantity.toInt()}, cartId: $orderCartId}');
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Customer ID source: _selectedOrder data structure');

        response = await cartProvider.decrementCartItemQuantityAPI(
          customerId: int.parse(customerId.toString()),
          productId:
              int.parse(cartItem['id'].toString()), // This is cart_item_id
          cartId: orderCartId,
          quantity: newQuantity.toInt(), // Can be 0 for removal
          accessToken: authModel.token ?? '',
        );
        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ decrementCartItemQuantityAPI Response: $response');
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
        // item already has ANY status ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â not just 'PREPARING' / 'COOKING' etc.
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
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error updating cart item: ${e.toString()}');
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
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€Ã¢â‚¬ËœÃƒÂ¯Ã‚Â¸Ã‚Â Removing cart item (using unified API): Sending request with customerId: $customerId, cartItemId: ${cartItem['id']}');
      // Use the unified decrementCartItemQuantityAPI with quantity 0 for removal
      final response = await cartProvider.decrementCartItemQuantityAPI(
        customerId: int.parse(customerId.toString()),
        productId:
            int.parse(cartItem['id'].toString()), // Send cart_item_id here
        cartId: orderCartId,
        quantity: 0, // Set quantity to 0 for removal
        accessToken: authModel.token ?? '',
      );

      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬â€Ã¢â‚¬ËœÃƒÂ¯Ã‚Â¸Ã‚Â Remove response (unified API): $response');

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
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error removing cart item: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to remove item: ${e.toString()}',
      );
    }
  }

  Future<void> _refreshOrderDetails() async {
    try {
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Refreshing order details by fetching saved orders...');

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
            debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Skipping reselect after order placed');
            return;
          }
          setState(() {
            _selectedOrder = updatedOrder;
          });
          debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Order details refreshed successfully');
        } else {
          debugPrint(
              'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Could not find updated order in the list');
        }
      } else {
        debugPrint(
            'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Failed to refresh saved orders: ${response['message']}');
      }
    } catch (e) {
      debugPrint(
          'ÃƒÂ¢Ã‚ÂÃ…â€™ Error refreshing order details: ${e.toString()}');
      // As a fallback, try to refresh the saved orders list
      try {
        await _fetchSavedOrders();
      } catch (fallbackError) {
        debugPrint(
            'ÃƒÂ¢Ã‚ÂÃ…â€™ Fallback refresh also failed: ${fallbackError.toString()}');
      }
    }
  }

  List<dynamic> _getCartItemsFromOrder(dynamic order) {
    debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ _getCartItemsFromOrder called');
    if (order == null) {
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ _getCartItemsFromOrder: Order is null');
      return [];
    }

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â _getCartItemsFromOrder: Available keys: ${order.keys.toList()}');

    if (order['cart_items'] != null) {
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Found cart_items key');
      if (order['cart_items']['cart_items'] is List) {
        final items = order['cart_items']['cart_items'];
        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from cart_items.cart_items');
        return items;
      } else if (order['cart_items'] is List) {
        final items = order['cart_items'];
        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from cart_items (List)');
        return items;
      }
    } else if (order['cart'] != null) {
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Found cart key');
      if (order['cart']['cart_items'] is List) {
        final items = order['cart']['cart_items'];
        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from cart.cart_items');
        return items;
      } else if (order['cart']['items'] is List) {
        final items = order['cart']['items'];
        debugPrint(
            'ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from cart.items');
        return items;
      }
    } else if (order['items'] is List) {
      final items = order['items'];
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from items');
      return items;
    } else if (order['order_items'] is List) {
      final items = order['order_items'];
      debugPrint(
          'ÃƒÂ¢Ã…â€œÃ¢â‚¬Å“ Returning ${items.length} items from order_items');
      return items;
    }

    debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ _getCartItemsFromOrder: No cart items found');
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
    String? documentTitleOverride,
    String? documentConfigType,
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
      documentTitleOverride: documentTitleOverride,
      documentConfigType: documentConfigType,
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
            documentTitleOverride: documentTitleOverride,
            documentConfigType: documentConfigType,
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
            "ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Fetching order details for bill print - Order $orderNumber");
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
          final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer);
          double? oldBalance =
              isDefaultCustomer ? null : _selectedCustomer?.balance;
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
            debugPrint(
                "ÃƒÂ°Ã…Â¸Ã¢â‚¬â€œÃ‚Â¨ÃƒÂ¯Ã‚Â¸Ã‚Â Attempting auto-print for order #$orderNumber");

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
                isDefaultCustomer:
                    isDefaultCustomer || _isDefaultCustomerPhone(customerPhone),
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
        debugPrint("ÃƒÂ¢Ã‚ÂÃ…â€™ Error printing bill: $e");
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
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Skipping reselect after order placed');
      return;
    }

    debugPrint(
        'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Refreshing selected order after cart update...');

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
              'ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Selected order refreshed successfully after cart update');
        } else {
          debugPrint(
              'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Could not find updated order in the list after cart update');
        }
      } else {
        debugPrint(
            'ÃƒÂ¢Ã…Â¡Ã‚Â ÃƒÂ¯Ã‚Â¸Ã‚Â Failed to refresh saved orders after cart update: ${response['message']}');
      }
    } catch (e) {
      debugPrint(
          'ÃƒÂ¢Ã‚ÂÃ…â€™ Error refreshing selected order after cart update: ${e.toString()}');
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

  List<Map<String, dynamic>> _getPaidMethodsForApi() {
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
      balanceAmount: _balanceAmount,
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

  double _calculateBalanceAmount() {
    final totalPaid = _getTotalPaidAmountFromState();
    final payableTotal = _getEffectiveOrderTotal();
    final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer);
    final customerPrevBalance =
        isDefaultCustomer ? 0.0 : (_selectedCustomer?.balance ?? 0.0);
    final requestedCustomerCredit = _toCustomerCreditEnabled
        ? (double.tryParse(_debitAmount) ?? _toCustomerCreditAmount)
        : 0.0;

    double cashBalance = 0.0;
    if (_toCustomerCreditEnabled &&
        _selectedCustomer != null &&
        !isDefaultCustomer) {
      if (customerPrevBalance < 0) {
        final transactionExcess = totalPaid - payableTotal;
        if (transactionExcess > 0) {
          final customerCredit = requestedCustomerCredit
              .clamp(
                0.0,
                transactionExcess,
              )
              .toDouble();
          cashBalance = transactionExcess - customerCredit;
        }
      } else {
        final netDue = payableTotal - customerPrevBalance;
        final availableBalance = totalPaid - netDue;
        if (availableBalance > 0) {
          final customerCredit = requestedCustomerCredit
              .clamp(
                0.0,
                availableBalance,
              )
              .toDouble();
          cashBalance = availableBalance - customerCredit;
        }
      }
    } else {
      cashBalance = totalPaid - payableTotal;
    }

    return cashBalance > 0 ? cashBalance : 0.0;
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
        'productName': item.displayName,
        'product_variant_id': item.variantId,
        'variant_attributes': item.variantAttributes,
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
        : (widget.preselectedDeliveryMethodName ??
            _getDefaultDeliveryMethod().name);

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
    final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer);
    final oldBalance = isDefaultCustomer ? null : _selectedCustomer?.balance;
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
        isDefaultCustomer: isDefaultCustomer ||
            _isDefaultCustomerPhone(
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

  Future<void> _printOfflineSavedOrderBill(SavedOrder savedOrder) async {
    final cartItems = <Map<String, dynamic>>[];
    double totalMrp = 0.0;
    double netTotal = 0.0;
    double totalTax = 0.0;

    for (final item in savedOrder.items) {
      final itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
      final itemPrice = item.price ?? item.product.price?.price ?? 0.0;
      final itemTotalPrice = itemPrice * item.quantity;
      final itemTax = (item.taxAmount ?? 0.0) * item.quantity;

      totalMrp += itemMrp * item.quantity;
      netTotal += itemTotalPrice;
      totalTax += itemTax;

      cartItems.add({
        'productName': item.displayName,
        'product_name': item.displayName,
        'product_variant_id': item.variantId,
        'variant_attributes': item.variantAttributes,
        'mrp': itemMrp.toString(),
        'quantity': item.quantity.toString(),
        'product_unit': item.product.unit ?? '',
        'unitPrice': itemPrice.toString(),
        'totalPrice': itemTotalPrice.toString(),
        'tax_amount': itemTax.toString(),
      });
    }

    final youSaved = math.max(0.0, totalMrp - netTotal);
    final netExcTax = netTotal - totalTax;
    final storeSession =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final storeName = storeSession.activeStore?.storeName ?? 'Store';
    final parsedPayment =
        PaymentHelper.parseLocalMultiPayment(context, savedOrder.paymentMethod);
    final paidAmount = double.tryParse(savedOrder.paidAmount ?? '0') ?? 0.0;

    Future<bool> printOnce() {
      return _printOrderDetailsWithFallback(
        storeName: storeName,
        cartItems: cartItems,
        formattedTotal: savedOrder.total.toString(),
        savedTotal: youSaved.toString(),
        discountAmount: ((savedOrder.flatDiscount ?? 0.0) +
                ((savedOrder.percentageDiscount ?? 0.0) > 0
                    ? (savedOrder.total *
                        (savedOrder.percentageDiscount ?? 0.0) /
                        100)
                    : 0.0))
            .toString(),
        orderDate: savedOrder.createdAt,
        orderNumber: savedOrder.orderNumber,
        isFromLocalStorage: true,
        customerName: savedOrder.customerName,
        customerPhone: savedOrder.customerPhone,
        customerAddress: savedOrder.address,
        paymentMethod:
            parsedPayment?.paymentMethodDisplay ?? savedOrder.paymentMethod,
        paymentBreakdown: parsedPayment?.paymentBreakdown,
        paidAmount: paidAmount > 0 ? paidAmount : null,
        customerAlternatePhone: savedOrder.alternatePhone,
        customerVatNumber: savedOrder.customerVatNumber,
        customerCrNumber: savedOrder.customerCrNumber,
        customerType: savedOrder.customerType,
        orderComment: savedOrder.comment,
        deliveryMethod: savedOrder.deliveryMethod ?? _deliveryMethod,
        isDefaultCustomer: _isDefaultCustomerPhone(savedOrder.customerPhone),
        netExcTax: netExcTax.toString(),
      );
    }

    final autoPrintSuccess = await printOnce();
    await _maybePrintCustomerCopy(
      canPrompt: autoPrintSuccess,
      printAction: printOnce,
    );
  }

  Future<void> _printOfflineSavedOrderKot(SavedOrder savedOrder) async {
    final printItems = savedOrder.items.map((item) {
      return {
        'productName': item.displayName,
        'product_variant_id': item.variantId,
        'variant_attributes': item.variantAttributes,
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
    final tableName = widget.tableId != null
        ? 'Table ${widget.tableId}'
        : (savedOrder.deliveryMethod ??
            widget.preselectedDeliveryMethodName ??
            _getDefaultDeliveryMethod().name);
    final showTableLabel = widget.tableId != null;
    final comment = savedOrder.comment?.trim();

    final success = await KotPrintPage.autoPrint(
      context,
      orderNumber: savedOrder.orderNumber,
      tableName: tableName,
      showTableLabel: showTableLabel,
      orderTime: orderTime,
      items: printItems,
      comment: comment != null && comment.isNotEmpty ? comment : null,
    );

    if (!success && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KotPrintPage(
            orderNumber: savedOrder.orderNumber,
            tableName: tableName,
            showTableLabel: showTableLabel,
            orderTime: orderTime,
            items: printItems,
            comment: comment != null && comment.isNotEmpty ? comment : null,
          ),
        ),
      );
    }
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

  void _resetConfirmedEditOrderContext() {
    _clearOrderEditingState();
    if (!mounted) return;
    setState(() {
      _blockReselectAfterPlace = true;
      _selectedOrder = null;
      _loadedLocalDraftId = null;
      if (_usesCounterOrderTabs) {
        _activeOrderPanelTab = OrderPanelTab.ongoing;
        _focusedOrderPanelTabIndex = _tabIndexFor(OrderPanelTab.ongoing);
        _showSavedOrdersView = true;
        _forceCounterCartView = false;
      }
    });
    _applyDefaultCustomer();
    widget.onOrderSelected(null);
    widget.onEditedOrderConfirmed?.call();
  }

  Future<bool> _saveCurrentCartAsConfirmedAndPrint({
    required bool printBill,
  }) async {
    final hasOrderContext = widget.tableId != null ||
        (widget.preselectedDeliveryMethodId?.isNotEmpty ?? false) ||
        _deliveryMethodId.trim().isNotEmpty ||
        (widget.allowCounterBilling && widget.isCounterBillingMode);
    if (!hasOrderContext) {
      showScaffoldError(
        context: context,
        message: 'Select a table or delivery method first',
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
    if (_selectedCustomer == null &&
        _selectedCustomerID == null &&
        (customerPhone == null || customerPhone.isEmpty)) {
      showScaffoldError(context: context, message: 'Please select a customer');
      return false;
    }

    setState(() {
      _isLoadingConfirm = true;
    });

    try {
      localProductProvider.cartTotal; // Recalculate priceSummary/discounts.
      _balanceAmount = _calculateBalanceAmount();
      final paymentData = _getLocalDraftPaymentData();
      final comment = widget.tableId != null
          ? buildTaggedDraftComment(widget.tableId!)
          : _orderComment.trim();

      SavedOrder? orderToUse;
      if (_loadedLocalDraftId != null) {
        localProductProvider.updateSavedOrder(
          _loadedLocalDraftId!,
          customerName: selectedCustomerNameForDraft,
          customerPhone: selectedCustomerPhoneForDraft,
          comment: comment.isNotEmpty ? comment : null,
          deliveryMethod: deliveryMethodForDraft,
          customerId: selectedCustomerIdForDraft,
          paymentMethod: paymentData['paymentMethod'],
          paidAmount: paymentData['paidAmount'],
          balanceAmount: balanceAmountForDraft,
          transactionId: transactionNumberForDraft,
          couponId: couponIdForDraft,
          deliveryMethodId: deliveryMethodIdForDraft,
          carNumber: carNumberForDraft,
          status: 'saved',
          deliveryDate: deliveryDateForDraft,
          deliveryTime: deliveryTimeForDraft,
          toCustomerCredit: toCustomerCreditForDraft,
          context: context,
          tableId: widget.tableId,
          address: deliveryAddressForDraft,
          deliveryCharge: deliveryChargeForDraft,
          alternatePhone: selectedCustomerAlternatePhoneForDraft,
          customerVatNumber: selectedCustomerVatNumberForDraft,
          customerCrNumber: selectedCustomerCrNumberForDraft,
          customerType: selectedCustomerTypeForDraft,
        );
        orderToUse =
            localProductProvider.moveToConfirmedOrders(_loadedLocalDraftId!);
      }

      orderToUse ??= localProductProvider.saveCurrentCartAsConfirmedOrder(
        customerName: selectedCustomerNameForDraft,
        customerPhone: selectedCustomerPhoneForDraft,
        comment: comment.isNotEmpty ? comment : null,
        deliveryMethod: deliveryMethodForDraft,
        customerId: selectedCustomerIdForDraft,
        paymentMethod: paymentData['paymentMethod'],
        paidAmount: paymentData['paidAmount'],
        balanceAmount: balanceAmountForDraft,
        transactionId: transactionNumberForDraft,
        couponId: couponIdForDraft,
        deliveryMethodId: deliveryMethodIdForDraft,
        carNumber: carNumberForDraft,
        status: 'confirmed',
        deliveryDate: deliveryDateForDraft,
        deliveryTime: deliveryTimeForDraft,
        toCustomerCredit: toCustomerCreditForDraft,
        context: context,
        tableId: widget.tableId,
        address: deliveryAddressForDraft,
        deliveryCharge: deliveryChargeForDraft,
        alternatePhone: selectedCustomerAlternatePhoneForDraft,
        customerVatNumber: selectedCustomerVatNumberForDraft,
        customerCrNumber: selectedCustomerCrNumberForDraft,
        customerType: selectedCustomerTypeForDraft,
      );

      if (printBill) {
        await _printOfflineSavedOrderBill(orderToUse);

        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        if (appSettingsProvider.appSettings?.enableKOTPrint ?? true) {
          await _printOfflineSavedOrderKot(orderToUse);
        }
      }

      localProductProvider.clearCart();
      _resetCurrentCartCheckoutState();
      _refreshLocalDrafts();
      if (_usesCounterOrderTabs) {
        resetActiveOrderContext();
        widget.onLocalDraftSaved?.call();
      }

      showScaffold(
        context: context,
        message: printBill
            ? 'Offline order saved and printed'
            : 'Offline order saved',
      );
      return true;
    } catch (e) {
      debugPrint('Error saving offline order: $e');
      showScaffoldError(
        context: context,
        message: 'Failed to save offline order: ${e.toString()}',
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
      _balanceAmount = _calculateBalanceAmount();
      final paymentMethods = _getSelectedPaymentMethodsForApi();
      final paidMethods = _getPaidMethodsForApi();

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
        balanceAmount: _balanceAmount.toString(),
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
      this.deleteLoadedDraftIfAny();
      localProductProvider.clearCartAfterOrder();
      _resetCurrentCartCheckoutState();
      _refreshLocalDrafts();
      if (_usesCounterOrderTabs) {
        resetActiveOrderContext();
        widget.onLocalDraftSaved?.call();
      }
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

      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Confirming order: $orderNumber (ID: $orderId)');

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
          _balanceAmount = _calculateBalanceAmount();

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

          paidMethods = PaymentHelper.normalizePaidMethodsForApi(
            paidMethods: paidMethods,
            balanceAmount: _balanceAmount,
            cashMethodId: cashId,
            codMethodId: codId,
          );

          // Keep for logs only; API will use paymentMethods/paidMethods format
          paymentMethod =
              selectedMethods.length == 1 ? selectedMethods.first : null;
        }
      }

      // Calculate balance amount
      _balanceAmount = _calculateBalanceAmount();
      final balanceAmount = _balanceAmount.toString();

      debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¦ Order details for confirmation:');
      debugPrint('   - Customer ID: $customerId');
      debugPrint('   - Customer Phone: $customerPhone');
      debugPrint('   - Total Price: $totalPrice');
      debugPrint('   - Transaction ID: $transactionId');
      debugPrint('   - Payment Method: $paymentMethod');
      debugPrint('   - Paid Amount: $paidAmount');
      debugPrint('   - Balance Amount: $balanceAmount');
      debugPrint('ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â« Discount details for confirmation:');
      debugPrint(
          '   - Flat Discount: ${flatDiscountAmount.toStringAsFixed(2)}');
      debugPrint(
          '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
      debugPrint(
          '   - Total Discount Amount: ${totalDiscountAmount.toStringAsFixed(2)}');
      debugPrint('   - Coupon Code: $_couponCode');
      debugPrint('ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â§ Payment Methods Details:');
      debugPrint('   - Payment Methods Array: $paymentMethods');
      debugPrint('   - Paid Methods Array: $paidMethods');
      debugPrint(
          '   - Is Cash Selected: $_isCashSelected (Amount: $_cashAmount)');
      debugPrint(
          '   - Is Card Selected: $_isCardSelected (Amount: $_cardAmount)');
      debugPrint('   - Is UPI Selected: $_isUpiSelected (Amount: $_upiAmount)');
      debugPrint(
          '\nÃƒÂ°Ã…Â¸Ã…Â¡Ã¢â€šÂ¬ CALLING updateOrderAPI with these parameters:');
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
      debugPrint('\nÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¡ About to call updateOrderAPI...');

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
        deliveryMethodId: widget.tableId == null
            ? (_deliveryMethodId.isNotEmpty
                ? _deliveryMethodId
                : _getDefaultDeliveryMethodId())
            : '',
        tableId: widget.tableId ?? '',
        address: _deliveryAddress.isNotEmpty ? _deliveryAddress : null,
        // Add discount parameters
        flatDiscount: _flatDiscount > 0 ? _flatDiscount : null,
        percentageDiscount:
            _percentageDiscount > 0 ? _percentageDiscount : null,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        toCustomerCredit: _toCustomerCreditEnabled,
        deliveryCharge: _getDeliveryChargeForOrder(),
      );

      debugPrint('\nÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â¥ updateOrderAPI RESPONSE:');
      debugPrint('   Response: $response');
      debugPrint('   Response Type: ${response.runtimeType}');
      if (response is Map) {
        debugPrint('   Status: ${response['status']}');
        debugPrint('   Message: ${response['message']}');
        debugPrint('   Data: ${response['data']}');
      }
      debugPrint('ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ Confirm order response: $response');

      if (isApiSuccess(response)) {
        _refreshCustomersInBackgroundAfterSale();

        showScaffold(
          context: context,
          message: 'Order $orderNumber confirmed successfully!',
        );

        // Refresh saved orders to show updated status
        debugPrint(
            'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Refreshing saved orders after confirming order');
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchSavedOrders();

        // Delete the local draft so it no longer appears in Saved Orders
        this.deleteLoadedDraftIfAny();

        // Clear the cart to prevent auto-save from recreating a draft on table switch
        Provider.of<LocalProductProvider>(context, listen: false).clearCart();

        _resetConfirmedEditOrderContext();
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
      debugPrint('ÃƒÂ¢Ã‚ÂÃ…â€™ Error confirming order: ${e.toString()}');
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
      debugPrint(
          'ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ¢â‚¬Å¾ Refreshing saved orders after updating order status');
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

  // Public method to force switch to Current Order tab
  Future<void> showCustomerSelectionModal() {
    return _showCheckoutModal(
      mode: CheckoutModalMode.selectionOnly,
      initialStep: 0,
      title: 'Select Customer',
    );
  }

  Future<void> showDeliverySelectionModalFromParent() {
    return _showCheckoutModal(
      mode: CheckoutModalMode.selectionOnly,
      initialStep: 1,
      title: 'Select Delivery Method',
    );
  }

  Future<void> clearCurrentCartFromParent() => _clearCurrentCart();

  Future<void> saveCurrentCartFromParent() => _saveCurrentCartAsPending();

  bool _hasAnySelectedPaymentAmount() {
    return (_isCashSelected && (double.tryParse(_cashAmount) ?? 0) > 0) ||
        (_isCardSelected && (double.tryParse(_cardAmount) ?? 0) > 0) ||
        (_isUpiSelected && (double.tryParse(_upiAmount) ?? 0) > 0) ||
        (_isCodSelected && (double.tryParse(_codAmount) ?? 0) > 0) ||
        (_isDebitSelected && (double.tryParse(_debitAmount) ?? 0) > 0);
  }

  void _applyDefaultPaymentForDirectConfirmAndPrint() {
    final orderTotal = _getEffectiveOrderTotal();
    if (orderTotal <= 0) return;

    final hasSelection = _isCashSelected ||
        _isCardSelected ||
        _isUpiSelected ||
        _isCodSelected ||
        _isDebitSelected;
    if (!hasSelection) {
      final defaultPayment =
          Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.defaultPaymentMethod
              .trim()
              .toUpperCase();
      switch (defaultPayment) {
        case 'CARD':
          _isCardSelected = true;
          break;
        case 'UPI':
          _isUpiSelected = true;
          break;
        case 'COD':
          _isCodSelected = true;
          break;
        case 'DEBIT':
          _isDebitSelected = true;
          break;
        case 'CASH':
        default:
          _isCashSelected = true;
          break;
      }
    }

    if (_hasAnySelectedPaymentAmount()) return;

    final totalText = orderTotal.toStringAsFixed(2);
    if (_isCashSelected) {
      _cashAmount = totalText;
    } else if (_isCardSelected) {
      _cardAmount = totalText;
    } else if (_isUpiSelected) {
      _upiAmount = totalText;
    } else if (_isCodSelected) {
      _codAmount = totalText;
    } else if (_isDebitSelected) {
      _debitAmount = totalText;
    }
  }

  Future<void> _confirmCurrentCartAndPrintWithoutCheckoutModal() async {
    if (_isLoadingConfirm) return;

    debugPrint(
      '[Restaurant] SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT enabled -> direct counter confirm & print',
    );

    _hydrateCustomerListFromProviderCache();
    if (!mounted) return;

    setState(() {
      if (_deliveryMethodId.isEmpty) {
        final defaultDeliveryMethod = _getDefaultDeliveryMethod();
        _deliveryMethod = defaultDeliveryMethod.name;
        _deliveryMethodId = defaultDeliveryMethod.id;
      }
      _applyDefaultPaymentForDirectConfirmAndPrint();
      _hasOpenedPaymentModalOnce = true;
      _balanceAmount = _calculateBalanceAmount();
    });

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.updatePaymentFromModal(
      isCash: _isCashSelected,
      isCard: _isCardSelected,
      isUpi: _isUpiSelected,
      isCod: _isCodSelected,
      isDebit: _isDebitSelected,
      cashAmount: _cashAmount,
      cardAmount: _cardAmount,
      upiAmount: _upiAmount,
      codAmount: _codAmount,
      debitAmount: _debitAmount,
      transactionNumber: _transactionNumber,
      toCustomerCredit: _toCustomerCreditEnabled,
      cashMethodId: billingProvider.cashPaymentMethodId,
      cardMethodId: billingProvider.cardPaymentMethodId,
      upiMethodId: billingProvider.upiPaymentMethodId,
      codMethodId: billingProvider.codPaymentMethodId,
    );

    widget.onCheckoutActionLoadingChanged?.call(
      isLoading: true,
      printBill: true,
    );
    try {
      await _confirmCurrentCart(printBill: true);
    } finally {
      widget.onCheckoutActionLoadingChanged?.call(
        isLoading: false,
        printBill: true,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  void showCurrentCartConfirmAndPrintFromParent() {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    if (!(appSettings?.showConfirmOrderAndPrintButton ?? true)) return;

    if (_skipCheckoutOnCounterConfirmAndPrint) {
      unawaited(_confirmCurrentCartAndPrintWithoutCheckoutModal());
      return;
    }
    showCheckoutFromParent(forCurrentCart: true);
  }

  void showCurrentCartCheckoutFromParent() {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    if (!(appSettings?.showConfirmOrderButton ?? true)) return;
    showCheckoutFromParent(forCurrentCart: true);
  }

  void showOfflineSaveAndPrintCheckoutFromParent({int? initialStep}) {
    _showCheckoutModal(
      forCurrentCart: true,
      offlineSaveAndPrint: true,
      initialStep: initialStep ?? _resolveCurrentCartCheckoutInitialStep(),
    );
  }

  void showCheckoutFromParent({
    bool? forCurrentCart,
    int? initialStep,
  }) {
    final useCurrentCart = forCurrentCart ?? _selectedOrder == null;
    _showCheckoutModal(
      forCurrentCart: useCurrentCart,
      initialStep: initialStep ??
          (useCurrentCart ? _resolveCurrentCartCheckoutInitialStep() : null),
    );
  }

  Future<void> prepareCounterKotBill({required bool autoMarkServed}) async {
    if (_selectedOrder == null) {
      showScaffoldError(
        context: context,
        message: 'No ongoing order selected for KOT + Bill',
      );
      return;
    }

    if (autoMarkServed && !_selectedOrderItemsAreServed()) {
      final served = await _markAllOrderItemsServed();
      if (!served || !mounted) return;
    }

    await _printSelectedOngoingOrderBill();
    if (!mounted) return;

    await _showCheckoutModal();
  }

  Future<void> _printSelectedOngoingOrderBillWithLoading() async {
    if (_isLoadingPreBill) return;
    setState(() {
      _isLoadingPreBill = true;
    });
    try {
      await _printSelectedOngoingOrderBill();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreBill = false;
        });
      }
    }
  }

  bool _selectedOrderItemsAreServed() {
    if (_selectedOrder == null) return false;
    final cartItems = _getCartItemsFromOrder(_selectedOrder);
    return cartItems.isNotEmpty &&
        cartItems.every((item) {
          if (item is Map<String, dynamic> && item['status'] != null) {
            final status = item['status'].toString().toUpperCase();
            return status == 'SERVED' || status == 'COMPLETED';
          }
          return false;
        });
  }

  Future<bool> _printSelectedOngoingOrderBill() async {
    if (_selectedOrder == null) return false;

    final orderNumber = _selectedOrder['order_number']?.toString() ??
        _selectedOrder['display_order_id']?.toString();
    if (orderNumber == null || orderNumber.trim().isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Order number not found for order summary print',
      );
      return false;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final response = await SalesProvider().listOrderDetails(
        context,
        orderNumber,
        authModel.token ?? '',
      );
      if (response == null) {
        showScaffoldError(
          context: context,
          message: 'Failed to fetch order summary details',
        );
        return false;
      }

      final orderDetails = OrderDetailsModel.fromJson(response);
      final details = orderDetails.data;
      final cart = details?.cart;
      final cartItems =
          cart?.cartItems ?? _getCartItemsFromOrder(_selectedOrder);
      final formattedTotal = cart?.priceSummary?.netPayable?.toString() ??
          cart?.priceSummary?.netTotal.toString() ??
          _calculateOrderTotal().toStringAsFixed(2);
      final savedTotal = cart?.priceSummary?.savedTotal.toString();
      final discountAmount =
          details?.priceSummary?.discount?.toString() ?? '0.00';
      final orderDate = details?.orderDate ??
          _selectedOrder['order_date']?.toString() ??
          DateHelper.formatISODateToIST(DateHelper.now().toIso8601String());
      final selectedOrder = _selectedOrder;
      final customerName = _resolveCustomerName(
        order: selectedOrder,
        orderDetails: details,
      );
      final customerPhone = _resolveCustomerPhone(
        order: selectedOrder,
        orderDetails: details,
      );
      final isDefaultCustomer = _isDefaultCustomer(_selectedCustomer) ||
          _isDefaultCustomerPhone(customerPhone);

      return _printOrderDetailsWithFallback(
        storeName: cart?.storeName,
        cartItems: cartItems,
        formattedTotal: formattedTotal,
        savedTotal: savedTotal,
        discountAmount: discountAmount,
        orderDate: orderDate,
        orderNumber: details?.orderNumber ?? orderNumber,
        tokenNumber: details?.tokenNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: details?.customerDetails?.email,
        customerAddress: details?.getCustomerAddressForDisplay(),
        customerAlternatePhone: _resolveCustomerAlternatePhone(
          orderDetails: details,
        ),
        customerVatNumber: details?.kycInfo?.vatNumber,
        customerCrNumber: details?.kycInfo?.crNumber,
        customerType: details?.customerDetails?.customerType,
        orderComment: _extractOrderLevelComment(selectedOrder),
        deliveryMethod: details?.deliveryMethodName,
        documentTitleOverride: 'ORDER SUMMARY',
        isDefaultCustomer: isDefaultCustomer,
        netExcTax: cart?.priceSummary?.netExcTax?.toString(),
      );
    } catch (e) {
      debugPrint('Error printing order summary: $e');
      showScaffoldError(
        context: context,
        message: 'Failed to print order summary: ${e.toString()}',
      );
      return false;
    }
  }

  int _resolveCurrentCartCheckoutInitialStep() {
    final hasCustomer = _selectedCustomer != null ||
        _selectedCustomerID != null ||
        (_selectedCustomerPhone?.trim().isNotEmpty ?? false);
    if (!hasCustomer) return 0;

    final hasOrderContext = widget.tableId != null ||
        (widget.preselectedDeliveryMethodId?.isNotEmpty ?? false) ||
        _deliveryMethodId.trim().isNotEmpty;
    if (!hasOrderContext) return 1;

    return 3;
  }

  void showCurrentOrderTab({bool preserveLoadedDraftMetadata = false}) {
    setState(() {
      _selectedOrder = null;
      _isLoadingOrders = false;
      _isLoadingOrderDetails = false;
      _error = null;
      if (!preserveLoadedDraftMetadata) {
        _orderComment = '';
        _loadedLocalDraftId = null;
      }
      _activeOrderPanelTab = OrderPanelTab.cart;
      _showSavedOrdersView = false;
      _forceCounterCartView = true;
    });
    widget.onOrderSelected(null);
  }
}
