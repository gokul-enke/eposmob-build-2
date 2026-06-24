import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/domain/order_payment_summary.dart';

/// A single saved-order card in the mobile Orders tab. Extracted verbatim from
/// `orders_tab.dart`'s `_buildOrderCard` (+ its info-chip / date helpers).
/// Actions are delegated to the parent via callbacks.
class MobileOrderCard extends StatelessWidget {
  final SavedOrder order;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const MobileOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final orderDate = DateTime.parse(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        child: InkWell(
          onTap: onTap,
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
                          '${order.total.toStringAsFixed(2)}',
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
                    _infoChip(
                      Icons.shopping_cart,
                      '${order.items.length} items',
                    ),
                    _infoChip(
                      Icons.payment,
                      formatOrderPaymentSummary(order.paymentMethod),
                    ),
                    _infoChip(
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
                        fct: onEdit,
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
                        fct: onPrint,
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
                        fct: onDelete,
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

  Widget _infoChip(IconData icon, String text) {
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
    final now = DateHelper.now();
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
}
