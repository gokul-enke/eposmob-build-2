import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';

import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/restaurant/table_model.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/cart_item_status.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart'; // Import CartProvider

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../screens/customers/add_customer_modal.dart';
import '../../screens/billing/widgets/payment_method_modal.dart';

import '../../components/build_round_button.dart'; // Add button import
import '../../providers/keyboard_provider.dart'; // Add keyboard provider import
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/billing/widgets/coupon_modal.dart';
import 'package:pos_machine/screens/billing/widgets/checkout_modal.dart';
import 'package:pos_machine/screens/print/print_kot.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/models/order_details.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

// Mobile view navigation enum
enum MobileView { tables, orders }

class _RestaurantPageState extends State<RestaurantPage> {
  String? _activeTableId;
  int? _activeCategoryId;
  dynamic _selectedOrderFromOrderPanel; // New state to hold selected order
  int?
      _refreshCounter; // Counter to trigger refreshes without creating new objects
  final GlobalKey<_OrderPanelState> _orderPanelKey =
      GlobalKey<_OrderPanelState>(); // Key to access OrderPanel methods
  bool _isLoadingSendToKitchen =
      false; // Loading state for Send to Kitchen button
  bool _isLoadingPrint = false; // Loading state for Print button

  // Mobile navigation state
  MobileView _currentMobileView = MobileView.tables;
  String? _selectedTableName; // Store selected table name for header

