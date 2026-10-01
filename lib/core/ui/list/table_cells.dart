import 'package:flutter/material.dart';

import '../buttons/app_buttons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';

/// Ready-made cells for [AppDataTable] columns, so pages don't rebuild the
/// same padding and text styles.
abstract final class TableCells {
  static const _padding = EdgeInsets.symmetric(vertical: 13, horizontal: 14);

  static Widget text(
    String value, {
    Color? color,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: _padding,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          color: color ?? AppColors.body,
          fontSize: 13,
          fontWeight: weight,
        ),
      ),
    );
  }

  /// Muted, centered row number.
  static Widget number(int value) =>
      text('$value', color: AppColors.muted, align: TextAlign.center);

  /// Two-decimal amount: green when ≥ 0, red when negative.
  static Widget amount(num value) => text(
        value.toStringAsFixed(2),
        color: AppColors.amount(value),
        weight: FontWeight.w700,
      );

  /// [avatar] (usually an `AppAvatar` of size 36) followed by a bold name.
  static Widget avatarName({required String name, required Widget avatar}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.heading,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Left-aligned arbitrary widget (badge, chip).
  static Widget widget(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );
  }

  /// Compact bordered action button.
  static Widget action({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: AppOutlinedButton(
          label: label,
          icon: icon,
          iconSize: 15,
          height: AppSizes.compactControl,
          radius: AppRadius.tile,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
