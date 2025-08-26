import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/build_round_button.dart';
import '../../components/build_dialog_box.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_model.dart';
import '../../models/cart_item_status.dart';

enum OrderStatus { pending, preparing, ready, served }

enum ItemStatus { pending, preparing, ready, served }

class KitchenOrder {
  final String id;
  final String tableId;
  final DateTime timestamp;
  final List<KitchenOrderItem> items;
  final OrderStatus status;
  final String? notes;

  KitchenOrder({
    required this.id,
    required this.tableId,
    required this.timestamp,
    required this.items,
    required this.status,
    this.notes,
  });

  KitchenOrder copyWith({
    String? id,
    String? tableId,
    DateTime? timestamp,
    List<KitchenOrderItem>? items,
    OrderStatus? status,
    String? notes,
  }) {
    return KitchenOrder(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class KitchenOrderItem {
  final String id;
  final String name;
  final int quantity;
  final ItemStatus status;
  final String? notes;
  final Map<String, List<String>> modifiers;
  final DateTime? startTime;
  final DateTime? readyTime;

  KitchenOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.status,
    this.notes,
    required this.modifiers,
    this.startTime,
    this.readyTime,
  });

  KitchenOrderItem copyWith({
    String? id,
    String? name,
    int? quantity,
    ItemStatus? status,
    String? notes,
    Map<String, List<String>>? modifiers,
    DateTime? startTime,
    DateTime? readyTime,
  }) {
    return KitchenOrderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      modifiers: modifiers ?? this.modifiers,
      startTime: startTime ?? this.startTime,
      readyTime: readyTime ?? this.readyTime,
    );
  }
}

class KitchenMaster extends StatefulWidget {
  const KitchenMaster({super.key});

  @override
  State<KitchenMaster> createState() => _KitchenMasterState();
}

class _KitchenMasterState extends State<KitchenMaster> {
  OrderStatus _selectedFilter = OrderStatus.pending;

