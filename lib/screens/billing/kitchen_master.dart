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

// Shared color and label helpers for statuses (top-level, file-private)
Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return const Color(0xFFD97706); // Amber
    case OrderStatus.preparing:
      return const Color(0xFFD97706); // Orange
    case OrderStatus.ready:
      return const Color(0xFF059669); // Green
    case OrderStatus.served:
      return const Color(0xFF059669); // Green
  }
}

Color _getItemStatusColor(ItemStatus status) {
  switch (status) {
    case ItemStatus.pending:
      return const Color(0xFFD97706); // Amber
    case ItemStatus.preparing:
      return const Color(0xFF2563EB); // Blue
    case ItemStatus.ready:
      return const Color(0xFF059669); // Green
    case ItemStatus.served:
      return const Color(0xFF6B7280); // Slate
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
  KitchenOrder? _selectedOrder; // Track selected order for details panel

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

  // Silent refresh method for background updates (no loading spinner)
  Future<void> _fetchAllSavedOrdersSilently() async {
    debugPrint('🔄 === FETCHING SAVED ORDERS SILENTLY ===');

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final response = await cartProvider.listSavedOrders(
        accessToken: authModel.token ?? '',
        tableId: null, // null => fetch for all tables
      );

      debugPrint(
          '📥 Saved Orders Response Status (silent): ${response['status']}');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final List<dynamic> orders =
            (response['orders'] as List<dynamic>?) ?? [];

        debugPrint('📦 Found ${orders.length} orders (silent)');

        final parsed =
            orders.map<KitchenOrder>(_mapSavedOrderToKitchenOrder).toList();
        setState(() {
          _orders = parsed;
        });

        debugPrint('✅ Orders mapped and state updated (silent)');
      } else {
        debugPrint(
            '⚠️ Failed to refresh orders silently: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Exception in silent refresh: $e');
    }
    debugPrint('🏁 === SILENT SAVED ORDERS FETCH COMPLETED ===');
  }

  // Refresh orders and update selected order reference
  Future<void> _refreshOrdersAndUpdateSelection() async {
    debugPrint('🔄 === REFRESHING ORDERS AND UPDATING SELECTION ===');

    final selectedOrderId = _selectedOrder?.id;

    // Refresh the orders data
    await _fetchAllSavedOrdersSilently();

    // Update selected order reference if one was selected
    if (selectedOrderId != null && mounted) {
      final updatedOrder = _orders.firstWhere(
        (order) => order.id == selectedOrderId,
        orElse: () => _selectedOrder!,
      );

      setState(() {
        _selectedOrder = updatedOrder;
      });

      debugPrint('✅ Selected order updated: ${updatedOrder.id}');
    }

    debugPrint('🏁 === REFRESH AND UPDATE SELECTION COMPLETED ===');
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

        // Test the dynamic status mapping
        debugPrint('🧪 === TESTING DYNAMIC STATUS MAPPING ===');
        final startId = _findStatusIdByValue('START');
        final readyId = _findStatusIdByValue('READY');
        final servedId = _findStatusIdByValue('SERVED');
        debugPrint('🧪 START ID: $startId');
        debugPrint('🧪 READY ID: $readyId');
        debugPrint('🧪 SERVED ID: $servedId');
        debugPrint('🧪 ======================================');
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
      debugPrint('🔍 Status Analysis:');
      debugPrint('   - Raw status type: ${rawStatus.runtimeType}');
      debugPrint('   - Is numeric: ${int.tryParse(rawStatus ?? '') != null}');
      if (int.tryParse(rawStatus ?? '') != null) {
        debugPrint('   - Numeric value: ${int.tryParse(rawStatus ?? '')}');
      }
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

    // Extract comment/notes from various API shapes
    String? notes = order['comment']?.toString();
    notes ??= order['order_comment']?.toString();
    // From nested map: orderProps: { COMMENT: "..." }
    if (notes == null || notes.isEmpty) {
      final propsMap = order['orderProps'];
      if (propsMap is Map && propsMap['COMMENT'] != null) {
        notes = propsMap['COMMENT']?.toString();
      }
    }
    // From array: order_props: [{ code: COMMENT, value: "..." }]
    if (notes == null || notes.isEmpty) {
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
            notes = match['value']?.toString();
          }
        } catch (_) {}
      }
    }
    // Normalize quotes
    if (notes != null) {
      notes = notes.trim();
      if (notes.startsWith('"') && notes.endsWith('"')) {
        notes = notes.substring(1, notes.length - 1);
      }
    }

    return KitchenOrder(
      id: id.isNotEmpty ? id : 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      tableId: tableDisplay.isNotEmpty ? tableDisplay : 'Table',
      timestamp: timestamp,
      items: items,
      status: status,
      notes: notes,
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

  // Helper method to find status ID by value
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

  // Helper method to find status value by ID
  String? _findStatusValueById(int id) {
    if (_availableStatuses.isEmpty) {
      debugPrint('⚠️ No available statuses loaded yet');
      return null;
    }

    final status = _availableStatuses.firstWhere(
      (s) => s.id == id,
      orElse: () => CartItemStatus(id: 0, value: '', description: ''),
    );

    if (status.id == 0) {
      debugPrint('⚠️ Status ID $id not found in available statuses');
      return null;
    }

    debugPrint('🔍 Found status value "${status.value}" for ID $id');
    return status.value;
  }

  ItemStatus _mapItemStatus(String? status) {
    debugPrint('🔄 Mapping status: "$status"');

    if (status == null || status.isEmpty || status.toLowerCase() == 'null') {
      debugPrint('   → ItemStatus.pending (null/empty)');
      return ItemStatus.pending;
    }

    ItemStatus result;

    // First try to match by string value
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
        // Check if it's a numeric status ID and try to find the corresponding value
        final statusId = int.tryParse(status);
        if (statusId != null) {
          debugPrint('   → Numeric status ID detected: $statusId');

          // Try to find the status value for this ID
          final statusValue = _findStatusValueById(statusId);
          if (statusValue != null) {
            debugPrint(
                '   → Found status value: "$statusValue" for ID $statusId');

            // Map based on the found status value
            switch (statusValue.toUpperCase()) {
              case 'START':
                result = ItemStatus.preparing;
                debugPrint(
                    '   → ItemStatus.preparing (ID $statusId = $statusValue)');
                break;
              case 'READY':
                result = ItemStatus.ready;
                debugPrint(
                    '   → ItemStatus.ready (ID $statusId = $statusValue)');
                break;
              case 'SERVED':
                result = ItemStatus.served;
                debugPrint(
                    '   → ItemStatus.served (ID $statusId = $statusValue)');
                break;
              default:
                result = ItemStatus.pending;
                debugPrint(
                    '   → ItemStatus.pending (unknown value: "$statusValue" for ID $statusId)');
                break;
            }
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
            selectedOrder: _selectedOrder,
            onFilterChanged: (filter) =>
                setState(() => _selectedFilter = filter),
            onOrderStatusChanged: _updateOrderStatus,
            onOrderSelected: (order) => setState(() => _selectedOrder = order),
            screenSize: screenSize,
            errorMessage: _errorMessage,
            onRetry: () {
              _refreshOrdersAndUpdateSelection();
              _fetchCartItemStatuses();
            },
            onPullToRefresh: () async {
              await _refreshOrdersAndUpdateSelection();
              await _fetchCartItemStatuses();
            },
          ),
        ),
        // Order Details Panel
        Expanded(
          flex: 4,
          child: _OrderDetailsPanel(
            selectedOrder: _selectedOrder,
            onItemStatusChanged: _updateItemStatus,
            availableStatuses: _availableStatuses,
            onCartItemStatusChanged: _updateCartItemStatusAPI,
            screenSize: screenSize,
            errorMessage: _errorMessage,
            onRefresh: () async {
              await _refreshOrdersAndUpdateSelection();
              await _fetchCartItemStatuses();
            },
          ),
        ),
        // Kitchen Stats Panel
        Expanded(
          flex: 2,
          child: _KitchenStatsPanel(
            orders: _orders,
            screenSize: screenSize,
            onRefresh: () {
              _refreshOrdersAndUpdateSelection();
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
              _refreshOrdersAndUpdateSelection();
              _fetchCartItemStatuses();
            },
          ),
        ),
        // Orders list with expandable details
        Expanded(
          child: _OrderQueuePanel(
            orders: _getFilteredOrders(),
            selectedFilter: _selectedFilter,
            selectedOrder: _selectedOrder,
            onFilterChanged: (filter) =>
                setState(() => _selectedFilter = filter),
            onOrderStatusChanged: _updateOrderStatus,
            onOrderSelected: (order) => setState(() => _selectedOrder = order),
            isCompact: true,
            screenSize: screenSize,
            availableStatuses: _availableStatuses,
            onCartItemStatusChanged: _updateCartItemStatusAPI,
            errorMessage: _errorMessage,
            onRetry: () {
              _refreshOrdersAndUpdateSelection();
              _fetchCartItemStatuses();
            },
            onPullToRefresh: () async {
              await _refreshOrdersAndUpdateSelection();
              await _fetchCartItemStatuses();
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

  // Helper method to determine actual order status based on item statuses
  OrderStatus _determineActualOrderStatus(KitchenOrder order) {
    if (order.items.isEmpty) return OrderStatus.pending;

    final itemStatuses = order.items.map((item) => item.status).toList();

    // If all items are served, order is served
    if (itemStatuses.every((s) => s == ItemStatus.served)) {
      return OrderStatus.served;
    }

    // If all items are ready, order is ready
    if (itemStatuses.every((s) => s == ItemStatus.ready)) {
      return OrderStatus.ready;
    }

    // If all items are pending, order is pending
    if (itemStatuses.every((s) => s == ItemStatus.pending)) {
      return OrderStatus.pending;
    }

    // Mixed statuses or some items are preparing = order is preparing
    return OrderStatus.preparing;
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

      // Enhanced debug prints for API response
      debugPrint('📥 === FULL API RESPONSE ===');
      debugPrint('📥 Raw Response: $response');
      debugPrint('📥 Response Type: ${response.runtimeType}');
      debugPrint('📥 Response Keys: ${response.keys.toList()}');

      // Print each key-value pair for better debugging
      response.forEach((key, value) {
        debugPrint('📥   $key: $value (${value.runtimeType})');
      });

      debugPrint('📊 Response Status: ${response['status']}');
      debugPrint('💬 Response Message: ${response['message']}');

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        debugPrint('✅ Cart item status updated successfully');

        // Check if status actually changed
        final data = response['data'];
        debugPrint('📊 Data Section: $data');

        if (data != null) {
          debugPrint('📊 Data Type: ${data.runtimeType}');
          debugPrint('📊 Data Keys: ${data.keys.toList()}');

          // Print each data key-value pair
          data.forEach((key, value) {
            debugPrint('📊   $key: $value (${value.runtimeType})');
          });
        }

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

        debugPrint('🔄 Refreshing order details silently...');

        // Refresh the order details and update selected order
        await _refreshOrdersAndUpdateSelection();

        debugPrint('✅ Order details refreshed silently');

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
        debugPrint('❌ Full Error Response: $response');
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to update item status: ${response['message']}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception updating cart item status: $e');
      debugPrint('❌ Exception Type: ${e.runtimeType}');
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
  final KitchenOrder? selectedOrder;
  final ValueChanged<OrderStatus> onFilterChanged;
  final Function(String, OrderStatus) onOrderStatusChanged;
  final Function(KitchenOrder) onOrderSelected;
  final bool isCompact;
  final Size screenSize;
  final List<CartItemStatus>? availableStatuses;
  final Function(int, int)? onCartItemStatusChanged;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Future<void> Function()? onPullToRefresh;

  const _OrderQueuePanel({
    required this.orders,
    required this.selectedFilter,
    this.selectedOrder,
    required this.onFilterChanged,
    required this.onOrderStatusChanged,
    required this.onOrderSelected,
    this.isCompact = false,
    required this.screenSize,
    this.availableStatuses,
    this.onCartItemStatusChanged,
    this.errorMessage,
    this.onRetry,
    this.onPullToRefresh,
  });

  // Helper method to determine actual order status based on item statuses
  OrderStatus _determineActualOrderStatus(KitchenOrder order) {
    if (order.items.isEmpty) return OrderStatus.pending;

    final itemStatuses = order.items.map((item) => item.status).toList();

    // If all items are served, order is served
    if (itemStatuses.every((s) => s == ItemStatus.served)) {
      return OrderStatus.served;
    }

    // If all items are ready, order is ready
    if (itemStatuses.every((s) => s == ItemStatus.ready)) {
      return OrderStatus.ready;
    }

    // If all items are pending, order is pending
    if (itemStatuses.every((s) => s == ItemStatus.pending)) {
      return OrderStatus.pending;
    }

    // Mixed statuses or some items are preparing = order is preparing
    return OrderStatus.preparing;
  }

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
                  _getStatusColor(selectedFilter).withOpacity(0.08),
                  _getStatusColor(selectedFilter).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: _getStatusColor(selectedFilter).withOpacity(0.1),
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
                        color: _getStatusColor(selectedFilter).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: _getStatusColor(selectedFilter),
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
                        color: _getStatusColor(selectedFilter).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s12,
                            0.21,
                            _getStatusColor(selectedFilter)),
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
                          child: RefreshIndicator(
                            onRefresh: onPullToRefresh ?? () async {},
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(isCompact ? 12 : 16),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final order = orders[index];
                                return _buildOrderCard(
                                    order, isCompact, selectedFilter);
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

  Widget _buildOrderCard(
      KitchenOrder order, bool compact, OrderStatus selectedFilter) {
    final timeSinceOrder = DateTime.now().difference(order.timestamp);
    final isSelected = selectedOrder?.id == order.id;

    // Determine the actual order status based on items
    final OrderStatus actualOrderStatus = _determineActualOrderStatus(order);

    // Add urgency based on time for pending/preparing orders
    final isUrgent = timeSinceOrder.inMinutes > 15 &&
        (actualOrderStatus == OrderStatus.pending ||
            actualOrderStatus == OrderStatus.preparing);
    final isVeryUrgent = timeSinceOrder.inMinutes > 30 &&
        (actualOrderStatus == OrderStatus.pending ||
            actualOrderStatus == OrderStatus.preparing);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOrderSelected(order),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: isSelected
                ? _getStatusColor(actualOrderStatus).withOpacity(0.15)
                : isVeryUrgent
                    ? const Color(0xFFDC2626).withOpacity(0.1)
                    : isUrgent
                        ? const Color(0xFFD97706).withOpacity(0.1)
                        : _getStatusColor(actualOrderStatus).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _getStatusColor(actualOrderStatus)
                  : isVeryUrgent
                      ? const Color(0xFFDC2626)
                      : isUrgent
                          ? const Color(0xFFD97706)
                          : _getStatusColor(actualOrderStatus).withOpacity(0.3),
              width: isSelected
                  ? 2
                  : (isUrgent || isVeryUrgent)
                      ? 2
                      : 1,
            ),
            boxShadow: (isUrgent || isVeryUrgent)
                ? [
                    BoxShadow(
                      color: (isVeryUrgent
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706))
                          .withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                      color:
                          _getStatusColor(actualOrderStatus).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.id,
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          compact ? FontSize.s12 : FontSize.s14,
                          0.21,
                          _getStatusColor(actualOrderStatus)),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(actualOrderStatus),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getStatusText(actualOrderStatus).toUpperCase(),
                          style: buildCustomStyle(FontWeightManager.bold,
                              FontSize.s8, 0.14, Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${timeSinceOrder.inMinutes}m ago',
                        style: buildCustomStyle(
                            FontWeightManager.medium,
                            compact ? FontSize.s10 : FontSize.s11,
                            0.21,
                            isVeryUrgent
                                ? const Color(0xFFDC2626)
                                : isUrgent
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF64748B)),
                      ),
                    ],
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
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getItemStatusColor(item.status),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getItemStatusColor(item.status)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getItemStatusColor(item.status)
                                        .withOpacity(0.3),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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
}

class _OrderDetailsPanel extends StatefulWidget {
  final KitchenOrder? selectedOrder;
  final Function(String, String, ItemStatus) onItemStatusChanged;
  final List<CartItemStatus> availableStatuses;
  final Function(int, int) onCartItemStatusChanged;
  final Size screenSize;
  final String? errorMessage;
  final Future<void> Function()? onRefresh;

  const _OrderDetailsPanel({
    this.selectedOrder,
    required this.onItemStatusChanged,
    required this.availableStatuses,
    required this.onCartItemStatusChanged,
    required this.screenSize,
    this.errorMessage,
    this.onRefresh,
  });

  @override
  State<_OrderDetailsPanel> createState() => _OrderDetailsPanelState();
}

class _OrderDetailsPanelState extends State<_OrderDetailsPanel> {
  Set<String> _loadingButtons = {}; // Track which buttons are loading

  // Helper method to determine actual order status based on item statuses
  OrderStatus _determineActualOrderStatus(KitchenOrder order) {
    if (order.items.isEmpty) return OrderStatus.pending;

    final itemStatuses = order.items.map((item) => item.status).toList();

    // If all items are served, order is served
    if (itemStatuses.every((s) => s == ItemStatus.served)) {
      return OrderStatus.served;
    }

    // If all items are ready, order is ready
    if (itemStatuses.every((s) => s == ItemStatus.ready)) {
      return OrderStatus.ready;
    }

    // If all items are pending, order is pending
    if (itemStatuses.every((s) => s == ItemStatus.pending)) {
      return OrderStatus.pending;
    }

    // Mixed statuses or some items are preparing = order is preparing
    return OrderStatus.preparing;
  }

  @override
  Widget build(BuildContext context) {
    final selectedOrder = widget.selectedOrder;

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
                    selectedOrder != null ? '1 Selected' : 'None Selected',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0.21, const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
          // Order details content
          Expanded(
            child: selectedOrder == null
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
                            Icons.touch_app,
                            size: 64,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Select an Order',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s16, 0.21, const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click on an order from the Kitchen Orders panel to view details and manage item status',
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.21, const Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _buildSelectedOrderDetails(selectedOrder),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedOrderDetails(KitchenOrder order) {
    final timeSinceOrder = DateTime.now().difference(order.timestamp);

    // Determine the actual order status based on items
    final OrderStatus actualOrderStatus = _determineActualOrderStatus(order);

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
        child: RefreshIndicator(
          onRefresh: widget.onRefresh ?? () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(actualOrderStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _getStatusColor(actualOrderStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(actualOrderStatus),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${order.id} - ${order.tableId}',
                              style: buildCustomStyle(FontWeightManager.bold,
                                  FontSize.s16, 0.21, Colors.white),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(actualOrderStatus),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusText(actualOrderStatus)
                                      .toUpperCase(),
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s10,
                                      0.21,
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${timeSinceOrder.inMinutes}m ago',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.21,
                                      const Color(0xFF1E293B)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.note,
                                color: _getStatusColor(actualOrderStatus),
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
                                      _getStatusColor(actualOrderStatus)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Order items
                Text(
                  'Order Items (${order.items.length})',
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                      0.21, const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                ...order.items
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildItemCard(order.id, item),
                        ))
                    .toList(),
              ],
            ),
          ),
        ),
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
                color: const Color(0xFFD97706).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.note,
                    color: Color(0xFFD97706),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.notes!,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s11, 0.21, const Color(0xFFD97706)),
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
                color: const Color(0xFF6B7280).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6B7280).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: const Color(0xFF059669), // Green
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Item Served',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.21,
                      const Color(
                          0xFF059669), // Green text for better visibility
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
              debugPrint('📊 Current Status Type: ${item.status.runtimeType}');
              debugPrint(
                  '🔢 Available Statuses Count: ${widget.availableStatuses.length}');

              // Show all available statuses
              for (var status in widget.availableStatuses) {
                debugPrint(
                    '   Available: ID=${status.id}, Value="${status.value}", Desc="${status.description}"');
              }

              debugPrint('🔍 === STATUS ENABLEMENT CHECK ===');
              // De-duplicate available statuses by value (case-insensitive)
              final Map<String, CartItemStatus> uniqueByValue = {};
              for (var s in widget.availableStatuses) {
                final key = s.value.toUpperCase();
                if (key.isEmpty) continue;
                uniqueByValue.putIfAbsent(key, () => s);
              }
              final dedupedStatuses = uniqueByValue.values.toList();

              final enabledStatuses = dedupedStatuses.where((status) {
                final isEnabled =
                    _shouldEnableStatus(status.value, item.status);
                debugPrint(
                    '   📊 Status "${status.value}" (ID: ${status.id}, ${status.description}) enabled: $isEnabled');
                debugPrint('      - Current item status: ${item.status}');
                debugPrint('      - Status value to check: ${status.value}');
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
              final buttonId =
                  '${item.id}_${status.id}'; // Unique button identifier
              final isLoading = _loadingButtons.contains(buttonId);

              // Use more descriptive button text based on status
              switch (status.value.toUpperCase()) {
                case 'START':
                  buttonText = 'Start Cooking';
                  break;
                case 'READY':
                  buttonText = 'Mark Ready';
                  break;
                case 'SERVED':
                  buttonText = '✓ Mark Served'; // Add check icon indicator
                  break;
              }

              return Container(
                width: double.infinity,
                child: _buildStatusButton(
                  isLoading ? 'Processing...' : buttonText,
                  color,
                  !isLoading, // Disable button when loading
                  isLoading, // Show loading indicator
                  () async {
                    if (isLoading) return; // Prevent multiple clicks

                    debugPrint('🎯 === BUTTON CLICKED ===');
                    debugPrint('🏷️ Button Text: $buttonText');
                    debugPrint('📦 Item ID: ${item.id}');
                    debugPrint('📊 Status Value: ${status.value}');
                    debugPrint('🆔 Status ID: ${status.id}');
                    debugPrint('🔍 Current Item Status: ${item.status}');

                    // Special debug for START COOKING action
                    if (status.value.toUpperCase() == 'START') {
                      debugPrint('🔥 === START COOKING ACTION TRIGGERED ===');
                      debugPrint('🔥 Item Name: ${item.name}');
                      debugPrint('🔥 Item Quantity: ${item.quantity}');
                      debugPrint('🔥 Item Modifiers: ${item.modifiers}');
                      debugPrint('🔥 Item Notes: ${item.notes}');
                    }

                    // Extract cart item ID from the item ID (assuming format like "cartItemId_productName")
                    final parts = item.id.split('_');
                    debugPrint('🔧 ID Parts: $parts');

                    final cartItemId = int.tryParse(parts.first);
                    debugPrint('🔢 Parsed Cart Item ID: $cartItemId');

                    if (cartItemId != null) {
                      debugPrint('✅ Valid cart item ID found, calling API...');
                      debugPrint(
                          '🔍 Using status ID ${status.id} for value "${status.value}"');

                      // Set loading state
                      setState(() {
                        _loadingButtons.add(buttonId);
                      });

                      try {
                        // Optimistic update - update local state immediately for better UX
                        final newItemStatus =
                            _mapStatusValueToItemStatus(status.value);
                        widget.onItemStatusChanged(
                            orderId, item.id, newItemStatus);

                        // Call API to update on server
                        await widget.onCartItemStatusChanged(
                            cartItemId, status.id);
                      } catch (e) {
                        // If API call fails, we should revert the optimistic update
                        // The refresh in onCartItemStatusChanged will handle this
                        debugPrint(
                            '❌ API call failed, will revert via refresh: $e');
                      } finally {
                        // Remove loading state
                        if (mounted) {
                          setState(() {
                            _loadingButtons.remove(buttonId);
                          });
                        }
                      }
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
                    false, // Not loading for fallback buttons
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
                    false, // Not loading for fallback buttons
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
                    false, // Not loading for fallback buttons
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

  Widget _buildStatusButton(String text, Color color, bool enabled,
      bool isLoading, VoidCallback onTap) {
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
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            enabled ? Colors.white : color.withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s11,
                            0.21,
                            enabled ? Colors.white : color.withOpacity(0.5)),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s11,
                        0.21,
                        enabled ? Colors.white : color.withOpacity(0.5)),
                  ),
          ),
        ),
      ),
    );
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
        return const Color(0xFFD97706); // Orange - actionable pending state
      case 'READY':
        return const Color(0xFFD97706); // Orange - actionable preparing state
      case 'SERVED':
        return const Color(0xFF059669); // Green - completion action
      default:
        return const Color(0xFF64748B);
    }
  }

  ItemStatus _mapStatusValueToItemStatus(String statusValue) {
    switch (statusValue.toUpperCase()) {
      case 'START':
        return ItemStatus.preparing;
      case 'READY':
        return ItemStatus.ready;
      case 'SERVED':
        return ItemStatus.served;
      default:
        return ItemStatus.pending;
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

    final totalItems =
        orders.fold<int>(0, (sum, order) => sum + order.items.length);

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
