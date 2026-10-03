import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles used by the shared layouts.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    color: AppColors.heading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const pageTitleCompact = TextStyle(
    color: AppColors.heading,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const pageSubtitle = TextStyle(color: AppColors.muted, fontSize: 13);

  static const sectionTitle = TextStyle(
    color: AppColors.heading,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const sectionHint = TextStyle(color: AppColors.muted, fontSize: 11);

  static const label = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const value = TextStyle(
    color: AppColors.heading,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: AppColors.body,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const input = TextStyle(
    color: AppColors.heading,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const tableHeader = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
  );

  static const button = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  static const caption = TextStyle(
    color: AppColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// [style] on top of the theme's body text, so it keeps the app font.
  ///
  /// Needed wherever Material uses a style as-is instead of merging it with
  /// the theme: a button's `textStyle`, `DropdownButton.style`.
  static TextStyle themed(BuildContext context, TextStyle style) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .merge(style);
}
