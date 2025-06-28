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

/// A widget to display saved orders in a horizontal scrollable list
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
  bool _isHovering = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        return SizedBox(
          height: 60,
          child: MouseRegion(
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
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: provider.savedOrders.length +
                    1, // +1 for the new order button
                itemBuilder: (context, index) {
                  // New Order button as the first item
                  if (index == 0) {
                    return _buildNewOrderButton(context, provider);
                  }

                  // Saved orders
                  final order = provider.savedOrders[index - 1];
                  String time = _formatTimeWith12Hour(order.createdAt);

                  return Padding(
                    padding:
                        const EdgeInsets.only(right: 10.0, bottom: 1, top: 1),
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      color: provider.currentOrder?.id == order.id
                          ? Colors.white
                          : Colors.white,
                      border: provider.currentOrder?.id == order.id
                          ? Border.all(
                              color: ColorManager.kPrimaryColor, width: 2)
                          : null,
                      width: 140,
                      child: InkWell(
                        onTap: () => widget.onOrderSelected(order.id),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.orderNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () {
                                      if (context.findAncestorStateOfType<
                                              BillingPageState>() !=
                                          null) {
                                        context
                                            .findAncestorStateOfType<
                                                BillingPageState>()!
                                            .printFromSavedOrder(order);
                                      }
                                    },
                                    child: const Icon(
                                      Icons.print,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "₹${order.total.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Items: ${order.items.length}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          _showDeleteConfirmationDialog(
                                              context, provider, order);
                                        },
                                        child: const Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: ColorManager.kButtonRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewOrderButton(
      BuildContext context, LocalProductProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0, bottom: 1, left: 5, top: 1),
      child: BuildBoxShadowContainer(
        circleRadius: 7,
        color: Colors.white,
        width: 60,
        child: InkWell(
          onTap: () {
            // If currently editing an order and cart has items, update it
            if (provider.currentOrder != null &&
                provider.cartItems.isNotEmpty) {
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
            if (provider.currentOrder != null) {
              String orderId = provider.currentOrder!.id;
              provider.loadOrderForEditing(orderId);
              provider.clearCart();
            }
            (context as Element).markNeedsBuild();
          },
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle,
                  size: 30,
                  color: ColorManager.kPrimaryColor,
                ),
              ],
            ),
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
