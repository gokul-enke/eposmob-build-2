import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Top app-bar row of the mobile Home tab: order label, keyboard toggle, sync,
/// connectivity indicator and the product-grid button. Extracted verbatim from
/// `home_tab.dart`'s header `Row`.
class MobileHomeAppBar extends StatelessWidget {
  final VoidCallback onShowGrid;

  const MobileHomeAppBar({super.key, required this.onShowGrid});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: Order label + number (like desktop)
        Consumer<LocalProductProvider>(
          builder: (context, localProductProvider, _) {
            final isEditingOrder = localProductProvider.currentOrder != null;
            final orderNumber = isEditingOrder
                ? '#${localProductProvider.currentOrder!.orderNumber}'
                : '#00000';
            return Row(
              children: [
                Text(
                  isEditingOrder ? 'Edit - ' : 'New - ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            );
          },
        ),
        const Spacer(),
        // Keyboard toggle
        Consumer<KeyboardProvider>(
          builder: (context, keyboardProvider, _) {
            final showing = keyboardProvider.showKeyboardFeature;
            return IconButton(
              onPressed: () {
                if (showing) {
                  keyboardProvider.featureOff();
                  keyboardProvider.clear();
                } else {
                  keyboardProvider.featureOn();
                }
              },
              icon: Icon(
                showing ? Icons.keyboard_hide : Icons.keyboard,
                color: showing
                    ? ColorManager.kPrimaryColor
                    : Colors.grey.shade600,
              ),
              tooltip: showing ? 'Hide Keyboard' : 'Show Keyboard',
            );
          },
        ),
        // Sync button
        const SyncButton(
          showTooltip: true,
          showText: false,
        ),
        const SizedBox(width: 4),
        // Connectivity indicator
        _ConnectivityIndicatorMobile(),
        const SizedBox(width: 8),
        // Grid toggle - Show modal instead
        IconButton(
          onPressed: onShowGrid,
          icon: const Icon(
            Icons.grid_view_outlined,
            color: ColorManager.kPrimaryColor,
          ),
          tooltip: 'Show Product Grid',
        ),
      ],
    );
  }
}

class _ConnectivityIndicatorMobile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        final hasNet = billingProvider.hasInternet;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: hasNet
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasNet ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Icon(
            hasNet ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: hasNet ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}
