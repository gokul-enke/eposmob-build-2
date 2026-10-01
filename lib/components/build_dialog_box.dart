import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

// Messages and the loading overlay come from the UI kit through the shared
// compatibility layer, so the whole app shows one message at a time with one
// position setting. New code should use AppToast / AppLoadingOverlay from
// package:pos_machine/core/ui/ui.dart.
export '../newcomponents/custom_dialog_box.dart'
    show
        hideLoadingOverlay,
        setNotificationPosition,
        showLoadingOverlay,
        showScaffold,
        showScaffoldError;

/// Confirmation prompt used when a sale would normally be blocked (e.g. the
/// system says stock is short but the physical product is in front of the
/// cashier). Returns true when the user chooses to proceed with the sale.
Future<bool> showSellAnywayConfirmDialog({
  required BuildContext context,
  required String message,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  title ??= 'general.stock_mismatch'.tr;
  confirmLabel ??= 'general.sell_anyway'.tr;
  cancelLabel ??= 'general.cancel'.tr;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title!,
        style: buildCustomStyle(
            FontWeightManager.semiBold, FontSize.s16, 0.12, Colors.black),
      ),
      content: Text(
        message,
        style: buildCustomStyle(
            FontWeightManager.regular, FontSize.s13, 0.12, Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            cancelLabel!,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                0.12, Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel!,
            style: buildCustomStyle(
                FontWeightManager.medium, FontSize.s13, 0.12, Colors.white),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
