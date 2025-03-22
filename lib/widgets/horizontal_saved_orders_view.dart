import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/local_product_provider.dart';
import '../resources/color_manager.dart';
import '../components/build_dialog_box.dart';

class HorizontalSavedOrdersView extends StatelessWidget {
  final Function(String) onOrderSelected;

  const HorizontalSavedOrdersView({
    Key? key,
    required this.onOrderSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        if (provider.savedOrders.isEmpty) {
          return SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildNewOrderButton(context, provider),
              ],
            ),
          );
        }

        return SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount:
                provider.savedOrders.length + 1, // +1 for the new order button
            itemBuilder: (context, index) {
              // First item is the new order button
              if (index == 0) {
                return _buildNewOrderButton(context, provider);
              }

              // Adjust index for actual order items
              final orderIndex = index - 1;
              final order = provider.savedOrders[orderIndex];
              // Format time from ISO date string to 12-hour format with AM/PM
              String time = _formatTimeWith12Hour(order.createdAt);

              return GestureDetector(
                onTap: () => onOrderSelected(order.id),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "₹${order.total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Items: ${order.items.length}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewOrderButton(
      BuildContext context, LocalProductProvider provider) {
    return GestureDetector(
      onTap: () {
        // If currently editing an order and cart has items, update it
        if (provider.currentOrder != null && provider.cartItems.isNotEmpty) {
          provider.updateSavedOrder(
            provider.currentOrder!.id,
            customerName: null,
            customerPhone: null,
            comment: null,
            deliveryMethod: null,
          );
        }
        // If cart has items, save as new order
        else if (provider.cartItems.isNotEmpty) {
          try {
            provider.saveCurrentCartAsOrder();

            // Show feedback
            showScaffold(
              context: context,
              message: "Order Saved Successfully",
            );
          } catch (e) {
            // Swallow exception if cart is empty
          }
        }

        // Clear cart and reset current order
        provider.clearCart();
        // Reset current order using proper method
        if (provider.currentOrder != null) {
          // Create a temporary order ID before clearing
          String orderId = provider.currentOrder!.id;
          // Need to manually clear the current order reference
          provider.loadOrderForEditing(orderId);
          provider.clearCart();
        }
        provider.notifyListeners();

        // Update UI
        (context as Element).markNeedsBuild();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: ColorManager.textColor,
            size: 30,
          ),
        ),
      ),
    );
  }

  String _formatTimeWith12Hour(String isoDate) {
    // Convert ISO date string to DateTime
    DateTime dateTime = DateTime.parse(isoDate);

    // Format time in 12-hour format with AM/PM
    String formattedTime = DateFormat('h:mm a').format(dateTime);

    return formattedTime;
  }
} 