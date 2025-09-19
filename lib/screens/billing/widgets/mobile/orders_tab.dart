import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/print_service.dart';

class MobileOrdersTab extends StatefulWidget {
  final void Function(String orderId) onOrderSelected;

  const MobileOrdersTab({
    super.key,
    required this.onOrderSelected,
  });

  @override
  State<MobileOrdersTab> createState() => _MobileOrdersTabState();
}

class _MobileOrdersTabState extends State<MobileOrdersTab> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Today',
    'This Week',
    'This Month'
  ];

  String _formatPaymentSummary(String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) return 'N/A';
    try {
      if (paymentMethod.trim().startsWith('{')) {
        final map = jsonDecode(paymentMethod) as Map<String, dynamic>;
        final methods = List<String>.from(map['methods'] ?? const []);
        final amounts = Map<String, dynamic>.from(map['amounts'] ?? const {});
        final parts = <String>[];
        for (final m in methods) {
          final raw = amounts[m];
          final num? val =
              raw is num ? raw : num.tryParse(raw?.toString() ?? '');
          if (val != null && val > 0) {
            final label = m[0] + m.substring(1).toLowerCase();
            parts.add('$label ₹${val.toStringAsFixed(2)}');
          } else {
            final label = m[0] + m.substring(1).toLowerCase();
            parts.add(label);
          }
        }
        if (parts.isEmpty) return 'Multiple';
        // Avoid overly long text
        return parts.length > 3
            ? parts.take(3).join(', ') + ' +' + (parts.length - 3).toString()
            : parts.join(', ');
      }
    } catch (_) {
      // Fall through to simple handling
    }
    final up = paymentMethod.toUpperCase();
    switch (up) {
      case 'CASH':
      case 'CARD':
      case 'UPI':
      case 'DEBIT':
        return up[0] + up.substring(1).toLowerCase();
      default:
        return paymentMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: ColorManager.kPrimaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Saved Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Consumer<LocalProductProvider>(
                      builder: (context, provider, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${provider.savedOrders.length} orders',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColorManager.kPrimaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search and Filter Row
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 3,
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search orders...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: ColorManager.kPrimaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            onChanged: (value) {
                              setState(() {
                                _selectedFilter = value!;
                              });
                            },
                            items: _filterOptions.map((filter) {
                              return DropdownMenuItem(
                                value: filter,
                                child: Text(
                                  filter,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            icon: Icon(
                              Icons.filter_list,
                              color: Colors.grey.shade600,
                              size: 18,
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

          // Orders List
          Expanded(
            child: Consumer<LocalProductProvider>(
              builder: (context, provider, child) {
                final filteredOrders = _getFilteredOrders(provider.savedOrders);

                if (filteredOrders.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SavedOrder> _getFilteredOrders(List<SavedOrder> orders) {
    List<SavedOrder> filtered = orders;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        return order.customerName
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true ||
            order.customerPhone?.contains(_searchQuery) == true ||
            order.id?.contains(_searchQuery) == true;
      }).toList();
    }

    // Apply date filter
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Today':
        filtered = filtered.where((order) {
          final orderDate = DateTime.parse(order.createdAt);
          return orderDate.year == now.year &&
              orderDate.month == now.month &&
              orderDate.day == now.day;
        }).toList();
        break;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered.where((order) {
          final orderDate = DateTime.parse(order.createdAt);
          return orderDate.isAfter(weekStart);
        }).toList();
        break;
      case 'This Month':
        filtered = filtered.where((order) {
          final orderDate = DateTime.parse(order.createdAt);
          return orderDate.year == now.year && orderDate.month == now.month;
        }).toList();
        break;
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) {
      return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
    });

    return filtered;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filter'
                : 'Saved orders will appear here',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(SavedOrder order) {
    final orderDate = DateTime.parse(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        child: InkWell(
          onTap: () => _showOrderDetailsModal(order),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName ?? 'Unknown Customer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (order.customerPhone != null)
                            Text(
                              order.customerPhone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorManager.kPrimaryColor,
                          ),
                        ),
                        Text(
                          _formatDate(orderDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Order Details
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _buildInfoChip(
                      Icons.shopping_cart,
                      '${order.items.length} items',
                    ),
                    _buildInfoChip(
                      Icons.payment,
                      _formatPaymentSummary(order.paymentMethod),
                    ),
                    _buildInfoChip(
                      Icons.local_shipping,
                      order.deliveryMethod ?? 'Store',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomRoundButton(
                        title: "Edit",
                        fct: () => widget.onOrderSelected(order.id),
                        fontSize: 12,
                        height: 32,
                        width: double.infinity,
                        boxColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                        borderColor: ColorManager.kPrimaryColor,
                        textColor: ColorManager.kPrimaryColor,
                        radius: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomRoundButton(
                        title: "Print",
                        fct: () => _printOrder(order),
                        fontSize: 12,
                        height: 32,
                        width: double.infinity,
                        boxColor: Colors.blue.shade50,
                        borderColor: Colors.blue.shade300,
                        textColor: Colors.blue.shade700,
                        radius: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomRoundButton(
                        title: "Delete",
                        fct: () => _deleteOrder(order),
                        fontSize: 12,
                        height: 32,
                        width: double.infinity,
                        boxColor: Colors.red.shade50,
                        borderColor: Colors.red.shade300,
                        textColor: Colors.red.shade700,
                        radius: 8,
                      ),
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showOrderDetailsModal(SavedOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Order details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info
                    _buildDetailSection(
                      'Customer Information',
                      [
                        'Name: ${order.customerName ?? 'N/A'}',
                        'Phone: ${order.customerPhone ?? 'N/A'}',
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Order Info
                    _buildDetailSection(
                      'Order Information',
                      [
                        'Order ID: ${order.id}',
                        'Date: ${_formatDate(DateTime.parse(order.createdAt))}',
                        'Payment: ${_formatPaymentSummary(order.paymentMethod)}',
                        'Delivery: ${order.deliveryMethod ?? 'N/A'}',
                        'Total: ₹${order.total.toStringAsFixed(2)}',
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Items
                    if (order.items.isNotEmpty)
                      _buildDetailSection(
                        'Items (${order.items.length})',
                        order.items
                            .map((item) =>
                                '${item.product.productName} x ${item.quantity} = ₹${((item.price ?? 0) * item.quantity).toStringAsFixed(2)}')
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CustomRoundButton(
                      title: "Edit Order",
                      fct: () {
                        Navigator.pop(context);
                        widget.onOrderSelected(order.id);
                      },
                      fontSize: 14,
                      height: 48,
                      width: double.infinity,
                      boxColor: ColorManager.kPrimaryColor,
                      borderColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                      radius: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomRoundButton(
                      title: "Print Order",
                      fct: () {
                        Navigator.pop(context);
                        _printOrder(order);
                      },
                      fontSize: 14,
                      height: 48,
                      width: double.infinity,
                      boxColor: Colors.blue.shade50,
                      borderColor: Colors.blue.shade300,
                      textColor: Colors.blue.shade700,
                      radius: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details
                .map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        detail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  void _printOrder(SavedOrder order) async {
    try {
      await const PrintService().printSavedOrder(context, order);
    } catch (error) {
      debugPrint("Error printing order: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print order: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteOrder(SavedOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
            'Are you sure you want to delete this order for ${order.customerName ?? 'Unknown Customer'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final provider =
                  Provider.of<LocalProductProvider>(context, listen: false);
              provider.deleteSavedOrder(order.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