  // Real data from API
  List<KitchenOrder> _orders = [];
  List<CartItemStatus> _availableStatuses = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllSavedOrders();
    _fetchCartItemStatuses();
  }

  Future<void> _fetchAllSavedOrders() async {
    debugPrint('🔄 === FETCHING SAVED ORDERS ===');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: null, // null => fetch for all tables
      );

      debugPrint('📥 Saved Orders Response Status: ${response['status']}');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final List<dynamic> orders =
            (response['orders'] as List<dynamic>?) ?? [];

        debugPrint('📦 Found ${orders.length} orders');

        final parsed =
            orders.map<KitchenOrder>(_mapSavedOrderToKitchenOrder).toList();
        setState(() {
          _orders = parsed;
        });

        debugPrint('✅ Orders mapped and state updated');
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Failed to load saved orders';
        });
        debugPrint('❌ Failed to load saved orders: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('❌ Exception fetching saved orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      debugPrint('🏁 === SAVED ORDERS FETCH COMPLETED ===');
    }
  }

  Future<void> _fetchCartItemStatuses() async {
    debugPrint('🚀 === FETCHING CART ITEM STATUSES ===');
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      debugPrint('🔑 Auth Token: ${authModel.token?.substring(0, 20)}...');
      debugPrint('🔄 Calling getCartItemStatuses API...');

      final response = await cartProvider.getCartItemStatuses(
        accessToken: authModel.token ?? '',
      );

      debugPrint('📥 API Response: $response');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final statusResponse = CartItemStatusResponse.fromJson(response);
        setState(() {
          _availableStatuses = statusResponse.data;
        });

        debugPrint(
            '✅ Fetched ${_availableStatuses.length} cart item statuses:');
        for (var status in _availableStatuses) {
          debugPrint(
              '   📊 ID: ${status.id}, Value: "${status.value}", Description: "${status.description}"');
        }
      } else {
        debugPrint(
            '❌ Failed to fetch cart item statuses: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Exception fetching cart item statuses: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    } finally {
      debugPrint('🏁 === CART ITEM STATUSES FETCH COMPLETED ===');
    }
  }

  KitchenOrder _mapSavedOrderToKitchenOrder(dynamic order) {
    final String id = (order['order_number'] ?? order['id'] ?? '').toString();
    final String tableDisplay = _extractTableName(order);
    final DateTime timestamp =
        _parseDateTime(order['created_at']) ?? DateTime.now();

    final List<dynamic> cartItems = _extractCartItems(order);
    final List<KitchenOrderItem> items =
        cartItems.map<KitchenOrderItem>((item) {
      final String name = _extractItemName(item);
      final int quantity = _parseInt(item['quantity']) ?? 0;
      final String? notes = item['notes']?.toString();
      final int? cartItemId = _parseInt(item['id']);

      final String? rawStatus = item['status']?.toString();
      final ItemStatus mappedStatus = _mapItemStatus(rawStatus);
      final String finalId =
          cartItemId != null ? '${cartItemId}_$name' : '${id}_$name';

      debugPrint('🔍 === CART ITEM MAPPING ===');
      debugPrint('📦 Cart Item ID: $cartItemId');
      debugPrint('🏷️ Item Name: $name');
      debugPrint('📊 Raw Status: "$rawStatus"');
      debugPrint('📊 Mapped Status: $mappedStatus');
      debugPrint('🆔 Final ID: $finalId');
      debugPrint('🔢 Quantity: $quantity');
      debugPrint('💬 Notes: $notes');
      debugPrint('========================');

      return KitchenOrderItem(
        id: finalId,
        name: name,
        quantity: quantity,
        status: mappedStatus,
        notes: notes,
        modifiers: _extractModifiers(item),
      );
    }).toList();

    final OrderStatus status = _mapOrderStatus(order['status']?.toString());

    return KitchenOrder(
      id: id.isNotEmpty ? id : 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      tableId: tableDisplay.isNotEmpty ? tableDisplay : 'Table',
      timestamp: timestamp,
      items: items,
      status: status,
      notes: order['comment']?.toString(),
    );
  }

  List<dynamic> _extractCartItems(dynamic order) {
    if (order == null) return [];

    // First try to get from cart.cart_items (nested structure)
    if (order['cart'] != null && order['cart']['cart_items'] != null) {
      return (order['cart']['cart_items'] as List<dynamic>);
    }

    // Then try cart_items.cart_items (alternative nested structure)
    if (order['cart_items'] != null &&
        order['cart_items']['cart_items'] != null) {
      return (order['cart_items']['cart_items'] as List<dynamic>);
    }

    // Finally try direct cart_items (flat structure)
    if (order['cart_items'] != null && order['cart_items'] is List) {
      return (order['cart_items'] as List<dynamic>);
    }

    return [];
  }

  String _extractTableName(dynamic order) {
    try {
      final props = order['orderProps'];
      if (props != null && props['TABLE'] != null) {
        return props['TABLE'].toString().replaceAll('"', '');
      }
      if (order['table'] != null) {
        final t = order['table'];
        if (t is Map && t['name'] != null) return t['name'].toString();
        if (t is String) return t;
      }
    } catch (_) {}
    return '';
  }

  String _extractItemName(dynamic item) {
    if (item == null) return 'Item';
    if (item['product'] != null && item['product']['name'] != null) {
      return item['product']['name'].toString();
    }
    if (item['product_name'] != null) return item['product_name'].toString();
    if (item['names'] != null &&
        item['names'] is List &&
        (item['names'] as List).isNotEmpty) {
      final first = (item['names'] as List).first;
      if (first is Map && first['name'] != null)
        return first['name'].toString();
    }
    return 'Item';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.round();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  OrderStatus _mapOrderStatus(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'init':
        return OrderStatus.pending;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
      case 'completed':
        return OrderStatus.served;
      default:
        return OrderStatus.pending;
    }
  }

  ItemStatus _mapItemStatus(String? status) {
    debugPrint('🔄 Mapping status: "$status"');

    if (status == null || status.isEmpty || status.toLowerCase() == 'null') {
      debugPrint('   → ItemStatus.pending (null/empty)');
      return ItemStatus.pending;
    }

    ItemStatus result;
    switch (status.toUpperCase()) {
      case 'START':
        result = ItemStatus.preparing;
        debugPrint('   → ItemStatus.preparing (START)');
        break;
      case 'READY':
        result = ItemStatus.ready;
        debugPrint('   → ItemStatus.ready (READY)');
        break;
      case 'SERVED':
        result = ItemStatus.served;
        debugPrint('   → ItemStatus.served (SERVED)');
        break;
      default:
        // Check if it's a numeric status ID
        final statusId = int.tryParse(status);
        if (statusId != null) {
          debugPrint('   → Numeric status ID detected: $statusId');
          // Map based on the status IDs we know from the API
          // Based on your API response: {"id": 49,"value": "START","description": "Start"}
          if (statusId == 49) {
            // START status ID - but this means it's already started!
            result = ItemStatus.preparing;
            debugPrint(
                '   → ItemStatus.preparing (ID 49 = START - already started)');
          } else if (statusId == 50) {
            // READY status ID
            result = ItemStatus.ready;
            debugPrint('   → ItemStatus.ready (ID 50 = READY)');
          } else if (statusId == 51) {
            // SERVED status ID
            result = ItemStatus.served;
            debugPrint('   → ItemStatus.served (ID 51 = SERVED)');
          } else {
            result = ItemStatus.pending;
            debugPrint('   → ItemStatus.pending (unknown ID: $statusId)');
          }
        } else {
          result = ItemStatus.pending;
          debugPrint('   → ItemStatus.pending (unknown status: "$status")');
        }
        break;
    }

    return result;
  }

  Map<String, List<String>> _extractModifiers(dynamic item) {
    Map<String, List<String>> modifiers = {};

    try {
      // Check if item has modifiers or customizations
      if (item['modifiers'] != null) {
        final mods = item['modifiers'];
        if (mods is Map) {
          mods.forEach((key, value) {
            if (value is List) {
              modifiers[key.toString()] =
                  value.map((v) => v.toString()).toList();
            } else {
              modifiers[key.toString()] = [value.toString()];
            }
          });
        }
      }

      // Check for customizations in product details
      if (item['product'] != null &&
          item['product']['customizations'] != null) {
        final customizations = item['product']['customizations'];
        if (customizations is List) {
          for (var custom in customizations) {
            if (custom is Map &&
                custom['name'] != null &&
                custom['value'] != null) {
              final key = custom['name'].toString();
              final value = custom['value'].toString();
              if (modifiers.containsKey(key)) {
                modifiers[key]!.add(value);
              } else {
                modifiers[key] = [value];
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting modifiers: $e');
    }

    return modifiers;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    final isLargeScreen = screenWidth >= 1200;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isSmallScreen
                ? _buildMobileLayout(screenSize)
                : _buildDesktopLayout(screenSize, isLargeScreen),
      ),
    );
  }

  Widget _buildDesktopLayout(Size screenSize, bool isLargeScreen) {
    return Row(
      children: [
        // Order Queue Panel
        Expanded(
          flex: 3,
          child: _OrderQueuePanel(
            orders: _getFilteredOrders(),
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) =>
                setState(() => _selectedFilter = filter),
            onOrderStatusChanged: _updateOrderStatus,
            screenSize: screenSize,
            errorMessage: _errorMessage,
            onRetry: () {
              _fetchAllSavedOrders();
              _fetchCartItemStatuses();
            },
          ),
        ),
        // Order Details Panel
        Expanded(
          flex: 4,
          child: _OrderDetailsPanel(
            orders: _orders,
            onItemStatusChanged: _updateItemStatus,
            availableStatuses: _availableStatuses,
            onCartItemStatusChanged: _updateCartItemStatusAPI,
            screenSize: screenSize,
            errorMessage: _errorMessage,
          ),
        ),
        // Kitchen Stats Panel
        Expanded(
          flex: 2,
          child: _KitchenStatsPanel(
            orders: _orders,
            screenSize: screenSize,
            onRefresh: () {
              _fetchAllSavedOrders();
              _fetchCartItemStatuses();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Size screenSize) {
    return Column(
      children: [
        // Top stats
        Container(
          height: screenSize.height * 0.25,
          child: _KitchenStatsPanel(
            orders: _orders,
            isCompact: true,
            screenSize: screenSize,
            onRefresh: () {
              _fetchAllSavedOrders();
              _fetchCartItemStatuses();
            },
          ),
        ),
        // Orders list with expandable details
        Expanded(
          child: _OrderQueuePanel(
            orders: _getFilteredOrders(),
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) =>
                setState(() => _selectedFilter = filter),
            onOrderStatusChanged: _updateOrderStatus,
            isCompact: true,
            screenSize: screenSize,
            availableStatuses: _availableStatuses,
            onCartItemStatusChanged: _updateCartItemStatusAPI,
            errorMessage: _errorMessage,
            onRetry: () {
              _fetchAllSavedOrders();
              _fetchCartItemStatuses();
            },
          ),
        ),
      ],
    );
  }

  List<KitchenOrder> _getFilteredOrders() {
    final filtered = _orders.where((order) {
      if (order.items.isEmpty) {
        return false;
      }

      final itemStatuses = order.items.map((item) => item.status).toList();

      switch (_selectedFilter) {
        case OrderStatus.pending:
          return itemStatuses.every((s) => s == ItemStatus.pending);
        case OrderStatus.served:
          return itemStatuses.every((s) => s == ItemStatus.served);
        case OrderStatus.ready:
          return itemStatuses.every((s) => s == ItemStatus.ready);
        case OrderStatus.preparing:
          final isPending = itemStatuses.every((s) => s == ItemStatus.pending);
          final isServed = itemStatuses.every((s) => s == ItemStatus.served);
          final isReady = itemStatuses.every((s) => s == ItemStatus.ready);
          return !isPending && !isServed && !isReady;
      }
    }).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  void _updateOrderStatus(String orderId, OrderStatus newStatus) {
    setState(() {
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
      }
    });
  }

  void _updateItemStatus(String orderId, String itemId, ItemStatus newStatus) {
    setState(() {
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        final order = _orders[orderIndex];
        final itemIndex = order.items.indexWhere((item) => item.id == itemId);
        if (itemIndex != -1) {
          final updatedItems = List<KitchenOrderItem>.from(order.items);
          updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
            status: newStatus,
            startTime: newStatus == ItemStatus.preparing
                ? DateTime.now()
                : updatedItems[itemIndex].startTime,
            readyTime: newStatus == ItemStatus.ready
                ? DateTime.now()
                : updatedItems[itemIndex].readyTime,
          );
          _orders[orderIndex] = order.copyWith(items: updatedItems);
        }
      }
    });
  }

  Future<void> _updateCartItemStatusAPI(int cartItemId, int statusId) async {
    debugPrint('🚀 === CART ITEM STATUS UPDATE STARTED ===');
    debugPrint('📦 Cart Item ID: $cartItemId');
    debugPrint('📊 Status ID: $statusId');

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      debugPrint('🔑 Auth Token: ${authModel.token?.substring(0, 20)}...');
      debugPrint('🔄 Calling updateCartItemStatus API...');

      final response = await cartProvider.updateCartItemStatus(
        cartItemId: cartItemId,
        statusId: statusId,
        accessToken: authModel.token ?? '',
      );

      debugPrint('📥 API Response: $response');
      debugPrint('📊 Response Status: ${response['status']}');
      debugPrint('💬 Response Message: ${response['message']}');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        debugPrint('✅ Cart item status updated successfully');

        // Check if status actually changed
        final data = response['data'];
        final oldStatus = data?['old_status']?.toString();
        final newStatus = data?['new_status']?.toString();
        final statusValue = data?['status_value']?.toString();

        debugPrint('📊 Status Change Details:');
        debugPrint('   Old Status ID: $oldStatus');
        debugPrint('   New Status ID: $newStatus');
        debugPrint('   Status Value: $statusValue');

        if (oldStatus == newStatus) {
          debugPrint(
              '⚠️ WARNING: Status did not change! Item might already be in this status.');
        }

        debugPrint('🔄 Refreshing order details...');

        // Refresh the order details
        await _fetchAllSavedOrders();

        debugPrint('✅ Order details refreshed');

        // Show success message using custom dialog
        if (mounted) {
          showScaffold(
            context: context,
            message: 'Item status updated to ${statusValue ?? 'new status'}',
          );
        }
      } else {
        debugPrint('❌ Failed to update cart item status');
        debugPrint('❌ Error: ${response['message']}');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to update item status: ${response['message']}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception updating cart item status: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error updating item status: $e',
        );
      }
    } finally {
      debugPrint('🏁 === CART ITEM STATUS UPDATE COMPLETED ===');
    }
  }
}

