import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// The one input look used by filters and forms: filled white, 10 px
/// radius, hairline border, primary-colour focus border.
abstract final class AppInputDecoration {
  static const _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
    borderSide: BorderSide(color: AppColors.border),
  );

  static InputDecoration of({
    String? label,
    String? hint,
    IconData? icon,
    Widget? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      suffixIcon: suffix,
      labelStyle: AppTextStyles.label.copyWith(fontSize: 12),
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
      prefixIconColor: AppColors.muted,
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: _border,
      enabledBorder: _border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: AppColors.red, width: 1.5),
      ),
    );
  }

  /// Single-line filter input: exactly [AppSizes.control] tall whatever the
  /// field type (a dropdown's arrow otherwise makes it taller than a text
  /// field), with the label always floated so every field reads the same.
  static InputDecoration filter({
    String? label,
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return of(label: label, hint: hint, icon: icon, suffix: suffix).copyWith(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      constraints: const BoxConstraints.tightFor(height: AppSizes.control),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
