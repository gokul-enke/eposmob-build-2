import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sales_services.dart';

/// A never-sent sale has no server copy, so it can be deleted outright.
bool localSaleCanDelete(LocalSaleSyncRecord? record) =>
    record == null || record.isUnsentLegacy;

/// A sale that may have reached the server is only taken off the list.
bool localSaleCanDismiss(LocalSaleSyncRecord? record) =>
    record != null && !localSaleCanDelete(record) && record.canRetry;

bool localSaleCanRemove(LocalSaleSyncRecord? record) =>
    localSaleCanDelete(record) || localSaleCanDismiss(record);

/// Removes several orders from Sync attention after one confirmation, e.g.
/// sales the server already has (HTTP 409 receipt conflict) because an
/// earlier response was lost. Sales that may be on the server are only
/// dismissed: their record and sync log stay on this device and they are
/// never sent again. Never-sent sales are deleted. Returns the ids removed.
Future<Set<String>> confirmAndRemoveLocalSales(BuildContext context,
    List<SavedOrder> orders, LocalSalesServices services) async {
  final sync = services.sync;
  final removable = orders
      .where((order) =>
          !sync.isSubmitting(order.id) &&
          localSaleCanRemove(sync.recordFor(order.id)))
      .toList();
  if (removable.isEmpty) return const {};
  final deleteCount = removable
      .where((order) => localSaleCanDelete(sync.recordFor(order.id)))
      .length;
  final dismissCount = removable.length - deleteCount;
  final kept = orders.length - removable.length;
  final single = removable.length == 1;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var checked = false;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(single
                  ? 'Remove 1 order from the list?'
                  : 'Remove ${removable.length} orders from the list?'),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    single
                        ? 'It will no longer appear here and will never be sent to the server again.'
                        : 'They will no longer appear here and will never be sent to the server again.',
                    style: const TextStyle(
                        color: Color(0xFF334155), height: 1.45)),
                const SizedBox(height: 10),
                if (dismissCount > 0)
                  _Bullet(dismissCount == 1
                      ? '1 order was sent before. Its details and sync log stay saved on this device.'
                      : '$dismissCount orders were sent before. Their details and sync logs stay saved on this device.'),
                if (deleteCount > 0)
                  _Bullet(deleteCount == 1
                      ? '1 order was never sent and is deleted from this device.'
                      : '$deleteCount orders were never sent and are deleted from this device.'),
                if (kept > 0)
                  _Bullet(kept == 1
                      ? '1 selected order is waiting to send and is kept.'
                      : '$kept selected orders are waiting to send and are kept.'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('confirm-remove-checked'),
                  value: checked,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setDialogState(() => checked = value ?? false),
                  title: const Text(
                      'I checked Sales and these orders are already there, or I handled them another way.',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel-remove-orders'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-remove-orders'),
              onPressed:
                  checked ? () => Navigator.of(dialogContext).pop(true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              child: Text(single ? 'Remove' : 'Remove ${removable.length}'),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true || !context.mounted) return const {};

  final removed = <String>{};
  final deleted = <String>{};
  var failed = 0;
  for (final order in removable) {
    try {
      if (localSaleCanDelete(sync.recordFor(order.id))) {
        await sync.remove(order.id);
        deleted.add(order.id);
      } else {
        await sync.dismiss(order.id,
            note: 'Removed by the operator in a bulk action after checking '
                'Sales or handling the sale outside the app.');
      }
      removed.add(order.id);
    } catch (_) {
      failed++;
    }
  }
  if (deleted.isNotEmpty) {
    services.products.deleteConfirmedOrders(deleted);
    await services.products.flushPersistence();
  }
  if (!context.mounted) return removed;
  if (failed == 0) {
    showScaffold(
        context: context,
        message: removed.length == 1
            ? '1 order was removed from the list.'
            : '${removed.length} orders were removed from the list.');
  } else {
    showScaffoldError(
        context: context,
        message: '${removed.length} removed, $failed could not be removed. '
            'Check them and try again.');
  }
  return removed;
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: Icon(Icons.circle, size: 5, color: Color(0xFF64748B)),
          ),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Color(0xFF475569), fontSize: 13, height: 1.45))),
        ]),
      );
}
