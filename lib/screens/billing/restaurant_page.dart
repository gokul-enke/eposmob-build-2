import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';

import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/restaurant/table_model.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart'; // Import CartProvider

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  String? _activeTableId;
  int? _activeCategoryId;
  dynamic _selectedOrderFromOrderPanel; // New state to hold selected order
  int? _refreshCounter; // Counter to trigger refreshes without creating new objects
  final GlobalKey<_OrderPanelState> _orderPanelKey = GlobalKey<_OrderPanelState>(); // Key to access OrderPanel methods

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
              setState(() {
                _activeTableId = id;
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
            onSendToKitchen: _sendOrderToKitchen, // Pass the new callback
            onNewOrder: _handleNewOrder, // Pass the new callback
            onOrderSelected: (order) {
              setState(() {
                _selectedOrderFromOrderPanel = order;
              });
            }, // Pass callback to update selected order
            selectedOrderFromParent:
                _selectedOrderFromOrderPanel, // Pass the selected order
            refreshCounter: _refreshCounter, // Pass refresh counter
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size screenSize) {
    return Column(
      children: [
        // Top section with tables and order summary
        SizedBox(
          height: screenSize.height * 0.35, // 35% of screen height
          child: Row(
            children: [
              // Tables panel - takes 60% of width
              Expanded(
                flex: 3,
                child: _TablesPanel(
                  activeTableId: _activeTableId,
                  onSelect: (id) {
                    setState(() {
                      _activeTableId = id;
                    });
                  },
                  isCompact: true,
                  screenSize: screenSize,
                ),
              ),
              // Order panel - takes 40% of width
              Expanded(
                flex: 2,
                child: _OrderPanel(
                  key: _orderPanelKey, // Add key to access methods
                  tableId: _activeTableId,
                  isCompact: true,
                  screenSize: screenSize,
                  onSendToKitchen: _sendOrderToKitchen, // Pass the new callback
                  onNewOrder: _handleNewOrder, // Pass the new callback
                  onOrderSelected: (order) {
                    setState(() {
                      _selectedOrderFromOrderPanel = order;
                    });
                  },
                  selectedOrderFromParent:
                      _selectedOrderFromOrderPanel, // Pass the selected order
                  refreshCounter: _refreshCounter, // Pass refresh counter
                ),
              ),
            ],
          ),
        ),
        // Menu panel takes remaining space
        Expanded(
          child: _MenuPanel(
            onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
            activeCategoryId: _activeCategoryId,
            onItemAdd: _handleItemAdd,
            isCompact: true,
            screenSize: screenSize,
            selectedOrder: _selectedOrderFromOrderPanel, // Pass selected order
          ),
        ),
      ],
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
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

      // Determine the cartId to use for API calls
      int? targetCartId;
      bool isEditingExistingOrder = _selectedOrderFromOrderPanel != null;
      
      if (isEditingExistingOrder) {
        // If a saved order is open, use its cart_id
        targetCartId = int.tryParse((_selectedOrderFromOrderPanel['cart']
                        ?['id'] ??
                    _selectedOrderFromOrderPanel['cart_id'])
                ?.toString() ??
            '');
        debugPrint('🔄 Editing existing order - Using cart_id from selected order: $targetCartId');
      } else {
        // If no saved order is open, add to local cart first (new order flow)
        debugPrint('🛒 Adding product to local cart via LocalProductProvider (new order)');
        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: product.price?.price != null ? double.tryParse(product.price!.price!) : null,
          mrp: product.mrp != null ? double.tryParse(product.mrp!) : null,
        );
      }

      // Check if this is a new cart (no existing cart items) - only relevant for new orders
      final isNewCart = !isEditingExistingOrder && (cartProvider.cartData.isEmpty ||
          cartProvider.cartData.first.cartItems?.isEmpty == true);

      // Use cart API directly
      debugPrint(
          '📦 addToCartAPI Request Body: {customerId: ${authModel.userId ?? 1}, productId: ${product.productId!}, quantity: $quantity, unitPrice: ${product.price?.price?.toString()}, cartId: $targetCartId}');
      debugPrint('➡️ Calling CartProvider.addToCartAPI');
      final addResponse = await cartProvider.addToCartAPI(
        customerId: authModel.userId ?? 1,
        productId: product.productId!,
        quantity: quantity,
        accessToken: authModel.token ?? '',
        unitPrice: product.price?.price?.toString(),
        cartId: targetCartId,
      );
      debugPrint('✅ addToCartAPI Response: $addResponse');

      // If this is the first item in a new cart, automatically create an order with status "new"
      if (isNewCart && !isEditingExistingOrder) {
        debugPrint(
            '🔄 First item added to new cart, creating initial order...');
        // Wait a bit for cart data to be updated
        await Future.delayed(const Duration(milliseconds: 500));
        await _createInitialOrder();
      }

      // Show success message
      if (mounted) {
        final messageContext = isEditingExistingOrder ? 'existing order' : 'Table $_activeTableId';
        showScaffold(
          context: context,
          message: 'Added ${product.productName} to $messageContext',
        );

        // If a saved order was active, trigger a refresh
        if (isEditingExistingOrder) {
          // Wait a bit for the cart to be updated on the server
          await Future.delayed(const Duration(milliseconds: 1000));

          // Use a more stable refresh mechanism
          setState(() {
            // Just increment a simple counter instead of creating new objects
            _refreshCounter = (_refreshCounter ?? 0) + 1;
          });
          
          // Also refresh the saved orders list to show updated totals (keeping current selection)
          debugPrint('🔄 Refreshing saved orders after adding item to existing order');
          _orderPanelKey.currentState?.refreshSavedOrdersKeepingSelection();
        }
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to add item: ${e.toString()}',
      );
    }
  }

  Future<void> _createInitialOrder() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

      // Get cart data from local provider (same as billing page)
      final cartItems = localProductProvider.getCartItems();
      debugPrint('🔍 Cart data from local provider: ${cartItems.length} items');

      if (cartItems.isEmpty) {
        debugPrint('❌ No cart items found to create order from');
        return; // No cart items to create order from
      }

      // Convert local cart items to API format (same as billing page)
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

      final total = localProductProvider.cartTotal;

      // Create order with status "new" and table association
      debugPrint(
          '🔄 Creating order with ${items.length} items for Table $_activeTableId');
      debugPrint('➡️ Calling CartProvider.addToOrderAPI');
      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0, // Use 0 for new cart since we're creating a new order
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
        comment: "Order for Table $_activeTableId", // Table context
        deliveryMethodId: null,
        carNumber: null,
        status: "new", // Status for new restaurant orders
        deliveryDate: null,
        deliveryTime: null,
        tableId: _activeTableId, // 🔧 KEY: Table association
      );

      debugPrint(
          '✅ Initial order created with status "new" for Table $_activeTableId');
      debugPrint('🔍 Order response: $response');

      // Refresh saved orders to show the new order
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Trigger a refresh of saved orders in the order panel
        debugPrint('🔄 Refreshing saved orders after creating initial order');
        _orderPanelKey.currentState?.refreshSavedOrders();
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Failed to create initial order: ${e.toString()}');
      // Don't show error to user as this is background operation
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
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

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

      // Get cart total from local provider
      final total = localProductProvider.cartTotal;

      // Call the addToOrderAPI with status: "new"
      debugPrint('➡️ Calling CartProvider.addToOrderAPI');
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
        comment: "Order for Table $_activeTableId", // Add a comment for context
        deliveryMethodId: null, // Not applicable
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
              'Order for Table $_activeTableId sent to kitchen successfully! Order ID: ${response["order_id"]}',
        );

        // Clear the local cart after successful submission
        if (cartItems.isNotEmpty) {
          debugPrint('🗑️ Clearing local cart after successful kitchen order');
          localProductProvider.clearCart();
        }

        // Refresh saved orders for the currently opened table
        if (mounted && _activeTableId != null) {
          debugPrint('🔄 Refreshing saved orders after sending order to kitchen');
          await Future.delayed(const Duration(milliseconds: 1000)); // Wait for server to process
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
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

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

    showScaffold(
      context: context,
      message: 'New order started. Cart cleared and table deselected.',
    );
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
                    color:_getTableBackgroundColor(table.status),
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

class _MenuPanel extends StatelessWidget {
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
        final selectedCategoryId = activeCategoryId ??
            (categories.isNotEmpty ? categories.first.categoryId : null);

        // Get products for selected category
        List<GetProduct> items = [];
        if (selectedCategoryId != null) {
          if (selectedCategoryId == 0) {
            // "ALL" category - show all products
            items = productProvider.filteredProducts;
          } else {
            // Specific category - filter products
            items = productProvider.products
                .where((product) => product.categoryId == selectedCategoryId)
                .toList();
          }
        }

        // Calculate responsive grid columns with better aspect ratios
        int crossAxisCount;
        double childAspectRatio;

        if (isCompact) {
          // Mobile/small tablet layout
          if (screenSize.width > 600) {
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
          if (screenSize.width > 1400) {
            crossAxisCount = 4;
            childAspectRatio =
                1.6; // Balanced - prevents overflow while keeping compact
          } else if (screenSize.width > 1000) {
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
                padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
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
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Menu',
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          isCompact ? FontSize.s16 : FontSize.s18,
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
                  height: isCompact ? 56 : 64,
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
                            horizontal: isCompact ? 12 : 16),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, idx) {
                          final c = categories[idx];
                          final active = c.categoryId == selectedCategoryId;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  onCategoryChanged(c.categoryId);
                                  // Update products for selected category
                                  if (c.categoryId == 0) {
                                    // "ALL" category
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
                                      horizontal: isCompact ? 16 : 20,
                                      vertical: isCompact ? 8 : 10),
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
                                          isCompact
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
                        itemCount: categories.length,
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
                            padding: EdgeInsets.all(isCompact ? 6 : 8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: isCompact ? 6 : 8,
                              crossAxisSpacing: isCompact ? 6 : 8,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, idx) {
                              final item = items[idx];
                              return _buildMenuItem(item, isCompact, context);
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

    // Find primary image
    String? primaryImage;
    if (item.attachment != null && item.attachment!.isNotEmpty) {
      for (var attachment in item.attachment!) {
        if (attachment.isPrimary == 1) {
          primaryImage = attachment.filePath;
          break;
        }
      }
      // If no primary image found, use the first one
      if (primaryImage == null && item.attachment!.isNotEmpty) {
        primaryImage = item.attachment!.first.filePath;
      }
    }

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
                  onItemAdd(item, 1);
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
                    // Product image
                    if (primaryImage != null)
                      Container(
                        height: compact ? 50 : 60,
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: compact ? 4 : 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            primaryImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.image_not_supported,
                                size: compact ? 24 : 30,
                                color: Colors.grey),
                          ),
                        ),
                      ),
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
                            '₹${item.price?.price ?? '0'}',
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
                          Container(
                            padding: EdgeInsets.all(compact ? 2 : 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.add,
                              color: const Color(0xFF2563EB),
                              size: compact ? 12 : 14,
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
  final Function(dynamic)
      onOrderSelected; // New callback to update selected order
  final dynamic
      selectedOrderFromParent; // Add this to track parent's selected order
  final int? refreshCounter; // Add refresh counter

  const _OrderPanel({
    super.key, // Add key parameter
    required this.tableId,
    this.isCompact = false,
    required this.screenSize,
    required this.onSendToKitchen, // Make it required
    required this.onNewOrder, // Make it required
    required this.onOrderSelected, // Make it required
    this.selectedOrderFromParent, // Add this parameter
    this.refreshCounter, // Add refresh counter parameter
  });

  @override
  State<_OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<_OrderPanel> {
  dynamic _selectedOrder;
  List<dynamic> _savedOrders = [];
  bool _isLoadingOrders = false;
  bool _isLoadingOrderDetails = false;
  String? _error;

  @override
  void didUpdateWidget(covariant _OrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tableId != oldWidget.tableId && widget.tableId != null) {
      _fetchSavedOrders();
    } else if (widget.tableId == null) {
      setState(() {
        _savedOrders = [];
        _selectedOrder = null;
        _error = null;
      });
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
      debugPrint('🔄 External refresh of saved orders triggered for table: ${widget.tableId}');
      _fetchSavedOrders();
    }
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
            final currentOrderId = currentSelectedOrder['id'] ?? currentSelectedOrder['order_id'];
            final updatedOrder = newOrders.firstWhere(
              (order) => order['id'] == currentOrderId || order['order_id'] == currentOrderId,
              orElse: () => null,
            );
            
            if (updatedOrder != null) {
              _selectedOrder = updatedOrder; // Update with fresh data
              debugPrint('✅ Updated selected order with fresh data');
            } else {
              // Keep the current selection - don't clear it immediately
              // The order might just be processing on the server
              debugPrint('⚠️ Selected order not found in updated list, keeping current selection');
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

  Future<void> _fetchOrderDetails(dynamic order) async {
    setState(() {
      _isLoadingOrderDetails = true;
      _error = null;
    });

    try {
      debugPrint('🔄 _fetchOrderDetails: Processing saved order data.');
      _selectedOrder =
          order; // Set the selected order directly - no need to modify local cart
      widget.onOrderSelected(
          order); // Call the callback to update the parent widget
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
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);
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
          _buildPanelHeader('Saved Orders', Icons.receipt, Colors.blue,
              itemCount: _savedOrders.length,
              subtitle: widget.tableId.toString()),
          Expanded(
            child: _savedOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add_shopping_cart,
                            size: widget.isCompact ? 48 : 64,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No orders found',
                          textAlign: TextAlign.center,
                          style: buildCustomStyle(
                              FontWeightManager.bold,
                              widget.isCompact ? FontSize.s16 : FontSize.s18,
                              0.21,
                              const Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add products from the menu\nto start a new order',
                          textAlign: TextAlign.center,
                          style: buildCustomStyle(
                              FontWeightManager.medium,
                              widget.isCompact ? FontSize.s13 : FontSize.s14,
                              0.21,
                              const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                : ListView.separated(
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
        ],
      ),
    );
  }

  Widget _buildOrderListItem(dynamic order) {
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
                  Text(
                    '${order['order_number']}',
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        widget.isCompact ? FontSize.s13 : FontSize.s15,
                        0.21,
                        const Color(0xFF1E293B)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getOrderStatusColor(order['status'])
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${order['status']}'.toUpperCase(),
                      style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          widget.isCompact ? FontSize.s11 : FontSize.s13,
                          0.21,
                          _getOrderStatusColor(order['status'])),
                    ),
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

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'init':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderDetailsView() {
    // Get cart items from the saved order
    List<dynamic> cartItems = [];
    if (_selectedOrder['cart'] != null &&
        _selectedOrder['cart']['cart_items'] != null) {
      cartItems = _selectedOrder['cart']['cart_items'];
    } else if (_selectedOrder['cart_items'] != null &&
        _selectedOrder['cart_items']['cart_items'] != null) {
      cartItems = _selectedOrder['cart_items']['cart_items'];
    }

    final total =
        double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
            0.0;

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
            onBackButtonPressed: () => setState(() => _selectedOrder = null),
            totalPrice: total,
            subtitle: '${_selectedOrder['order_number']}',
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
                          'No items in this order',
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
                          return _buildSavedOrderItem(item, idx);
                        },
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
                '₹${totalPrice.toStringAsFixed(0)}',
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
            // First row: Confirm Order button
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: cartItems.isEmpty ? null : () => _confirmOrder(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: widget.isCompact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: cartItems.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: cartItems.isNotEmpty
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: widget.isCompact ? 16 : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confirm Order',
                            style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                widget.isCompact ? FontSize.s13 : FontSize.s14,
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
            const SizedBox(height: 12),
            // Second row: Back and Update Order buttons
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedOrder = null),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF64748B),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Back',
                            style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                widget.isCompact ? FontSize.s13 : FontSize.s14,
                                0.21,
                                const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: cartItems.isEmpty ? null : () => _updateOrderStatus(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: cartItems.isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: cartItems.isNotEmpty
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF059669).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.update,
                                color: Colors.white,
                                size: widget.isCompact ? 16 : 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Update Order',
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    widget.isCompact ? FontSize.s13 : FontSize.s14,
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

  // Cart API methods for saved orders
  Future<void> _updateCartItemQuantity(
      dynamic cartItem, double newQuantity) async {
    final currentQuantity =
        double.tryParse(cartItem['quantity'].toString()) ?? 0.0;

    if (newQuantity <= 0) {
      await _removeCartItem(cartItem);
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get customer ID from the order data
      final customerId = _selectedOrder['cart']?['customer_id'] ?? 1;
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

        response = await cartProvider.addToCartAPI(
          customerId: int.parse(customerId.toString()),
          productId: int.parse(productId.toString()),
          quantity: deltaQuantity,
          unitPrice: unitPrice,
          accessToken: authModel.token ?? '',
          cartId: orderCartId,
        );
        debugPrint('✅ addToCartAPI Response: $response');
      } else if (newQuantity < currentQuantity) {
        // Decrement quantity - use decrementCartItemQuantityAPI
        debugPrint(
            '➡️ Calling CartProvider.decrementCartItemQuantityAPI for decrement');
        debugPrint(
            '📦 decrementCartItemQuantityAPI Request Body: {customerId: $customerId, cartItemId: ${cartItem['id']}, quantity: ${newQuantity.toInt()}, cartId: $orderCartId}');

        response = await cartProvider.decrementCartItemQuantityAPI(
          customerId: int.parse(customerId.toString()),
          productId:
              int.parse(cartItem['id'].toString()), // This is cart_item_id
          cartId: orderCartId,
          quantity: newQuantity.toInt(),
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

        for (var item in cartItemsList) {
          if (item['id'].toString() == cartItem['id'].toString()) {
            item['quantity'] = newQuantity.toString();
            item['total_price'] =
                (newQuantity * double.parse(item['unit_price'].toString()))
                    .toString();
            break;
          }
        }
      });

      // Check if the response indicates success (handle 'success' and 'sucesss' typo)
      if (response != null &&
          (response['status']?.toLowerCase() == 'success' ||
              response['status']?.toLowerCase() == 'sucesss')) {
        // Try to refresh the order details, but don't fail if it doesn't work
        try {
          await _refreshOrderDetails();
        } catch (e) {
          debugPrint(
              '⚠️ Could not refresh order details, but update was successful: $e');
        }

        // Also refresh the saved orders list to show updated totals (keeping current selection)
        debugPrint('🔄 Refreshing saved orders after updating cart item quantity');
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshSavedOrdersKeepingSelection();

        showScaffold(
          context: context,
          message: 'Item quantity updated successfully',
        );
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

          for (var item in cartItemsList) {
            if (item['id'].toString() == cartItem['id'].toString()) {
              item['quantity'] =
                  currentQuantity.toString(); // Revert to original
              item['total_price'] = (currentQuantity *
                      double.parse(item['unit_price'].toString()))
                  .toString(); // Revert to original
              break;
            }
          }
        });

        showScaffoldError(
          context: context,
          message:
              'Failed to update quantity: ${response?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating cart item quantity: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to update quantity: ${e.toString()}',
      );
    }
  }

  Future<void> _removeCartItem(dynamic cartItem) async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get customer ID from the order data
      final customerId = _selectedOrder['cart']['customer_id'] ?? 1;
      final cartId = int.tryParse(_selectedOrder['cart_id'].toString());

      debugPrint(
          '🗑️ Removing cart item: Sending request with customerId: $customerId, cartItemId: ${cartItem['id']}');
      // Use the cart API to remove item with correct cart_item_id
      final response = await cartProvider.removeFromCartAPI(
        customerId: int.parse(customerId.toString()),
        productId:
            int.parse(cartItem['id'].toString()), // Send cart_item_id here
        accessToken: authModel.token ?? '',
        cartId: cartId,
      );

      debugPrint('🗑️ Remove response: $response');

      // Update the UI optimistically first
      setState(() {
        // Remove the cart item from the selected order
        final cartItems = _selectedOrder['cart']['cart_items'] as List<dynamic>;
        cartItems.removeWhere(
            (item) => item['id'].toString() == cartItem['id'].toString());
      });

      // Check if the response indicates success
      if (response != null) {
        // Try to refresh the order details, but don't fail if it doesn't work
        try {
          await _refreshOrderDetails();
        } catch (e) {
          debugPrint(
              '⚠️ Could not refresh order details, but removal was successful: $e');
        }

        // Also refresh the saved orders list to show updated totals (keeping current selection)
        debugPrint('🔄 Refreshing saved orders after removing cart item');
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshSavedOrdersKeepingSelection();

        showScaffold(
          context: context,
          message: 'Item removed successfully',
        );
      } else {
        // Revert the optimistic update by refreshing saved orders (keeping current selection)
        await refreshSavedOrdersKeepingSelection();

        showScaffoldError(
          context: context,
          message: 'Failed to remove item: Server returned empty response',
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

  Future<void> _confirmOrder() async {
    if (_selectedOrder == null) {
      showScaffoldError(
        context: context,
        message: 'No order selected to confirm',
      );
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Get order details
      final orderId = _selectedOrder['id'] ?? _selectedOrder['order_id'];
      final orderNumber = _selectedOrder['order_number'];

      debugPrint('🔄 Confirming order: $orderNumber (ID: $orderId)');

      // Get order details for API call
      final customerId = _selectedOrder['customer_id'] ?? authModel.userId ?? 1;
      final customerPhone = _selectedOrder['customer_phone'] ?? '';
      final totalPrice = _selectedOrder['grand_total']?.toString() ?? '0';
      final transactionId = _selectedOrder['transaction_number'] ?? '';
      final comment = _selectedOrder['comment'] ?? 'Order confirmed from restaurant';

      debugPrint('📦 Order details for confirmation:');
      debugPrint('   - Customer ID: $customerId');
      debugPrint('   - Customer Phone: $customerPhone');
      debugPrint('   - Total Price: $totalPrice');
      debugPrint('   - Transaction ID: $transactionId');

      // Call update order API with status "confirmed"
      final response = await cartProvider.updateOrderAPI(
        orderId: orderId.toString(),
        accessToken: authModel.token ?? '',
        transactionId: transactionId,
        totalPrice: totalPrice,
        customerId: int.tryParse(customerId.toString()),
        customerPhone: customerPhone,
        status: 'confirmed',
        comment: comment,
      );

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

        // Go back to orders list
        setState(() => _selectedOrder = null);
      } else {
        showScaffoldError(
          context: context,
          message: 'Failed to confirm order: ${response?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error confirming order: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to confirm order: ${e.toString()}',
      );
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
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s12,
                      0.21,
                      const Color(0xFF059669)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit price and quantity info
          Row(
            children: [
              Text(
                '₹${unitPrice.toStringAsFixed(0)} × ${quantity.toStringAsFixed(0)}',
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
                        style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s14,
                            0.21,
                            const Color(0xFF1E293B)),
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
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onNewOrder(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: widget.isCompact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF64748B),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'New Order',
                        style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            widget.isCompact ? FontSize.s13 : FontSize.s14,
                            0.21,
                            const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      cartItems.isEmpty ? null : () => widget.onSendToKitchen(),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: widget.isCompact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: cartItems.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: cartItems.isNotEmpty
                          ? [
                              BoxShadow(
                                color: const Color(0xFF059669).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send,
                            color: Colors.white,
                            size: widget.isCompact ? 16 : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Send to Kitchen',
                            style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                widget.isCompact ? FontSize.s13 : FontSize.s14,
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
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

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
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

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
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);

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

  Widget _buildSavedOrderItem(dynamic cartItem, int index) {
    final productName = cartItem['product']?['name'] ??
        cartItem['product_name'] ??
        cartItem['names']?[0]?['name'] ??
        'Unknown Product';
    final quantity = double.tryParse(cartItem['quantity'].toString()) ?? 0.0;
    final unitPrice = double.tryParse(cartItem['unit_price'].toString()) ?? 0.0;
    final totalPrice = double.tryParse(cartItem['total_price'].toString()) ??
        (quantity * unitPrice);

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
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      widget.isCompact ? FontSize.s12 : FontSize.s14,
                      0.21,
                      const Color(0xFF059669)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Unit price and quantity info
          Row(
            children: [
              Text(
                '₹${unitPrice.toStringAsFixed(0)} × ${quantity.toStringAsFixed(0)}',
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
                        onTap: () =>
                            _updateCartItemQuantity(cartItem, quantity - 1),
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
                        onTap: () =>
                            _updateCartItemQuantity(cartItem, quantity + 1),
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
                  onTap: () => _removeCartItem(cartItem),
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
}
