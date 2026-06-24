import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/controllers/coordinators/payment_coordinator.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_option_button.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/pine_labs_section.dart';

/// Payment-method summary row + change/modify action + Pine Labs button.
/// Extracted verbatim from `billing_tab.dart`'s `_buildPaymentMethodsSection`.
class PaymentMethodsSection extends StatelessWidget {
  const PaymentMethodsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        final selectedMethods =
            provider.getSelectedPaymentMethodsExcludingEmpty();

        // Build a single row styled exactly like Delivery section
        final summaryText = selectedMethods.isEmpty
            ? 'Select Payment Method'
            : selectedMethods.join(', ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => PaymentCoordinator.showPaymentMethodModal(context),
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
                      Icons.payment,
                      color: ColorManager.kPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            summaryText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedMethods.isEmpty
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
            if (selectedMethods.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BillingOptionButton(
                      title: selectedMethods.length > 1
                          ? 'Modify Payment Methods'
                          : 'Change Payment Method',
                      icon: Icons.edit,
                      onTap: () =>
                          PaymentCoordinator.showPaymentMethodModal(context),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const PineLabsSection(),
          ],
        );
      },
    );
  }
}
