import 'package:flutter/material.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'build_legacy_sale_request.dart';
import 'local_sales_services.dart';

/// Sales that may already exist on the server, or that have no duplicate
/// protection, must be checked against the backend Sales list before sending.
bool localSaleNeedsVerification(LocalSaleSyncRecord? record) =>
    record == null ||
    record.state == LocalSaleSyncState.needsReview ||
    record.isUnsentLegacy;

Future<bool> confirmSyncLocalSales(BuildContext context,
    List<SavedOrder> orders, LocalSalesServices services) async {
  final records = [for (final order in orders) services.sync.recordFor(order.id)];
  final reviewCount = records.where(localSaleNeedsVerification).length;
  final rejected = records
      .where((record) => record?.state == LocalSaleSyncState.rejected)
      .toList();
  final single = orders.length == 1;
  final rejectedMessage =
      single && rejected.length == 1 ? rejected.single?.message : null;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(single
              ? 'Sync order #${orders.single.orderNumber}?'
              : 'Sync ${orders.length} orders?'),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      single
                          ? 'The order will be sent once using its current saved request. You can edit the JSON before syncing.'
                          : 'Each order will be sent once using its current saved request. You can edit the JSON before syncing.',
                      style: const TextStyle(
                          color: Color(0xFF334155), height: 1.45)),
                  if (reviewCount > 0)
                    _Notice(
                        key: const ValueKey('bulk-sync-verify-notice'),
                        color: const Color(0xFF9A5B07),
                        background: const Color(0xFFFFF7E8),
                        icon: Icons.warning_amber_rounded,
                        text: single
                            ? 'Check the backend Sales list first and sync only if this order is absent. Retrying an existing sale can create a duplicate.'
                            : '$reviewCount order${reviewCount == 1 ? '' : 's'} need verification. Check the backend Sales list first and sync only orders that are absent. Retrying an existing sale can create a duplicate.'),
                  if (rejected.isNotEmpty)
                    _Notice(
                        key: const ValueKey('bulk-sync-rejected-notice'),
                        color: const Color(0xFFB42318),
                        background: const Color(0xFFFEF3F2),
                        icon: Icons.error_outline,
                        text: rejectedMessage?.isNotEmpty == true
                            ? 'Last rejection: $rejectedMessage\nFix the cause on the server or edit the JSON first, otherwise it will be rejected again.'
                            : '${rejected.length} order${rejected.length == 1 ? ' was' : 's were'} rejected before. Fix the cause or edit the JSON first, otherwise they will be rejected again.'),
                  if (!single) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Orders that are already sending or resolved will be skipped.',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            height: 1.45)),
                  ],
                ]),
          ),
          actions: [
            TextButton(
                key: const ValueKey('cancel-bulk-sync'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                key: const ValueKey('confirm-bulk-sync'),
                style: FilledButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(reviewCount > 0
                    ? 'Verified — Sync'
                    : single
                        ? 'Sync order'
                        : 'Sync orders')),
          ],
        ),
      ) ??
      false;
}

class _Notice extends StatelessWidget {
  const _Notice(
      {super.key,
      required this.color,
      required this.background,
      required this.icon,
      required this.text});

  final Color color, background;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 13, height: 1.45))),
        ]),
      );
}

Future<LocalSaleBatchResult> syncVerifiedLocalSales(
  BuildContext context,
  List<SavedOrder> orders,
  LocalSalesServices services, {
  required void Function(int completed, int total) onProgress,
}) {
  // Build legacy bodies before asynchronous work so no disposed context is used
  // when a batch keeps running after the operator navigates away.
  final legacyPayloads = <String, Map<String, dynamic>>{};
  final legacyErrors = <String, Object>{};
  for (final order in orders) {
    if (services.sync.recordFor(order.id) == null) {
      try {
        legacyPayloads[order.id] =
            buildLegacySaleRequest(context, order, services);
      } catch (error) {
        legacyErrors[order.id] = error;
      }
    }
  }
  final byId = {for (final order in orders) order.id: order};
  return services.sync.syncAfterVerification(
    localOrderIds: byId.keys,
    accessToken: services.auth.token ?? '',
    onProgress: onProgress,
    prepareSale: (id) async {
      if (legacyErrors.containsKey(id)) throw legacyErrors[id]!;
      final order = byId[id]!;
      await services.sync.enqueue(
          localOrderId: id,
          localOrderNumber: order.orderNumber,
          sourceCartSessionId: id,
          surface: LocalSaleSurface.legacy,
          payload: legacyPayloads[id]!);
    },
  );
}
