import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sales_services.dart';

Future<void> confirmAndDismissLocalSale(
    BuildContext context, SavedOrder order, LocalSalesServices services) async {
  final saleSync = services.sync;
  final record = saleSync.recordFor(order.id);
  if (record == null) return;
  final isRejected = record.state == LocalSaleSyncState.rejected;
  final (checkLabel, note) = isRejected
      ? (
          'I have handled this rejected sale another way (for example, '
              're-entered it or refunded the customer).',
          'Rejected sale removed by the operator after handling it outside '
              'the app.',
        )
      : (
          'I checked the admin panel and this order is already there.',
          'Removed by the operator after verifying the order exists in the '
              'admin panel.',
        );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var checked = false;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Color(0xFFB42318)),
              SizedBox(width: 10),
              Text('Remove this sale from the list?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.orderNumber} will no longer appear here and '
                'will never be sent to the server again. Its details and '
                'sync log stay saved on this device.',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: checked,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) =>
                    setDialogState(() => checked = value ?? false),
                title: Text(
                  checkLabel,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  checked ? () => Navigator.of(dialogContext).pop(true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await saleSync.dismiss(order.id, note: note);
    if (!context.mounted) return;
    showScaffold(
      context: context,
      message: 'Order #${order.orderNumber} was removed from the list.',
    );
  } on StateError catch (error) {
    if (!context.mounted) return;
    showScaffoldError(context: context, message: error.message.toString());
  }
}
