import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

import 'package:pos_machine/helpers/delivery_method_display.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_container_box.dart';

class QuickAccessBar extends StatelessWidget {
  final VoidCallback onShowPaymentMethodModal;
  final VoidCallback onShowDeliveryMethodModal;
  final VoidCallback onShowCouponModal;
  const QuickAccessBar({
    super.key,
    required this.onShowPaymentMethodModal,
    required this.onShowDeliveryMethodModal,
    required this.onShowCouponModal,
  });

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    // Note: Use Consumers below to react to provider changes

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 5),
            Consumer<BillingProvider>(builder: (context, bp, _) {
              return _buildQuickAccessIcon(
                context: context,
                icon: bp.getPaymentIcon(),
                label: bp.getPaymentLabel(),
                color: ColorManager.kPrimaryColor,
                onTap: onShowPaymentMethodModal,
              );
            }),
            const SizedBox(width: 12),
            // Delivery Method Icon
            Consumer<BillingProvider>(builder: (context, bp, _) {
              final dm = bp.deliveryMethod;
              final icon = DeliveryMethodDisplay.iconFor(dm);
              // First word of the localized label — `split(' ')` on the raw
              // name would slice an Arabic label at the wrong place.
              final label = DeliveryMethodDisplay.labelFor(dm);
              return _buildQuickAccessIcon(
                context: context,
                icon: icon,
                label: label.split(' ').first,
                color: ColorManager.kButtonBlue,
                onTap: onShowDeliveryMethodModal,
              );
            }),
            const SizedBox(width: 12),
            // Coupon Icon
            Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                if (appSettingsProvider.appSettings == null ||
                    !(appSettingsProvider.appSettings?.discountAndCoupon ??
                        false)) {
                  return Container();
                }
                return Consumer<BillingProvider>(
                  builder: (context, billingProvider, child) {
                    return _buildQuickAccessIcon(
                      context: context,
                      icon: billingProvider.isCouponApplied
                          ? Icons.discount
                          : Icons.local_offer_outlined,
                      label: billingProvider.isCouponApplied
                          ? 'billing.applied_label'.tr
                          : 'billing.discount'.tr,
                      color: billingProvider.isCouponApplied
                          ? ColorManager.kButtonGreen
                          : ColorManager.kButtonYellow,
                      onTap: onShowCouponModal,
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Payment Summary in minimized view
        Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: Consumer<BillingProvider>(
            builder: (context, bp, _) {
              final double totalPaid = bp.getTotalPaidAmount();
              final double balance = bp.balanceAmount;
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${'billing.total_paid'.tr}: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s15,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        '$currency ${totalPaid.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.14,
                          ColorManager.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text(
                        '${'billing.balance'.tr}: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s15,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        '$currency ${balance.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s15,
                          0.14,
                          balance > 0
                              ? ColorManager.kButtonGreen
                              : ColorManager.textColorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessIcon({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        blurRadius: 4,
        circleRadius: 5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.14,
                color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
