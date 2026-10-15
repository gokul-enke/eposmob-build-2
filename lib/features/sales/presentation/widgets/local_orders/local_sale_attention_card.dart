import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

const _ink = Color(0xFF0F172A);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _danger = Color(0xFFB42318);

enum _CardAction { details, print, editJson, remove }

/// One unsynced sale: who and how much, the receipt number and sale time the
/// next sync will send, and a single primary action. The sale details are
/// read-only until the operator taps Edit; rarely used tools live in the
/// "more" menu.
class LocalSaleAttentionCard extends StatefulWidget {
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
    required this.onSaleDetailsChanged,
    this.actionsEnabled = true,
    this.submitting = false,
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

  /// Saves a corrected receipt number and/or sale time (a UTC ISO-8601
  /// instant); a null argument is left unchanged. Resolves to whether it was
  /// saved.
  final Future<bool> Function({String? receiptNumber, String? issuedAt})
      onSaleDetailsChanged;
  final bool actionsEnabled;

  /// Whether a send of this sale is queued or running.
  final bool submitting;

  @override
  State<LocalSaleAttentionCard> createState() => _LocalSaleAttentionCardState();
}

class _LocalSaleAttentionCardState extends State<LocalSaleAttentionCard> {
  final _receipt = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  DateTime? _draftTime;
  String? _error;

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  SavedOrder get _order => widget.order;
  LocalSaleSyncRecord? get _record => widget.syncRecord;
  bool get _canAct =>
      widget.actionsEnabled && (_record == null || _record!.canEditRequest);
  DateTime? get _savedTime => _toLocal(widget.issuedAt);
  bool get _receiptChanged => _receipt.text.trim() != widget.receiptNumber;
  bool get _timeChanged => _draftTime != null && _draftTime != _savedTime;

  void _startEditing() => setState(() {
        _receipt.text = widget.receiptNumber;
        _draftTime = _savedTime;
        _error = null;
        _editing = true;
      });

