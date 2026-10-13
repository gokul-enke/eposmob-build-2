import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sale_sync_badge.dart';

class LocalSaleAttentionCard extends StatelessWidget {
  const LocalSaleAttentionCard({
    super.key,
    required this.order,
    required this.syncRecord,
    required this.currency,
    required this.selected,
    required this.onSelectionChanged,
    required this.onView,
    required this.onSync,
    required this.onEdit,
    required this.onDismiss,
    required this.onDelete,
    required this.onLog,
    required this.onPrint,
    this.actionsEnabled = true,
  });

  final SavedOrder order;
  final LocalSaleSyncRecord? syncRecord;
  final String currency;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback onView,
      onSync,
      onEdit,
      onDismiss,
      onDelete,
      onLog,
      onPrint;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final record = syncRecord;
    final sending = record?.state == LocalSaleSyncState.sending;
    final canAct = actionsEnabled && (record == null || record.canEditRequest);
    // A never-sent order has no server copy, so it can be deleted outright.
    // Anything that reached the server is only taken off this list.
    final canDelete = record == null || record.isUnsentLegacy;
    final canDismiss = record != null && !canDelete && record.canRetry;
    final (tone, tint, guidanceIcon, guidance) = switch (record?.state) {
      LocalSaleSyncState.needsReview => (
          const Color(0xFFB45309),
          const Color(0xFFFFF7E8),
          Icons.fact_check_outlined,
          'Check Sales first. Sync only if this order is absent.',
        ),
      LocalSaleSyncState.queued => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          Icons.schedule_outlined,
          'Request saved on this device. Ready to sync.',
        ),
      LocalSaleSyncState.sending => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          Icons.sync,
          'Sending this order. Waiting for the server response.',
        ),
      LocalSaleSyncState.rejected => (
          const Color(0xFFB42318),
          const Color(0xFFFEF3F2),
          Icons.error_outline,
          record?.message?.isNotEmpty == true
              ? 'Rejected: ${record!.message}'
              : 'The server rejected this sale. Review the request or log.',
        ),
      _ => (
          const Color(0xFF475569),
          const Color(0xFFF1F5F9),
          Icons.cloud_off_outlined,
          'Saved on this device only. Check Sales, then sync it.',
        ),
    };
    final date = DateTime.tryParse(order.createdAt) == null
        ? order.createdAt
        : DateHelper.formatToISODateFromIST(order.createdAt);
    final customer = order.customerName?.trim();
    return Material(
      color: selected ? const Color(0xFFF0F6FF) : Colors.white,
      elevation: selected ? 0 : 0.5,
      shadowColor: const Color(0x140F172A),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected
                  ? ColorManager.kPrimaryColor
                  : tone.withValues(alpha: 0.35),
              width: selected ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('order-details-${order.id}'),
        onTap: onView,
        onLongPress: onSelectionChanged == null
            ? null
            : () => onSelectionChanged!(!selected),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // State accent so needs-review and rejected orders read at a glance.
          Container(height: 4, color: tone.withValues(alpha: 0.85)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                        width: 40,
                        height: 44,
                        child: Checkbox(
                            key: ValueKey('select-order-${order.id}'),
                            value: selected,
                            semanticLabel: 'Select order ${order.orderNumber}',
                            onChanged: onSelectionChanged == null
                                ? null
                                : (value) =>
                                    onSelectionChanged!(value ?? false))),
                    const SizedBox(width: 2),
                    Expanded(
                        child: Text('Order #${order.orderNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF0F3D75),
                                fontSize: 15,
                                fontWeight: FontWeight.w700))),
                    IconButton(
                        icon: const Icon(Icons.print_outlined, size: 20),
                        tooltip: 'Print receipt',
                        onPressed: onPrint,
                        color: ColorManager.kPrimaryColor),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                LocalSaleSyncBadge(record: record),
                                if (record != null &&
                                    record.attempts.isNotEmpty)
                                  Text(
                                      '${record.attempts.length} attempt${record.attempts.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12)),
                              ]),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(guidanceIcon,
                                        size: 16, color: tone),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(guidance,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 13,
                                              height: 1.4))),
                                ]),
                          ),
                          const SizedBox(height: 12),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (customer?.isNotEmpty == true)
                                          _Meta(
                                              icon: Icons.person_outline,
                                              text: customer!),
                                        _Meta(
                                            icon: Icons.schedule_outlined,
                                            text: date),
                                      ]),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                    '$currency ${order.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Color(0xFF0F3D75),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ])),
                              ]),
                          const SizedBox(height: 14),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            FilledButton.icon(
                                key: ValueKey('sync-order-${order.id}'),
                                onPressed: canAct ? onSync : null,
                                icon: sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.sync, size: 18),
                                label: Text(sending
                                    ? 'Sending…'
                                    : record?.state ==
                                            LocalSaleSyncState.rejected
                                        ? 'Retry sync'
                                        : 'Sync order'),
                                style: FilledButton.styleFrom(
                                    backgroundColor:
                                        ColorManager.kPrimaryColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                            OutlinedButton.icon(
                                key: ValueKey('edit-request-${order.id}'),
                                onPressed: canAct ? onEdit : null,
                                icon: const Icon(Icons.data_object, size: 18),
                                label: const Text('Edit JSON'),
                                style: _secondaryButtonStyle),
                          ]),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 4, runSpacing: 0, children: [
                            if (record != null)
                              TextButton.icon(
                                  key: ValueKey('sync-log-${order.id}'),
                                  onPressed: onLog,
                                  icon: const Icon(Icons.receipt_long_outlined,
                                      size: 18),
                                  label: Text('Log (${record.attempts.length})'),
                                  style: _tertiaryButtonStyle),
                            TextButton.icon(
                                onPressed: onView,
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 18),
                                label: const Text('Details'),
                                style: _tertiaryButtonStyle),
                            if (canDelete || canDismiss)
                              TextButton.icon(
                                  key: ValueKey('remove-order-${order.id}'),
                                  onPressed: actionsEnabled
                                      ? (canDelete ? onDelete : onDismiss)
                                      : null,
                                  icon: Icon(
                                      canDelete
                                          ? Icons.delete_outline
                                          : Icons.playlist_remove,
                                      size: 18),
                                  label: Text(canDelete ? 'Delete' : 'Remove'),
                                  style: _tertiaryButtonStyle.copyWith(
                                      foregroundColor:
                                          const WidgetStatePropertyAll(
                                              Color(0xFFB42318)))),
                          ]),
                        ]),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }

  static final _secondaryButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF334155),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  static final _tertiaryButtonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      foregroundColor: const Color(0xFF475569),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500));
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF475569), fontSize: 12))),
        ]),
      );
}
