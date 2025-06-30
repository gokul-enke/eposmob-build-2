import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/billing/billing_page.dart';
import 'package:provider/provider.dart';

/// A widget to display saved orders in a grid layout with new order button at top
class HorizontalSavedOrdersView extends StatefulWidget {
  final Function(String) onOrderSelected;

  const HorizontalSavedOrdersView({
    Key? key,
    required this.onOrderSelected,
  }) : super(key: key);

  @override
  State<HorizontalSavedOrdersView> createState() =>
      _HorizontalSavedOrdersViewState();
}

class _HorizontalSavedOrdersViewState extends State<HorizontalSavedOrdersView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 300, // Fixed height for the container
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // New Order Button at the top
              _buildNewOrderButton(context, provider),
              const SizedBox(height: 12),

              // Saved Orders Grid
              Expanded(
                child: provider.savedOrders.isEmpty
                    ? _buildEmptyState()
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: GridView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 cards per row
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio:
                                1.6, // Reduced for more height to prevent overflow
                          ),
                          itemCount: provider.savedOrders.length,
                          itemBuilder: (context, index) {
                            final order = provider.savedOrders[index];
                            return _buildSavedOrderCard(
                                context, provider, order);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewOrderButton(
      BuildContext context, LocalProductProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: BuildBoxShadowContainer(
        circleRadius: 8,
        color: Colors.white,
        child: InkWell(
          onTap: () {
            debugPrint("===== NEW ORDER (+) BUTTON PRESSED =====");
            debugPrint("🔄 Current state:");
            debugPrint("  - Current order ID: ${provider.currentOrder?.id}");
            debugPrint(
                "  - Current order number: ${provider.currentOrder?.orderNumber}");
            debugPrint("  - Cart items count: ${provider.cartItems.length}");

            // If currently editing an order and cart has items, update it
            if (provider.currentOrder != null &&
                provider.cartItems.isNotEmpty) {
              debugPrint(
                  "📝 Currently editing order ${provider.currentOrder!.orderNumber} with items in cart");

              // Get current values from billing page to preserve customer info
              final billingPageState =
                  context.findAncestorStateOfType<BillingPageState>();
              if (billingPageState != null) {
                debugPrint("💾 Updating current order before creating new one");
                debugPrint(
                    "  - Will save with all current customer and payment info");
                debugPrint(
                    "  - Current order ID: ${provider.currentOrder!.id}");
                debugPrint(
                    "  - Current order phone before save: ${provider.currentOrder!.customerPhone}");
                // Call the billing page's save method to properly save with current customer info
                billingPageState.saveCurrentOrder();
                debugPrint(
                    "  - Current order phone after save: ${provider.currentOrder?.customerPhone}");
              } else {
                // Fallback - update with null values (not ideal but better than losing the order)
                debugPrint(
                    "⚠️ Could not find billing page state, updating with minimal info");
                provider.updateSavedOrder(
                  provider.currentOrder!.id,
                  customerName: null,
                  customerPhone: null,
                  comment: null,
                  deliveryMethod: null,
                );
              }
            }

            // If cart has items, save as new order
            else if (provider.cartItems.isNotEmpty) {
              // Get current values from billing page to preserve customer info
              final billingPageState =
                  context.findAncestorStateOfType<BillingPageState>();
              if (billingPageState != null) {
                debugPrint("💾 Saving new order with current customer info");
                // Call the billing page's save method to properly save with current customer info
                billingPageState.saveCurrentOrder();
              } else {
                // Fallback - save without customer info (not ideal)
                debugPrint(
                    "⚠️ Could not find billing page state, saving without customer info");
                try {
                  provider.saveCurrentCartAsOrder();
                  showScaffold(
                    context: context,
                    message: "Order Saved Successfully",
                  );
                } catch (e) {
                  debugPrint("Error saving order: $e");
                }
              }
            }

            // Clear cart and reset current order
            debugPrint("🧹 Clearing cart and resetting for new order");
            provider.clearCart();

            // **FIX: Trigger the billing page to reset to default sales executive**
            // Find the billing page state and call the reset methods
            final billingPageState =
                context.findAncestorStateOfType<BillingPageState>();
            if (billingPageState != null) {
              debugPrint("✅ Found BillingPageState, calling reset method");
              debugPrint("  - This will reset to default sales executive");
              debugPrint("  - This will clear all form fields");

              // Call the public method to reset to default sales executive
              billingPageState.resetToDefaultSalesExecutive();

              showScaffold(
                context: context,
                message: "New Order - Reset to default sales executive",
              );
            } else {
              debugPrint("⚠️ BillingPageState not found, manual rebuild");
              (context as Element).markNeedsBuild();
            }

            debugPrint("===== NEW ORDER (+) BUTTON COMPLETE =====");
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle,
                  size: 24,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  "Create New Order",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedOrderCard(
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
        onTap: () => widget.onOrderSelected(order.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header row with order number and time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Amount and items count row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "₹${order.total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    "${order.items.length} items",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Action buttons row - spread across the card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.findAncestorStateOfType<BillingPageState>() !=
                          null) {
                        context
                            .findAncestorStateOfType<BillingPageState>()!
                            .printFromSavedOrder(order);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.print,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _showDeleteConfirmationDialog(context, provider, order);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ColorManager.kButtonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: ColorManager.kButtonRed,
                      ),
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
          const SizedBox(height: 12),
          Text(
            "No saved orders yet",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Create your first order above",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withOpacity(0.6),
            ),
          ),
        ],
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

  void _showDeleteConfirmationDialog(
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
}
