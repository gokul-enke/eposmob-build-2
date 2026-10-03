import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

Widget expenseDetailsHeader(String refNumber, VoidCallback onBack) {
  return Row(
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, color: ColorManager.textColor),
        onPressed: () {
          onBack(); // Back to list
        },
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'expense.breadcrumb_view'.tr} $refNumber',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'expense.title'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.20,
                  Colors.grey,
                ),
              ),
              const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
              Text(
                refNumber,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.20,
                  Colors.grey,
                ),
              ),
              const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
              Text(
                'expense.breadcrumb_view'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.20,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
