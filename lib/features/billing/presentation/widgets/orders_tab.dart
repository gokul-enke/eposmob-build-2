import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/horizontal_saved_orders_view.dart';

class OrdersTab extends StatelessWidget {
  final void Function(String orderId) onOrderSelected;
  const OrdersTab({super.key, required this.onOrderSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: HorizontalSavedOrdersView(
              onOrderSelected: (orderId) async {
                // Persist current work-in-progress before switching
                final localProductProvider =
                    Provider.of<LocalProductProvider>(context, listen: false);
                final billingProvider =
                    Provider.of<BillingProvider>(context, listen: false);

                if (localProductProvider.currentOrder != null &&
                    localProductProvider.cartItems.isNotEmpty) {
                  try {
                    localProductProvider.updateSavedOrder(
                      localProductProvider.currentOrder!.id,
                      customerName: billingProvider.selectedCustomer?.name,
                      customerPhone: billingProvider.selectedCustomerPhone ??
                          billingProvider.mobileNumberText,
                      comment: billingProvider.commentController.text,
                      deliveryMethod: billingProvider.deliveryMethod,
                      context: context,
                      deliveryDate:
                          billingProvider.deliveryDate?.toIso8601String(),
                      deliveryTime: billingProvider.deliveryTime,
                    );
                  } catch (_) {}
                } else if (localProductProvider.cartItems.isNotEmpty) {
                  try {
                    localProductProvider.saveCurrentCartAsOrder(
                      deliveryDate:
                          billingProvider.deliveryDate?.toIso8601String(),
                      deliveryTime: billingProvider.deliveryTime,
                    );
                  } catch (_) {}
                }

                onOrderSelected(orderId);
              },
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.shade300,
                Colors.transparent,
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const HorizontalProductViewLocal(),
          ),
        ),
      ],
    );
  }
}
