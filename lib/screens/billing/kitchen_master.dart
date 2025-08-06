import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../providers/restaurant/order_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

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
  
  // Mock data - replace with actual data from your providers
  List<KitchenOrder> _orders = [
    KitchenOrder(
      id: 'ORD001',
      tableId: 'Table 1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      status: OrderStatus.pending,
      items: [
        KitchenOrderItem(
          id: 'ITEM001',
          name: 'Tomato Soup',
          quantity: 2,
          status: ItemStatus.pending,
          modifiers: {'Size': ['Large'], 'Spice': ['Medium']},
          notes: 'Extra herbs',
        ),
        KitchenOrderItem(
          id: 'ITEM002',
          name: 'Chicken Biryani',
          quantity: 1,
          status: ItemStatus.preparing,
          modifiers: {'Spice': ['Hot']},
          startTime: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ],
    ),
    KitchenOrder(
      id: 'ORD002',
      tableId: 'Table 3',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      status: OrderStatus.preparing,
      items: [
        KitchenOrderItem(
          id: 'ITEM003',
          name: 'Margherita Pizza',
          quantity: 1,
          status: ItemStatus.ready,
          modifiers: {'Size': ['Medium'], 'Crust': ['Thin']},
          readyTime: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    final isLargeScreen = screenWidth >= 1200;
    final isSmallScreen = screenWidth < 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: isSmallScreen 
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
            onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
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
            screenSize: screenSize,
          ),
        ),
        // Kitchen Stats Panel
        Expanded(
          flex: 2,
          child: _KitchenStatsPanel(
            orders: _orders,
            screenSize: screenSize,
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
          ),
        ),
        // Orders list
        Expanded(
          child: _OrderQueuePanel(
            orders: _getFilteredOrders(),
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
            onOrderStatusChanged: _updateOrderStatus,
            isCompact: true,
            screenSize: screenSize,
          ),
        ),
      ],
    );
  }

  List<KitchenOrder> _getFilteredOrders() {
    return _orders.where((order) => order.status == _selectedFilter).toList();
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
            startTime: newStatus == ItemStatus.preparing ? DateTime.now() : updatedItems[itemIndex].startTime,
            readyTime: newStatus == ItemStatus.ready ? DateTime.now() : updatedItems[itemIndex].readyTime,
          );
          _orders[orderIndex] = order.copyWith(items: updatedItems);
        }
      }
    });
  }
}

class _OrderQueuePanel extends StatelessWidget {
  final List<KitchenOrder> orders;
  final OrderStatus selectedFilter;
  final ValueChanged<OrderStatus> onFilterChanged;
  final Function(String, OrderStatus) onOrderStatusChanged;
  final bool isCompact;
  final Size screenSize;

