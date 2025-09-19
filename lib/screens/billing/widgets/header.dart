import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class HeaderBar extends StatelessWidget {
  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;
  const HeaderBar({super.key, required this.isSidebarVisible, required this.onToggleSidebar});

  @override
  Widget build(BuildContext context) {
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: true);
    final bool isEditingOrder = localProductProvider.currentOrder != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              isEditingOrder ? 'Edit Order - ' : 'New Order - ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
            Text(
              isEditingOrder ? '#${localProductProvider.currentOrder!.orderNumber}' : '#00000',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                Provider.of<KeyboardProvider>(context).showKeyboardFeature
                    ? Icons.keyboard_hide
                    : Icons.keyboard,
                color: Provider.of<KeyboardProvider>(context).showKeyboardFeature
                    ? ColorManager.kPrimaryColor
                    : Colors.grey.shade600,
              ),
              tooltip: Provider.of<KeyboardProvider>(context).showKeyboardFeature
                  ? 'Hide Keyboard'
                  : 'Show Keyboard',
              onPressed: () {
                final keyboardProvider = Provider.of<KeyboardProvider>(context, listen: false);
                if (keyboardProvider.showKeyboardFeature) {
                  keyboardProvider.featureOff();
                  keyboardProvider.clear();
                } else {
                  keyboardProvider.featureOn();
                }
              },
            ),
            const SyncButton(
              showTooltip: true,
              showText: false,
            ),
            const SizedBox(width: 0),
            const _ConnectivityIndicator(),
            if (!isSidebarVisible) ...[
              const SizedBox(width: 12),
              CustomRoundButton(
                title: "☰",
                fct: onToggleSidebar,
                fontSize: 16,
                height: 32,
                width: 32,
                boxColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
                radius: 8,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ConnectivityIndicator extends StatelessWidget {
  const _ConnectivityIndicator();
  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: billingProvider.hasInternet
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: billingProvider.hasInternet ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                billingProvider.hasInternet ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: billingProvider.hasInternet ? Colors.green : Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }
}