  void _cancelEditing() {
    if (_saving) return;
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  String? _futureError(DateTime value) => value.isAfter(_nowLocal())
      ? 'The sale time cannot be in the future.'
      : null;

  Future<void> _save() async {
    if (_saving || !_canAct) return;
    final receipt = _receipt.text.trim();
    if (receipt.isEmpty) {
      setState(() => _error = 'Enter a receipt number.');
      return;
    }
    final time = _draftTime;
    final timeError = _timeChanged ? _futureError(time!) : null;
    if (timeError != null) {
      setState(() => _error = timeError);
      return;
    }
    if (!_receiptChanged && !_timeChanged) {
      _cancelEditing();
      return;
    }
    final utc = _timeChanged
        ? DateHelper.configuredDateTimeToUtcIso(
            DateFormat('yyyy-MM-dd HH:mm:ss').format(time!))
        : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSaleDetailsChanged(
        receiptNumber: _receiptChanged ? receipt : null, issuedAt: utc);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _editing = false;
    });
  }

  Future<void> _pickDate() async {
    final base = _draftTime ?? _nowLocal();
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
    if (picked == null || !mounted) return;
    setState(() {
      _draftTime = DateTime(
          picked.year, picked.month, picked.day, base.hour, base.minute);
      _error = _futureError(_draftTime!);
    });
  }

  Future<void> _pickTime() async {
    final base = _draftTime ?? _nowLocal();
    final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
        helpText: 'Sale time');
    if (picked == null || !mounted) return;
    setState(() {
      _draftTime =
          DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
      _error = _futureError(_draftTime!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final order = _order;
    final sending = record?.state == LocalSaleSyncState.sending;
    final canAct = _canAct;
    // A never-sent order has no server copy, so it can be deleted outright.
    // Anything that reached the server is only taken off this list.
    final canDelete = record == null || record.isUnsentLegacy;
    final canDismiss = record != null && !canDelete && record.canRetry;
    // HTTP 409: the server already has this receipt number or client sale
    // ID, usually because an earlier send succeeded but its reply was lost.
    final receiptConflict = record?.attempts.lastOrNull?.responseBody
            ?.contains('receipt_identity_conflict') ==
        true;
    final (tone, hintIcon, hint) = switch (record?.state) {
      LocalSaleSyncState.needsReview ||
      LocalSaleSyncState.rejected when receiptConflict =>
        (
          const Color(0xFFB45309),
          Icons.info_outline,
          'The server already has this receipt, so it was most likely synced. '
              'Check Sales and compare the total price, then remove it from '
              'this list.',
        ),
      LocalSaleSyncState.needsReview => (
          const Color(0xFFB45309),
          Icons.info_outline,
          'Check Sales and compare the total price. If it is there, remove '
              'it; otherwise sync it.',
        ),
      // Sends run one at a time, so a queued sale can wait for its turn.
      LocalSaleSyncState.queued when widget.submitting => (
          const Color(0xFF2563EB),
          Icons.hourglass_top_outlined,
          'Waiting for earlier orders to finish sending…',
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
          'Saved on this device only. Check Sales and compare the total '
              'price, then sync it.',
        ),
    };
    final customer = order.customerName?.trim();

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
                color: widget.selected ? ColorManager.kPrimaryColor : _line,
                width: widget.selected ? 1.5 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('order-details-${order.id}'),
          onTap: _editing ? null : widget.onView,
          onLongPress: widget.onSelectionChanged == null
              ? null
              : () => widget.onSelectionChanged!(!widget.selected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Who bought and how much. The hint line below says what the
                // sync status means for the operator.
                LayoutBuilder(
                  builder: (context, box) => Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 40,
                            height: 40,
                            child: Checkbox(
                                key: ValueKey('select-order-${order.id}'),
                                value: widget.selected,
                                semanticLabel:
                                    'Select order ${order.orderNumber}',
                                onChanged: widget.onSelectionChanged == null
                                    ? null
                                    : (value) => widget
                                        .onSelectionChanged!(value ?? false))),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              customer?.isNotEmpty == true
                                  ? customer!
                                  : 'Walk-in customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        // Shrinks a long amount instead of squeezing the name.
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: box.maxWidth * 0.45),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                                '${widget.currency} ${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _saleDetails(),
                      const SizedBox(height: 12),
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
                                        color: tone,
                                        fontSize: 12.5,
                                        height: 1.4))),
                          ]),
                      const SizedBox(height: 14),
                      // On narrow cards Log shows only its icon so Sync
                      // keeps a readable label.
                      LayoutBuilder(
                          builder: (context, box) => Row(children: [
                                Expanded(
                                  child: FilledButton.icon(
                                      key: ValueKey('sync-order-${order.id}'),
                                      // An unsaved edit must not be sent by surprise.
                                      onPressed: canAct && !_editing
                                          ? widget.onSync
                                          : null,
                                      icon: sending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.sync, size: 18),
                                      label: Text(
                                          sending
                                              ? 'Sending…'
                                              : record?.state ==
                                                      LocalSaleSyncState
                                                          .rejected
                                                  ? 'Retry sync'
                                                  : 'Sync order',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              ColorManager.kPrimaryColor,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 44),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          textStyle: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600))),
                                ),
                                if (record != null) ...[
                                  const SizedBox(width: 8),
                                  _logButton(record.attempts.length,
                                      compact: box.maxWidth < 330),
                                ],
                                const SizedBox(width: 8),
                                _moreMenu(
                                    canAct: canAct,
                                    canDelete: canDelete,
                                    canDismiss: canDismiss),
                              ])),
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

  Widget _logButton(int attempts, {required bool compact}) {
    final key = ValueKey('sync-log-${_order.id}');
    final style = OutlinedButton.styleFrom(
        foregroundColor: _body,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
    if (compact) {
      return Tooltip(
        message: 'Sync log ($attempts)',
        child: OutlinedButton(
            key: key,
            onPressed: widget.onLog,
            style: style,
            child: const Icon(Icons.history, size: 19)),
      );
    }
    return OutlinedButton.icon(
        key: key,
        onPressed: widget.onLog,
        icon: const Icon(Icons.history, size: 18),
        label: Text('Log ($attempts)'),
        style: style);
  }

  /// Receipt number and sale time: read-only rows, or the edit form after
  /// the operator taps Edit.
  Widget _saleDetails() {
    final id = _order.id;
    final saved = _savedTime;
    final enabled = _canAct && !_saving;
    String format(DateTime value) =>
        '${DateFormat('dd-MM-yyyy').format(value)} · ${DateFormat('hh:mm a').format(value)}';

    final header = Row(children: [
      Expanded(
        child: Text(_editing ? 'Edit sale details' : 'Sale details',
            style: const TextStyle(
                color: _body, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
      if (_editing)
        IconButton(
            key: ValueKey('close-sale-details-$id'),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 19),
            color: _muted,
            onPressed: _saving ? null : _cancelEditing)
      else
        IconButton(
            key: ValueKey('edit-sale-details-$id'),
            tooltip: _canAct
                ? 'Edit receipt no., date and time'
                : 'Cannot edit while this order is sending',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: ColorManager.kPrimaryColor,
            onPressed: _canAct ? _startEditing : null),
    ]);

    final Widget body;
    if (!_editing) {
      body = Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(children: [
          _ReadRow('Receipt no.', widget.receiptNumber,
              key: ValueKey('receipt-value-$id')),
          const SizedBox(height: 6),
          _ReadRow(
              'Date & time', saved == null ? widget.issuedAt : format(saved),
              key: ValueKey('sale-time-value-$id')),
        ]),
      );
    } else {
      final draft = _draftTime;
      OutlineInputBorder border(Color color, [double width = 1]) =>
          OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: width));
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _cancelEditing
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Receipt no.'),
              TextField(
                key: ValueKey('receipt-number-$id'),
                controller: _receipt,
                enabled: enabled,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(40),
                ],
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()]),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Receipt number',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  prefixIcon: const Icon(Icons.tag, size: 18, color: _muted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 44),
                  border: border(_line),
                  enabledBorder: border(_line),
                  disabledBorder: border(_line),
                  focusedBorder: border(ColorManager.kPrimaryColor, 1.5),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Date'),
                        _PickerField(
                          key: ValueKey('sale-date-$id'),
                          icon: Icons.calendar_today_outlined,
                          text: draft == null
                              ? widget.issuedAt
                              : DateFormat('dd-MM-yyyy').format(draft),
                          onTap: enabled ? _pickDate : null,
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
                          key: ValueKey('sale-time-$id'),
                          icon: Icons.schedule_outlined,
                          text: draft == null
                              ? '--:--'
                              : DateFormat('hh:mm a').format(draft),
                          onTap: enabled ? _pickTime : null,
                        ),
                      ]),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    key: ValueKey('sale-details-error-$id'),
                    style: const TextStyle(
                        color: _danger, fontSize: 12.5, height: 1.4)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                        key: ValueKey('cancel-sale-details-$id'),
                        onPressed: _saving ? null : _cancelEditing,
                        style: TextButton.styleFrom(
                            foregroundColor: _body,
                            minimumSize: const Size(0, 40)),
                        child: const Text('Cancel')),
                    FilledButton.icon(
                        key: ValueKey('save-sale-details-$id'),
                        onPressed: enabled && (_receiptChanged || _timeChanged)
                            ? _save
                            : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save'),
                        style: FilledButton.styleFrom(
                            backgroundColor: ColorManager.kPrimaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _editing ? ColorManager.kPrimaryColor : _line,
              width: _editing ? 1.5 : 1)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, body]),
    );
  }

  Widget _moreMenu({
    required bool canAct,
    required bool canDelete,
    required bool canDismiss,
  }) {
    final id = _order.id;
    PopupMenuItem<_CardAction> item(
            _CardAction value, String key, IconData icon, String label,
            {bool enabled = true, bool danger = false}) =>
        PopupMenuItem(
          key: ValueKey('$key-$id'),
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
      key: ValueKey('order-actions-$id'),
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
            widget.onView();
          case _CardAction.print:
            widget.onPrint();
          case _CardAction.editJson:
            widget.onEdit();
          case _CardAction.remove:
            canDelete ? widget.onDelete() : widget.onDismiss();
        }
      },
      itemBuilder: (_) => [
        item(_CardAction.details, 'view-order', Icons.visibility_outlined,
            'View details'),
        item(_CardAction.print, 'print-order', Icons.print_outlined,
            'Print receipt'),
        item(_CardAction.editJson, 'edit-request', Icons.data_object,
            'Edit request JSON',
            enabled: canAct && !_editing),
        if (canDelete || canDismiss) ...[
          const PopupMenuDivider(),
          item(
              _CardAction.remove,
              'remove-order',
              canDelete ? Icons.delete_outline : Icons.playlist_remove,
              canDelete ? 'Delete' : 'Remove from list',
              enabled: widget.actionsEnabled,
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
}

class _ReadRow extends StatelessWidget {
  const _ReadRow(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: const TextStyle(
                color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()]))),
      ]);
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
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
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
                          fontFeatures: const [FontFeature.tabularFigures()]))),
            ]),
          ),
        ),
      ),
    );
  }
}