class _OrderQueuePanel extends StatelessWidget {
  final List<KitchenOrder> orders;
  final OrderStatus selectedFilter;
  final ValueChanged<OrderStatus> onFilterChanged;
  final Function(String, OrderStatus) onOrderStatusChanged;
  final bool isCompact;
  final Size screenSize;
  final List<CartItemStatus>? availableStatuses;
  final Function(int, int)? onCartItemStatusChanged;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const _OrderQueuePanel({
    required this.orders,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOrderStatusChanged,
    this.isCompact = false,
    required this.screenSize,
    this.availableStatuses,
    this.onCartItemStatusChanged,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header with filters
          Container(
            padding: EdgeInsets.all(isCompact ? 16.0 : 20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD97706).withOpacity(0.05),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: const Color(0xFFD97706),
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Kitchen Orders',
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
                        color: const Color(0xFFD97706).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s12, 0.21, const Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Status filters
                MouseRegion(
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
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: OrderStatus.values.map((status) {
                          final isActive = status == selectedFilter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => onFilterChanged(status),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _getStatusColor(status)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: _getStatusColor(status)
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    _getStatusText(status),
                                    style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.21,
                                        isActive
                                            ? Colors.white
                                            : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Orders list
          Expanded(
            child: errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: isCompact ? 48 : 64,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "No Orders Found",
                          style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              isCompact ? FontSize.s12 : FontSize.s14,
                              0.21,
                              const Color(0xFFDC2626)),
                          textAlign: TextAlign.center,
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 16),
                          CustomRoundButton(
                            title: 'Retry',
                            fct: onRetry!,
                            height: 36,
                            width: 100,
                            fontSize: 12,
                          ),
                        ],
                      ],
                    ),
                  )
                : orders.isEmpty
                    ? Center(
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
                                Icons.restaurant_menu,
                                size: isCompact ? 48 : 64,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No ${_getStatusText(selectedFilter).toLowerCase()} orders',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  isCompact ? FontSize.s14 : FontSize.s16,
                                  0.21,
                                  const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Orders will appear here when they match this status',
                              style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  isCompact ? FontSize.s11 : FontSize.s12,
                                  0.21,
                                  const Color(0xFF94A3B8)),
                              textAlign: TextAlign.center,
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
                            padding: EdgeInsets.all(isCompact ? 12 : 16),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final order = orders[index];
                              return _buildOrderCard(order, isCompact, selectedFilter);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(KitchenOrder order, bool compact, OrderStatus selectedFilter) {
    final timeSinceOrder = DateTime.now().difference(order.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Navigate to order details
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(compact ? 12 : 16),
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
              // Order header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.id,
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          compact ? FontSize.s12 : FontSize.s14,
                          0.21,
                          _getStatusColor(order.status)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${timeSinceOrder.inMinutes}m ago',
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        compact ? FontSize.s10 : FontSize.s11,
                        0.21,
                        const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Order items summary
              ...order.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _getItemStatusColor(item.status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${item.quantity}x',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  compact ? FontSize.s11 : FontSize.s12,
                                  0.21,
                                  const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.name,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    compact ? FontSize.s11 : FontSize.s12,
                                    0.21,
                                    const Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getItemStatusColor(item.status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getItemStatusText(item.status),
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s8,
                                    0.14,
                                    _getItemStatusColor(item.status)),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text, Color color, VoidCallback onTap, bool compact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              text,
              style: buildCustomStyle(FontWeightManager.semiBold,
                  compact ? FontSize.s10 : FontSize.s11, 0.21, color),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.preparing:
        return const Color(0xFF2563EB);
      case OrderStatus.ready:
        return const Color(0xFF059669);
      case OrderStatus.served:
        return const Color(0xFF6B7280);
    }
  }

  Color _getItemStatusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return const Color(0xFFD97706);
      case ItemStatus.preparing:
        return const Color(0xFF2563EB);
      case ItemStatus.ready:
        return const Color(0xFF059669);
      case ItemStatus.served:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.served:
        return 'Served';
    }
  }

