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

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);

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
          const Color(0xFFFFF8EB),
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
    final (date, time) = _dateParts(order.createdAt);
    final customer = order.customerName?.trim();
    final attempts = record?.attempts.length ?? 0;
    return Material(
      color: selected ? const Color(0xFFF5F9FF) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected ? ColorManager.kPrimaryColor : _line,
              width: selected ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('order-details-${order.id}'),
        onTap: onView,
        onLongPress: onSelectionChanged == null
            ? null
            : () => onSelectionChanged!(!selected),
        // State stripe on the leading edge reads at a glance in a grid.
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: tone, width: 4))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 40,
                        height: 40,
                        child: Checkbox(
                            key: ValueKey('select-order-${order.id}'),
                            value: selected,
                            semanticLabel: 'Select order ${order.orderNumber}',
                            onChanged: onSelectionChanged == null
                                ? null
                                : (value) =>
                                    onSelectionChanged!(value ?? false))),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('#${order.orderNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.1)),
                              const SizedBox(height: 6),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    LocalSaleSyncBadge(record: record),
                                    if (attempts > 0)
                                      Text(
                                          '$attempts attempt${attempts == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                              color: _muted, fontSize: 12)),
                                  ]),
                            ]),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.print_outlined, size: 20),
                        tooltip: 'Print receipt',
                        onPressed: onPrint,
                        color: const Color(0xFF475569)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFF1F5F9))),
                            child: LayoutBuilder(
                              builder: (context, box) => Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _Meta(
                                                icon: Icons.person_outline,
                                                text:
                                                    customer?.isNotEmpty == true
                                                        ? customer!
                                                        : 'Walk-in customer'),
                                            const SizedBox(height: 4),
                                            _Meta(
                                                icon: Icons.event_outlined,
                                                text: time == null
                                                    ? date
                                                    : '$date · $time'),
                                          ]),
                                    ),
                                    const SizedBox(width: 12),
                                    // Shrinks the amount rather than squeezing
                                    // the date on narrow phones or large text.
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxWidth: box.maxWidth * 0.45),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text('Total',
                                                  style: TextStyle(
                                                      color: _muted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.4)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '$currency ${order.total.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      color: _ink,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontFeatures: [
                                                        FontFeature
                                                            .tabularFigures()
                                                      ])),
                                            ]),
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                          const SizedBox(height: 10),
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
                                              fontSize: 12.5,
                                              height: 1.4))),
                                ]),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
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
                                      minimumSize: const Size(0, 42),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                  key: ValueKey('edit-request-${order.id}'),
                                  onPressed: canAct ? onEdit : null,
                                  icon: const Icon(Icons.data_object, size: 18),
                                  label: const Text('Edit JSON'),
                                  style: _secondaryButtonStyle),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          Row(children: [
                            Expanded(
                              child: Wrap(spacing: 0, children: [
                                if (record != null)
                                  TextButton.icon(
                                      key: ValueKey('sync-log-${order.id}'),
                                      onPressed: onLog,
                                      icon: const Icon(Icons.history, size: 17),
                                      label: Text('Log ($attempts)'),
                                      style: _tertiaryButtonStyle),
                                TextButton.icon(
                                    onPressed: onView,
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 17),
                                    label: const Text('Details'),
                                    style: _tertiaryButtonStyle),
                              ]),
                            ),
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
                                      size: 17),
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
        ),
      ),
    );
  }

  /// Date and time in the business timezone, or the raw value when the
  /// stored timestamp cannot be parsed.
  static (String, String?) _dateParts(String createdAt) =>
      DateTime.tryParse(createdAt) == null
          ? (createdAt, null)
          : (
              DateHelper.formatToISODateOnlyFromISO(createdAt),
              DateHelper.formatToISOTimeOnlyFromISO(createdAt)
            );

  static final _secondaryButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF334155),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      minimumSize: const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

  static final _tertiaryButtonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      foregroundColor: const Color(0xFF475569),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500));
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500))),
      ]);
}
