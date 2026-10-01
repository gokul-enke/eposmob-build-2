import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../components/export_share_button.dart';
import '../../components/filter_toggle_button.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../helpers/date_helper.dart';
import '../../helpers/ui_code_labels.dart';
import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../newcomponents/custom_dialog_box.dart';
import '../../services/customer_ledger_snapshot.dart';
import '../../services/list_excel_export_service.dart';
import 'widgets/common_details_dialog.dart';

typedef _Filters = ({
  String amount,
  String name,
  String reference,
  String type,
  String? customerId,
  String? date
});
typedef _ServerFilters = ({String type, String? customerId, String? date});

class CustomerTransactionListScreen extends StatefulWidget {
  const CustomerTransactionListScreen({super.key});
  @override
  State<CustomerTransactionListScreen> createState() =>
      _CustomerTransactionListScreenState();
}

class _CustomerTransactionListScreenState
    extends State<CustomerTransactionListScreen> {
  final _amount = TextEditingController(),
      _name = TextEditingController(),
      _reference = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountKey = GlobalKey<TextFilterFieldState>(),
      _referenceKey = GlobalKey<TextFilterFieldState>();
  final _table = ScrollController();
  final _progress = ValueNotifier<String?>(null);
  Timer? _nameTimer;
  String _type = 'All';
  String? _customerId;
  DateTime? _date;
  bool _loading = false, _showFilters = true;
  String? _error;
  int _generation = 0, _page = 1, _pages = 1;
  List<ListTransaction> _rows = [], _suggestions = [];
  List<ListTransaction>? _cache;
  _ServerFilters? _cacheKey;
  _Filters? _loaded;

  _Filters get _filters => (
        amount: _amount.text.trim(),
        name: _name.text.trim(),
        reference: _reference.text.trim(),
        type: _type,
        customerId: _customerId,
        date: _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!)
      );
  _ServerFilters _server(_Filters f) =>
      (type: f.type, customerId: f.customerId, date: f.date);
  bool _local(_Filters f) =>
      f.amount.isNotEmpty ||
      f.reference.isNotEmpty ||
      (f.name.isNotEmpty && f.customerId == null);
  List<ListTransaction> _match(List<ListTransaction> rows, _Filters f) => rows
      .where((r) =>
          (r.amount ?? '').contains(f.amount) &&
          (r.referenceId ?? '')
              .toLowerCase()
              .contains(f.reference.toLowerCase()) &&
          (f.customerId != null ||
              (r.customerName ?? '')
                  .toLowerCase()
                  .contains(f.name.toLowerCase())))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    _generation++;
    _nameTimer?.cancel();
    _amount.dispose();
    _name.dispose();
    _reference.dispose();
    _nameFocus.dispose();
    _table.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _cancelPending() {
    _nameTimer?.cancel();
    _amountKey.currentState?.cancelPendingSearch();
    _referenceKey.currentState?.cancelPendingSearch();
  }

  Future<void> _fetch(
      {int page = 1, bool force = false, _Filters? filters}) async {
    final f = filters ?? _filters;
    final generation = ++_generation;
    final provider = context.read<InvoiceProvider>();
    final token = context.read<AuthModel>().token ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Future<dynamic> request(int p, int count) =>
          provider.listCustomerTransactions(
              accessToken: token,
              customerId: f.customerId,
              dateFrom: f.date,
              dateTo: f.date,
              type: f.type == 'All' ? null : f.type.toLowerCase(),
              page: p,
              perPage: count,
              updateState: false);
      List<ListTransaction> rows;
      List<ListTransaction>? cache;
      int current, last;
      if (_local(f)) {
        cache = !force && _cacheKey == _server(f) ? _cache : null;
        cache ??= await fetchCustomerLedgerSnapshot((p) => request(p, 1000));
        final filtered = _match(cache, f);
        last = ((filtered.length + 19) ~/ 20).clamp(1, 2147483647);
        current = page.clamp(1, last);
        rows = filtered.skip((current - 1) * 20).take(20).toList();
      } else {
        final result = CustomerLedgerPage.parse(await request(page, 20), page);
        rows = result.rows;
        current = result.current;
        last = result.last;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = rows;
        _page = current;
        _pages = last;
        _loaded = f;
        _suggestions = cache ?? rows;
        if (force) {
          _cache = null;
          _cacheKey = null;
        }
        if (cache != null) {
          _cache = cache;
          _cacheKey = _server(f);
        }
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'party_accounts.load_error'.tr);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    _cancelPending();
    await _fetch(force: true);
  }

  void _reset() {
    _cancelPending();
    _amount.clear();
    _name.clear();
    _reference.clear();
    setState(() {
      _type = 'All';
      _customerId = null;
      _date = null;
      _cache = null;
      _cacheKey = null;
    });
    _fetch();
  }

  Future<File> _export() async {
    _cancelPending();
    final f = _filters;
    if (_loading || _error != null) {
      throw StateError('Customer ledger is unavailable.');
    }
    final provider = context.read<InvoiceProvider>();
    final token = context.read<AuthModel>().token ?? '';
    final master = context.read<MasterDataProvider>();
    // Materialize payment labels before handing rows to the workbook encoder.
    final paymentLabels = <String, String>{};
    String payment(ListTransaction r) => paymentLabels.putIfAbsent(
        r.paymentMethod ?? '',
        () =>
            master.getPaymentMethodValue(
                int.tryParse(r.paymentMethod ?? '') ?? -1) ??
            r.paymentMethod ??
            '');
    try {
      if (_loaded != f) {
        await _fetch(filters: f);
      }
      if (!mounted || _error != null || _loaded != f) {
        throw StateError('Customer ledger filters changed.');
      }
      final all = _cacheKey == _server(f) && _cache != null
          ? _cache!
          : await fetchCustomerLedgerSnapshot(
              (p) => provider.listCustomerTransactions(
                  accessToken: token,
                  customerId: f.customerId,
                  dateFrom: f.date,
                  dateTo: f.date,
                  type: f.type == 'All' ? null : f.type.toLowerCase(),
                  page: p,
                  perPage: 1000,
                  updateState: false), onProgress: (p, last) {
              if (mounted) {
                _progress.value = 'party_accounts.export_fetching'
                    .trParams({'page': '$p', 'total': '$last'});
              }
            });
      if (!mounted) throw StateError('Customer ledger screen closed.');
      final rows = _match(all, f);
      for (final row in rows) {
        payment(row);
      }
      _progress.value = 'supplier_transactions.export_creating'.tr;
      return await ListExcelExportService.export<ListTransaction>(
          items: rows,
          fileNamePrefix: 'customer-transactions',
          sheetName: 'Customer Transactions',
          columns: [
            ListExportColumn(
                label: 'party_accounts.col_no'.tr, value: (_, i) => i + 1),
            ListExportColumn(
                label: 'party_accounts.transaction_id'.tr,
                value: (r, _) => r.id?.toString()),
            ListExportColumn(
                label: 'party_accounts.customer_name'.tr,
                value: (r, _) => r.customerName),
            ListExportColumn(
                label: 'party_accounts.date'.tr, value: (r, _) => r.date),
            ListExportColumn(
                label: 'party_accounts.amount'.tr,
                value: (r, _) => ListExcelExportService.numericValue(r.amount)),
            ListExportColumn(
                label: 'party_accounts.currency'.tr,
                value: (r, _) => r.currency),
            ListExportColumn(
                label: 'party_accounts.reference_id'.tr,
                value: (r, _) => r.referenceId),
            ListExportColumn(
                label: 'party_accounts.type'.tr,
                value: (r, _) => _typeLabel(r.type)),
            ListExportColumn(
                label: 'party_accounts.status'.tr,
                value: (r, _) => _statusLabel(r.status)),
            ListExportColumn(
                label: 'party_accounts.transaction_type'.tr,
                value: (r, _) =>
                    UiCodeLabels.documentKind(r.transactionType ?? '')),
            ListExportColumn(
                label: 'party_accounts.payment_method'.tr,
                value: (r, _) => paymentLabels[r.paymentMethod ?? '']),
            ListExportColumn(
                label: 'party_accounts.reference'.tr,
                value: (r, _) => r.reference),
            ListExportColumn(
                label: 'party_accounts.comment'.tr,
                value: (r, _) => r.transactionComment),
            ListExportColumn(
                label: 'party_accounts.created_at'.tr,
                value: (r, _) => r.createdAt?.toIso8601String()),
          ]);
    } finally {
      if (mounted) _progress.value = null;
    }
  }

  String _typeLabel(String? raw) => switch (raw?.toLowerCase()) {
        'credit' => 'transaction_status_labels.credit'.tr,
        'debit' => 'transaction_status_labels.debit'.tr,
        _ => raw ?? '—'
      };
  String _statusLabel(String? raw) => switch (raw?.toUpperCase()) {
        'SUCC' || 'SUCCESS' => 'transaction_status_labels.succ'.tr,
        'INIT' || 'INITIATED' => 'transaction_status_labels.init'.tr,
        'FAIL' || 'FAILED' => 'transaction_status_labels.fail'.tr,
        _ => raw ?? '—'
      };
  Widget _badge(String label, Color color) => Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600))));
  Widget _typeBadge(ListTransaction r) => _badge(
      _typeLabel(r.type),
      r.type?.toLowerCase() == 'credit'
          ? AppColors.green
          : r.type?.toLowerCase() == 'debit'
              ? AppColors.red
              : AppColors.muted);
  Widget _statusBadge(ListTransaction r) => _badge(
      _statusLabel(r.status),
      switch (r.status?.toUpperCase()) {
        'SUCC' || 'SUCCESS' => AppColors.green,
        'FAIL' || 'FAILED' => AppColors.red,
        'INIT' || 'INITIATED' => Colors.orange.shade800,
        _ => AppColors.muted
      });
  String _money(ListTransaction r) =>
      '${r.currency ?? ''} ${double.parse(r.amount!).toStringAsFixed(3)}'
          .trim();
  Widget _ref(ListTransaction r) => Row(children: [
        Expanded(child: TableCells.text(r.referenceId ?? '—')),
        if (r.referenceId?.isNotEmpty == true)
          IconButton(
              tooltip: 'party_accounts.ref_copied'.tr,
              icon: const Icon(Icons.copy_outlined, size: 16),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: r.referenceId!));
                if (mounted) {
                  showScaffold(
                      context: context,
                      message: 'party_accounts.ref_copied'.tr);
                }
              })
      ]);

  Widget _customerField() => RawAutocomplete<ListTransaction>(
      textEditingController: _name,
      focusNode: _nameFocus,
      displayStringForOption: (r) => r.customerName ?? '',
      optionsBuilder: (value) {
        final ids = <int?>{};
        return _suggestions.where((r) =>
            (r.customerName?.isNotEmpty ?? false) &&
            (r.customerName!)
                .toLowerCase()
                .contains(value.text.toLowerCase()) &&
            ids.add(r.customerId));
      },
      onSelected: (r) {
        _cancelPending();
        _customerId = r.customerId?.toString();
        _fetch();
      },
      fieldViewBuilder: (_, controller, focus, submit) => TextField(
          controller: controller,
          focusNode: focus,
          decoration: listFilterDecoration(
              'party_accounts.customer_name'.tr, Icons.person_outline),
          onChanged: (_) {
            _customerId = null;
            _nameTimer?.cancel();
            _nameTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) _fetch();
            });
          },
          onSubmitted: (_) {
            _cancelPending();
            _fetch();
          }),
      optionsViewBuilder: (_, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
              elevation: 4,
              child: SizedBox(
                  width: 280,
                  height: 200,
                  child: ListView(children: [
                    for (final r in options)
                      ListTile(
                          title: Text(r.customerName ?? ''),
                          onTap: () => select(r))
                  ])))));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100));
    if (!mounted || picked == null) return;
    _cancelPending();
    setState(() => _date = picked);
    _fetch();
  }

  Widget _filtersPanel(bool mobile) => FilterPanel(
          key: ValueKey(
              'customer-transactions-${mobile ? 'mobile' : 'desktop'}-filters'),
          title: 'party_accounts.find'.tr,
          hint: 'party_accounts.filter_hint'.tr,
          onReset: _reset,
          fields: [
            TextFilterField(
                key: _amountKey,
                controller: _amount,
                label: 'party_accounts.amount'.tr,
                icon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSearch: () => _fetch()),
            _customerField(),
            DropdownButtonFormField<String>(
                key: ValueKey('customer-type:$_type'),
                initialValue: _type,
                isExpanded: true,
                decoration: listFilterDecoration(
                    'party_accounts.type'.tr, Icons.swap_vert),
                items: [
                  for (final t in ['All', 'Credit', 'Debit'])
                    DropdownMenuItem(
                        value: t,
                        child:
                            Text(t == 'All' ? 'common.all'.tr : _typeLabel(t)))
                ],
                onChanged: (v) {
                  _cancelPending();
                  setState(() => _type = v ?? 'All');
                  _fetch();
                }),
            TextFilterField(
                key: _referenceKey,
                controller: _reference,
                label: 'party_accounts.reference_id'.tr,
                icon: Icons.tag,
                onSearch: () => _fetch()),
            InkWell(
                key: const ValueKey('customer-transactions-date'),
                onTap: _pickDate,
                child: InputDecorator(
                    decoration: listFilterDecoration('party_accounts.date'.tr,
                        Icons.calendar_today_outlined),
                    child: Text(_date == null
                        ? 'party_accounts.select_date'.tr
                        : DateFormat('MMM dd, yyyy').format(_date!)))),
          ]);
  Widget _card(ListTransaction r, int index) => AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TableCells.identity(r.customerName ?? 'party_accounts.no_name'.tr),
        const SizedBox(height: 12),
        Text('${'party_accounts.col_no'.tr}: $index'),
        Text('${r.date} · ${_money(r)}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [_typeBadge(r), _statusBadge(r)]),
        _ref(r),
        TableCells.viewButton(() => _showTransactionDetails(r))
      ]));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, size) => ListPageScaffold<ListTransaction>(
            header: ListPageHeader(
                icon: Icons.swap_horiz,
                title: 'party_accounts.title'.tr,
                subtitle: 'party_accounts.subtitle'.tr,
                onRefresh: _refresh,
                extraActions: [
                  FilterToggleButton(
                      key:
                          const ValueKey('customer-transactions-filter-toggle'),
                      showFilters: _showFilters,
                      showTooltip: 'party_accounts.filters'.tr,
                      hideTooltip: 'party_accounts.hide_filters'.tr,
                      activeFiltersListenable:
                          Listenable.merge([_amount, _name, _reference]),
                      activeFiltersBuilder: () =>
                          _amount.text.trim().isNotEmpty ||
                          _name.text.trim().isNotEmpty ||
                          _reference.text.trim().isNotEmpty ||
                          _date != null ||
                          _type != 'All',
                      hasActiveFilters: _filters !=
                          (
                            amount: '',
                            name: '',
                            reference: '',
                            type: 'All',
                            customerId: null,
                            date: null
                          ),
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  ExportShareButton(
                      createFile: _export,
                      label: 'supplier_transactions.export'.tr,
                      loadingLabel: 'supplier_transactions.export_creating'.tr,
                      tooltip: 'party_accounts.export_tooltip'.tr,
                      errorMessage: 'party_accounts.export_error'.tr,
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      compact: size.maxWidth < 560,
                      enabled: !_loading && _error == null && _loaded != null,
                      progressLabel: _progress),
                ]),
            filters: _filtersPanel(size.maxWidth < 700),
            showFilters: _showFilters,
            toolbar: _error == null
                ? null
                : Row(children: [
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.red))),
                    TextButton(
                        onPressed: _refresh,
                        child: Text('party_accounts.retry'.tr))
                  ]),
            tableScrollController: _table,
            tableMinWidth: 1080,
            isLoading: _loading,
            items: _rows,
            columns: [
              TableColumnDef(
                  label: 'party_accounts.col_no'.tr,
                  flex: .5,
                  cellBuilder: (_, i) => TableCells.text('$i')),
              TableColumnDef(
                  label: 'party_accounts.col_name'.tr,
                  flex: 2,
                  cellBuilder: (r, _) => TableCells.identity(
                      r.customerName ?? 'party_accounts.no_name'.tr)),
              TableColumnDef(
                  label: 'party_accounts.date'.tr,
                  cellBuilder: (r, _) => TableCells.text(r.date ?? '')),
              TableColumnDef(
                  label: 'party_accounts.amount'.tr,
                  flex: 1.2,
                  cellBuilder: (r, _) => TableCells.text(_money(r))),
              TableColumnDef(
                  label: 'party_accounts.reference_id'.tr,
                  flex: 1.8,
                  cellBuilder: (r, _) => _ref(r)),
              TableColumnDef(
                  label: 'party_accounts.type'.tr,
                  cellBuilder: (r, _) => _typeBadge(r)),
              TableColumnDef(
                  label: 'party_accounts.status'.tr,
                  cellBuilder: (r, _) => _statusBadge(r)),
              TableColumnDef(
                  label: 'party_accounts.col_action'.tr,
                  cellBuilder: (r, _) =>
                      TableCells.viewButton(() => _showTransactionDetails(r))),
            ],
            cardBuilder: _card,
            emptyState:
                Center(child: Text('party_accounts.no_transactions'.tr)),
            onRefresh: _refresh,
            currentPage: _page,
            totalPages: _pages,
            itemsPerPage: 20,
            countLabel: 'party_accounts.page_count'
                .trParams({'count': '${_rows.length}'}),
            onPageChanged: (p) {
              if (!_loading) {
                _cancelPending();
                _fetch(page: p);
              }
            },
          ));

  void _showTransactionDetails(ListTransaction transaction) {
    final masterData = context.read<MasterDataProvider>();
    final paymentId = int.tryParse(transaction.paymentMethod ?? '');
    final paymentLabel = (paymentId != null
            ? masterData.getPaymentMethodValue(paymentId)
            : null) ??
        transaction.paymentMethod ??
        'party_accounts.na'.tr;

    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'party_accounts.dialog_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.customer_name'.tr,
                transaction.customerName ?? 'party_accounts.no_name'.tr),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.date'.tr,
                transaction.date ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.type'.tr,
                UiCodeLabels.documentKind(
                    transaction.type ?? 'party_accounts.na'.tr)),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.transaction_type'.tr,
                UiCodeLabels.documentKind(
                    transaction.transactionType ?? 'party_accounts.na'.tr)),
            CommonDetailsDialog.buildKeyValueRow(
              'party_accounts.payment_method'.tr,
              paymentLabel,
            ),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('party_accounts.amount'.tr,
                '${transaction.currency ?? ''} ${transaction.amount ?? ''}'),
            CommonDetailsDialog.buildKeyValueRow(
                'party_accounts.reference_id'.tr,
                transaction.referenceId ?? 'party_accounts.na'.tr,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.reference'.tr,
                transaction.reference ?? 'party_accounts.na'.tr,
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.status'.tr,
                transaction.status ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow('party_accounts.comment'.tr,
                transaction.transactionComment ?? 'party_accounts.na'.tr),
            CommonDetailsDialog.buildKeyValueRow(
              'party_accounts.created_at'.tr,
              transaction.createdAt != null
                  ? DateHelper.formatDate(transaction.createdAt!)
                  : 'party_accounts.na'.tr,
            ),
          ],
        ],
      ),
    );
  }
}
