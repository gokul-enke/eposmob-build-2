import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/resources/color_manager.dart';

class ViewOrders extends StatelessWidget {
  const ViewOrders({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data - replace with your actual data source
    final List<Map<String, dynamic>> orders = List.generate(10, (index) {
      final now = DateTime.now().subtract(Duration(days: index));
      return {
        'id': 'ORD-${1000 + index}',
        'date': now.toIso8601String(),
        'total': (index + 1) * 50.0,
        'items': (index + 2),
        'status': index % 3 == 0 ? 'Completed' : 'Pending',
        'customer': 'Customer ${index + 1}',
      };
    });

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: orders.isEmpty
            ? _buildEmptyState()
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 cards per row
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5, // Width/height ratio
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _buildOrderCard(context, order);
                },
              ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    bool isSelected = false; // Add selection logic if needed
    String time = _formatTimeWith12Hour(order['date']);

    return BuildBoxShadowContainer(
      circleRadius: 8,
      color: isSelected ? Colors.white : Colors.white,
      border: isSelected
          ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
          : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Handle order selection
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row - Order ID and Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['id'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected
                            ? ColorManager.kPrimaryColor
                            : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Bottom row - Amount, Items, and Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Print Button
                  IconButton(
                    onPressed: () => _printOrder(order),
                    icon: const Icon(Icons.print, size: 20),
                    color: Colors.blue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  // Amount and Items Count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${order['items']} items",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "₹${order['total'].toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  // Delete Button
                  IconButton(
                    onPressed: () => _showDeleteDialog(context, order),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: ColorManager.kButtonRed,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeWith12Hour(String isoDate) {
    DateTime dateTime = DateTime.parse(isoDate);
    return DateFormat('h:mm a').format(dateTime);
  }

  void _printOrder(Map<String, dynamic> order) {
    debugPrint("Printing order: ${order['id']}");
    // Add your print logic here
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Order"),
        content: Text("Are you sure you want to delete order ${order['id']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              // Add delete logic here
              Navigator.pop(context);
            },
            child: const Text(
              "DELETE",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No orders found",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class BuildBoxShadowContainer extends StatelessWidget {
  final Widget child;
  final double circleRadius;
  final Color color;
  final Border? border;

  const BuildBoxShadowContainer({
    super.key,
    required this.child,
    this.circleRadius = 0,
    this.color = Colors.white,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(circleRadius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}