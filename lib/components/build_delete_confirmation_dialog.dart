import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String? title;
  final String itemName;
  final String? message;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;
  final String? deleteButtonText;
  final String? cancelButtonText;
  final IconData? warningIcon;
  final Color? warningIconColor;
  final Color? deleteButtonColor;
  final Color? backgroundColor;
  final bool showCloseButton;
  final bool barrierDismissible;
  final Widget? customContent;
  final String? subtitle;

  const DeleteConfirmationDialog({
    Key? key,
    this.title,
    required this.itemName,
    this.message,
    required this.onDelete,
    this.onCancel,
    this.deleteButtonText,
    this.cancelButtonText,
    this.warningIcon = Icons.warning_amber_rounded,
    this.warningIconColor = ColorManager.kButtonRed,
    this.deleteButtonColor = ColorManager.kButtonRed,
    this.backgroundColor = Colors.white,
    this.showCloseButton = true,
    this.barrierDismissible = true,
    this.customContent,
    this.subtitle,
  }) : super(key: key);

  /// Show a delete confirmation dialog with full customization options
  static Future<bool?> show({
    required BuildContext context,
    String? title,
    required String itemName,
    String? message,
    required VoidCallback onDelete,
    VoidCallback? onCancel,
    String? deleteButtonText,
    String? cancelButtonText,
    IconData? warningIcon = Icons.warning_amber_rounded,
    Color? warningIconColor = ColorManager.kButtonRed,
    Color? deleteButtonColor = ColorManager.kButtonRed,
    Color? backgroundColor = Colors.white,
    bool showCloseButton = true,
    bool barrierDismissible = true,
    Widget? customContent,
    String? subtitle,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          title: title ?? 'general.delete_item'.tr,
          itemName: itemName,
          message: message ?? 'general.delete_warning'.tr,
          onDelete: onDelete,
          onCancel: onCancel,
          deleteButtonText: deleteButtonText ?? 'general.delete'.tr,
          cancelButtonText: cancelButtonText ?? 'general.cancel'.tr,
          warningIcon: warningIcon,
          warningIconColor: warningIconColor,
          deleteButtonColor: deleteButtonColor,
          backgroundColor: backgroundColor,
          showCloseButton: showCloseButton,
          barrierDismissible: barrierDismissible,
          customContent: customContent,
          subtitle: subtitle,
        );
      },
    );
  }

  /// Show a quick delete dialog with minimal parameters for convenience
  static Future<bool?> showQuick({
    required BuildContext context,
    required String itemName,
    required VoidCallback onDelete,
    String? customMessage,
  }) {
    return show(
      context: context,
      itemName: itemName,
      onDelete: onDelete,
      message: customMessage ?? 'general.delete_warning'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: backgroundColor,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? 'general.delete_item'.tr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () {
                      if (onCancel != null) onCancel!();
                      Navigator.of(context).pop(false);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Custom content or default warning message
            if (customContent != null)
              customContent!
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Column(
                  children: [
                    if (warningIcon != null)
                      Icon(
                        warningIcon!,
                        color: warningIconColor,
                        size: 32,
                      ),
                    if (warningIcon != null) const SizedBox(height: 8),
                    Text(
                      'general.confirm_delete_item'.trParams({
                        'item': itemName,
                      }),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message ?? 'general.delete_warning'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButton(
                  fct: () {
                    if (onCancel != null) onCancel!();
                    Navigator.pop(context, false);
                  },
                  title: cancelButtonText ?? 'general.cancel'.tr,
                  height: 40,
                  width: 100,
                  fontSize: 14,
                  borderColor: Colors.grey,
                  boxColor: Colors.white,
                  textColor: Colors.grey[700]!,
                ),
                const SizedBox(width: 12),
                CustomRoundButton(
                  fct: () {
                    onDelete();
                    Navigator.pop(context, true);
                  },
                  title: deleteButtonText ?? 'general.delete'.tr,
                  height: 40,
                  width: 100,
                  fontSize: 14,
                  borderColor: deleteButtonColor,
                  boxColor: deleteButtonColor,
                  textColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 