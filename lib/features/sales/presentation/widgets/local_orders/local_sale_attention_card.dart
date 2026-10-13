import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sale_sync_badge.dart';

const _ink = Color(0xFF0F172A);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _danger = Color(0xFFB42318);

enum _CardAction { details, print, editJson, log, remove }

/// One unsynced sale: who and how much, the receipt number and sale time the
/// next sync will send (editable in place), and a single primary action.
/// Rarely used tools live in the "more" menu.
class LocalSaleAttentionCard extends StatelessWidget {
  const LocalSaleAttentionCard({
    super.key,
    required this.order,
    required this.syncRecord,
    required this.currency,
    required this.receiptNumber,
    required this.issuedAt,
    required this.selected,
    required this.onSelectionChanged,
    required this.onView,
    required this.onSync,
    required this.onEdit,
    required this.onDismiss,
    required this.onDelete,
    required this.onLog,
    required this.onPrint,
    required this.onReceiptNumberChanged,
    required this.onIssuedAtChanged,
    this.actionsEnabled = true,
  });

  final SavedOrder order;
  final LocalSaleSyncRecord? syncRecord;
  final String currency;

  /// Receipt number and sale time (ISO-8601) the next sync will send.
  final String receiptNumber, issuedAt;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback onView,
      onSync,
      onEdit,
      onDismiss,
      onDelete,
      onLog,
      onPrint;

