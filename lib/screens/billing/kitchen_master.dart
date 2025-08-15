import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/build_round_button.dart';
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

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        final List<dynamic> orders =
            (response['orders'] as List<dynamic>?) ?? [];
        final parsed =
            orders.map<KitchenOrder>(_mapSavedOrderToKitchenOrder).toList();
        setState(() {
          _orders = parsed;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Failed to load saved orders';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCartItemStatuses() async {
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
      } else {
        debugPrint('❌ Failed to fetch cart item statuses: ${response['message']}');
      }
    } catch (e) {
      debugPrint('❌ Exception fetching cart item statuses: $e');
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
      
      return KitchenOrderItem(
        id: cartItemId != null ? '${cartItemId}_$name' : '${id}_$name',
        name: name,
        quantity: quantity,
        status: _mapItemStatus(item['status']?.toString()),
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
    if (order['cart'] != null && order['cart']['cart_items'] != null) {
      return (order['cart']['cart_items'] as List<dynamic>);
    }
    if (order['cart_items'] != null &&
        order['cart_items']['cart_items'] != null) {
      return (order['cart_items']['cart_items'] as List<dynamic>);
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
    switch ((status ?? '').toLowerCase()) {
      case 'start':
      case 'preparing':
        return ItemStatus.preparing;
      case 'ready':
        return ItemStatus.ready;
      case 'served':
      case 'completed':
        return ItemStatus.served;
      default:
        return ItemStatus.pending;
    }
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
              modifiers[key.toString()] = value.map((v) => v.toString()).toList();
            } else {
              modifiers[key.toString()] = [value.toString()];
            }
          });
        }
      }
      
      // Check for customizations in product details
      if (item['product'] != null && item['product']['customizations'] != null) {
        final customizations = item['product']['customizations'];
        if (customizations is List) {
          for (var custom in customizations) {
            if (custom is Map && custom['name'] != null && custom['value'] != null) {
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
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.21,
                            const Color(0xFFDC2626),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        CustomRoundButton(
                          title: 'Retry',
                          fct: () {
                            _fetchAllSavedOrders();
                            _fetchCartItemStatuses();
                          },
                          height: 40,
                          width: 120,
                          fontSize: 14,
                        ),
                      ],
                    ),
                  )
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
          ),
        ),
      ],
    );
  }

  List<KitchenOrder> _getFilteredOrders() {
    final filtered = _orders.where((order) => order.status == _selectedFilter).toList();
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
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      debugPrint('🔄 Updating cart item $cartItemId to status $statusId');
      
      final response = await cartProvider.updateCartItemStatus(
        cartItemId: cartItemId,
        statusId: statusId,
        accessToken: authModel.token ?? '',
      );

      if ((response['status'] as String?)?.toLowerCase() == 'success') {
        debugPrint('✅ Cart item status updated successfully');
        // Refresh the order details
        await _fetchAllSavedOrders();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item status updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to update cart item status: ${response['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update item status: ${response['message']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception updating cart item status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item status: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
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

  const _OrderQueuePanel({
    required this.orders,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOrderStatusChanged,
    this.isCompact = false,
    required this.screenSize,
    this.availableStatuses,
    this.onCartItemStatusChanged,
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
            child: orders.isEmpty
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
                            Icons.check_circle_outline,
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
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final order = orders[index];
                          return _buildOrderCard(order, isCompact);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(KitchenOrder order, bool compact) {
    final timeSinceOrder = DateTime.now().difference(order.timestamp);
    final isUrgent = timeSinceOrder.inMinutes > 15;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Navigate to order details
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: isUrgent
                ? const Color(0xFFDC2626).withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent
                  ? const Color(0xFFDC2626).withOpacity(0.3)
                  : Colors.grey.shade200,
              width: isUrgent ? 2 : 1,
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
                        isUrgent
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B)),
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
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Start All',
                      const Color(0xFF2563EB),
                      () =>
                          onOrderStatusChanged(order.id, OrderStatus.preparing),
                      compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      'Mark Ready',
                      const Color(0xFF059669),
                      () => onOrderStatusChanged(order.id, OrderStatus.ready),
                      compact,
                    ),
                  ),
                ],
              ),
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
        return 'PENDING';
      case ItemStatus.preparing:
        return 'COOKING';
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

  const _OrderDetailsPanel({
    required this.orders,
    required this.onItemStatusChanged,
    required this.availableStatuses,
    required this.onCartItemStatusChanged,
    required this.screenSize,
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
            child: activeOrders.isEmpty
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
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s16, 0.21, const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Orders will appear here when they need preparation',
                          style: buildCustomStyle(FontWeightManager.regular,
                              FontSize.s12, 0.21, const Color(0xFF94A3B8)),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, index) {
                          final order = activeOrders[index];
                          final timeSinceOrder = DateTime.now().difference(order.timestamp);
                          final isUrgent = timeSinceOrder.inMinutes > 15;

                          return Container(
                            decoration: BoxDecoration(
                              color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.3) : Colors.grey.shade200,
                                width: isUrgent ? 2 : 1,
                              ),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                initiallyExpanded: _expandedOrderId == null ? index == 0 : _expandedOrderId == order.id,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    _expandedOrderId = expanded ? order.id : null;
                                  });
                                },
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(order.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${order.id} - ${order.tableId}',
                                        style: buildCustomStyle(
                                          FontWeightManager.bold, 
                                          FontSize.s14, 
                                          0.21, 
                                          _getStatusColor(order.status)
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${timeSinceOrder.inMinutes}m ago',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium, 
                                        FontSize.s12, 
                                        0.21, 
                                        isUrgent ? const Color(0xFFDC2626) : const Color(0xFF64748B)
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  // Order items
                                  ...order.items.map((item) => _buildItemCard(order.id, item)).toList(),
                                  // Order notes
                                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706).withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFD97706).withOpacity(0.2),
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
                                                const Color(0xFFD97706)
                                              ),
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
          // Status control buttons from API
          if (widget.availableStatuses.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.availableStatuses.map((status) {
                final isEnabled = _shouldEnableStatus(status.value, item.status);
                final color = _getStatusButtonColor(status.value);
                
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 100) / 3,
                  child: _buildStatusButton(
                    status.description,
                    color,
                    isEnabled,
                    () {
                      if (isEnabled) {
                        // Extract cart item ID from the item ID (assuming format like "cartItemId_productName")
                        final cartItemId = int.tryParse(item.id.split('_').first);
                        if (cartItemId != null) {
                          widget.onCartItemStatusChanged(cartItemId, status.id);
                        } else {
                          debugPrint('❌ Could not extract cart item ID from: ${item.id}');
                        }
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // Fallback to original buttons if API statuses not loaded
            Row(
              children: [
                Expanded(
                  child: _buildStatusButton(
                    'Start',
                    const Color(0xFF2563EB),
                    item.status == ItemStatus.pending,
                    () => widget.onItemStatusChanged(orderId, item.id, ItemStatus.preparing),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Ready',
                    const Color(0xFF059669),
                    item.status == ItemStatus.preparing,
                    () => widget.onItemStatusChanged(orderId, item.id, ItemStatus.ready),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Served',
                    const Color(0xFF6B7280),
                    item.status == ItemStatus.ready,
                    () => widget.onItemStatusChanged(orderId, item.id, ItemStatus.served),
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
    // Enable status based on current item status and API status value
    switch (statusValue.toUpperCase()) {
      case 'START':
        return currentStatus == ItemStatus.pending;
      case 'READY':
        return currentStatus == ItemStatus.preparing;
      case 'SERVED':
        return currentStatus == ItemStatus.ready;
      default:
        return true; // Enable all unknown statuses
    }
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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Urgent Orders',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.21, const Color(0xFF64748B)),
                  ),
                  Text(
                    stats['urgentOrders'].toString(),
                    style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.21,
                        stats['urgentOrders'] > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1E293B)),
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
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    final preparing =
        orders.where((o) => o.status == OrderStatus.preparing).length;
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;
    final served = orders.where((o) => o.status == OrderStatus.served).length;

    final totalItems =
        orders.fold<int>(0, (sum, order) => sum + order.items.length);

    final urgentOrders = orders.where((order) {
      final timeSinceOrder = DateTime.now().difference(order.timestamp);
      return timeSinceOrder.inMinutes > 15 &&
          order.status != OrderStatus.served;
    }).length;

    // Calculate average prep time (mock calculation)
    final avgPrepTime = 12; // This would be calculated from actual data

    return {
      'pending': pending,
      'preparing': preparing,
      'ready': ready,
      'served': served,
      'totalItems': totalItems,
      'urgentOrders': urgentOrders,
      'avgPrepTime': avgPrepTime,
    };
  }
}
