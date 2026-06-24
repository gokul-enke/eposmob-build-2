import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/controllers/coordinators/payment_coordinator.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Coupon/discount summary row + applied-discount badge.
/// Extracted verbatim from `billing_tab.dart`'s `_buildCouponSection`.
class CouponSection extends StatelessWidget {
  const CouponSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Coupon Input Button
            GestureDetector(
              onTap: () => PaymentCoordinator.showCouponModal(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer,
                      color: ColorManager.kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Discount / Coupon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            provider.coupenCodeTextController.text.isEmpty
                                ? 'Add or apply coupon'
                                : provider.coupenCodeTextController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  provider.coupenCodeTextController.text.isEmpty
                                      ? Colors.grey.shade700
                                      : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            // Applied Discount Info
            Consumer<LocalProductProvider>(
              builder: (context, localProvider, child) {
                final summary = localProvider.priceSummary;
                if (summary != null &&
                    (summary.flatDiscount > 0 ||
                        summary.percentageDiscount > 0)) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discount Applied: ${(summary.flatDiscount + summary.percentageDiscount).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}