  /// Save a new value and resolve to whether it was saved.
  final Future<bool> Function(String receiptNumber) onReceiptNumberChanged;
  final Future<bool> Function(String issuedAtUtc) onIssuedAtChanged;
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
    final (tone, hintIcon, hint) = switch (record?.state) {
      LocalSaleSyncState.needsReview => (
          const Color(0xFFB45309),
          Icons.info_outline,
          'Check Sales first. Sync only if this order is not there.',
        ),
      LocalSaleSyncState.queued => (
          const Color(0xFF2563EB),
          Icons.schedule_outlined,
          'Saved on this device and ready to sync.',
        ),
      LocalSaleSyncState.sending => (
          const Color(0xFF2563EB),
          Icons.sync,
          'Sending to the server…',
        ),
      LocalSaleSyncState.rejected => (
          _danger,
          Icons.error_outline,
          record?.message?.isNotEmpty == true
              ? record!.message!
              : 'The server rejected this sale. Fix the details, then retry.',
        ),
      _ => (
          _body,
          Icons.cloud_off_outlined,
          'Saved on this device only. Check Sales, then sync it.',
        ),
    };
    final customer = order.customerName?.trim();
    final local = _toLocal(issuedAt);
    final attempts = record?.attempts.length ?? 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Who bought and how much, with the sync status.
                LayoutBuilder(
                  builder: (context, box) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 40,
                            height: 40,
                            child: Checkbox(
                                key: ValueKey('select-order-${order.id}'),
                                value: selected,
                                semanticLabel:
                                    'Select order ${order.orderNumber}',
                                onChanged: onSelectionChanged == null
                                    ? null
                                    : (value) =>
                                        onSelectionChanged!(value ?? false))),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      customer?.isNotEmpty == true
                                          ? customer!
                                          : 'Walk-in customer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  LocalSaleSyncBadge(record: record),
                                ]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Shrinks a long amount instead of squeezing the name.
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: box.maxWidth * 0.45),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                  '$currency ${order.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ])),
                            ),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Receipt no.'),
                      _ReceiptNumberField(
                        orderId: order.id,
                        value: receiptNumber,
                        enabled: canAct,
                        onSubmit: onReceiptNumberChanged,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Date'),
                                _PickerField(
                                  key: ValueKey('sale-date-${order.id}'),
                                  icon: Icons.calendar_today_outlined,
                                  text: local == null
                                      ? issuedAt
                                      : DateFormat('dd-MM-yyyy').format(local),
                                  tooltip: 'Change sale date',
                                  onTap: canAct
                                      ? () => _pickDate(context, local)
                                      : null,
                                ),
                              ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Time'),
                                _PickerField(
                                  key: ValueKey('sale-time-${order.id}'),
                                  icon: Icons.schedule_outlined,
                                  text: local == null
                                      ? '--:--'
                                      : DateFormat('hh:mm a').format(local),
                                  tooltip: 'Change sale time',
                                  onTap: canAct
                                      ? () => _pickTime(context, local)
                                      : null,
                                ),
                              ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(hintIcon, size: 16, color: tone),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(hint,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: tone == _body ? _body : tone,
                                        fontSize: 12.5,
                                        height: 1.4))),
                          ]),
                      const SizedBox(height: 14),
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
                                  : record?.state == LocalSaleSyncState.rejected
                                      ? 'Retry sync'
                                      : 'Sync order'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: ColorManager.kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 44),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600))),
                        ),
                        const SizedBox(width: 8),
                        _moreMenu(
                            canAct: canAct,
                            canDelete: canDelete,
                            canDismiss: canDismiss,
                            attempts: attempts),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moreMenu({
    required bool canAct,
    required bool canDelete,
    required bool canDismiss,
    required int attempts,
  }) {
    PopupMenuItem<_CardAction> item(
            _CardAction value, String key, IconData icon, String label,
            {bool enabled = true, bool danger = false}) =>
        PopupMenuItem(
          key: ValueKey('$key-${order.id}'),
          value: value,
          enabled: enabled,
          height: 44,
          child: Row(children: [
            Icon(icon, size: 19, color: danger ? _danger : _body),
            const SizedBox(width: 12),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: danger ? _danger : _ink)),
            ),
          ]),
        );
    return PopupMenuButton<_CardAction>(
      key: ValueKey('order-actions-${order.id}'),
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _line)),
      onSelected: (action) {
        switch (action) {
          case _CardAction.details:
            onView();
          case _CardAction.print:
            onPrint();
          case _CardAction.editJson:
            onEdit();
          case _CardAction.log:
            onLog();
          case _CardAction.remove:
            canDelete ? onDelete() : onDismiss();
        }
      },
      itemBuilder: (_) => [
        item(_CardAction.details, 'view-order', Icons.visibility_outlined,
            'View details'),
        item(_CardAction.print, 'print-order', Icons.print_outlined,
            'Print receipt'),
        item(_CardAction.editJson, 'edit-request', Icons.data_object,
            'Edit request JSON',
            enabled: canAct),
        if (syncRecord != null)
          item(_CardAction.log, 'sync-log', Icons.history,
              'Sync log ($attempts)'),
        if (canDelete || canDismiss) ...[
          const PopupMenuDivider(),
          item(
              _CardAction.remove,
              'remove-order',
              canDelete ? Icons.delete_outline : Icons.playlist_remove,
              canDelete ? 'Delete' : 'Remove from list',
              enabled: actionsEnabled,
              danger: true),
        ],
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.more_horiz, color: _body),
      ),
    );
  }

  /// [value] as a wall-clock time in the business timezone, or null when it
  /// cannot be parsed.
  static DateTime? _toLocal(String value) => DateTime.tryParse(
      DateHelper.formatISODateTimeForInput(value).replaceFirst(' ', 'T'));

  static DateTime _nowLocal() {
    final now = DateHelper.nowInConfiguredTimeZone();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final base = current ?? _nowLocal();
    final now = _nowLocal();
    final day = DateTime(base.year, base.month, base.day);
    var last = DateTime(now.year, now.month, now.day);
    if (day.isAfter(last)) last = day;
    var first = DateTime(last.year - 1, last.month, last.day);
    if (day.isBefore(first)) first = day;
    final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: first,
        lastDate: last,
        helpText: 'Sale date');
    if (picked == null || !context.mounted) return;
    await _saveIssuedAt(
        context,
        current,
        DateTime(
            picked.year, picked.month, picked.day, base.hour, base.minute));
  }

  Future<void> _pickTime(BuildContext context, DateTime? current) async {
    final base = current ?? _nowLocal();
    final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
        helpText: 'Sale time');
    if (picked == null || !context.mounted) return;
    await _saveIssuedAt(context, current,
        DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
  }

  Future<void> _saveIssuedAt(
      BuildContext context, DateTime? current, DateTime value) async {
    if (value == current) return;
    if (value.isAfter(_nowLocal())) {
      showScaffoldError(
          context: context, message: 'The sale time cannot be in the future.');
      return;
    }
    final utc = DateHelper.configuredDateTimeToUtcIso(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(value));
    if (utc != null) await onIssuedAtChanged(utc);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Looks like an input; opens a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.icon,
    required this.text,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String text, tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: enabled ? tooltip : '',
      child: Material(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(icon, size: 17, color: _muted),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: enabled ? _ink : _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ]))),
                if (enabled)
                  const Icon(Icons.expand_more, size: 18, color: _muted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edits the receipt number in place. Saves on Enter, the check button or
/// leaving the field; Escape or the close button restores the saved value.
class _ReceiptNumberField extends StatefulWidget {
  const _ReceiptNumberField({
    required this.orderId,
    required this.value,
    required this.enabled,
    required this.onSubmit,
  });

  final String orderId, value;
  final bool enabled;
  final Future<bool> Function(String) onSubmit;

  @override
  State<_ReceiptNumberField> createState() => _ReceiptNumberFieldState();
}

class _ReceiptNumberFieldState extends State<_ReceiptNumberField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  bool _saving = false;

  /// Last value saved but not yet reflected in [widget.value], so leaving the
  /// field right after a save does not save it twice.
  String? _submitted;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      if (!_focus.hasFocus && _dirty) _commit();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(_ReceiptNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _submitted = null;
      if (!_focus.hasFocus) _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _text => _controller.text.trim();
  bool get _dirty => _text != widget.value && _text != _submitted;

  void _revert() {
    _controller.text = widget.value;
    _focus.unfocus();
    setState(() {});
  }

  Future<void> _commit() async {
    final value = _text;
    if (_saving || !_dirty) return;
    if (value.isEmpty) {
      showScaffoldError(
          context: context, message: 'Receipt number cannot be empty.');
      _revert();
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSubmit(value);
    if (!mounted) return;
    if (saved) _submitted = value;
    setState(() => _saving = false);
    if (saved) _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _dirty;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: width));
    final Widget? suffix = _saving
        ? const Padding(
            padding: EdgeInsets.all(13),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)))
        : dirty
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    key: ValueKey('save-receipt-${widget.orderId}'),
                    tooltip: 'Save receipt number',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check, size: 20),
                    color: const Color(0xFF16764A),
                    onPressed: _commit),
                IconButton(
                    tooltip: 'Cancel',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    color: _muted,
                    onPressed: _revert),
                const SizedBox(width: 4),
              ])
            : widget.enabled && !_focus.hasFocus
                ? const Icon(Icons.edit_outlined, size: 17, color: _muted)
                : null;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _revert},
      child: TextField(
        key: ValueKey('receipt-number-${widget.orderId}'),
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enabled && !_saving,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(40),
        ],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _commit(),
        style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()]),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: widget.enabled ? Colors.white : const Color(0xFFF8FAFC),
          hintText: 'Receipt number',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          prefixIcon: const Icon(Icons.tag, size: 18, color: _muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 44),
          suffixIcon: suffix,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 44),
          border: border(_line),
          enabledBorder: border(_line),
          disabledBorder: border(_line),
          focusedBorder: border(ColorManager.kPrimaryColor, 1.5),
        ),
      ),
    );
  }
}