  String _getItemStatusText(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return 'NEW';
      case ItemStatus.preparing:
        return 'STARTED';
      case ItemStatus.ready:
        return 'READY';
      case ItemStatus.served:
        return 'SERVED';
    }
  }
}

class _OrderDetailsPanel extends StatefulWidget {
  final List<KitchenOrder> orders;
  final Function(String, String, ItemStatus) onItemStatusChanged;
  final List<CartItemStatus> availableStatuses;
  final Function(int, int) onCartItemStatusChanged;
  final Size screenSize;
  final String? errorMessage;

  const _OrderDetailsPanel({
    required this.orders,
    required this.onItemStatusChanged,
    required this.availableStatuses,
    required this.onCartItemStatusChanged,
    required this.screenSize,
    this.errorMessage,
  });

  @override
  State<_OrderDetailsPanel> createState() => _OrderDetailsPanelState();
}

class _OrderDetailsPanelState extends State<_OrderDetailsPanel> {
  String? _expandedOrderId;

  @override
  Widget build(BuildContext context) {
    final activeOrders = widget.orders
        .where((order) =>
            order.status == OrderStatus.preparing ||
            order.status == OrderStatus.pending)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
          // Header
          Container(
            padding: const EdgeInsets.all(20.0),
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
                  child: const Icon(
                    Icons.assignment,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Order Details',
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s18,
                      0.30, const Color(0xFF1E293B)),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activeOrders.length} Active',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0.21, const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
          // Order details list
          Expanded(
            child: widget.errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Orders Found',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s16, 0.21, const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  )
                : activeOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.kitchen,
                                size: 64,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No active orders',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.21,
                                  const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Orders will appear here when they need preparation',
                              style: buildCustomStyle(FontWeightManager.regular,
                                  FontSize.s12, 0.21, const Color(0xFF94A3B8)),
                              textAlign: TextAlign.center,
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
                            padding: const EdgeInsets.all(16),
                            itemCount: activeOrders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, index) {
                              final order = activeOrders[index];
                              final timeSinceOrder =
                                  DateTime.now().difference(order.timestamp);

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    initiallyExpanded: _expandedOrderId == null
                                        ? index == 0
                                        : _expandedOrderId == order.id,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _expandedOrderId =
                                            expanded ? order.id : null;
                                      });
                                    },
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${order.id} - ${order.tableId}',
                                            style: buildCustomStyle(
                                                FontWeightManager.bold,
                                                FontSize.s14,
                                                0.21,
                                                _getStatusColor(order.status)),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${timeSinceOrder.inMinutes}m ago',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      // Order items
                                      ...order.items
                                          .map((item) =>
                                              _buildItemCard(order.id, item))
                                          .toList(),
                                      // Order notes
                                      if (order.notes != null &&
                                          order.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD97706)
                                                .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFD97706)
                                                  .withOpacity(0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.note,
                                                color: Color(0xFFD97706),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Order Notes: ${order.notes}',
                                                  style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.21,
                                                      const Color(0xFFD97706)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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
  }

  Widget _buildItemCard(String orderId, KitchenOrderItem item) {
    final cookingTime = item.startTime != null
        ? DateTime.now().difference(item.startTime!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getItemStatusColor(item.status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getItemStatusColor(item.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantity}x',
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s12,
                      0.21, _getItemStatusColor(item.status)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                      0.21, const Color(0xFF1E293B)),
                ),
              ),
              if (cookingTime != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${cookingTime.inMinutes}m',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s10, 0.21, const Color(0xFF2563EB)),
                  ),
                ),
            ],
          ),
          // Modifiers
          if (item.modifiers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.modifiers.entries.map((modifier) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${modifier.key}: ${modifier.value.join(', ')}',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s9, 0.21, const Color(0xFF64748B)),
                  ),
                );
              }).toList(),
            ),
          ],
          // Item notes
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.note,
                    color: Color(0xFFDC2626),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s11, 0.21, const Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Status control buttons from API or served indicator
          if (item.status == ItemStatus.served) ...[
            // Show served indicator instead of buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF059669).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Item Served',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.21,
                      const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (widget.availableStatuses.isNotEmpty) ...[
            // Show only the next available action button
            ...(() {
              debugPrint('🎨 === RENDERING BUTTONS FOR ITEM ===');
              debugPrint('📦 Item: ${item.name}');
              debugPrint('🆔 Item ID: ${item.id}');
              debugPrint('📊 Current Status: ${item.status}');
              debugPrint(
                  '🔢 Available Statuses Count: ${widget.availableStatuses.length}');

              // Show all available statuses
              for (var status in widget.availableStatuses) {
                debugPrint(
                    '   Available: ID=${status.id}, Value="${status.value}", Desc="${status.description}"');
              }

              final enabledStatuses = widget.availableStatuses.where((status) {
                final isEnabled =
                    _shouldEnableStatus(status.value, item.status);
                debugPrint(
                    '   📊 Status "${status.value}" (ID: ${status.id}, ${status.description}) enabled: $isEnabled');
                return isEnabled;
              }).toList();

              debugPrint('✅ Enabled Statuses Count: ${enabledStatuses.length}');
              for (var status in enabledStatuses) {
                debugPrint(
                    '   Will show button: "${status.description}" (${status.value})');
              }
              debugPrint('=====================================');

              return enabledStatuses;
            })()
                .map((status) {
              final color = _getStatusButtonColor(status.value);
              String buttonText = status.description;

              // Use more descriptive button text based on status
              switch (status.value.toUpperCase()) {
                case 'START':
                  buttonText = 'Start Cooking';
                  break;
                case 'READY':
                  buttonText = 'Mark Ready';
                  break;
                case 'SERVED':
                  buttonText = 'Mark Served';
                  break;
              }

              return Container(
                width: double.infinity,
                child: _buildStatusButton(
                  buttonText,
                  color,
                  true,
                  () {
                    debugPrint('🎯 === BUTTON CLICKED ===');
                    debugPrint('🏷️ Button Text: $buttonText');
                    debugPrint('📦 Item ID: ${item.id}');
                    debugPrint('📊 Status Value: ${status.value}');
                    debugPrint('🆔 Status ID: ${status.id}');
                    debugPrint('🔍 Current Item Status: ${item.status}');

                    // Extract cart item ID from the item ID (assuming format like "cartItemId_productName")
                    final parts = item.id.split('_');
                    debugPrint('🔧 ID Parts: $parts');

                    final cartItemId = int.tryParse(parts.first);
                    debugPrint('🔢 Parsed Cart Item ID: $cartItemId');

                    if (cartItemId != null) {
                      debugPrint('✅ Valid cart item ID found, calling API...');
                      widget.onCartItemStatusChanged(cartItemId, status.id);
                    } else {
                      debugPrint(
                          '❌ Could not extract cart item ID from: ${item.id}');
                      debugPrint('❌ First part was: "${parts.first}"');
                    }
                  },
                ),
              );
            }).toList(),
          ] else ...[
            // Fallback to original buttons if API statuses not loaded
            Row(
              children: [
                Expanded(
                  child: _buildStatusButton(
                    'Start',
                    const Color(0xFF2563EB),
                    item.status == ItemStatus.pending,
                    () => widget.onItemStatusChanged(
                        orderId, item.id, ItemStatus.preparing),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Ready',
                    const Color(0xFF059669),
                    item.status == ItemStatus.preparing,
                    () => widget.onItemStatusChanged(
                        orderId, item.id, ItemStatus.ready),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Served',
                    const Color(0xFF6B7280),
                    item.status == ItemStatus.ready,
                    () => widget.onItemStatusChanged(
                        orderId, item.id, ItemStatus.served),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusButton(
      String text, Color color, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              text,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s11,
                  0.21, enabled ? Colors.white : color.withOpacity(0.5)),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.preparing:
        return const Color(0xFF2563EB);
      case OrderStatus.ready:
        return const Color(0xFF059669);
      case OrderStatus.served:
        return const Color(0xFF6B7280);
    }
  }

  Color _getItemStatusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.pending:
        return const Color(0xFFD97706);
      case ItemStatus.preparing:
        return const Color(0xFF2563EB);
      case ItemStatus.ready:
        return const Color(0xFF059669);
      case ItemStatus.served:
        return const Color(0xFF6B7280);
    }
  }

  bool _shouldEnableStatus(String statusValue, ItemStatus currentStatus) {
    debugPrint(
        '🔍 Checking if status "$statusValue" should be enabled for current status: $currentStatus');

    bool shouldEnable = false;

    // Enable only the next logical status based on current item status
    switch (statusValue.toUpperCase()) {
      case 'START':
        // START button is enabled only when item is pending (null status)
        shouldEnable = currentStatus == ItemStatus.pending;
        debugPrint(
            '   START: pending=${currentStatus == ItemStatus.pending} → $shouldEnable');
        break;
      case 'READY':
        // READY button is enabled only when item is currently being prepared (START status)
        shouldEnable = currentStatus == ItemStatus.preparing;
        debugPrint(
            '   READY: preparing=${currentStatus == ItemStatus.preparing} → $shouldEnable');
        break;
      case 'SERVED':
        // SERVED button is enabled only when item is ready
        shouldEnable = currentStatus == ItemStatus.ready;
        debugPrint(
            '   SERVED: ready=${currentStatus == ItemStatus.ready} → $shouldEnable');
        break;
      default:
        shouldEnable = false; // Disable unknown statuses
        debugPrint('   UNKNOWN STATUS: $statusValue → $shouldEnable');
        break;
    }

    debugPrint(
        '🎯 Final decision: Status "$statusValue" enabled = $shouldEnable');
    return shouldEnable;
  }

  Color _getStatusButtonColor(String statusValue) {
    switch (statusValue.toUpperCase()) {
      case 'START':
        return const Color(0xFF2563EB);
      case 'READY':
        return const Color(0xFF059669);
      case 'SERVED':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getNextActionText(ItemStatus currentStatus) {
    switch (currentStatus) {
      case ItemStatus.pending:
        return 'Start Cooking';
      case ItemStatus.preparing:
        return 'Mark Ready';
      case ItemStatus.ready:
        return 'Mark Served';
      case ItemStatus.served:
        return 'Completed';
    }
  }
}

class _KitchenStatsPanel extends StatelessWidget {
  final List<KitchenOrder> orders;
  final bool isCompact;
  final Size screenSize;
  final VoidCallback? onRefresh;

  const _KitchenStatsPanel({
    required this.orders,
    this.isCompact = false,
    required this.screenSize,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

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
          // Header
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
                    Icons.analytics,
                    color: const Color(0xFF059669),
                    size: isCompact ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Kitchen Stats',
                  style: buildCustomStyle(
                      FontWeightManager.bold,
                      isCompact ? FontSize.s16 : FontSize.s18,
                      0.30,
                      const Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          // Stats content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
              child: isCompact
                  ? _buildCompactStats(stats)
                  : _buildDetailedStats(stats),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStats(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending',
            stats['pending'].toString(),
            const Color(0xFFD97706),
            Icons.schedule,
            true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Cooking',
            stats['preparing'].toString(),
            const Color(0xFF2563EB),
            Icons.local_fire_department,
            true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Ready',
            stats['ready'].toString(),
            const Color(0xFF059669),
            Icons.check_circle,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> stats) {
    return Column(
      children: [
        // Order status stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending Orders',
                stats['pending'].toString(),
                const Color(0xFFD97706),
                Icons.schedule,
                false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Preparing',
                stats['preparing'].toString(),
                const Color(0xFF2563EB),
                Icons.local_fire_department,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Ready to Serve',
                stats['ready'].toString(),
                const Color(0xFF059669),
                Icons.check_circle,
                false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                stats['served'].toString(),
                const Color(0xFF6B7280),
                Icons.done_all,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Performance metrics
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                    0.21, const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avg. Prep Time',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.21, const Color(0xFF64748B)),
                  ),
                  Text(
                    '${stats['avgPrepTime']} min',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0.21, const Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Items',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.21, const Color(0xFF64748B)),
                  ),
                  Text(
                    stats['totalItems'].toString(),
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0.21, const Color(0xFF1E293B)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        // Quick actions
        if (onRefresh != null)
          Container(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Refresh Orders',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s12, 0.21, const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: compact ? 16 : 20,
              ),
              if (!compact) ...[
                const Spacer(),
                Text(
                  value,
                  style: buildCustomStyle(
                      FontWeightManager.bold, FontSize.s20, 0.21, color),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          if (compact)
            Center(
              child: Text(
                value,
                style: buildCustomStyle(
                    FontWeightManager.bold, FontSize.s16, 0.21, color),
              ),
            ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            title,
            style: buildCustomStyle(
                FontWeightManager.medium,
                compact ? FontSize.s9 : FontSize.s11,
                0.21,
                const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    int pending = 0;
    int preparing = 0;
    int ready = 0;
    int served = 0;

    for (final order in orders) {
      if (order.items.isEmpty) continue;

      final itemStatuses = order.items.map((item) => item.status).toList();

      if (itemStatuses.every((s) => s == ItemStatus.pending)) {
        pending++;
      } else if (itemStatuses.every((s) => s == ItemStatus.served)) {
        served++;
      } else if (itemStatuses.every((s) => s == ItemStatus.ready)) {
        ready++;
      } else {
        preparing++;
      }
    }

    final totalItems = orders.fold<int>(0, (sum, order) => sum + order.items.length);

    // Calculate average prep time
    int totalPrepTimeMinutes = 0;
    int itemsWithPrepTime = 0;

    for (var order in orders) {
      for (var item in order.items) {
        if (item.startTime != null && item.readyTime != null) {
          final prepDuration = item.readyTime!.difference(item.startTime!);
          totalPrepTimeMinutes += prepDuration.inMinutes;
          itemsWithPrepTime++;
        }
      }
    }

    final avgPrepTime = itemsWithPrepTime > 0
        ? (totalPrepTimeMinutes / itemsWithPrepTime).round()
        : 0;

    return {
      'pending': pending,
      'preparing': preparing,
      'ready': ready,
      'served': served,
      'totalItems': totalItems,
      'avgPrepTime': avgPrepTime,
    };
  }
}
