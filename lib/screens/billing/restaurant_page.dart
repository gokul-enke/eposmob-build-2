import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';

import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/restaurant/table_model.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart'; // Import CartProvider

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../screens/customers/add_customer_modal.dart';
import '../../screens/billing/widgets/payment_method_modal.dart';
import 'package:pos_machine/helpers/amount_helper.dart'; // Add AmountHelper import
import '../../components/build_round_button.dart'; // Add button import
import '../../providers/keyboard_provider.dart'; // Add keyboard provider import
import 'package:pos_machine/providers/delivery_methods_provider.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

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
            onSendToKitchen:
                _sendOrderToKitchenWithLoading, // Use wrapper method
            onNewOrder: _handleNewOrder, // Pass the new callback
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
                  onSendToKitchen:
                      _sendOrderToKitchenWithLoading, // Use wrapper method
                  onNewOrder: _handleNewOrder, // Pass the new callback
                  onOrderSelected: (order) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedOrderFromOrderPanel = order;
                        });
                      }
                    });
                  },
                  selectedOrderFromParent:
                      _selectedOrderFromOrderPanel, // Pass the selected order
                  refreshCounter: _refreshCounter, // Pass refresh counter
                  isLoadingSendToKitchen:
                      _isLoadingSendToKitchen, // Pass loading state
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
        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: product.price?.price != null
              ? double.tryParse(product.price!.price!)
              : null,
          mrp: product.mrp != null ? double.tryParse(product.mrp!) : null,
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

      // Get cart total from local provider
      final total = localProductProvider.cartTotal;

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
            : "Order for Table $_activeTableId", // Add a comment for context
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
              'Order for Table $_activeTableId sent to kitchen successfully! Order ID: ${response["order_id"]}',
        );

        // Clear the local cart after successful submission
        if (cartItems.isNotEmpty) {
          debugPrint('🗑️ Clearing local cart after successful kitchen order');
          localProductProvider.clearCart();
        }

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
                                  '₹${product.price!.price}',
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
                            _buildKeyValueRow('MRP', '₹${product.mrp}'),
                          if (product.price?.price != null)
                            _buildKeyValueRow(
                                'Price', '₹${product.price!.price}'),

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
        final selectedCategoryId = widget.activeCategoryId ??
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
                        itemBuilder: (_, idx) {
                          final c = categories[idx];
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
                        itemCount: categories.length,
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
  final Function(dynamic)
      onOrderSelected; // New callback to update selected order
  final dynamic
      selectedOrderFromParent; // Add this to track parent's selected order
  final int? refreshCounter; // Add refresh counter
  final bool isLoadingSendToKitchen; // Loading state for Send to Kitchen button

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
    this.isLoadingSendToKitchen = false, // Add loading state parameter
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
  final Set<String> _loadingCartItems =
      {}; // Track which cart items are being updated
  bool _isLoadingConfirm = false; // Loading state for Confirm button

  // Payment Method Variables
  bool _isCashSelected = false;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  bool _isDebitSelected = false;
  String _cashAmount = "";
  String _cardAmount = "";
  String _upiAmount = "";
  String _debitAmount = "";
  String _transactionNumber = "";
  double _balanceAmount = 0.0;
  bool _toCustomerCreditEnabled = false;
  double _toCustomerCreditAmount = 0.0; // Store the actual credit amount
  String _orderComment = "";

  // Expose current comment to parent (RestaurantPage) for new order flow
  String get orderComment => _orderComment;

  // Customer Selection Variables
  CustomerListModelData? _selectedCustomer;
  int? _selectedCustomerID;
  String? _selectedCustomerPhone;
  List<CustomerListModelData> _customers = [];

  // Discount Variables
  bool _isCouponApplied = false;
  double _flatDiscount = 0.0;
  double _percentageDiscount = 0.0;
  String _couponCode = "";

  @override
  void didUpdateWidget(covariant _OrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Initialize customers when first loaded - defer to avoid setState during build
    if (_customers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCustomers();
      });
    }

    if (widget.tableId != oldWidget.tableId && widget.tableId != null) {
      _fetchSavedOrders();
    } else if (widget.tableId == null) {
      setState(() {
        _savedOrders = [];
        _selectedOrder = null;
        _error = null;
      });
      // Clear state when no table is selected
      _clearOrderEditingState();
      widget.onOrderSelected(null);
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
    }
  }

  // Public method to refresh saved orders silently (no loading spinner)
  void refreshSavedOrdersSilently() {
    if (widget.tableId != null) {
      debugPrint(
          '🔄 External silent refresh of saved orders triggered for table: ${widget.tableId}');
      _refreshSavedOrdersSilently();
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);

      await customerProvider.loadAllCustomers(
        authModel.token ?? '',
      );

      setState(() {
        _customers = customerProvider.customerList ?? [];
      });
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  void _showPaymentMethodModal() {
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

    debugPrint(
        '💰 Payment Modal - Cart items count: ${cartItems.length}, Order Total: ₹${orderTotal.toStringAsFixed(2)}');

    final customerPrevBalance = _selectedCustomer?.balance ?? 0.0;

    // Auto-fill cash amount if no payment methods are currently selected
    String autoFillCashAmount = _cashAmount;
    bool autoSelectCash = _isCashSelected;

    if (!_isCashSelected &&
        !_isCardSelected &&
        !_isUpiSelected &&
        !_isDebitSelected) {
      // No payment method selected, auto-fill cash with order total
      autoFillCashAmount = orderTotal.toStringAsFixed(2);
      autoSelectCash = true;
      debugPrint(
          '🔧 Auto-fill triggered: Cash amount set to ₹${autoFillCashAmount}, Cash selected: $autoSelectCash');
    } else {
      debugPrint('🔧 Auto-fill skipped: Payment methods already selected');
    }

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: autoSelectCash,
        initialIsCardSelected: _isCardSelected,
        initialIsUpiSelected: _isUpiSelected,
        initialIsDebitSelected: _isDebitSelected,
        initialCashAmount: autoFillCashAmount,
        initialCardAmount: _cardAmount,
        initialUpiAmount: _upiAmount,
        initialDebitAmount: _debitAmount,
        initialTransactionNumber: _transactionNumber,
        cartTotal: orderTotal,
        customerPrevBalance: customerPrevBalance,
        onPaymentMethodSelected: (isCash, isCard, isUpi, isDebit, cash, card,
            upi, debit, transaction, toCustomerCredit) {
          setState(() {
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _isDebitSelected = isDebit;
            _cashAmount = cash;
            _cardAmount = card;
            _upiAmount = upi;
            _debitAmount = debit;
            _transactionNumber = transaction;
            _toCustomerCreditEnabled = toCustomerCredit;
            // Capture the actual customer credit amount from the debit parameter
            _toCustomerCreditAmount = double.tryParse(debit) ?? 0.0;

            debugPrint('💳 Payment Method Updated:');
            debugPrint(
                '  - To Customer Credit Enabled: $_toCustomerCreditEnabled');
            debugPrint(
                '  - Customer Credit Amount: ₹${_toCustomerCreditAmount.toStringAsFixed(2)}');

            // Calculate balance
            final totalPaid = (double.tryParse(cash) ?? 0.0) +
                (double.tryParse(card) ?? 0.0) +
                (double.tryParse(upi) ?? 0.0);
            _balanceAmount = totalPaid - orderTotal;
          });
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
                                          });
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

  void _showDiscountModal() {
    if (_selectedOrder == null) return;

    // Calculate current order total from cart items for discount calculation
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

    // Calculate subtotal for discount modal
    double orderSubTotal = 0.0;
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

    // If we still have zero total, try getting it from order total as fallback
    if (orderSubTotal == 0.0 && _selectedOrder['grand_total'] != null) {
      orderSubTotal =
          double.tryParse(_selectedOrder['grand_total']?.toString() ?? '0') ??
              0.0;
    }

    debugPrint(
        '🎫 Discount Modal - Order Subtotal: ₹${orderSubTotal.toStringAsFixed(2)}');

    showDialog(
      context: context,
      builder: (context) => RestaurantCouponModal(
        initialCouponCode: _couponCode,
        isCouponApplied: _isCouponApplied,
        orderSubTotal: orderSubTotal,
        currentFlatDiscount: _flatDiscount,
        currentPercentageDiscount: _percentageDiscount,
        onCouponAction: (couponCode, isApplied,
            {flatDiscount, percentageDiscount}) {
          setState(() {
            _couponCode = couponCode;
            _isCouponApplied = isApplied;
            _flatDiscount = flatDiscount ?? 0.0;
            _percentageDiscount = percentageDiscount ?? 0.0;

            debugPrint('🎫 Discount Applied in Restaurant Page:');
            debugPrint('  - Coupon Code: $_couponCode');
            debugPrint('  - Is Applied: $_isCouponApplied');
            debugPrint(
                '  - Flat Discount: ₹${_flatDiscount.toStringAsFixed(2)}');
            debugPrint(
                '  - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');

            // If clearing discount
            if (!isApplied) {
              debugPrint('🧹 Clearing all discount values');
              _couponCode = "";
              _flatDiscount = 0.0;
              _percentageDiscount = 0.0;
            }
          });
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
      _isDebitSelected = false;
      _cashAmount = "";
      _cardAmount = "";
      _upiAmount = '';
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
    });
    debugPrint('✅ Order editing state cleared');
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

        debugPrint('✅ Loaded customer: ${customer.name} (${customer.phone})');
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
          _isDebitSelected = false;
          _cashAmount = '';
          _cardAmount = '';
          _upiAmount = '';
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
            default:
              // Default to cash if payment method is unknown
              _isCashSelected = true;
              _cashAmount = paidAmount;
          }
        });

        debugPrint(
            '✅ Loaded payment method: $paymentMethod, Amount: ₹$paidAmount');
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
              (e) => (e is Map) && (e['code']?.toString()?.toUpperCase() == 'COMMENT'),
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
          loadedComment = loadedComment!.substring(1, loadedComment!.length - 1);
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
        debugPrint('   - Flat Discount: ₹${_flatDiscount.toStringAsFixed(2)}');
        debugPrint(
            '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
        debugPrint('   - Coupon Code: $_couponCode');
      }

      // Calculate balance amount
      final orderTotal =
          double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0.0;
      final totalPaid = double.tryParse(paidAmount) ?? 0.0;
      _balanceAmount = totalPaid - orderTotal;

      debugPrint(
          '💰 Calculated balance: ₹${_balanceAmount.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('❌ Error loading order-specific data: $e');
    }

    debugPrint('✅ Order-specific data loading completed');
  }

  bool _hasPaymentMethod() {
    return _isCashSelected ||
        _isCardSelected ||
        _isUpiSelected ||
        _isDebitSelected;
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
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
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
        '💰 Payment Summary - Cart items count: ${cartItems.length}, Order Total: ₹${orderTotal.toStringAsFixed(2)}');

    final customerBalance = _selectedCustomer?.balance ?? 0.0;
    final cashAmount = double.tryParse(_cashAmount) ?? 0.0;
    final cardAmount = double.tryParse(_cardAmount) ?? 0.0;
    final upiAmount = double.tryParse(_upiAmount) ?? 0.0;
    final totalPaidAmount = cashAmount + cardAmount + upiAmount;

    debugPrint('\n🧮 === RESTAURANT PAGE BALANCE CALCULATION START ===');
    debugPrint('💰 Input Values:');
    debugPrint('  - Order Total: ₹${orderTotal.toStringAsFixed(2)}');
    debugPrint('  - Customer Balance: ₹${customerBalance.toStringAsFixed(2)}');
    debugPrint('  - Cash Amount: ₹${cashAmount.toStringAsFixed(2)}');
    debugPrint('  - Card Amount: ₹${cardAmount.toStringAsFixed(2)}');
    debugPrint('  - UPI Amount: ₹${upiAmount.toStringAsFixed(2)}');
    debugPrint('  - Total Paid Amount: ₹${totalPaidAmount.toStringAsFixed(2)}');
    debugPrint('  - To Customer Credit Enabled: $_toCustomerCreditEnabled');
    debugPrint(
        '  - Customer Credit Amount: ₹${_toCustomerCreditAmount.toStringAsFixed(2)}');

    // Calculate balance using the same logic as billing_page.dart
    double cashBalance = 0.0;

    if (_toCustomerCreditEnabled && _selectedCustomer != null) {
      debugPrint(
          '🔛 RESTAURANT PAGE: Toggle is ON - Calculating with customer credit consideration');

      if (customerBalance < 0) {
        // Customer has debt - use transaction excess logic for consistency with auto-fill
        debugPrint('💳 Customer has debt - using transaction excess logic');
        final transactionExcess = totalPaidAmount - orderTotal;
        debugPrint(
            '💰 Transaction excess: ₹${transactionExcess.toStringAsFixed(2)}');

        if (transactionExcess > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = _toCustomerCreditAmount;

          // Clamp customer credit to available excess
          if (actualCustomerCredit > transactionExcess) {
            actualCustomerCredit = transactionExcess;
            debugPrint(
                '  - Clamped customer credit to transaction excess: ₹${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = transaction excess - customer credit
          cashBalance = transactionExcess - actualCustomerCredit;
          debugPrint(
              '  - Balance = Transaction Excess (₹${transactionExcess.toStringAsFixed(2)}) - Customer Credit (₹${actualCustomerCredit.toStringAsFixed(2)}) = ₹${cashBalance.toStringAsFixed(2)}');
        } else {
          cashBalance = 0.0;
          debugPrint('  - No transaction excess, balance = 0');
        }
      } else {
        // Customer has positive/zero balance - use Net Due logic
        debugPrint('💵 Customer has credit/zero balance - using Net Due logic');
        // Net Due = Purchase Total - Customer Previous Balance
        double netDue = orderTotal - customerBalance;
        debugPrint('💰 Net Due calculation:');
        debugPrint('  - Purchase Total: ₹${orderTotal.toStringAsFixed(2)}');
        debugPrint(
            '  - Customer Prev Balance: ₹${customerBalance.toStringAsFixed(2)}');
        debugPrint('  - Net Due: ₹${netDue.toStringAsFixed(2)}');

        // Available balance = Total Collected - Net Due
        double availableBalance = totalPaidAmount - netDue;
        debugPrint(
            '  - Total Collected: ₹${totalPaidAmount.toStringAsFixed(2)}');
        debugPrint(
            '  - Available Balance: ₹${availableBalance.toStringAsFixed(2)}');

        if (availableBalance > 0) {
          // Get the actual customer credit amount being allocated
          double actualCustomerCredit = _toCustomerCreditAmount;

          // Clamp customer credit to available balance
          if (actualCustomerCredit > availableBalance) {
            actualCustomerCredit = availableBalance;
            debugPrint(
                '  - Clamped customer credit to available balance: ₹${actualCustomerCredit.toStringAsFixed(2)}');
          }

          // Cash balance = available balance - customer credit
          cashBalance = availableBalance - actualCustomerCredit;
          debugPrint(
              '  - Balance = Available Balance (₹${availableBalance.toStringAsFixed(2)}) - Customer Credit (₹${actualCustomerCredit.toStringAsFixed(2)}) = ₹${cashBalance.toStringAsFixed(2)}');
        } else {
          cashBalance = 0.0;
          debugPrint('  - No available balance, balance = 0');
        }
      }
    } else {
      debugPrint(
          '🔴 RESTAURANT PAGE: Toggle is OFF - Using simple calculation');
      // Toggle OFF: Simple calculation without previous balance
      cashBalance = totalPaidAmount - orderTotal;
      debugPrint(
          '  - Balance = Total Collected (₹${totalPaidAmount.toStringAsFixed(2)}) - Cart Total (₹${orderTotal.toStringAsFixed(2)}) = ₹${cashBalance.toStringAsFixed(2)}');
    }

    // Store the raw balance before clamping for comparison
    double rawBalance = cashBalance;

    // Clamp cash balance to never show negative values in UI
    // Negative balance means insufficient payment, but cash drawer can't give negative money
    if (cashBalance < 0) {
      debugPrint(
          '🚫 RESTAURANT PAGE: Clamping negative cash balance (₹${cashBalance.toStringAsFixed(2)}) to 0 for UI display');
      cashBalance = 0.0;
    }

    debugPrint('💵 Final cash balance: ₹${cashBalance.toStringAsFixed(2)}');
    debugPrint(
        '💵 Raw balance (before clamping): ₹${rawBalance.toStringAsFixed(2)}');
    debugPrint('🧮 === RESTAURANT PAGE BALANCE CALCULATION END ===\n');

    // Calculate discount amounts
    final flatDiscountAmount = _flatDiscount;
    final percentageDiscountAmount = (orderTotal * _percentageDiscount / 100);
    final totalDiscountAmount = flatDiscountAmount + percentageDiscountAmount;
    final finalOrderTotal = orderTotal - totalDiscountAmount;

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
            '₹${orderTotal.toStringAsFixed(2)}',
            color: const Color(0xFF64748B),
          ),

          // Show discount information if any discount is applied (single line format like billing_page.dart)
          if (_hasDiscount()) ...[
            _buildSummaryRow(
              'Discount',
              '₹${totalDiscountAmount.toStringAsFixed(2)} (${(orderTotal > 0 ? ((totalDiscountAmount / orderTotal) * 100) : 0.0).toStringAsFixed(1)}%)',
              color: const Color(0xFFDC2626),
            ),
            _buildSummaryRow(
              'Final Total',
              '₹${finalOrderTotal.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
              isBold: true,
            ),
          ] else ...[
            _buildSummaryRow(
              'Final Total',
              '₹${orderTotal.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
              isBold: true,
            ),
          ],

          // Hide discount section for now
          // if (_hasDiscount()) ...[
          //   _buildSummaryRow(
          //     'Discount',
          //     '-₹${discountAmount.toStringAsFixed(2)}',
          //     color: const Color(0xFFD97706),
          //   ),
          //   _buildSummaryRow(
          //     'Final Total',
          //     '₹${finalOrderTotal.toStringAsFixed(2)}',
          //     color: const Color(0xFF1E293B),
          //     isBold: true,
          //   ),
          // ],

          if (_selectedCustomer != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Customer Balance',
              '₹${customerBalance.toStringAsFixed(2)}',
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
              '₹${totalPaidAmount.toStringAsFixed(2)}',
              color: const Color(0xFF059669),
            ),
            _buildSummaryRow(
              'Balance',
              rawBalance >= 0
                  ? '₹${rawBalance.toStringAsFixed(2)}'
                  : 'Short: ₹${(-rawBalance).toStringAsFixed(2)}',
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
    // Get cart items from the saved order - handle multiple possible structures
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
        '📊 Cart items count: ${cartItems.length}, Total: ₹${total.toStringAsFixed(2)}');

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
              setState(() => _selectedOrder = null);
              widget.onOrderSelected(null);
            },
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
            // Payment Summary Section
            _buildPaymentSummary(),
            const SizedBox(height: 16),
            // Payment Method, Customer Selection, and Discount buttons row
            Row(
              children: [
                // Payment Method Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showPaymentMethodModal(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: _hasPaymentMethod()
                              ? const Color(0xFF2563EB).withOpacity(0.1)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: _hasPaymentMethod()
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.payment,
                                color: _hasPaymentMethod()
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF64748B),
                                size: widget.isCompact ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _hasPaymentMethod() ? 'Paid' : 'Payment',
                                  style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      widget.isCompact
                                          ? FontSize.s11
                                          : FontSize.s12,
                                      0.21,
                                      _hasPaymentMethod()
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B)),
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
                const SizedBox(width: 6),
                // Customer Selection Button
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCustomerSelectionModal(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: _selectedCustomer != null
                              ? const Color(0xFF059669).withOpacity(0.1)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: _selectedCustomer != null
                                ? const Color(0xFF059669)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                color: _selectedCustomer != null
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                                size: widget.isCompact ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _selectedCustomer != null
                                      ? (_selectedCustomer!.name
                                              ?.split(' ')
                                              .first ??
                                          'Customer')
                                      : 'Customer',
                                  style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      widget.isCompact
                                          ? FontSize.s11
                                          : FontSize.s12,
                                      0.21,
                                      _selectedCustomer != null
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF64748B)),
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
                // Discount Button
                const SizedBox(width: 6),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDiscountModal(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: _hasDiscount()
                              ? const Color(0xFFD97706).withOpacity(0.1)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: _hasDiscount()
                                ? const Color(0xFFD97706)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.discount,
                                color: _hasDiscount()
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF64748B),
                                size: widget.isCompact ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _hasDiscount() ? 'Applied' : 'Discount',
                                  style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      widget.isCompact
                                          ? FontSize.s11
                                          : FontSize.s12,
                                      0.21,
                                      _hasDiscount()
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B)),
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
              ],
            ),
            const SizedBox(height: 12),
            // First row: Confirm Order button - REMOVED (using bottom Confirm button instead)
            // SizedBox(
            //   width: double.infinity,
            //   child: Material(
            //     color: Colors.transparent,
            //     child: InkWell(
            //       onTap: allItemsReadyOrServed ? () => _confirmOrder() : null,
            //       borderRadius: BorderRadius.circular(12),
            //       child: AnimatedContainer(
            //         duration: const Duration(milliseconds: 200),
            //         height: widget.isCompact ? 44 : 48,
            //         decoration: BoxDecoration(
            //           color: !allItemsReadyOrServed
            //               ? const Color(0xFF94A3B8)
            //               : const Color(0xFF2563EB),
            //           borderRadius: BorderRadius.circular(12),
            //           boxShadow: allItemsReadyOrServed
            //               ? [
            //                   BoxShadow(
            //                     color: const Color(0xFF2563EB).withOpacity(0.3),
            //                     blurRadius: 8,
            //                     offset: const Offset(0, 2),
            //                   ),
            //                 ]
            //               : [],
            //         ),
            //         child: Center(
            //           child: Row(
            //             mainAxisAlignment: MainAxisAlignment.center,
            //             children: [
            //               Icon(
            //                 Icons.check_circle,
            //                 color: Colors.white,
            //                 size: widget.isCompact ? 16 : 18,
            //               ),
            //               const SizedBox(width: 8),
            //               Text(
            //                 'Confirm Order',
            //                 style: buildCustomStyle(
            //                     FontWeightManager.semiBold,
            //                     widget.isCompact ? FontSize.s13 : FontSize.s14,
            //                     0.21,
            //                     Colors.white),
            //               ),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 12),
            // Second row: Back and Update Order buttons
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedOrder = null);
                        widget.onOrderSelected(null);
                      },
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
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              Flexible(
                                child: Text(
                                  'Comment',
                                  style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      widget.isCompact
                                          ? FontSize.s13
                                          : FontSize.s14,
                                      0.21,
                                      const Color(0xFF64748B)),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (cartItems.isEmpty ||
                              !allItemsServed ||
                              _isLoadingConfirm)
                          ? null
                          : () => _confirmOrder(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: (cartItems.isEmpty ||
                                  !allItemsServed ||
                                  _isLoadingConfirm)
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (cartItems.isNotEmpty &&
                                  allItemsServed &&
                                  !_isLoadingConfirm)
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
                          child: _isLoadingConfirm
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
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: widget.isCompact ? 16 : 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Confirm',
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
      final totalPrice = _selectedOrder['grand_total']?.toString() ?? '0';
      final transactionId = _transactionNumber.isNotEmpty
          ? _transactionNumber
          : (_selectedOrder['transaction_number'] ?? '');
      final comment = _orderComment.isNotEmpty
          ? _orderComment
          : (_selectedOrder['comment'] ?? 'Order confirmed from restaurant');

      // Prepare payment method data
      String? paymentMethod;
      String? paidAmount;
      List<String> paymentMethods = [];
      List<Map<String, dynamic>> paidMethods = [];

      if (_hasPaymentMethod()) {
        // Multi-payment handling
        List<String> selectedMethods = [];
        if (_isCashSelected) selectedMethods.add('CASH');
        if (_isCardSelected) selectedMethods.add('CARD');
        if (_isUpiSelected) selectedMethods.add('UPI');

        if (selectedMethods.length > 1) {
          // Multi-payment: store as JSON
          Map<String, dynamic> multiPaymentData = {
            "methods": selectedMethods,
            "amounts": {
              "CASH": _cashAmount.isNotEmpty ? _cashAmount : "0",
              "CARD": _cardAmount.isNotEmpty ? _cardAmount : "0",
              "UPI": _upiAmount.isNotEmpty ? _upiAmount : "0",
            },
            "isMultiPayment": true
          };
          paymentMethod = json.encode(multiPaymentData);

          // Calculate total paid amount
          final cashAmount = double.tryParse(_cashAmount) ?? 0.0;
          final cardAmount = double.tryParse(_cardAmount) ?? 0.0;
          final upiAmount = double.tryParse(_upiAmount) ?? 0.0;
          paidAmount = (cashAmount + cardAmount + upiAmount).toString();

          // Prepare paidMethods array
          if (_isCashSelected) {
            paidMethods.add({
              "method": "CASH",
              "amount": double.tryParse(_cashAmount) ?? 0.0
            });
          }
          if (_isCardSelected) {
            paidMethods.add({
              "method": "CARD",
              "amount": double.tryParse(_cardAmount) ?? 0.0
            });
          }
          if (_isUpiSelected) {
            paidMethods.add({
              "method": "UPI",
              "amount": double.tryParse(_upiAmount) ?? 0.0
            });
          }

          paymentMethods = selectedMethods;
        } else {
          // Single payment method
          paymentMethod = selectedMethods.first;
          if (paymentMethod == "CASH") {
            paidAmount = _cashAmount;
          } else if (paymentMethod == "CARD") {
            paidAmount = _cardAmount;
          } else if (paymentMethod == "UPI") {
            paidAmount = _upiAmount;
          }
        }
      }

      // Calculate balance amount
      final totalPaid = double.tryParse(paidAmount ?? '0') ?? 0.0;
      final orderAmount = double.tryParse(totalPrice) ?? 0.0;
      final balanceAmount = (totalPaid - orderAmount).toString();

      // Calculate discount amount for API
      final orderSubTotal = orderAmount; // Use order amount as subtotal base
      final flatDiscountAmount = _flatDiscount;
      final percentageDiscountAmount =
          (orderSubTotal * _percentageDiscount / 100);
      final totalDiscountAmount = flatDiscountAmount + percentageDiscountAmount;

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
          '   - Flat Discount: ₹${flatDiscountAmount.toStringAsFixed(2)}');
      debugPrint(
          '   - Percentage Discount: ${_percentageDiscount.toStringAsFixed(1)}%');
      debugPrint(
          '   - Total Discount Amount: ₹${totalDiscountAmount.toStringAsFixed(2)}');
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

        // Go back to orders list
        setState(() => _selectedOrder = null);
        widget.onOrderSelected(null);
      } else {
        showScaffoldError(
          context: context,
          message:
              'Failed to confirm order: ${response?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error confirming order: ${e.toString()}');
      showScaffoldError(
        context: context,
        message: 'Failed to confirm order: ${e.toString()}',
      );
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
                  '₹${totalPrice.toStringAsFixed(0)}',
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
            // Bottom row: New Order and Send to Kitchen
            Row(
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
                          (cartItems.isEmpty || widget.isLoadingSendToKitchen)
                              ? null
                              : () => widget.onSendToKitchen(),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: widget.isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          color: (cartItems.isEmpty ||
                                  widget.isLoadingSendToKitchen)
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: (cartItems.isNotEmpty &&
                                  !widget.isLoadingSendToKitchen)
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
                          child: widget.isLoadingSendToKitchen
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
                                      size: widget.isCompact ? 16 : 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Send to Kitchen',
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
                      '₹${totalPrice.toStringAsFixed(0)}',
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
                        onTap: _loadingCartItems
                                .contains('${cartItem['id']}_decrease')
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

// Custom Coupon Modal for Restaurant Page that doesn't depend on LocalProductProvider
class RestaurantCouponModal extends StatefulWidget {
  final String initialCouponCode;
  final bool isCouponApplied;
  final double orderSubTotal;
  final double currentFlatDiscount;
  final double currentPercentageDiscount;
  final Function(String, bool,
      {double? flatDiscount, double? percentageDiscount}) onCouponAction;

  const RestaurantCouponModal({
    Key? key,
    required this.initialCouponCode,
    required this.isCouponApplied,
    required this.orderSubTotal,
    required this.currentFlatDiscount,
    required this.currentPercentageDiscount,
    required this.onCouponAction,
  }) : super(key: key);

  @override
  State<RestaurantCouponModal> createState() => _RestaurantCouponModalState();
}

class _RestaurantCouponModalState extends State<RestaurantCouponModal> {
  late TextEditingController couponController;
  late TextEditingController flatDiscountController;
  late TextEditingController percentageDiscountController;
  late bool isCouponApplied;

  @override
  void initState() {
    super.initState();
    couponController = TextEditingController(text: widget.initialCouponCode);
    flatDiscountController = TextEditingController(
        text: widget.currentFlatDiscount == 0.0
            ? ''
            : widget.currentFlatDiscount.toString());
    percentageDiscountController = TextEditingController(
        text: widget.currentPercentageDiscount == 0.0
            ? ''
            : widget.currentPercentageDiscount.toString());
    isCouponApplied = widget.isCouponApplied;

    // Add listeners for real-time calculation
    flatDiscountController.addListener(() => setState(() {}));
    percentageDiscountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    couponController.dispose();
    flatDiscountController.dispose();
    percentageDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentFlatDiscount =
        double.tryParse(flatDiscountController.text) ?? 0.0;
    final currentPercentageDiscount =
        double.tryParse(percentageDiscountController.text) ?? 0.0;

    // Calculate the new total after applying current modal discounts
    final percentageDiscountValue =
        widget.orderSubTotal * (currentPercentageDiscount / 100);
    final totalDiscount = currentFlatDiscount + percentageDiscountValue;
    final newTotal = widget.orderSubTotal - totalDiscount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: 450,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount & Coupon',
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
            const SizedBox(height: 20),

            // Discount Fields
            Row(
              children: [
                // Flat Discount Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flat Discount',
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
                        padding: const EdgeInsets.only(left: 15),
                        height: 50,
                        child: TextField(
                          controller: flatDiscountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0.00',
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
                            Colors.black.withOpacity(.5),
                          ),
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (flatDiscountController.text.isNotEmpty) {
                                flatDiscountController.selection =
                                    TextSelection(
                                  baseOffset: 0,
                                  extentOffset:
                                      flatDiscountController.text.length,
                                );
                              }
                            });
                            Provider.of<KeyboardProvider>(context,
                                    listen: false)
                                .show(
                              'number',
                              flatDiscountController,
                              replaceOnFirstInput: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                // Percentage Discount Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Percentage Discount (%)',
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
                        padding: const EdgeInsets.only(left: 15),
                        height: 50,
                        child: TextField(
                          controller: percentageDiscountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
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
                            Colors.black.withOpacity(.5),
                          ),
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (percentageDiscountController
                                  .text.isNotEmpty) {
                                percentageDiscountController.selection =
                                    TextSelection(
                                  baseOffset: 0,
                                  extentOffset:
                                      percentageDiscountController.text.length,
                                );
                              }
                            });
                            Provider.of<KeyboardProvider>(context,
                                    listen: false)
                                .show(
                              'number',
                              percentageDiscountController,
                              replaceOnFirstInput: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Coupon Code Field
            Text(
              'Coupon Code (Optional)',
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
              padding: const EdgeInsets.only(left: 15),
              height: 50,
              child: TextField(
                controller: couponController,
                enabled: (!isCouponApplied || couponController.text.isEmpty),
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
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
                  Colors.black.withOpacity(.5),
                ),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (couponController.text.isNotEmpty) {
                      couponController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: couponController.text.length,
                      );
                    }
                  });
                  Provider.of<KeyboardProvider>(context, listen: false).show(
                    'text',
                    couponController,
                    replaceOnFirstInput: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Updated Total Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorManager.kButtonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Total:',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        'INR ${AmountHelper.formatAmount(widget.orderSubTotal)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s15,
                          0.21,
                          ColorManager.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount Amount:',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColorRed,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'INR ${AmountHelper.formatAmount(totalDiscount)}',
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              FontSize.s15,
                              0.21,
                              ColorManager.textColorRed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${(widget.orderSubTotal > 0 ? ((totalDiscount / widget.orderSubTotal) * 100) : 0.0).toStringAsFixed(1)}%)',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.21,
                              ColorManager.textColorRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total after Discount:',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        'INR ${AmountHelper.formatAmount(newTotal)}',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s15,
                          0.21,
                          ColorManager.kButtonGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomRoundButton(
                    title: "Clear All",
                    fct: () {
                      setState(() {
                        flatDiscountController.clear();
                        percentageDiscountController.clear();
                        couponController.clear();
                      });
                    },
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
                    title: "Apply Discount",
                    fct: () {
                      double flatDiscount =
                          double.tryParse(flatDiscountController.text) ?? 0.0;
                      double percentageDiscount =
                          double.tryParse(percentageDiscountController.text) ??
                              0.0;

                      widget.onCouponAction(
                        couponController.text,
                        flatDiscount > 0 ||
                            percentageDiscount > 0 ||
                            couponController.text.isNotEmpty,
                        flatDiscount: flatDiscount,
                        percentageDiscount: percentageDiscount,
                      );
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
  }
}
