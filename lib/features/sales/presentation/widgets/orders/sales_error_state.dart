import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SalesErrorState extends StatelessWidget {
  const SalesErrorState(
      {super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.cloud_off_outlined,
                  size: 40, color: ColorManager.kPrimaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              message,
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
              'sales.orders_load_failed_hint'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.10,
                ColorManager.kGreyColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CustomRoundButton(
                title: 'sales.retry'.tr,
                boxColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
                fct: onRetry,
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
