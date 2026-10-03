import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

Widget expenseDetailItem(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.1,
          Colors.grey,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s13,
          0.1,
          ColorManager.textColor,
        ),
      ),
    ],
  );
}

Widget expenseDetailItemWithBadge(
    String label, String value, Color badgeBg, Color badgeText) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.1,
          Colors.grey,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: badgeText,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
