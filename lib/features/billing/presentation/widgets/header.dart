import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/keyboard_shortcuts_help_dialog.dart';

class HeaderBar extends StatelessWidget {
  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;
  const HeaderBar(
      {super.key,
      required this.isSidebarVisible,
      required this.onToggleSidebar});

  @override
  Widget build(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: true);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: true).appSettings;
    final bool isEditingOrder = localProductProvider.currentOrder != null;
    final currentOrder = localProductProvider.currentOrder;
    final selectedCustomer = customerSelectionProvider.selectedCustomer;
    final fallbackCustomerName = selectedCustomer?.name ??
        currentOrder?.customerName ??
        currentOrder?.customerPhone;
    final bool showCustomerType = appSettings?.companyB2BEnabled ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditingOrder
                        ? '${'billing.edit_order'.tr} - '
                        : '${'billing.new_order'.tr} - ',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                  Text(
                    isEditingOrder
                        ? '#${localProductProvider.currentOrder!.orderNumber}'
                        : '#00000',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                ],
              ),
              if (fallbackCustomerName != null &&
                  fallbackCustomerName.trim().isNotEmpty)
                _SelectedCustomerDetails(
                  name: fallbackCustomerName,
                  balance: selectedCustomer?.balance,
                  customerType:
                      showCustomerType ? selectedCustomer?.customerType : null,
                ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.help_outline,
                color: Colors.grey.shade600,
              ),
              tooltip: 'billing.keyboard_shortcuts'.tr,
              onPressed: () {
                KeyboardShortcutsHelpDialog.show(context);
              },
            ),
            IconButton(
              icon: Icon(
                Provider.of<KeyboardProvider>(context).showKeyboardFeature
                    ? Icons.keyboard_hide
                    : Icons.keyboard,
                color:
                    Provider.of<KeyboardProvider>(context).showKeyboardFeature
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade600,
              ),
              tooltip:
                  Provider.of<KeyboardProvider>(context).showKeyboardFeature
                      ? 'keyboard.hide'.tr
                      : 'keyboard.show'.tr,
              onPressed: () {
                final keyboardProvider =
                    Provider.of<KeyboardProvider>(context, listen: false);
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

class _SelectedCustomerDetails extends StatelessWidget {
  final String? name;
  final double? balance;
  final String? customerType;

  const _SelectedCustomerDetails({
    required this.name,
    required this.balance,
    required this.customerType,
  });

  @override
  Widget build(BuildContext context) {
    final String displayName = (name == null || name!.trim().isEmpty)
        ? 'billing.customer'.tr
        : name!.trim();
    final String displayBalance = (balance ?? 0).toStringAsFixed(2);
    final String? displayCustomerType = customerType?.trim().isEmpty == true
        ? null
        : customerType?.trim().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            size: 16,
            color: ColorManager.kPrimaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${'billing.balance'.tr}: $displayBalance',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              Colors.grey.shade700,
            ),
          ),
          if (displayCustomerType != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: displayCustomerType == 'B2B'
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: displayCustomerType == 'B2B'
                      ? Colors.green.shade300
                      : Colors.blue.shade300,
                ),
              ),
              child: Text(
                displayCustomerType,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.15,
                  displayCustomerType == 'B2B'
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
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
