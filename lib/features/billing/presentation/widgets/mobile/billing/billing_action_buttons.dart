import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Persistent bottom action bar for the mobile Billing tab (Save / Print /
/// Confirm). Extracted verbatim from `billing_tab.dart`'s `bottomSheet`.
class BillingActionButtons extends StatelessWidget {
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final bool isConfirmingOrder;

  const BillingActionButtons({
    super.key,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    required this.isConfirmingOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Save Order
          Expanded(
            child: CustomRoundButton(
              title: "Save Order",
              fct: onSaveOrder,
              fontSize: 14,
              height: 48,
              width: double.infinity,
              boxColor: Colors.orange.shade50,
              borderColor: Colors.orange.shade300,
              textColor: Colors.orange.shade700,
              radius: 12,
            ),
          ),
          const SizedBox(width: 12),
          // Print Order
          Expanded(
            child: CustomRoundButton(
              title: "Print Order",
              fct: onCreateOrderAndPrint,
              fontSize: 14,
              height: 48,
              width: double.infinity,
              boxColor: Colors.blue.shade50,
              borderColor: Colors.blue.shade300,
              textColor: Colors.blue.shade700,
              radius: 12,
            ),
          ),
          const SizedBox(width: 12),
          // Confirm Order
          Expanded(
            child: Consumer<LocalProductProvider>(
              builder: (context, provider, child) {
                final hasItems = provider.cartItems.isNotEmpty;
                return CustomRoundButton(
                  title: "Confirm Order",
                  fct: hasItems ? onConfirmOrder : () {},
                  fontSize: 14,
                  height: 48,
                  width: double.infinity,
                  boxColor: hasItems
                      ? ColorManager.kPrimaryColor
                      : Colors.grey.shade300,
                  borderColor: hasItems
                      ? ColorManager.kPrimaryColor
                      : Colors.grey.shade300,
                  textColor: hasItems ? Colors.white : Colors.grey.shade600,
                  radius: 12,
                  isLoading: isConfirmingOrder,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
