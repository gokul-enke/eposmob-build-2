import 'package:flutter/material.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import '../navigation/sales_navigation.dart';

/// Confirmed sales on this device that have not reached the server and were
/// not dismissed by the operator — exactly what Sync attention lists.
List<SavedOrder> localSalesNeedingSync(
        LocalProductProvider products, LocalSaleSyncService sync) =>
    products.confirmedOrders.where((order) {
      final record = sync.recordFor(order.id);
      return record?.state != LocalSaleSyncState.synced &&
          record?.isDismissed != true;
    }).toList();

/// Warns before Day Close when sales are still waiting in Sync attention.
/// Returns true when Day Close should continue.
Future<bool> confirmDayCloseWithUnsyncedSales(BuildContext context) async {
  final pending = localSalesNeedingSync(
          context.read<LocalProductProvider>(),
          context.read<LocalSaleSyncService>())
      .length;
  if (pending == 0) return true;
  final orders = pending == 1 ? '1 order has' : '$pending orders have';
  final choice = await showDialog<_UnsyncedChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Color(0xFFB54708)),
          SizedBox(width: 10),
          Expanded(child: Text('Sync orders before Day Close?')),
        ],
      ),
      content: Text(
        '$orders not been synced to the server yet. Sync them on the '
        'Confirmed Orders page before closing the day, otherwise they will '
        'be missing from this day close.',
        style: const TextStyle(color: Color(0xFF334155)),
      ),
      actions: [
        TextButton(
          key: const ValueKey('day-close-unsynced-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('day-close-unsynced-continue'),
          onPressed: () =>
              Navigator.of(dialogContext).pop(_UnsyncedChoice.closeAnyway),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
          child: const Text('Close anyway'),
        ),
        FilledButton(
          key: const ValueKey('day-close-unsynced-review'),
          onPressed: () =>
              Navigator.of(dialogContext).pop(_UnsyncedChoice.review),
          child: const Text('Go to Confirmed Orders'),
        ),
      ],
    ),
  );
  if (choice == _UnsyncedChoice.review) SalesNavigation.openConfirmed();
  return choice == _UnsyncedChoice.closeAnyway;
}

enum _UnsyncedChoice { review, closeAnyway }