  @override
  void initState() {
    super.initState();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final productProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final authModel = Provider.of<AuthModel>(context, listen: false);

    // Load categories if not already loaded
    if (!categoryProvider.isCategoriesLoaded) {
      await categoryProvider.listAllCategory();
    }

    // Load all products (refreshProducts is void, so no await needed)
    productProvider.refreshProducts();

    // Load tables from API
    await tableProvider.loadTables(accessToken: authModel.token);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // Better responsive breakpoints
    final isLargeScreen = screenWidth >= 1200;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern light background
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isSmallScreen
              ? _buildMobileLayout(screenSize)
              : _buildDesktopLayout(screenSize, isLargeScreen),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Size screenSize, bool isLargeScreen) {
    // More responsive width calculations
    final screenWidth = screenSize.width;

    // Calculate flexible widths based on screen size
    double tablesPanelFlex;
    double orderPanelFlex;
    double menuPanelFlex;

    if (screenWidth >= 1400) {
      // Large screens: more space for menu
      tablesPanelFlex = 2;
      menuPanelFlex = 5.0;
      orderPanelFlex = 3.0;
    } else if (screenWidth >= 1200) {
      // Medium-large screens: balanced
      tablesPanelFlex = 2;
      menuPanelFlex = 4.5;
      orderPanelFlex = 3.0;
    } else if (screenWidth >= 1000) {
      // Medium screens: compact tables
      tablesPanelFlex = 2.0;
      menuPanelFlex = 4.0;
      orderPanelFlex = 2.5;
    } else {
      // Small desktop screens: very compact
      tablesPanelFlex = 1.8;
      menuPanelFlex = 3.5;
      orderPanelFlex = 2.2;
    }

    return Row(
      children: [
        // Tables panel - flexible width
        Expanded(
          flex: tablesPanelFlex.round(),
          child: _TablesPanel(
            activeTableId: _activeTableId,
            onSelect: (id) {
              _autoSaveCurrentTableBeforeSwitch();
              // Get table name from provider for desktop mode
              final tableProvider =
                  Provider.of<TableProvider>(context, listen: false);
              final selectedTable = tableProvider.tables.firstWhere(
                (table) => table.id == id,
                orElse: () => tableProvider.tables.first,
              );
              setState(() {
                _activeTableId = id;
                _selectedTableName = selectedTable.name;
              });
            },
            screenSize: screenSize,
          ),
        ),
        // Menu panel - flexible width (gets most space)
        Expanded(
          flex: menuPanelFlex.round(),
          child: _MenuPanel(
            onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
            activeCategoryId: _activeCategoryId,
            onItemAdd: _handleItemAdd,
            screenSize: screenSize,
            selectedOrder: _selectedOrderFromOrderPanel, // Pass selected order
          ),
        ),
        // Order panel - flexible width
        Expanded(
          flex: orderPanelFlex.round(),
          child: _OrderPanel(
            key: _orderPanelKey, // Add key to access methods
            tableId: _activeTableId,
            screenSize: screenSize,
            onSendToKitchen:
                _sendOrderToKitchenWithLoading, // Use wrapper method
            onNewOrder: _handleNewOrder, // Pass the new callback
            onPrintOrder: _printOrderWithLoading, // Pass the print callback
            onOrderSelected: (order) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedOrderFromOrderPanel = order;
                  });
                }
              });
            }, // Pass callback to update selected order
            selectedOrderFromParent:
                _selectedOrderFromOrderPanel, // Pass the selected order
            refreshCounter: _refreshCounter, // Pass refresh counter
            isLoadingSendToKitchen:
                _isLoadingSendToKitchen, // Pass loading state
            isLoadingPrint: _isLoadingPrint, // Pass print loading state
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size screenSize) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentMobileView == MobileView.tables
            ? _buildTablesView(screenSize)
            : _buildOrdersView(screenSize),
      ),
    );
  }

  // Full-page tables view for mobile
  Widget _buildTablesView(Size screenSize) {
    return Column(
      key: const ValueKey('tables_view'),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_restaurant,
                color: const Color(0xFF2563EB),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Select a Table',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s20,
                  0.30,
                  const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              // Menu button
              IconButton(
                icon:
                    const Icon(Icons.restaurant_menu, color: Color(0xFF2563EB)),
                onPressed: () => _showProductsBottomSheet(context),
                tooltip: 'Menu',
              ),
            ],
          ),
        ),
        // Tables Panel - full page
        Expanded(
          child: _TablesPanel(
            activeTableId: _activeTableId,
            onSelect: (id) {
              _autoSaveCurrentTableBeforeSwitch();
              // Get table name from provider
              final tableProvider =
                  Provider.of<TableProvider>(context, listen: false);
              final selectedTable = tableProvider.tables.firstWhere(
                (table) => table.id == id,
                orElse: () => tableProvider.tables.first,
              );
              setState(() {
                _activeTableId = id;
                _selectedTableName = selectedTable.name;
                _currentMobileView =
                    MobileView.orders; // Navigate to orders view
              });
            },
            screenSize: screenSize,
          ),
        ),
      ],
    );
  }

  // Full-page orders view for mobile
  Widget _buildOrdersView(Size screenSize) {
    return Column(
      key: const ValueKey('orders_view'),
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
                onPressed: () {
                  setState(() {
                    _currentMobileView = MobileView.tables;
                  });
                },
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.receipt_long,
                color: const Color(0xFF2563EB),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedTableName ?? 'Orders',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s20,
                    0.30,
                    const Color(0xFF1E293B),
                  ),
                ),
              ),
              // Menu button
              IconButton(
                icon:
                    const Icon(Icons.restaurant_menu, color: Color(0xFF2563EB)),
                onPressed: () => _showProductsBottomSheet(context),
                tooltip: 'Menu',
              ),
            ],
          ),
        ),
        // Orders Panel - full page
        Expanded(
          child: _OrderPanel(
            key: _orderPanelKey,
            tableId: _activeTableId,
            screenSize: screenSize,
            onSendToKitchen: _sendOrderToKitchenWithLoading,
            onNewOrder: _handleNewOrder,
            onPrintOrder: _printOrderWithLoading,
            onOrderSelected: (order) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedOrderFromOrderPanel = order;
                  });
                }
              });
            },
            selectedOrderFromParent: _selectedOrderFromOrderPanel,
            refreshCounter: _refreshCounter,
            isLoadingSendToKitchen: _isLoadingSendToKitchen,
            isLoadingPrint: _isLoadingPrint,
          ),
        ),
      ],
    );
  }

  // Show products as a bottom sheet
  void _showProductsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header with only close button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Products panel
                    Expanded(
                      child: _MenuPanel(
                        onCategoryChanged: (cid) {
                          // Update both parent and modal state
                          setState(() => _activeCategoryId = cid);
                          setModalState(() => _activeCategoryId = cid);
                        },
                        activeCategoryId: _activeCategoryId,
                        onItemAdd: (product, quantity) async {
                          await _handleItemAdd(product, quantity);
                          // Optionally close the bottom sheet after adding
                          // Navigator.pop(context);
                        },
                        screenSize: MediaQuery.of(context).size,
                        selectedOrder: _selectedOrderFromOrderPanel,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleItemAdd(GetProduct product, int quantity) async {
    if (_activeTableId == null) {
      showScaffoldError(
        context: context,
        message: 'Select a table first',
      );
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Only call API when editing an existing saved order
      final bool isEditingExistingOrder = _selectedOrderFromOrderPanel != null;

      if (isEditingExistingOrder) {
        // Use the cart_id from the selected saved order
        int? targetCartId = int.tryParse((_selectedOrderFromOrderPanel['cart']
                        ?['id'] ??
                    _selectedOrderFromOrderPanel['cart_id'])
                ?.toString() ??
            '');

        // Get the customer ID from the selected order (not the logged-in user ID)
        final customerId = _selectedOrderFromOrderPanel['cart']
                ?['customer_id'] ??
            _selectedOrderFromOrderPanel['customer_id'] ??
            authModel.userId ??
            1;

        debugPrint(
            '🔄 Editing existing order - Using cart_id: $targetCartId, customerId: $customerId');

        debugPrint('➡️ Calling CartProvider.addToCartAPI');
        final addResponse = await cartProvider.addToCartAPI(
          customerId: int.parse(customerId.toString()),
          productId: product.productId!,
          quantity: quantity,
          accessToken: authModel.token ?? '',
          unitPrice: product.price?.price?.toString(),
          cartId: targetCartId,
        );
        debugPrint('✅ addToCartAPI Response: $addResponse');

        // Check if the API call was successful
        if (addResponse != null &&
            (addResponse['status']?.toLowerCase() == 'success' ||
                addResponse['status']?.toLowerCase() == 'sucesss')) {
          if (mounted) {
            showScaffold(
              context: context,
              message: 'Added ${product.productName} to existing order',
            );

            // Wait for server update then refresh the selected order and list silently
            await Future.delayed(const Duration(milliseconds: 1000));
            setState(() {
              _refreshCounter = (_refreshCounter ?? 0) + 1;
            });
            _orderPanelKey.currentState?.refreshSavedOrdersSilently();

            // Ensure parent widget also updates its state
            if (mounted) {
              setState(() {});
            }
          }
        } else {
          // API call failed, show error message
          if (mounted) {
            showScaffoldError(
              context: context,
              message:
                  'Failed to add ${product.productName}: ${addResponse?['message'] ?? 'Unknown error'}',
            );
          }
        }
      } else {
        // New order: strictly local cart only (no API here)
        debugPrint(
            '🛒 Adding product to local cart via LocalProductProvider (new order)');
        // Try to pass a specific stock reference when it's safe to infer
        // 1) If provider's selectedProduct matches this product, use its selectedStock
        // 2) Else if the product has exactly one stock entry, use that
        final selectedStockToUse =
            (localProductProvider.selectedProduct?.productId ==
                    product.productId)
                ? localProductProvider.selectedStock
                : ((product.stock != null && product.stock!.length == 1)
                    ? product.stock!.first
                    : null);

        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: product.price?.price != null
              ? double.tryParse(product.price!.price!)
              : null,
          mrp: product.mrp != null ? double.tryParse(product.mrp!) : null,
          selectedStock: selectedStockToUse,
        );

        if (mounted) {
          showScaffold(
            context: context,
            message: 'Added ${product.productName} to Table $_activeTableId',
          );
          // Ensure the OrderPanel shows Current Order immediately
          setState(() {});
          _orderPanelKey.currentState?.showCurrentOrderTab();
        }
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to add item: ${e.toString()}',
      );
    }
  }

  Future<void> _sendOrderToKitchen() async {
    if (_activeTableId == null) {
      showScaffoldError(
        context: context,
        message: 'Select a table first to send the order to kitchen',
      );
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Get cart data from the local provider instead of cart provider
      final cartItems = localProductProvider.getCartItems();
      if (cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'No items in cart to send to kitchen',
        );
        return;
      }

      // Convert local cart items to API format
      List<Map<String, dynamic>> items = [];
      for (var item in cartItems) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price?.toString() ?? '0',
          'mrp': item.mrp?.toString() ?? '0',
          'stock_id': item.selectedStock?.id, // Include stock_id if available
        });
      }

      // Get cart total from local provider (apply round-off when enabled)
      final total = localProductProvider.getRoundedTotal(context);

      // Call the addToOrderAPI with status: "new"
      debugPrint('➡️ Calling CartProvider.addToOrderAPI');
      final currentComment = _orderPanelKey.currentState?.orderComment ?? "";
      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0, // Use 0 for new cart since we're creating a new order
        accessToken: authModel.token ?? "",
        transactionId: "", // Not applicable for initial kitchen order
        totalPrice: total.toStringAsFixed(2),
        customerId: authModel.userId ?? 1,
        customerPhone: null, // Not applicable
        paymentMethod: null, // Not applicable
        paidAmount: null, // Not applicable
        paymentMethods: [], // Not applicable
        paidMethods: [], // Not applicable
        balanceAmount: "0", // Not applicable
        couponId: null, // Not applicable
        comment: currentComment.isNotEmpty
            ? currentComment
            : "Order for ${_selectedTableName ?? _activeTableId}", // Use table name for clarity
        deliveryMethodId:
            Provider.of<DeliveryMethodsProvider>(context, listen: false)
                    .defaultDeliveryMethod
                    ?.id ??
                "11", // Default to Store Takeaway same as billing
        carNumber: null, // Not applicable
        status: "new", // Set status to "new"
        deliveryDate: null, // Not applicable
        deliveryTime: null, // Not applicable
        tableId: _activeTableId,
      );

      if (response["order_id"] != null) {
        showScaffold(
          context: context,
          message:
              'Order for $_activeTableId sent to kitchen successfully! Order ID: ${response["order_id"]}',
        );

        // Clear the local cart after successful submission
        if (cartItems.isNotEmpty) {
          debugPrint('🗑️ Clearing local cart after successful kitchen order');
          localProductProvider.clearCart();
        }

        // If a local draft was loaded, remove it after successful send
        _orderPanelKey.currentState?.deleteLoadedDraftIfAny();

        // Refresh saved orders for the currently opened table
        if (mounted && _activeTableId != null) {
          debugPrint(
              '🔄 Refreshing saved orders after sending order to kitchen');
          await Future.delayed(
              const Duration(milliseconds: 1000)); // Wait for server to process
          _orderPanelKey.currentState?.refreshSavedOrders();
        }
      } else {
        showScaffoldError(
          context: context,
          message:
              'Failed to send order to kitchen: ${response["message"] ?? "Unknown error"}',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to send order to kitchen: ${e.toString()}',
      );
    }
  }

  Future<void> _handleNewOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    // Clear the local cart first
    if (localProductProvider.cartItems.isNotEmpty) {
      debugPrint('🗑️ Clearing local cart via LocalProductProvider');
      localProductProvider.clearCart();
    }

    // Clear the cart from API if it exists
    if (cartProvider.cartData.isNotEmpty &&
        cartProvider.cartData.first.cartItems?.isNotEmpty == true) {
      debugPrint('➡️ Calling CartProvider.clearCartAPI');
      await cartProvider.clearCartAPI(
        customerId: cartProvider.cartData.first.customerId ?? 1,
        productId: cartProvider.cartData.first.cartItems!.first.id ??
            0, // A dummy product ID, as clearCartAPI uses cart_item_id only if provided
        accessToken: Provider.of<AuthModel>(context, listen: false).token ?? '',
      );
    }

    // Deselect the active table
    setState(() {
      _activeTableId = null;
    });

    // Reset payment modal flag in OrderPanel
    _orderPanelKey.currentState?.resetPaymentModalFlag();

    showScaffold(
      context: context,
      message: 'New order started. Cart cleared and table deselected.',
    );
  }

  Future<void> _sendOrderToKitchenWithLoading() async {
    setState(() {
      _isLoadingSendToKitchen = true;
    });

    try {
      await _sendOrderToKitchen();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSendToKitchen = false;
        });
      }
    }
  }

  Future<void> _printOrderWithLoading() async {
    if (_activeTableId == null) {
      showScaffoldError(
        context: context,
        message: 'Select a table first to print the order',
      );
      return;
    }

    setState(() {
      _isLoadingPrint = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Get cart data BEFORE sending (it will be cleared after)
      final cartItems = localProductProvider.getCartItems();

      if (cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'No items in cart to print',
        );
        return;
      }

      // Capture data for printing BEFORE clearing
      final tableName = _selectedTableName ?? 'Table $_activeTableId';
      final currentComment = _orderPanelKey.currentState?.orderComment ?? "";
      final total = localProductProvider.getRoundedTotal(context);

      // Build print items BEFORE clearing cart
      List<Map<String, dynamic>> printItems = [];
      for (var item in cartItems) {
        printItems.add({
          'productName': item.product.productName ?? '',
          'quantity': item.quantity.toString(),
          'unitPrice': item.price?.toStringAsFixed(2) ?? '0.00',
          'totalPrice': ((item.price ?? 0) * item.quantity).toStringAsFixed(2),
          'mrp': item.mrp?.toStringAsFixed(2) ??
              item.price?.toStringAsFixed(2) ??
              '0.00',
        });
      }

      // Convert local cart items to API format
      List<Map<String, dynamic>> items = [];
      for (var item in cartItems) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price?.toString() ?? '0',
          'mrp': item.mrp?.toString() ?? '0',
          'stock_id': item.selectedStock?.id,
        });
      }

      // Call the addToOrderAPI with status: "new"
      debugPrint('➡️ Print: Calling CartProvider.addToOrderAPI');
      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0,
        accessToken: authModel.token ?? "",
        transactionId: "",
        totalPrice: total.toStringAsFixed(2),
        customerId: authModel.userId ?? 1,
        customerPhone: null,
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: [],
        paidMethods: [],
        balanceAmount: "0",
        couponId: null,
        comment: currentComment.isNotEmpty
            ? currentComment
            : "Order for ${_selectedTableName ?? _activeTableId}",
        deliveryMethodId:
            Provider.of<DeliveryMethodsProvider>(context, listen: false)
                    .defaultDeliveryMethod
                    ?.id ??
                "11",
        carNumber: null,
        status: "new",
        deliveryDate: null,
        deliveryTime: null,
        tableId: _activeTableId,
      );

      if (response["order_id"] != null) {
        // Get order number from API response
        final orderNumber = response["order_number"]?.toString() ??
            'ORD-${response["order_id"]}';

        showScaffold(
          context: context,
          message: 'Order sent to kitchen! Order: $orderNumber',
        );

        // Clear the local cart after successful submission
        debugPrint('🗑️ Clearing local cart after successful kitchen order');
        localProductProvider.clearCart();

        // If a local draft was loaded, remove it after successful send
        _orderPanelKey.currentState?.deleteLoadedDraftIfAny();

        // Refresh saved orders
        if (mounted && _activeTableId != null) {
          _orderPanelKey.currentState?.refreshSavedOrders();
        }

          // Check if KOT print is enabled in app settings
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        if (appSettingsProvider.appSettings?.enableKOTPrint ?? true) {
          // Get current time for KOT (using DateHelper for timezone support)
          final orderTime = DateHelper.getCurrentFormattedTimeWithAMPM();

          // Navigate to simple KOT print page
          if (mounted) {

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KotPrintPage(
                  orderNumber: orderNumber,
                  tableName: tableName,
                  orderTime: orderTime,
                  items: printItems,
                  comment: currentComment.isNotEmpty ? currentComment : null,
                ),
              ),
            );
          }
        }
      } else {
        showScaffoldError(
          context: context,
          message:
              'Failed to send order: ${response["message"] ?? "Unknown error"}',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to print order: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrint = false;
        });
      }
    }
  }

  // Auto-save current table's cart before switching to another table
  void _autoSaveCurrentTableBeforeSwitch() {
    if (_activeTableId == null) return;

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final cartItems = localProductProvider.cartItems;

      if (cartItems.isEmpty) {
        debugPrint(
            '💾 No items in cart for table $_activeTableId, skipping auto-save');
        return;
      }

      debugPrint(
          '💾 Auto-saving cart for table $_activeTableId before switch (${cartItems.length} items)');

      // Auto-save as pending draft with tableId
      localProductProvider.saveCurrentCartAsOrder(
        comment: 'TABLE:$_activeTableId',
        status: 'pending',
        context: context,
        tableId: _activeTableId,
      );

      debugPrint('✅ Auto-saved pending draft for table $_activeTableId');
      localProductProvider.clearCart();
    } catch (e) {
      debugPrint('❌ Error auto-saving cart: $e');
    }
  }
}

