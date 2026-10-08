import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sale_sync_badge.dart';

class LocalSaleAttentionCard extends StatelessWidget {
  final SavedOrder order;
  final LocalSaleSyncRecord? syncRecord;
  final String currency;
  final VoidCallback onView;
  final VoidCallback onRetryLegacy;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;
  final VoidCallback onLog;
  final VoidCallback onPrint;
  const LocalSaleAttentionCard(
      {super.key,
      required this.order,
      required this.syncRecord,
      required this.currency,
      required this.onView,
      required this.onRetryLegacy,
      required this.onRetry,
      required this.onDismiss,
      required this.onDelete,
      required this.onLog,
      required this.onPrint});
  @override
  Widget build(BuildContext context) {
    final isRetryable = syncRecord?.canRetry ?? false;
    final isRejected = syncRecord?.state == LocalSaleSyncState.rejected;
    final guidance = switch (syncRecord?.state) {
      LocalSaleSyncState.needsReview =>
        'Check Sales first. Retry only when this order is not there.',
      LocalSaleSyncState.queued =>
        'Saved safely on this device. The first server attempt is waiting.',
      LocalSaleSyncState.sending =>
        'Saved safely on this device. Waiting for the server response.',
      LocalSaleSyncState.rejected => syncRecord?.message?.isNotEmpty == true
          ? 'Rejected: ${syncRecord!.message}'
          : 'The server rejected this sale. Open details before taking action.',
      _ => 'This local sale needs your attention.',
    };

    return Semantics(
      button: true,
      label: 'Review sale ${order.orderNumber}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onView(),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF4D8A8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${order.orderNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F3D75),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 19),
                        tooltip: 'Print receipt',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onPrint(),
                        color: ColorManager.kPrimaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LocalSaleSyncBadge(record: syncRecord),
                  const SizedBox(height: 10),
                  Text(
                    guidance,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_formatDateTime(order.createdAt)} · ${_formatTime(order.createdAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$currency${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: ColorManager.kPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        Expanded(
                          child: isRetryable
                              ? FilledButton.icon(
                                  onPressed: () => onRetry(),
                                  icon: const Icon(Icons.replay, size: 17),
                                  // One line on narrow cards; the dialog
                                  // explains what "review" means.
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      isRejected ? 'Retry' : 'Review & retry',
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isRejected
                                        ? const Color(0xFFB42318)
                                        : const Color(0xFFB45309),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                )
                              : syncRecord == null
                                  ? FilledButton.icon(
                                      onPressed: () => onRetryLegacy(),
                                      icon: const Icon(Icons.replay, size: 17),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Review & retry',
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFB45309),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () => onView(),
                                      icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 17),
                                      label: const Text('View details'),
                                      style: _secondaryButtonStyle,
                                    ),
                        ),
                        if (syncRecord != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => onLog(),
                            icon: const Icon(Icons.receipt_long_outlined,
                                size: 17),
                            label: Text('Log (${syncRecord!.attempts.length})'),
                            style: _secondaryButtonStyle,
                          ),
                        ],
                        if (syncRecord == null) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'View details',
                            child: OutlinedButton(
                              onPressed: () => onView(),
                              style: _secondaryButtonStyle.copyWith(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(horizontal: 10),
                                ),
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(40, 38),
                                ),
                              ),
                              child: const Icon(Icons.visibility_outlined,
                                  size: 19),
                            ),
                          ),
                        ],
                        if (isRetryable || syncRecord == null) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: syncRecord == null
                                ? 'Delete this local order'
                                : 'Remove from this list',
                            child: OutlinedButton(
                              onPressed: () =>
                                  syncRecord == null ? onDelete() : onDismiss(),
                              style: _secondaryButtonStyle.copyWith(
                                foregroundColor: const WidgetStatePropertyAll(
                                  Color(0xFFB42318),
                                ),
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(horizontal: 10),
                                ),
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(40, 38),
                                ),
                              ),
                              child: const Icon(Icons.delete_outline, size: 19),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String isoDateString) {
    return DateHelper.formatToISODateOnlyFromISO(isoDateString);
  }

  String _formatTime(String isoDateString) {
    return DateHelper.formatToISODateFromIST(isoDateString);
  }

  static final ButtonStyle _secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF334155),
    side: const BorderSide(color: Color(0xFFCBD5E1)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
  );
}
