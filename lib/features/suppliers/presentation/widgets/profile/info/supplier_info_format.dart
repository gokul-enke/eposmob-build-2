import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Display text and colours for supplier profile fields.
abstract final class SupplierInfoFormat {
  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  /// The value, or "Not provided" when blank.
  static String orNotProvided(String? value) =>
      _blank(value) ? 'supplier_profile.not_provided'.tr : value!;

  /// The value, or "N/A" when blank.
  static String orNa(String? value) => _blank(value) ? 'general.na'.tr : value!;

  /// The supplier's name, or the "Supplier Name" placeholder when blank.
  static String name(String? value) =>
      _blank(value) ? 'supplier_profile.label_supplier_name'.tr : value!;

  static String id(int id) => '${'supplier_profile.id_prefix'.tr}$id';

  static String amount(double value) => value.toStringAsFixed(2);

  /// `to_pay` / `to_receive` as their translated labels; anything else as is.
  static String paymentType(String? value) => switch (value) {
        'to_pay' => 'supplier_profile.edit_radio_to_pay'.tr,
        'to_receive' => 'supplier_profile.edit_radio_to_receive'.tr,
        _ => orNa(value),
      };

  /// Red when the business owes the supplier, green when it is owed.
  static Color balanceStatusColor(String? paymentType) => switch (paymentType) {
        'to_pay' => AppColors.red,
        'to_receive' => AppColors.green,
        _ => AppColors.heading,
      };
}