  const _OrderQueuePanel({
    required this.orders,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onOrderStatusChanged,
    this.isCompact = false,
    required this.screenSize,
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
                        const Color(0xFF1E293B)
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold, 
                          FontSize.s12, 
                          0.21, 
                          const Color(0xFFD97706)
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Status filters
                SingleChildScrollView(
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive 
                                  ? _getStatusColor(status) 
                                  : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isActive ? [
                                  BoxShadow(
                                    color: _getStatusColor(status).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : [],
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold, 
                                  FontSize.s12, 
                                  0.21, 
                                  isActive ? Colors.white : const Color(0xFF64748B)
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                          const Color(0xFF64748B)
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final order = orders[index];
                    return _buildOrderCard(order, isCompact);
                  },
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
            color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.3) : Colors.grey.shade200,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        _getStatusColor(order.status)
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    order.tableId,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      compact ? FontSize.s13 : FontSize.s15, 
                      0.21, 
                      const Color(0xFF1E293B)
                    ),
                  ),
                  const Spacer(),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.warning,
                        color: const Color(0xFFDC2626),
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${timeSinceOrder.inMinutes}m ago',
                    style: buildCustomStyle(
                      FontWeightManager.medium, 
                      compact ? FontSize.s10 : FontSize.s11, 
                      0.21, 
                      isUrgent ? const Color(0xFFDC2626) : const Color(0xFF64748B)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Order items summary
              ...order.items.map((item) => Padding(
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
                        const Color(0xFF64748B)
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.name,
                        style: buildCustomStyle(
                          FontWeightManager.medium, 
                          compact ? FontSize.s11 : FontSize.s12, 
                          0.21, 
                          const Color(0xFF1E293B)
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getItemStatusColor(item.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getItemStatusText(item.status),
                        style: buildCustomStyle(
                          FontWeightManager.semiBold, 
                          FontSize.s8, 
                          0.14, 
                          _getItemStatusColor(item.status)
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Start All',
                      const Color(0xFF2563EB),
                      () => onOrderStatusChanged(order.id, OrderStatus.preparing),
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

  Widget _buildActionButton(String text, Color color, VoidCallback onTap, bool compact) {
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
              style: buildCustomStyle(
                FontWeightManager.semiBold, 
                compact ? FontSize.s10 : FontSize.s11, 
                0.21, 
                color
              ),
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

class _OrderDetailsPanel extends StatelessWidget {
  final List<KitchenOrder> orders;
  final Function(String, String, ItemStatus) onItemStatusChanged;
  final Size screenSize;

  const _OrderDetailsPanel({
    required this.orders,
    required this.onItemStatusChanged,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders.where((order) => 
      order.status == OrderStatus.preparing || order.status == OrderStatus.pending
    ).toList();

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
                  style: buildCustomStyle(
                    FontWeightManager.bold, 
                    FontSize.s18, 
                    0.30, 
                    const Color(0xFF1E293B)
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activeOrders.length} Active',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF2563EB)
                    ),
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
                        style: buildCustomStyle(
                          FontWeightManager.semiBold, 
                          FontSize.s16, 
                          0.21, 
                          const Color(0xFF64748B)
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Orders will appear here when they need preparation',
                        style: buildCustomStyle(
                          FontWeightManager.regular, 
                          FontSize.s12, 
                          0.21, 
                          const Color(0xFF94A3B8)
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) {
                    final order = activeOrders[index];
                    return _buildDetailedOrderCard(order);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedOrderCard(KitchenOrder order) {
    final timeSinceOrder = DateTime.now().difference(order.timestamp);
    final isUrgent = timeSinceOrder.inMinutes > 15;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? const Color(0xFFDC2626).withOpacity(0.3) : Colors.grey.shade200,
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
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'URGENT',
                        style: buildCustomStyle(
                          FontWeightManager.bold, 
                          FontSize.s10, 
                          0.21, 
                          const Color(0xFFDC2626)
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          // Order items with individual controls
          ...order.items.map((item) => _buildItemCard(order.id, item)).toList(),
          // Order notes if any
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
                  style: buildCustomStyle(
                    FontWeightManager.bold, 
                    FontSize.s12, 
                    0.21, 
                    _getItemStatusColor(item.status)
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: buildCustomStyle(
                    FontWeightManager.bold, 
                    FontSize.s14, 
                    0.21, 
                    const Color(0xFF1E293B)
                  ),
                ),
              ),
              if (cookingTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${cookingTime.inMinutes}m',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      FontSize.s10, 
                      0.21, 
                      const Color(0xFF2563EB)
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${modifier.key}: ${modifier.value.join(', ')}',
                    style: buildCustomStyle(
                      FontWeightManager.medium, 
                      FontSize.s9, 
                      0.21, 
                      const Color(0xFF64748B)
                    ),
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
                      style: buildCustomStyle(
                        FontWeightManager.medium, 
                        FontSize.s11, 
                        0.21, 
                        const Color(0xFFDC2626)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Status control buttons
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  'Start',
                  const Color(0xFF2563EB),
                  item.status == ItemStatus.pending,
                  () => onItemStatusChanged(orderId, item.id, ItemStatus.preparing),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  'Ready',
                  const Color(0xFF059669),
                  item.status == ItemStatus.preparing,
                  () => onItemStatusChanged(orderId, item.id, ItemStatus.ready),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusButton(
                  'Served',
                  const Color(0xFF6B7280),
                  item.status == ItemStatus.ready,
                  () => onItemStatusChanged(orderId, item.id, ItemStatus.served),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String text, Color color, bool enabled, VoidCallback onTap) {
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
            boxShadow: enabled ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
          child: Center(
            child: Text(
              text,
              style: buildCustomStyle(
                FontWeightManager.semiBold, 
                FontSize.s11, 
                0.21, 
                enabled ? Colors.white : color.withOpacity(0.5)
              ),
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
}

class _KitchenStatsPanel extends StatelessWidget {
  final List<KitchenOrder> orders;
  final bool isCompact;
  final Size screenSize;

  const _KitchenStatsPanel({
    required this.orders,
    this.isCompact = false,
    required this.screenSize,
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
                    const Color(0xFF1E293B)
                  ),
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
                style: buildCustomStyle(
                  FontWeightManager.bold, 
                  FontSize.s14, 
                  0.21, 
                  const Color(0xFF1E293B)
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avg. Prep Time',
                    style: buildCustomStyle(
                      FontWeightManager.medium, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF64748B)
                    ),
                  ),
                  Text(
                    '${stats['avgPrepTime']} min',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Items',
                    style: buildCustomStyle(
                      FontWeightManager.medium, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF64748B)
                    ),
                  ),
                  Text(
                    stats['totalItems'].toString(),
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Urgent Orders',
                    style: buildCustomStyle(
                      FontWeightManager.medium, 
                      FontSize.s12, 
                      0.21, 
                      const Color(0xFF64748B)
                    ),
                  ),
                  Text(
                    stats['urgentOrders'].toString(),
                    style: buildCustomStyle(
                      FontWeightManager.semiBold, 
                      FontSize.s12, 
                      0.21, 
                      stats['urgentOrders'] > 0 ? const Color(0xFFDC2626) : const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        // Quick actions
        Container(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Refresh data
              },
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
                      style: buildCustomStyle(
                        FontWeightManager.semiBold, 
                        FontSize.s12, 
                        0.21, 
                        const Color(0xFF2563EB)
                      ),
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

  Widget _buildStatCard(String title, String value, Color color, IconData icon, bool compact) {
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
                    FontWeightManager.bold, 
                    FontSize.s20, 
                    0.21, 
                    color
                  ),
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
                  FontWeightManager.bold, 
                  FontSize.s16, 
                  0.21, 
                  color
                ),
              ),
            ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.medium, 
              compact ? FontSize.s9 : FontSize.s11, 
              0.21, 
              const Color(0xFF64748B)
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    final preparing = orders.where((o) => o.status == OrderStatus.preparing).length;
    final ready = orders.where((o) => o.status == OrderStatus.ready).length;
    final served = orders.where((o) => o.status == OrderStatus.served).length;
    
    final totalItems = orders.fold<int>(0, (sum, order) => sum + order.items.length);
    
    final urgentOrders = orders.where((order) {
      final timeSinceOrder = DateTime.now().difference(order.timestamp);
      return timeSinceOrder.inMinutes > 15 && order.status != OrderStatus.served;
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