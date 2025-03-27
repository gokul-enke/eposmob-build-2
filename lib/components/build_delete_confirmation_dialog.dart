import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String itemName;
  final String message;
  final VoidCallback onDelete;
  final String deleteButtonText;
  final String cancelButtonText;

  const DeleteConfirmationDialog({
    Key? key,
    this.title = "Delete Item",
    required this.itemName,
    this.message = "This action cannot be undone.",
    required this.onDelete,
    this.deleteButtonText = "Delete",
    this.cancelButtonText = "Cancel",
  }) : super(key: key);

  static Future<bool?> show({
    required BuildContext context,
    String title = "Delete Item",
    required String itemName,
    String message = "This action cannot be undone.",
    required VoidCallback onDelete,
    String deleteButtonText = "Delete",
    String cancelButtonText = "Cancel",
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          title: title,
          itemName: itemName,
          message: message,
          onDelete: onDelete,
          deleteButtonText: deleteButtonText,
          cancelButtonText: cancelButtonText,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: ColorManager.kButtonRed,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Are you sure you want to delete '$itemName'?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
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
                  fct: () => Navigator.pop(context, false),
                  title: cancelButtonText,
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
                  title: deleteButtonText,
                  height: 40,
                  width: 100,
                  fontSize: 14,
                  borderColor: ColorManager.kButtonRed,
                  boxColor: ColorManager.kButtonRed,
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