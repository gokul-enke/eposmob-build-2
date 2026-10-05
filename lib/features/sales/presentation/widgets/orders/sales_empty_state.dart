import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SalesEmptyState extends StatelessWidget {
  const SalesEmptyState(
      {super.key,
      required this.isOnlineSales,
      required this.hasActiveFilters,
      required this.onReset,
      required this.hasUnmatchedOrders});
  final bool isOnlineSales, hasActiveFilters, hasUnmatchedOrders;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final hasFilters = hasActiveFilters;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 40, color: ColorManager.kPrimaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              hasUnmatchedOrders
                  ? (isOnlineSales
                      ? 'sales.no_online_orders'.tr
                      : 'sales.no_orders_match_filters'.tr)
                  : 'sales.no_orders_available'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.20,
                ColorManager.kTitleTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'sales.try_adjusting_filters'.tr
                  : 'sales.orders_appear_here'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.10,
                ColorManager.kGreyColor,
              ),
            ),
            if (hasFilters)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CustomRoundButton(
                  title: 'sales.reset_filters'.tr,
                  boxColor: ColorManager.kPrimaryColor,
                  textColor: Colors.white,
                  fct: onReset,
                  height: 44,
                  width: 180,
                  fontSize: FontSize.s12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
