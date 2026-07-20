import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';

typedef OversellApprovalPrompt = Future<bool> Function({
  required BuildContext context,
  required GetProduct product,
  required num availableQuantity,
  required num requestedQuantity,
  required String unitLabel,
});

Future<bool> showOversellApprovalDialog({
  required BuildContext context,
  required GetProduct product,
  required num availableQuantity,
  required num requestedQuantity,
  required String unitLabel,
}) async {
  if (!context.mounted) return false;

  final available = availableQuantity < 0 ? 0 : availableQuantity;
  final productName = product.productName?.trim().isNotEmpty == true
      ? product.productName!.trim()
      : 'This product';
  final message = available <= 0
      ? '$productName is out of stock (0 available). '
          'Do you want to approve this oversell?'
      : 'Only $available $unitLabel available, but '
          '$requestedQuantity requested. Do you want to approve this oversell?';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Oversell approval required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Approve & Add to Cart'),
        ),
      ],
    ),
  );

  return result ?? false;
}
