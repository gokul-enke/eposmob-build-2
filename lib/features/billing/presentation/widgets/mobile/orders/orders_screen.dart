import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/order_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/order_stat_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/orders_empty_state.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    super.key,
    required this.onOrderSelected,
    required this.onPrintOrder,
    required this.onDeleteOrder,
    this.isLoadingOrder = false,
  });

  final Future<void> Function(String orderId) onOrderSelected;
  final Future<void> Function(SavedOrder order) onPrintOrder;
  final void Function(SavedOrder order) onDeleteOrder;
  final bool isLoadingOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Consumer<LocalProductProvider>(
            builder: (context, provider, _) {
              final orders = _sortedOrders(provider.savedOrders);
              final readyCount = orders.where(_isReadyOrder).length;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ActiveOrdersStatCard(value: orders.length),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ReadyOrdersStatCard(value: readyCount),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: orders.isEmpty
                        ? const OrdersEmptyState(hasSearchQuery: false)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(top: 0, bottom: 16),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return OrderCard(
                                order: order,
                                onTap: isLoadingOrder
                                    ? null
                                    : () => _showOrderDetails(context, order),
                                onEdit: isLoadingOrder
                                    ? null
                                    : () => onOrderSelected(order.id),
                                onPrint: isLoadingOrder
                                    ? null
                                    : () => onPrintOrder(order),
                                onDelete: isLoadingOrder
                                    ? null
                                    : () => onDeleteOrder(order),
                                isLoadingOrder: isLoadingOrder,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static List<SavedOrder> _sortedOrders(List<SavedOrder> orders) {
    final sorted = List<SavedOrder>.from(orders);
    sorted.sort((first, second) {
      final firstDate = DateTime.tryParse(first.createdAt) ?? DateTime(1970);
      final secondDate = DateTime.tryParse(second.createdAt) ?? DateTime(1970);
      return secondDate.compareTo(firstDate);
    });
    return sorted;
  }

  static bool _isReadyOrder(SavedOrder order) {
    final status = order.status?.trim().toLowerCase() ?? '';
    return status.contains('ready') ||
        status.contains('complete') ||
        status.contains('pickup');
  }

  void _showOrderDetails(BuildContext context, SavedOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final orderNumber = order.orderNumber.trim().isEmpty
            ? order.id
            : order.orderNumber.trim();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  orderNumber.startsWith('#') ? orderNumber : '#$orderNumber',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.customerName ?? 'Walk-in Customer',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.blueGrey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                    label: 'Items', value: order.items.length.toString()),
                _DetailRow(
                    label: 'Delivery', value: order.deliveryMethod ?? '-'),
                _DetailRow(
                  label: 'Total',
                  value: '\$${order.total.toStringAsFixed(2)}',
                  valueColor: ColorManager.kPrimaryColor,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoadingOrder
                            ? null
                            : () {
                                Navigator.pop(context);
                                onPrintOrder(order);
                              },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoadingOrder
                            ? null
                            : () {
                                Navigator.pop(context);
                                onDeleteOrder(order);
                              },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: isLoadingOrder
                        ? null
                        : () {
                            Navigator.pop(context);
                            onOrderSelected(order.id);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.kPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Edit Order',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.blueGrey.shade500,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