// Using the existing TableModel and TableStatus from your models

class _TablesPanel extends StatelessWidget {
  final String? activeTableId;
  final ValueChanged<String> onSelect;
  final bool isCompact;
  final Size screenSize;

  const _TablesPanel({
    required this.activeTableId,
    required this.onSelect,
    this.isCompact = false,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, tableProvider, _) {
        final tables = tableProvider.tables;

        if (tableProvider.isLoading && tables.isEmpty) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (tableProvider.error != null && tables.isEmpty) {
          return BuildBoxShadowContainer(
            circleRadius: 10,
            margin: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load tables',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s16,
                      0.21,
                      Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tableProvider.error!,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.21,
                      ColorManager.textColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => tableProvider.refreshTables(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced header with modern styling
              Container(
                padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2563EB).withOpacity(0.05),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: const Color(0xFF2563EB),
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tables',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          isCompact ? FontSize.s16 : FontSize.s18,
                          0.30,
                          const Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tables.length}',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s12, 0.21, const Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
              // Tables list/grid
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => tableProvider.refreshTables(),
                  child: _buildTablesView(tables, context), // Pass context here
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTablesView(List<TableModel> tables, BuildContext context) {
    if (tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 48,
              color: ColorManager.textColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No tables available',
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                  0.21, ColorManager.textColor.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    // Determine layout based on screen size and compact mode
    if (isCompact) {
      return _buildCompactTablesList(tables, context); // Pass context here
    } else {
      return _buildTableGrid(tables, context); // Pass context here
    }
  }

  Widget _buildCompactTablesList(
      List<TableModel> tables, BuildContext context) {
    return MouseRegion(
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
          padding: const EdgeInsets.all(12),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final isActive = table.id == activeTableId;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(table.id),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2563EB).withOpacity(0.08)
                          : _getTableBackgroundColor(table.status),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF2563EB)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        // Table icon and name
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.table_restaurant,
                            color: _tableColor(table.status),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.name,
                                style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s14,
                                    0.21,
                                    const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getStatusText(table.status),
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s11,
                                    0.21,
                                    _tableColor(table.status)),
                              ),
                            ],
                          ),
                        ),
                        // Status indicator with pulse animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _tableColor(table.status),
                            shape: BoxShape.circle,
                            boxShadow: table.status == TableStatus.occupied
                                ? [
                                    BoxShadow(
                                      color: _tableColor(table.status)
                                          .withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableGrid(List<TableModel> tables, BuildContext context) {
    // Calculate responsive grid columns
    int crossAxisCount;
    double childAspectRatio;

    if (screenSize.width >= 1200) {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else if (screenSize.width >= 900) {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }

    return MouseRegion(
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
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final isActive = table.id == activeTableId;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(table.id),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _getTableBackgroundColor(table.status),
                    border: isActive
                        ? Border.all(color: const Color(0xFF2563EB), width: 3)
                        : Border.all(color: Colors.grey.shade200, width: 1),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? const Color(0xFF2563EB).withOpacity(0.15)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: isActive ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Table icon - even smaller
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.table_restaurant,
                            color: _tableColor(table.status),
                            size: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Table name - smaller font
                        Text(
                          table.name,
                          style: buildCustomStyle(FontWeightManager.bold,
                              FontSize.s12, 0.21, const Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Status indicator - minimal
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tableColor(table.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: _tableColor(table.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _getStatusText(table.status),
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s6,
                                    0.14,
                                    _tableColor(table.status)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getTableBackgroundColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Colors.white;
      case TableStatus.occupied:
        return const Color(0xFFFEF2F2); // Modern red tint
      case TableStatus.reserved:
        return const Color(0xFFFAF5FF); // Modern purple tint
      case TableStatus.cleaning:
        return const Color(0xFFF0F9FF); // Modern blue tint
      case TableStatus.maintenance:
        return const Color(0xFFFFF7ED); // Modern orange tint
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return 'FREE';
      case TableStatus.occupied:
        return 'BUSY';
      case TableStatus.reserved:
        return 'RSVD';
      case TableStatus.cleaning:
        return 'CLEAN';
      case TableStatus.maintenance:
        return 'MAINT';
    }
  }

  Color _tableColor(TableStatus s) {
    switch (s) {
      case TableStatus.available:
        return const Color(0xFF059669); // Modern green
      case TableStatus.occupied:
        return const Color(0xFFD97706); // Modern amber
      case TableStatus.reserved:
        return const Color(0xFF7C3AED); // Modern purple
      case TableStatus.cleaning:
        return const Color(0xFF0EA5E9); // Modern blue
      case TableStatus.maintenance:
        return const Color(0xFFDC2626); // Modern red
    }
  }
}

class _MenuPanel extends StatefulWidget {
  final ValueChanged<int?> onCategoryChanged;
  final int? activeCategoryId;
  final Function(GetProduct product, int quantity) onItemAdd;
  final bool isCompact;
  final Size screenSize;
  final dynamic selectedOrder; // New parameter to receive selected order

  const _MenuPanel({
    required this.onCategoryChanged,
    required this.activeCategoryId,
    required this.onItemAdd,
    this.isCompact = false,
    required this.screenSize,
    this.selectedOrder, // Make it optional for now, as it might be null
  });

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showProductInfoDialog(
      BuildContext context, GetProduct product, bool compact) {
    // Resolve primary image
    String? primaryImage;
    if (product.attachment != null && product.attachment!.isNotEmpty) {
      for (var attachment in product.attachment!) {
        if (attachment.isPrimary == 1) {
          primaryImage = attachment.filePath;
          break;
        }
      }
      primaryImage ??= product.attachment!.first.filePath;
    }

    // Resolve category name from product model directly
    final String? categoryName = product.category?.name;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 14 : 20,
            vertical: widget.isCompact ? 14 : 20,
          ),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: widget.isCompact ? 380 : 520,
              constraints: const BoxConstraints(maxHeight: 720),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu,
                              color: Color(0xFF059669), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.productName ?? 'Product',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.21,
                                  const Color(0xFF1E293B),
                                ),
                              ),
                              if (product.price?.price != null)
                                Text(
                                  '${product.price!.price}',
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s14,
                                    0.21,
                                    const Color(0xFF059669),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close,
                              color: Colors.grey.shade600, size: 20),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          Container(
                            height: widget.isCompact ? 220 : 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: primaryImage != null
                                ? Image.network(
                                    primaryImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey.shade500),
                                  )
                                : Center(
                                    child: Icon(Icons.image,
                                        color: Colors.grey.shade400, size: 36),
                                  ),
                          ),
                          const SizedBox(height: 12),

                          // Tags (VEG/NON-VEG, stock)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ..._buildFoodTypeTags(product, compact),
                              if (!(product.stock != null &&
                                  product.stock!.isNotEmpty &&
                                  product.stock!
                                      .any((s) => (s.quantity ?? 0) > 0)))
                                _buildCompactTag('No Stock',
                                    const Color(0xFF6B7280), compact),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Basic details
                          if (categoryName != null && categoryName.isNotEmpty)
                            _buildKeyValueRow('Category', categoryName),
                          if (product.sku != null &&
                              (product.sku ?? '').toString().isNotEmpty)
                            _buildKeyValueRow('SKU', product.sku!),
                          if (product.mrp != null)
                            _buildKeyValueRow('MRP', '${product.mrp}'),
                          if (product.price?.price != null)
                            _buildKeyValueRow(
                                'Price', '${product.price!.price}'),

                          if (product.barcode != null &&
                              (product.barcode ?? '').toString().isNotEmpty)
                            _buildKeyValueRow(
                                'Barcode', product.barcode.toString()),
                          if (product.stock != null &&
                              product.stock!.isNotEmpty)
                            _buildKeyValueRow(
                              'Stock Qty',
                              product.stock!
                                  .map((s) => (s.quantity ?? 0).toString())
                                  .toList()
                                  .join(' / '),
                            ),
                          if (product.description != null &&
                              product.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                product.description!,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.21,
                                  const Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Footer with actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                widget.onItemAdd(product, 1);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: widget.isCompact ? 44 : 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669)
                                          .withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_shopping_cart,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add to Order',
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              key,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.21,
                const Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.21,
                const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryProvider, LocalProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        if (categoryProvider.isLoading &&
            (categoryProvider.category?.isEmpty ?? true)) {
          return const BuildBoxShadowContainer(
            circleRadius: 10,
            margin: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final categories = categoryProvider.category ?? [];
        final selectedCategoryId = widget.activeCategoryId ?? 0;

        // Get products for selected category - only show sellable products in billing
        List<GetProduct> items = [];
        if (selectedCategoryId == 0) {
          // "ALL" category - show all sellable products
          items = productProvider.sellableFilteredProducts;
        } else {
          // Specific category - filter sellable products by category
          items = productProvider.sellableProducts
              .where((product) => product.categoryId == selectedCategoryId)
              .toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          items = items.where((product) {
            return product.productName?.toLowerCase().contains(_searchQuery) ??
                false;
          }).toList();
        }

        // Calculate responsive grid columns with better aspect ratios
        int crossAxisCount;
        double childAspectRatio;

        if (widget.isCompact) {
          // Mobile/small tablet layout
          if (widget.screenSize.width > 600) {
            crossAxisCount = 2;
            childAspectRatio =
                1.7; // Balanced - prevents overflow while keeping compact
          } else {
            crossAxisCount = 1;
            childAspectRatio =
                1.9; // Balanced - prevents overflow while keeping compact
          }
        } else {
          // Desktop/large tablet layout
          if (widget.screenSize.width > 1400) {
            crossAxisCount = 4;
            childAspectRatio =
                1.6; // Balanced - prevents overflow while keeping compact
          } else if (widget.screenSize.width > 1000) {
            crossAxisCount = 3;
            childAspectRatio =
                1.7; // Balanced - prevents overflow while keeping compact
          } else {
            crossAxisCount = 2;
            childAspectRatio =
                1.7; // Balanced - prevents overflow while keeping compact
          }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced header
              Container(
                padding: EdgeInsets.all(widget.isCompact ? 16.0 : 20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF059669).withOpacity(0.05),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: const Color(0xFF059669),
                        size: widget.isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menu',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          widget.isCompact ? FontSize.s16 : FontSize.s18,
                          0.30,
                          const Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length} items',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s12, 0.21, const Color(0xFF059669)),
                        ),
                      ),
                  ],
                ),
              ),
              // Enhanced categories with modern styling
              if (categories.isNotEmpty)
                Container(
                  height: widget.isCompact ? 56 : 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal: widget.isCompact ? 12 : 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        itemBuilder: (_, idx) {
                          // Handle "All" category at index 0
                          if (idx == 0) {
                            final active = selectedCategoryId == 0;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    widget.onCategoryChanged(0);
                                    // Update products for "All" category
                                    productProvider.refreshProducts();
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: widget.isCompact ? 16 : 20,
                                        vertical: widget.isCompact ? 8 : 10),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: active
                                            ? const Color(0xFF2563EB)
                                            : Colors.grey.shade200,
                                        width: 1,
                                      ),
                                      boxShadow: active
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF2563EB)
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'All',
                                        style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            widget.isCompact
                                                ? FontSize.s12
                                                : FontSize.s13,
                                            0.21,
                                            active
                                                ? Colors.white
                                                : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          // Handle regular categories (index offset by 1)
                          final c = categories[idx - 1];
                          final active = c.categoryId == selectedCategoryId;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  widget.onCategoryChanged(c.categoryId);
                                  // Update products for selected category
                                  if (c.categoryId == 0) {
                                    // Should not happen for regular categories but kept for safety
                                    productProvider.refreshProducts();
                                  } else {
                                    // Specific category
                                    productProvider.listAllProducts(
                                        categoryId: c.categoryId);
                                  }
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: widget.isCompact ? 16 : 20,
                                      vertical: widget.isCompact ? 8 : 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: active
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB)
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.categoryName ?? 'Unknown',
                                      style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          widget.isCompact
                                              ? FontSize.s12
                                              : FontSize.s13,
                                          0.21,
                                          active
                                              ? Colors.white
                                              : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                      ),
                    ),
                  ),
                ),
              // Search bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCompact ? 12 : 16,
                  vertical: 8,
                ),
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
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search menu items...',
                      hintStyle: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s14,
                        0.21,
                        Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade500,
                        size: widget.isCompact ? 18 : 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey.shade500,
                                size: widget.isCompact ? 18 : 20,
                              ),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.isCompact ? 12 : 16,
                        vertical: widget.isCompact ? 12 : 16,
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
              // Menu items
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: ColorManager.textColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this category',
                              style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s14,
                                  0.21,
                                  ColorManager.textColor.withOpacity(0.7)),
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
                          child: GridView.builder(
                            padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: widget.isCompact ? 6 : 8,
                              crossAxisSpacing: widget.isCompact ? 6 : 8,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, idx) {
                              final item = items[idx];
                              return _buildMenuItem(
                                  item, widget.isCompact, context);
                            },
                            physics: const BouncingScrollPhysics(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(GetProduct item, bool compact, BuildContext context) {
    // Check if product is available (has stock or stock management is disabled)
    bool isAvailable = true;
    if (item.stock != null && item.stock!.isNotEmpty) {
      // Check if any stock has quantity > 0
      isAvailable = item.stock!.any((stock) => (stock.quantity ?? 0) > 0);
    }

    // Find primary image - COMMENTED OUT (images not displayed)
    // String? primaryImage;
    // if (item.attachment != null && item.attachment!.isNotEmpty) {
    //   for (var attachment in item.attachment!) {
    //     if (attachment.isPrimary == 1) {
    //       primaryImage = attachment.filePath;
    //       break;
    //     }
    //   }
    //   // If no primary image found, use the first one
    //   if (primaryImage == null && item.attachment!.isNotEmpty) {
    //     primaryImage = item.attachment!.first.filePath;
    //   }
    // }

    return Container(
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable
              ? () {
                  widget.onItemAdd(item, 1);
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8.0 : 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Distribute content evenly
              children: [
                // Top section: Image, name, price, description
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image - COMMENTED OUT
                    // if (primaryImage != null)
                    //   Container(
                    //     height: compact ? 50 : 60,
                    //     width: double.infinity,
                    //     margin: EdgeInsets.only(bottom: compact ? 4 : 6),
                    //     decoration: BoxDecoration(
                    //       borderRadius: BorderRadius.circular(8),
                    //       color: Colors.grey.shade100,
                    //     ),
                    //     child: ClipRRect(
                    //       borderRadius: BorderRadius.circular(8),
                    //       child: Image.network(
                    //         primaryImage,
                    //         fit: BoxFit.cover,
                    //         errorBuilder: (context, error, stackTrace) => Icon(
                    //             Icons.image_not_supported,
                    //             size: compact ? 24 : 30,
                    //             color: Colors.grey),
                    //       ),
                    //     ),
                    //   ),
                    // Header with name and price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName ?? 'Unknown Product',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              compact ? FontSize.s10 : FontSize.s12,
                              0.21,
                              isAvailable
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 4 : 6,
                            vertical: compact ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.price?.price ?? '0'}',
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              compact ? FontSize.s9 : FontSize.s11,
                              0.23,
                              isAvailable
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF059669).withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    // productName
                    if (item.productName != null)
                      Text(
                        item.productName.toString(),
                        maxLines: compact ? 1 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          compact ? FontSize.s8 : FontSize.s10,
                          0.21,
                          const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),

                // Bottom section: Tags and add button with proper spacing
                Column(
                  children: [
                    SizedBox(
                        height: compact
                            ? 6
                            : 8), // Add space between top and bottom sections
                    // Tags and add button
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: compact ? 3 : 4,
                            runSpacing: 2,
                            children: [
                              // Check for FOOD_TYPE in product_props
                              ...(_buildFoodTypeTags(item, compact)),
                              // Show unit if no food type is available
                              if (!_hasFoodType(item) && isAvailable)
                                _buildCompactTag('Available',
                                    const Color(0xFF059669), compact),
                              if (!isAvailable)
                                _buildCompactTag('No Stock',
                                    const Color(0xFF6B7280), compact),
                            ],
                          ),
                        ),
                        if (isAvailable)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showProductInfoDialog(
                                  context, item, compact),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: EdgeInsets.all(compact ? 3 : 4),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF2563EB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF2563EB),
                                  size: compact ? 12 : 14,
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
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTag(String text, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: buildCustomStyle(FontWeightManager.semiBold,
            compact ? FontSize.s6 : FontSize.s8, 0.14, color),
      ),
    );
  }

  /// Check if product has FOOD_TYPE property
  bool _hasFoodType(GetProduct product) {
    if (product.productProps == null || product.productProps!.isEmpty) {
      return false;
    }
    return product.productProps!.any((prop) => prop.propsCode == 'FOOD_TYPE');
  }

  /// Get food type from product props
  String? _getFoodType(GetProduct product) {
    if (product.productProps == null || product.productProps!.isEmpty) {
      return null;
    }

    final foodTypeProp = product.productProps!.firstWhere(
        (prop) => prop.propsCode == 'FOOD_TYPE',
        orElse: () => ProductProp());

    return foodTypeProp.masterValue;
  }

  /// Build food type tags (VEG/NON-VEG)
  List<Widget> _buildFoodTypeTags(GetProduct product, bool compact) {
    final foodType = _getFoodType(product);
    if (foodType == null) return [];

    switch (foodType.toUpperCase()) {
      case 'VEG':
        return [
          _buildVegNonVegTag('VEG', const Color(0xFF059669), compact, true)
        ];
      case 'NON-VEG':
      case 'NONVEG':
      case 'NON VEG':
      case 'NON_VEG':
        return [
          _buildVegNonVegTag('NON VEG', const Color(0xFFDC2626), compact, false)
        ];
      default:
        // If it's some other food type, show it as is
        return [_buildCompactTag(foodType, const Color(0xFF2563EB), compact)];
    }
  }

  /// Build VEG/NON-VEG tag with dot indicator
  Widget _buildVegNonVegTag(
      String text, Color color, bool compact, bool isVeg) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicator
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.bold,
              compact ? FontSize.s6 : FontSize.s8,
              0.14,
              color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderPanel extends StatefulWidget {
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

  const _OrderPanel({
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
  });

  @override
  State<_OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<_OrderPanel> {
  dynamic _selectedOrder;
  List<dynamic> _savedOrders = [];
  List<SavedOrder> _localDrafts = [];
  bool _isLoadingOrders = false;
  bool _isLoadingOrderDetails = false;
  String? _error;
  final Set<String> _loadingCartItems =
      {}; // Track which cart items are being updated
  bool _isLoadingConfirm = false; // Loading state for Confirm button
  String? _loadedLocalDraftId; // track currently loaded local draft

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

  // Expose current comment to parent (RestaurantPage) for new order flow
  String get orderComment => _orderComment;

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
    // Load saved orders and local drafts when the widget is first created with a tableId
    if (widget.tableId != null) {
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
  void didUpdateWidget(covariant _OrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Initialize customers only once
    if (!_customersInitialized) {
      _customersInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCustomers();
      });
    }

    // Only react when tableId actually changes
    if (widget.tableId != oldWidget.tableId) {
      if (widget.tableId != null) {
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
        '🔄 _fetchSavedOrders: Sending request with tableId: ${widget.tableId}');
    try {
      debugPrint('➡️ Calling CartProvider.listSavedOrders');
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
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
    if (widget.tableId != null) {
      debugPrint(
          '🔄 External refresh of saved orders triggered for table: ${widget.tableId}');
      _fetchSavedOrders();
      _refreshLocalDrafts();
    }
  }

  // Public method to refresh saved orders silently (no loading spinner)
  void refreshSavedOrdersSilently() {
    if (widget.tableId != null) {
      debugPrint(
          '🔄 External silent refresh of saved orders triggered for table: ${widget.tableId}');
      _refreshSavedOrdersSilently();
      _refreshLocalDrafts();
    }
  }

  Future<void> _fetchCustomers() async {
    debugPrint("🔍 [DEBUG] Restaurant: _fetchCustomers called");
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);

      debugPrint("🔍 [DEBUG] Restaurant: Loading customers from provider...");
      await customerProvider.loadAllCustomers(
        authModel.token ?? '',
      );

      setState(() {
        _customers = customerProvider.allCustomers ?? [];
        debugPrint(
            "🔍 [DEBUG] Restaurant: Fetched ${_customers.length} total customers (incl. background load)");
      });

      // Apply default customer logic after fetching
      _applyDefaultCustomer();
    } catch (e) {
      debugPrint('❌ [DEBUG] Error fetching customers: $e');
    }
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
        debugPrint('❌ Failed to fetch cart item statuses: ${response['message']}');
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

    // Calculate current total from cart items (dynamic calculation)
    List<dynamic> cartItems = [];
    if (_selectedOrder['cart_items'] != null) {
      if (_selectedOrder['cart_items']['cart_items'] is List) {
        cartItems = _selectedOrder['cart_items']['cart_items'];
      } else if (_selectedOrder['cart_items'] is List) {
        cartItems = _selectedOrder['cart_items'];
      }
    } else if (_selectedOrder['cart'] != null) {
      if (_selectedOrder['cart']['cart_items'] is List) {
        cartItems = _selectedOrder['cart']['cart_items'];
      } else if (_selectedOrder['cart']['items'] is List) {
        cartItems = _selectedOrder['cart']['items'];
      }
    } else if (_selectedOrder['items'] is List) {
      cartItems = _selectedOrder['items'];
    } else if (_selectedOrder['order_items'] is List) {
      cartItems = _selectedOrder['order_items'];
    }

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

    // Apply discounts if any
    double totalDiscountAmount =
        _flatDiscount + (orderTotal * _percentageDiscount / 100);
    orderTotal = orderTotal - totalDiscountAmount;

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
        isDefaultCustomer: Provider.of<CustomerSelectionProvider>(context, listen: false).isDefaultCustomer,
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
                                            .then((result) {
                                          if (result != null &&
                                              result['status'] == 'success') {
                                            _fetchCustomers().then((_) {
                                              // Find and auto-select the newly added customer by phone
                                              final addedPhone =
                                                  result['phone'];
                                              final matchingCustomer =
                                                  _customers.firstWhere(
                                                (customer) =>
                                                    customer.phone ==
                                                    addedPhone,
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
                                            });
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
                              .then((result) {
                            if (result != null &&
                                result['status'] == 'success') {
                              _fetchCustomers().then((_) {
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
                              });
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
    // Create a temporary LocalProductProvider instance for the CouponModal
    // Calculate current order total for the modal
    double orderSubTotal = 0.0;
    if (_selectedOrder != null) {
      List<dynamic> cartItems = [];
      if (_selectedOrder['cart_items'] != null) {
        if (_selectedOrder['cart_items']['cart_items'] is List) {
          cartItems = _selectedOrder['cart_items']['cart_items'];
        } else if (_selectedOrder['cart_items'] is List) {
          cartItems = _selectedOrder['cart_items'];
        }
      } else if (_selectedOrder['cart'] != null) {
        if (_selectedOrder['cart']['cart_items'] is List) {
          cartItems = _selectedOrder['cart']['cart_items'];
        } else if (_selectedOrder['cart']['items'] is List) {
          cartItems = _selectedOrder['cart']['items'];
        }
      } else if (_selectedOrder['items'] is List) {
        cartItems = _selectedOrder['items'];
      } else if (_selectedOrder['order_items'] is List) {
        cartItems = _selectedOrder['order_items'];
      }

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
      );
      debugPrint('✅ listSavedOrders Response: $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
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
              _hasOpenedPaymentModalOnce = false; // Reset payment modal flag when switching orders
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
      );
      debugPrint('✅ listSavedOrders Response (silent): $response');
      if (response['status'] == 'success') {
        final newOrders = response['orders'] as List<dynamic>;

        setState(() {
          _savedOrders = newOrders;

          // If we had a selected order, try to find and update it with fresh data
          if (currentSelectedOrder != null) {
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
              _hasOpenedPaymentModalOnce = false; // Reset payment modal flag when switching orders
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

      // Clear previous order's customer and payment state to prevent contamination
      _clearOrderEditingState();

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
    });
    debugPrint('✅ Order editing state cleared');
  }

  // Sync variant without setState to avoid triggering extra rebuilds in lifecycle hooks
  void _clearOrderEditingStateSync() {
    debugPrint('🧹 Clearing previous order editing state...');
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

    debugPrint('✅ Order editing state cleared');
  }

  // Public method to reset payment modal flag (called from parent)
  void resetPaymentModalFlag() {
    setState(() {
      _hasOpenedPaymentModalOnce = false;
    });
  }

  // Load order-specific data (customer, payment, etc.) from the selected order
  void _loadOrderSpecificData(dynamic order) {
    debugPrint('📋 Loading order-specific data...');

    try {
      // Load customer information if available
      final customerId = order['customer_id'];
      final customerPhone = order['customer_phone'] ?? order['phone'];

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

        debugPrint(
            '✅ Loaded customer from order: ${customer.name} (${customer.phone})');
      } else {
        debugPrint(
            'ℹ️ No customer associated with this order. Applying default if applicable...');
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

      // Load existing comment if available (supports multiple API shapes)
      String? loadedComment = order['comment']?.toString();
      loadedComment ??= order['order_comment']?.toString();

      // From nested map: orderProps: { COMMENT: "..." }
      if (loadedComment == null || loadedComment.isEmpty) {
        final propsMap = order['orderProps'];
        if (propsMap is Map && propsMap['COMMENT'] != null) {
          loadedComment = propsMap['COMMENT']?.toString();
        }
      }

      // From array: order_props: [{ code: COMMENT, value: "..." }]
      if (loadedComment == null || loadedComment.isEmpty) {
        final propsList = order['order_props'];
        if (propsList is List) {
          try {
            final match = propsList.firstWhere(
              (e) =>
                  (e is Map) &&
                  (e['code']?.toString()?.toUpperCase() == 'COMMENT'),
              orElse: () => null,
            );
            if (match is Map && match['value'] != null) {
              loadedComment = match['value']?.toString();
            }
          } catch (_) {}
        }
      }

      // Normalize: strip surrounding quotes if present (API sometimes returns quoted strings)
      if (loadedComment != null) {
        loadedComment = loadedComment!.trim();
        if (loadedComment!.startsWith('"') && loadedComment!.endsWith('"')) {
          loadedComment =
              loadedComment!.substring(1, loadedComment!.length - 1);
        }
      }

      setState(() {
        _orderComment = loadedComment ?? '';
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
        : (_selectedOrder?['comment']?.toString() ??
            _selectedOrder?['order_comment']?.toString() ??
            '');
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
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (controller.text.isNotEmpty) {
                          controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: controller.text.length,
                          );
                        }
                      });
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

  Widget _buildPaymentSummary() {
    if (_selectedOrder == null) {
      return const SizedBox.shrink();
    }

    // Calculate current total from cart items (dynamic calculation)
    List<dynamic> cartItems = [];
    if (_selectedOrder['cart_items'] != null) {
      if (_selectedOrder['cart_items']['cart_items'] is List) {
        cartItems = _selectedOrder['cart_items']['cart_items'];
      } else if (_selectedOrder['cart_items'] is List) {
        cartItems = _selectedOrder['cart_items'];
      }
    } else if (_selectedOrder['cart'] != null) {
      if (_selectedOrder['cart']['cart_items'] is List) {
        cartItems = _selectedOrder['cart']['cart_items'];
      } else if (_selectedOrder['cart']['items'] is List) {
        cartItems = _selectedOrder['cart']['items'];
      }
    } else if (_selectedOrder['items'] is List) {
      cartItems = _selectedOrder['items'];
    } else if (_selectedOrder['order_items'] is List) {
      cartItems = _selectedOrder['order_items'];
    }

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
    final finalOrderTotal = orderTotal - totalDiscountAmount;

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

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Color(0xFF2563EB),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s15,
                  0.21,
                  const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Summary rows
          _buildSummaryRow(
            'Order Total',
            '${orderTotal.toStringAsFixed(2)}',
            color: const Color(0xFF64748B),
          ),

          // Show discount information if any discount is applied (single line format like billing_page.dart)
          if (_hasDiscount()) ...[
            _buildSummaryRow(
              'Discount',
              '${totalDiscountAmount.toStringAsFixed(2)} (${(orderTotal > 0 ? ((totalDiscountAmount / orderTotal) * 100) : 0.0).toStringAsFixed(1)}%)',
              color: const Color(0xFFDC2626),
            ),
            _buildSummaryRow(
              'Final Total',
              '${finalOrderTotal.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
              isBold: true,
            ),
          ] else ...[
            _buildSummaryRow(
              'Final Total',
              '${orderTotal.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
              isBold: true,
            ),
          ],

          // Hide discount section for now
          // if (_hasDiscount()) ...[
          //   _buildSummaryRow(
          //     'Discount',
          //     '-${discountAmount.toStringAsFixed(2)}',
          //     color: const Color(0xFFD97706),
          //   ),
          //   _buildSummaryRow(
          //     'Final Total',
          //     '${finalOrderTotal.toStringAsFixed(2)}',
          //     color: const Color(0xFF1E293B),
          //     isBold: true,
          //   ),
          // ],

          // Only show customer balance if a customer is selected AND it's NOT the default customer
          if (_selectedCustomer != null && 
              !Provider.of<CustomerSelectionProvider>(context, listen: false).isDefaultCustomer) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Customer Balance',
              '${customerBalance.toStringAsFixed(2)}',
              color: customerBalance >= 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
            ),
          ],

          if (_hasPaymentMethod()) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Paid Amount',
              '${totalPaidAmount.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
            ),
            _buildSummaryRow(
              'Balance',
              rawBalance >= 0
                  ? '${rawBalance.toStringAsFixed(2)}'
                  : 'Short: ${(-rawBalance).toStringAsFixed(2)}',
              color: rawBalance >= 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount, {
    required Color color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              isBold ? FontWeightManager.semiBold : FontWeightManager.regular,
              FontSize.s14,
              0.21,
              const Color(0xFF64748B),
            ),
          ),
          Text(
            amount,
            style: buildCustomStyle(
              isBold ? FontWeightManager.bold : FontWeightManager.semiBold,
              FontSize.s15,
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
    if (widget.tableId == null) {
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
        // Show the custom empty state instead of error
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
            // Display list of saved orders
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
              'Pending Orders', Icons.pending_actions, const Color(0xFFD97706),
              itemCount: _localDrafts.length,
              subtitle: widget.tableId?.toString()),
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
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                        children: [
                          Center(
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
          const SizedBox(height: 8),
          // Saved Orders Section (independent scroll)
          _buildPanelHeader('Saved Orders', Icons.receipt, Colors.blue,
              itemCount: _savedOrders.length,
              subtitle: widget.tableId.toString()),
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
                                      const Color(0xFF059669).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
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
                              const SizedBox(height: 16),
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

  // Print KOT for ONLY new items (status == null)
  void _printNewKOT() async {
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

    debugPrint('🆕 _printNewKOT: New items (status=null): ${newItems.length}');

    if (newItems.isEmpty) {
      debugPrint('⚠️ _printNewKOT: No new items to print');
      showScaffoldError(
        context: context,
        message: 'No new items to print (all items already sent to kitchen)',
      );
      return;
    }

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
      debugPrint('📡 [KOT STATUS UPDATE] Step 2: Parsed orderId = $orderId ✅');
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

    // Reuse existing print logic with filtered items
    debugPrint('🖨️ _printNewKOT: Now calling _printSavedOrderKot...');
    _printSavedOrderKot(_selectedOrder, newItems);
  }

  // Print KOT for a saved order
  void _printSavedOrderKot(dynamic order, List<dynamic> cartItems) {
    debugPrint(
        '🖨️ _printSavedOrderKot() called with ${cartItems.length} items');

    // Get order number
    final orderNumber = order['order_number']?.toString() ?? 'Unknown';

    // Get table name
    String tableName = 'Unknown';
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

    // Get current time
    final now = DateTime.now();
    final orderTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
        quantity = (item['quantity'] ?? item['qty'] ?? 1).toString();

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

        // Extract item-level notes
        itemNotes = item['notes']?.toString();
        if (itemNotes == null || itemNotes.isEmpty) {
          final props = item['order_item_props'];
          if (props is List) {
            try {
              final noteProp = props.firstWhere(
                (p) =>
                    p is Map &&
                    p['code'] != null &&
                    p['code'].toString().toUpperCase() == 'NOTES',
                orElse: () => null,
              );
              if (noteProp != null) {
                itemNotes = noteProp['value']?.toString();
              }
            } catch (_) {}
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
      debugPrint('🖨️ _printSavedOrderKot: Navigating to KotPrintPage');
      debugPrint(
          '📋 Order Number: $orderNumber, Table: $tableName, Items: ${printItems.length}');
      // Navigate to KOT print page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KotPrintPage(
            orderNumber: orderNumber,
            tableName: tableName,
            orderTime: orderTime,
            items: printItems,
            comment: comment,
          ),
        ),
      );
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
            'Edit Order',
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
            totalPrice: total,
            subtitle: '${_selectedOrder['order_number']}',
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
          ? const EdgeInsets.fromLTRB(0, 16, 16, 16)
          : EdgeInsets.all(widget.isCompact ? 16.0 : 20.0),
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
              splashRadius: 20,
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: widget.isCompact ? 18 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      widget.isCompact ? FontSize.s16 : FontSize.s18,
                      0.30,
                      const Color(0xFF1E293B)),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        widget.isCompact ? FontSize.s12 : FontSize.s13,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      onTap: () => _printNewKOT(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD97706),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
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
                              ? (_isLoadingConfirm ? null : () => _showCheckoutModal())
                              : (_isMarkingServed ? null : () => _markAllOrderItemsServed()),
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
                                      : const Color(0xFF059669)), // Green for Mark Served
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: cartItems.isNotEmpty && !_isLoadingConfirm && !_isMarkingServed
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
                                      allItemsServed ? 'Confirm' : 'Mark Served',
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
    double finalOrderTotal = orderTotal - totalDiscountAmount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Total: ',
            style: buildCustomStyle(
                FontWeightManager.semiBold, 16, 0.2, Colors.black87),
          ),
          Text(
            finalOrderTotal.toStringAsFixed(2),
            style: buildCustomStyle(
                FontWeightManager.bold, 16, 0.2, const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutModal() {
    // Mark that payment modal opportunity has been given (via checkout dialog)
    setState(() {
      _hasOpenedPaymentModalOnce = false;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CheckoutModal(
          cartTotal: _calculateOrderTotal(),
          availableCustomers: _customers,
          selectedCustomer: _selectedCustomer,
          
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
            
            // Check if search query is a 10-digit number
            String phoneToPreFill = '';
            if (searchQuery.length == 10 && RegExp(r'^[0-9]+$').hasMatch(searchQuery)) {
              phoneToPreFill = searchQuery;
            }
            final result = await showAddCustomerModal(
              context, 
              MediaQuery.of(context).size,
              mobileNumber: phoneToPreFill
            );
            
            if (result != null && result['status'] == 'success') {
              await _fetchCustomers();
              // Find and return the newly added customer
              final addedPhone = result['phone'];
              final matchingCustomer = _customers.firstWhere(
                (customer) => customer.phone == addedPhone,
                orElse: () => CustomerListModelData(),
              );
              
              if (matchingCustomer.phone == addedPhone) {
                // Also update parent state
                setState(() {
                  _selectedCustomer = matchingCustomer;
                  _selectedCustomerID = matchingCustomer.id;
                  _selectedCustomerPhone = matchingCustomer.phone;
                });
                return matchingCustomer;
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
          },
          onPaymentUpdated: (isCash, isCard, isUpi, isCod, isDebit, cash, card, upi, cod, debit, trans, toCredit, {cashMethodId, cardMethodId, upiMethodId, codMethodId}) {
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
              _toCustomerCreditAmount = double.tryParse(debit) ?? 0.0; // Correctly update credit amount
            });
            
            // Update provider
            final billingProvider = Provider.of<BillingProvider>(context, listen: false);
            billingProvider.updatePaymentFromModal(
              isCash: isCash, isCard: isCard, isUpi: isUpi, isCod: isCod, isDebit: isDebit,
              cashAmount: cash, cardAmount: card, upiAmount: upi, codAmount: cod, debitAmount: debit,
              transactionNumber: trans, toCustomerCredit: toCredit,
              cashMethodId: cashMethodId, cardMethodId: cardMethodId, upiMethodId: upiMethodId, codMethodId: codMethodId
            );
          },
          onConfirmOrder: () async {
            Navigator.of(dialogContext).pop();
            await _confirmOrder();
          },
          onConfirmAndPrint: () async {
            Navigator.of(dialogContext).pop();
            await _confirmOrderAndPrintBill();
          },
        );
      },
    );
  }

  double _calculateOrderTotal() {
    if (_selectedOrder == null) return 0.0;
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

      // Check if the response indicates success (handle 'success' and 'sucesss' typo)
      if (response != null &&
          (response['status']?.toLowerCase() == 'success' ||
              response['status']?.toLowerCase() == 'sucesss')) {
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
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _refreshSavedOrdersSilently();
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

      // Check if the response indicates success
      if (response != null &&
          (response['status']?.toLowerCase() == 'success' ||
              response['status']?.toLowerCase() == 'sucesss')) {
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
          String? customerName = orderDetails.data?.customerDetails?.name;
          String? customerPhone = orderDetails.data?.customerDetails?.phone;
          String? customerEmail = orderDetails.data?.customerDetails?.email;
          String? customerAddress =
              orderDetails.data?.customerDetails?.address?.join(', ');

          String? customerAlternatePhone =
              orderDetails.data?.customerDetails?.alternatePhone;
          String? paymentMethod =
              orderDetails.data?.paymentDetails?.paymentMethod;

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
            // Navigate to PrintPage
            await Navigator.push(
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
                  isDefaultCustomer: Provider.of<CustomerSelectionProvider>(
                          context,
                          listen: false)
                      .isDefaultCustomer,
                  netExcTax: orderDetails.data?.cart!.priceSummary?.netExcTax?.toString(),
                ),
              ),
            );

            // After returning from print or successful navigation, cleanup
            if (mounted) {
              setState(() => _selectedOrder = null);
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
          setState(() => _selectedOrder = null);
          widget.onOrderSelected(null);
        }
      }
    }
  }

  Future<void> _refreshSelectedOrderAfterCartUpdate() async {
    if (_selectedOrder == null) return;

    debugPrint('🔄 Refreshing selected order after cart update...');

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Fetch updated saved orders
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: widget.tableId,
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

  Future<bool> _confirmOrder({bool closeOnSuccess = true}) async {
    if (_selectedOrder == null) {
      showScaffoldError(
        context: context,
        message: 'No order selected to confirm',
      );
      return false;
    }

    if (!_hasOpenedPaymentModalOnce) {
      _showPaymentMethodModal(onAfterApply: () => _confirmOrder(closeOnSuccess: closeOnSuccess));
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
      final customerPhone =
          _selectedCustomer?.phone ?? _selectedOrder['customer_phone'] ?? '';
      // Get order items to calculate subtotal
      List<dynamic> cartItems = [];
      if (_selectedOrder['cart_items'] != null) {
        if (_selectedOrder['cart_items']['cart_items'] is List) {
          cartItems = _selectedOrder['cart_items']['cart_items'];
        } else if (_selectedOrder['cart_items'] is List) {
          cartItems = _selectedOrder['cart_items'];
        }
      } else if (_selectedOrder['cart'] != null) {
        if (_selectedOrder['cart']['cart_items'] is List) {
          cartItems = _selectedOrder['cart']['cart_items'];
        } else if (_selectedOrder['cart']['items'] is List) {
          cartItems = _selectedOrder['cart']['items'];
        }
      } else if (_selectedOrder['items'] is List) {
        cartItems = _selectedOrder['items'];
      } else if (_selectedOrder['order_items'] is List) {
        cartItems = _selectedOrder['order_items'];
      }

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
      final finalOrderTotal = rawOrderTotal - totalDiscountAmount;

      final totalPrice = finalOrderTotal.toString();
      final transactionId = _transactionNumber.isNotEmpty
          ? _transactionNumber
          : (_selectedOrder['transaction_number'] ?? '');
      final comment = _orderComment.isNotEmpty
          ? _orderComment
          : (_selectedOrder['comment'] ?? 'Order confirmed from restaurant');

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

        // Multi-payment handling with dynamic IDs
        List<String> selectedMethods = [];
        final cashAmountVal = double.tryParse(_cashAmount) ?? 0;
        final cardAmountVal = double.tryParse(_cardAmount) ?? 0;
        final upiAmountVal = double.tryParse(_upiAmount) ?? 0;
        final codAmountVal = double.tryParse(_codAmount) ?? 0;

        if (_isCashSelected && cashAmountVal > 0) selectedMethods.add(cashId);
        if (_isCardSelected && cardAmountVal > 0) selectedMethods.add(cardId);
        if (_isUpiSelected && upiAmountVal > 0) selectedMethods.add(upiId);
        if (_isCodSelected && codAmountVal > 0) selectedMethods.add(codId);

        if (selectedMethods.length > 1) {
          // Multi-payment: store as JSON with IDs as keys
          Map<String, dynamic> multiPaymentData = {
            "methods": selectedMethods,
            "amounts": {
              cashId: _cashAmount.isNotEmpty ? _cashAmount : "0",
              cardId: _cardAmount.isNotEmpty ? _cardAmount : "0",
              upiId: _upiAmount.isNotEmpty ? _upiAmount : "0",
              codId: _codAmount.isNotEmpty ? _codAmount : "0",
            },
            "isMultiPayment": true
          };
          paymentMethod = json.encode(multiPaymentData);

          // Calculate total paid amount (using already-parsed values)
          paidAmount =
              (cashAmountVal + cardAmountVal + upiAmountVal + codAmountVal)
                  .toString();

          // Prepare paidMethods array with IDs (only include methods with amount > 0)
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

          paymentMethods = selectedMethods;
        } else if (selectedMethods.isNotEmpty) {
          // Single payment method with ID
          paymentMethod = selectedMethods.first;
          if (_isCashSelected && cashAmountVal > 0) {
            paidAmount = _cashAmount;
          } else if (_isCardSelected && cardAmountVal > 0) {
            paidAmount = _cardAmount;
          } else if (_isUpiSelected && upiAmountVal > 0) {
            paidAmount = _upiAmount;
          } else if (_isCodSelected && codAmountVal > 0) {
            paidAmount = _codAmount;
          }
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
        deliveryMethodId: _getDefaultDeliveryMethodId(),
        // Add discount parameters
        flatDiscount: _flatDiscount > 0 ? _flatDiscount : null,
        percentageDiscount:
            _percentageDiscount > 0 ? _percentageDiscount : null,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        toCustomerCredit: _toCustomerCreditEnabled,
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

      if (response != null &&
          (response['status']?.toLowerCase() == 'success' ||
              response['status']?.toLowerCase() == 'sucesss')) {
        showScaffold(
          context: context,
          message: 'Order $orderNumber confirmed successfully!',
        );

        // Refresh saved orders to show updated status
        debugPrint('🔄 Refreshing saved orders after confirming order');
        await Future.delayed(const Duration(milliseconds: 500));
        await _fetchSavedOrders();

        if (closeOnSuccess) {
          // Go back to orders list
          setState(() => _selectedOrder = null);
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
                  '${totalPrice.toStringAsFixed(0)}',
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
                      '${unitPrice.toStringAsFixed(2)}',
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
    );
  }

  // Footer actions for current cart (New Order flow)
  Widget _buildCurrentCartActionButtons(List<LocalCartItem> cartItems) {
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
            // Bottom row: Save, Send & Print
            Row(
              children: [
                // New button - REMOVED
                // Expanded(
                //   child: Material(
                //     color: Colors.transparent,
                //     child: InkWell(
                //       onTap: () => widget.onNewOrder(),
                //       borderRadius: BorderRadius.circular(12),
                //       child: AnimatedContainer(
                //         duration: const Duration(milliseconds: 200),
                //         height: widget.isCompact ? 44 : 48,
                //         decoration: BoxDecoration(
                //           color: Colors.white,
                //           border: Border.all(
                //             color: const Color(0xFF64748B),
                //             width: 1.5,
                //           ),
                //           borderRadius: BorderRadius.circular(12),
                //         ),
                //         child: Center(
                //           child: Text(
                //             'New',
                //             style: buildCustomStyle(
                //                 FontWeightManager.semiBold,
                //                 widget.isCompact ? FontSize.s12 : FontSize.s13,
                //                 0.21,
                //                 const Color(0xFF64748B)),
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 8),
                // Save button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (cartItems.isEmpty || widget.tableId == null)
                          ? null
                          : () => _saveCurrentCartAsPending(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: (cartItems.isEmpty || widget.tableId == null)
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow:
                              (cartItems.isNotEmpty && widget.tableId != null)
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.save,
                                color: Colors.white,
                                size: widget.isCompact ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Save',
                                  style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      widget.isCompact
                                          ? FontSize.s12
                                          : FontSize.s13,
                                      0.21,
                                      Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send & Print KOT button (Mixed)
                Expanded(
                  flex: 2, // Give it more space as it's the primary action
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (cartItems.isEmpty || widget.isLoadingPrint)
                          ? null
                          : () => widget.onPrintOrder(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: (cartItems.isEmpty || widget.isLoadingPrint)
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow:
                              (cartItems.isNotEmpty && !widget.isLoadingPrint)
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF059669)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                        ),
                        child: Center(
                          child: widget.isLoadingPrint
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
                                      Icons.send,
                                      color: Colors.white,
                                      size: widget.isCompact ? 14 : 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Send To Kitchen',
                                      style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          widget.isCompact
                                              ? FontSize.s12
                                              : FontSize.s13,
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
              ],
            ),
          ],
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
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      debugPrint(
          '🔄 _updateCurrentCartItemQuantity: Updating quantity for ${cartItem.product.productName} to ${newQuantity.toInt()}');

      // Use LocalProductProvider to set the exact quantity
      localProductProvider.setCartItemQuantity(
        cartItem.product.productId!,
        cartItem.selectedStock,
        newQuantity,
      );

      showScaffold(
        context: context,
        message: 'Item quantity updated successfully',
      );
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

  // Save current cart locally as a PENDING draft for the active table
  Future<void> _saveCurrentCartAsPending() async {
    if (widget.tableId == null) {
      showScaffoldError(context: context, message: 'Select a table first');
      return;
    }

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: 'No items in cart to save');
        return;
      }

      // Prefix table tag into comment so we can filter drafts per table without Hive migration
      final String taggedComment = 'TABLE:${widget.tableId}' +
          (_orderComment.isNotEmpty ? ' | ' + _orderComment : '');

      // If a local draft is loaded, update it instead of creating a new one
      if (_loadedLocalDraftId != null) {
        debugPrint('📝 Updating existing local draft $_loadedLocalDraftId');
        localProductProvider.updateSavedOrder(
          _loadedLocalDraftId!,
          comment: taggedComment,
          status: 'pending',
          tableId: widget.tableId,
        );
        showScaffold(context: context, message: 'Updated local draft');
      } else {
        debugPrint('📝 Creating new local draft');
        final saved = localProductProvider.saveCurrentCartAsOrder(
          comment: taggedComment,
          status: 'pending',
          context: context,
          tableId: widget.tableId,
        );
        showScaffold(
            context: context,
            message: 'Saved local draft ${saved.orderNumber}');
      }

      // Clear cart and refresh local drafts
      localProductProvider.clearCart();
      _loadedLocalDraftId = null;
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
        return st == 'pending' && o.tableId == widget.tableId;
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
    if (_loadedLocalDraftId == null) return;
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.deleteSavedOrder(_loadedLocalDraftId!);
    _loadedLocalDraftId = null;
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

      if (response != null &&
          (response['status']?.toLowerCase() == 'success' ||
              response['status']?.toLowerCase() == 'sucesss')) {
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

    final TextEditingController _priceController =
        TextEditingController(text: price.toStringAsFixed(2));

    // Auto-select all text when dialog opens
    _priceController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _priceController.text.length,
    );

    void _handleUpdate() {
      Navigator.pop(context);
      final newPriceStr = _priceController.text;
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
                controller: _priceController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleUpdate(),
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
                      .show('numeric', _priceController);
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
                    onPressed: _handleUpdate,
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
    final hasStarted = statusUpper == 'START' ||
        statusUpper == 'PREPARING' ||
        statusUpper == 'COOKING' ||
        statusUpper == 'IN_PROGRESS' ||
        statusUpper == 'READY' ||
        statusUpper == 'SERVED' ||
        statusUpper == 'COMPLETED';
    final isRemovable = !hasStarted;
    final statusText = _statusTextForDisplay(status);

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
                      '${totalPrice.toStringAsFixed(0)}',
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
                            '${unitPrice.toStringAsFixed(2)}',
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
              // Remove button with modern styling
              if (isRemovable)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        _loadingCartItems.contains('${cartItem['id']}_remove')
                            ? null
                            : () => _removeCartItemWithLoading(cartItem),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          _loadingCartItems.contains('${cartItem['id']}_remove')
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
    });
  }
}

