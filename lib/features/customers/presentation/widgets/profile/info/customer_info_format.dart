import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Translated display text for the fields on the customer info tab.
abstract final class CustomerInfoFormat {
  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  /// [value], or "Not provided" when it is null or blank.
  static String orNotProvided(String? value) =>
      _has(value) ? value! : 'customer_profile.view_msg_not_provided'.tr;

  /// [value], or "Not available" when it is null or blank.
  static String orNotAvailable(String? value) =>
      _has(value) ? value! : 'customer_profile.view_msg_not_available'.tr;

  static String amount(num? value) => (value ?? 0).toStringAsFixed(2);

  /// Known genders are translated; anything else is shown capitalised.
  static String gender(String? value) {
    if (!_has(value)) return 'customer_profile.view_msg_not_provided'.tr;
    final trimmed = value!.trim();
    return switch (trimmed.toLowerCase()) {
      'male' => 'customer_profile.gender_male'.tr,
      'female' => 'customer_profile.gender_female'.tr,
      'other' => 'customer_profile.gender_other'.tr,
      _ => trimmed[0].toUpperCase() + trimmed.substring(1),
    };
  }

  /// `d/m/yyyy`, or "Not available".
  static String memberSince(DateTime? createdAt) => createdAt == null
      ? 'customer_profile.view_msg_not_available'.tr
      : '${createdAt.day}/${createdAt.month}/${createdAt.year}';

  static String paymentType(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'to_pay' => 'customer_profile.field_payment_to_pay'.tr,
        'to_receive' => 'customer_profile.field_payment_to_receive'.tr,
        _ => 'customer_profile.view_msg_not_set'.tr,
      };

  static Color paymentTypeColor(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'to_pay' => AppColors.amber,
        'to_receive' => AppColors.green,
        _ => AppColors.muted,
      };

  /// Green for credits, red for debits, muted otherwise.
  static Color transactionColor(String? type) =>
      switch (type?.trim().toLowerCase()) {
        'credit' => AppColors.green,
        'debit' => AppColors.red,
        _ => AppColors.muted,
      };

  static IconData transactionIcon(String? type) =>
      switch (type?.trim().toLowerCase()) {
        'credit' => Icons.arrow_upward,
        'debit' => Icons.arrow_downward,
        _ => Icons.swap_horiz,
      };
}
