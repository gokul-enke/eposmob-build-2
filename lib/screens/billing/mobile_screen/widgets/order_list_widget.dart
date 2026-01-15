import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class ViewOrders extends StatelessWidget {
  final Function(String) onOrderSelected;

  const ViewOrders({
    Key? key,
    required this.onOrderSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: provider.savedOrders.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 cards per row
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5, // Width/height ratio
                  ),
                  itemCount: provider.savedOrders.length,
                  itemBuilder: (context, index) {
                    final order = provider.savedOrders[index];
                    return _buildOrderCard(context, provider, order);
                  },
                ),
        );
      },
    );
  }

  Widget _buildOrderCard(
      BuildContext context, LocalProductProvider provider, SavedOrder order) {
    String time = _formatTimeWith12Hour(order.createdAt);
    bool isSelected = provider.currentOrder?.id == order.id;

    return BuildBoxShadowContainer(
      circleRadius: 8,
      color: isSelected ? Colors.white : Colors.white,
      border: isSelected
          ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
          : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOrderSelected(order.id),
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
                      order.orderNumber,
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

              // Middle row - Customer info if available
              if (order.customerName != null && order.customerName!.isNotEmpty)
                Text(
                  order.customerName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),

              // Bottom row - Amount, Items, and Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Print Button
                  IconButton(
                    onPressed: () => _printOrder(context, order),
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
                        "${order.items.length} items",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "${order.total.toStringAsFixed(2)}",
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
                    onPressed: () =>
                        _showDeleteDialog(context, provider, order),
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

  void _printOrder(BuildContext context, SavedOrder order) {
    debugPrint("Printing order: ${order.orderNumber}");
    // Add your print logic here
    showScaffold(
      context: context,
      message: "Printing order ${order.orderNumber}",
    );
  }

  void _showDeleteDialog(
      BuildContext context, LocalProductProvider provider, SavedOrder order) {
    DeleteConfirmationDialog.show(
      context: context,
      title: "Delete Order",
      itemName: order.orderNumber,
      message: "This order will be permanently removed from your saved orders.",
      warningIcon: Icons.receipt_long_outlined,
      onDelete: () {
        // Delete the order
        provider.deleteSavedOrder(order.id);

        // Show success message
        showScaffold(
          context: context,
          message: "Order deleted successfully",
        );
      },
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
          const SizedBox(height: 4),
          Text(
            "Create orders in the billing section",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to show snackbar messages
void showScaffold({required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}
