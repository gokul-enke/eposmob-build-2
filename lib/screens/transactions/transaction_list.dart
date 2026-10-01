import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:provider/provider.dart';

import '../../helpers/date_helper.dart';
import '../../helpers/ui_code_labels.dart';
import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/master_data_provider.dart';
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
  const CustomerTransactionListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const desktopFiltersKey =
      ValueKey('customer-transactions-desktop-filters');
  static const mobileFiltersKey =
      ValueKey('customer-transactions-mobile-filters');
  static const filterToggleKey =
      ValueKey('customer-transactions-filter-toggle');
  static const exportKey = ValueKey('customer-transactions-export');
  static const refreshKey = ValueKey('customer-transactions-refresh');
  static const dateFieldKey = ValueKey('customer-transactions-date');

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
  late final SearchDebouncer _search = SearchDebouncer(() {
    if (mounted) _fetch();
  });
  late final ExportController _exporter = widget.export ?? ExportController();
  final _table = ScrollController();
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
    _search.dispose();
    if (widget.export == null) _exporter.dispose();
    _amount.dispose();
    _name.dispose();
    _reference.dispose();
    _nameFocus.dispose();
    _table.dispose();
    super.dispose();
  }

  void _cancelPending() => _search.cancel();

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

  Future<void> _runExport() async {
    final exported = await _exporter.run(context, createFile: _export);
    if (!exported && mounted) {
      AppToast.error(context, 'party_accounts.export_error'.tr);
    }
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
              _exporter.setStage('party_accounts.export_fetching'
                  .trParams({'page': '$p', 'total': '$last'}));
            }
          });
    if (!mounted) throw StateError('Customer ledger screen closed.');
    final rows = _match(all, f);
    for (final row in rows) {
      payment(row);
    }
    _exporter.setStage('supplier_transactions.export_creating'.tr);
    return ListExcelExportService.export<ListTransaction>(
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
  Widget _typeBadge(ListTransaction r) => AppBadge(
      label: _typeLabel(r.type),
      tone: switch (r.type?.toLowerCase()) {
        'credit' => AppBadgeTone.success,
        'debit' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral
      });
  Widget _statusBadge(ListTransaction r) => AppBadge(
      label: _statusLabel(r.status),
      tone: switch (r.status?.toUpperCase()) {
        'SUCC' || 'SUCCESS' => AppBadgeTone.success,
        'FAIL' || 'FAILED' => AppBadgeTone.danger,
        'INIT' || 'INITIATED' => AppBadgeTone.warning,
        _ => AppBadgeTone.neutral
      });
  String _money(ListTransaction r) =>
      '${r.currency ?? ''} ${double.parse(r.amount!).toStringAsFixed(3)}'
          .trim();

  /// Blank values show as a dash, as in the other list columns.
  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  Widget? _copyButton(ListTransaction r) => r.referenceId?.isNotEmpty == true
      ? IconButton(
          tooltip: 'party_accounts.ref_copied'.tr,
          icon: const Icon(Icons.copy_outlined, size: 16),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: r.referenceId!));
            if (mounted) {
              AppToast.success(context, 'party_accounts.ref_copied'.tr);
            }
          })
      : null;

  Widget _ref(ListTransaction r) {
    final copy = _copyButton(r);
    return Row(children: [
      Expanded(child: TableCells.text(_orDash(r.referenceId))),
      if (copy != null) copy,
    ]);
  }

  FilterFieldDef _customerField() => CustomFilterField(
      child: RawAutocomplete<ListTransaction>(
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
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: AppTextStyles.input,
              decoration: AppInputDecoration.filter(
                  label: 'party_accounts.customer_name'.tr,
                  icon: Icons.person_outline),
              onChanged: (_) {
                _customerId = null;
                _search.schedule();
              },
              onSubmitted: (_) => _search.flush()),
          optionsViewBuilder: (_, select, options) => Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                  elevation: 4,
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: SizedBox(
                      width: 280,
                      height: 200,
                      child: ListView(children: [
                        for (final r in options)
                          ListTile(
                              title: Text(r.customerName ?? ''),
                              onTap: () => select(r))
                      ]))))));

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

  FilterFieldDef _dateField() => CustomFilterField(
      child: InkWell(
          key: CustomerTransactionListScreen.dateFieldKey,
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: _pickDate,
          child: InputDecorator(
              textAlignVertical: TextAlignVertical.center,
              decoration: AppInputDecoration.filter(
                  label: 'party_accounts.date'.tr,
                  icon: Icons.calendar_today_outlined),
              child: Text(
                  _date == null
                      ? 'party_accounts.select_date'.tr
                      : DateFormat('MMM dd, yyyy').format(_date!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.input))));

  FilterPanel _filtersPanel(bool mobile) => FilterPanel(
          key: mobile
              ? CustomerTransactionListScreen.mobileFiltersKey
              : CustomerTransactionListScreen.desktopFiltersKey,
          title: 'party_accounts.find'.tr,
          hint: 'party_accounts.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: _search.schedule,
          onSubmit: _search.flush,
          onReset: _reset,
          fields: [
            TextFilterField(
                controller: _amount,
                label: 'party_accounts.amount'.tr,
                hint: 'party_accounts.amount'.tr,
                icon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            _customerField(),
            DropdownFilterField<String>(
                label: 'party_accounts.type'.tr,
                icon: Icons.swap_vert,
                value: _type,
                options: [
                  for (final t in ['All', 'Credit', 'Debit'])
                    FilterOption(
                        t, t == 'All' ? 'common.all'.tr : _typeLabel(t)),
                ],
                onChanged: (v) {
                  _cancelPending();
                  setState(() => _type = v ?? 'All');
                  _fetch();
                }),
            TextFilterField(
                controller: _reference,
                label: 'party_accounts.reference_id'.tr,
                hint: 'party_accounts.reference_id'.tr,
                icon: Icons.tag),
            _dateField(),
          ]);

  Widget _card(ListTransaction r, int index) => AppListCard(
        leading: AppAvatar(
            name: r.customerName ?? '',
            semanticLabel: r.customerName ?? 'party_accounts.no_name'.tr,
            size: 42),
        title: r.customerName ?? 'party_accounts.no_name'.tr,
        subtitle: '#$index · ${_orDash(r.date)}',
        trailing: _statusBadge(r),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'party_accounts.amount'.tr,
                  value: _money(r)),
              AppMetric(
                  icon: Icons.swap_vert,
                  label: 'party_accounts.type'.tr,
                  value: _typeLabel(r.type)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
                icon: Icons.tag,
                label: 'party_accounts.reference_id'.tr,
                value: _orDash(r.referenceId),
                trailing: _copyButton(r)),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => _showTransactionDetails(r),
      );

  List<TableColumnDef<ListTransaction>> get _columns => [
        TableColumnDef(
            label: 'party_accounts.col_no'.tr,
            flex: .5,
            align: TextAlign.center,
            cellBuilder: (_, i) => TableCells.number(i)),
        TableColumnDef(
            label: 'party_accounts.col_name'.tr,
            flex: 2,
            cellBuilder: (r, _) => TableCells.avatarName(
                name: r.customerName ?? 'party_accounts.no_name'.tr,
                avatar: AppAvatar(
                    name: r.customerName ?? '',
                    semanticLabel:
                        r.customerName ?? 'party_accounts.no_name'.tr,
                    size: 36))),
        TableColumnDef(
            label: 'party_accounts.date'.tr,
            cellBuilder: (r, _) => TableCells.text(_orDash(r.date))),
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
            cellBuilder: (r, _) => TableCells.widget(_typeBadge(r))),
        TableColumnDef(
            label: 'party_accounts.status'.tr,
            cellBuilder: (r, _) => TableCells.widget(_statusBadge(r))),
        TableColumnDef(
            label: 'party_accounts.col_action'.tr,
            cellBuilder: (r, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => _showTransactionDetails(r))),
      ];

  bool get _hasActiveFilters =>
      _amount.text.trim().isNotEmpty ||
      _name.text.trim().isNotEmpty ||
      _reference.text.trim().isNotEmpty ||
      _date != null ||
      _type != 'All';

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> get _headerActions => [
        HeaderAction(
          key: CustomerTransactionListScreen.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'party_accounts.hide_filters'.tr
              : 'party_accounts.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: _hasActiveFilters,
        ),
        HeaderAction(
          key: CustomerTransactionListScreen.exportKey,
          icon: Icons.ios_share_rounded,
          label: _exporter.busy
              ? (_exporter.stage ?? 'supplier_transactions.export_creating'.tr)
              : 'party_accounts.export_tooltip'.tr,
          onPressed: !_loading && _error == null && _loaded != null
              ? _runExport
              : null,
          busy: _exporter.busy,
        ),
        HeaderAction(
          key: CustomerTransactionListScreen.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: _refresh,
        ),
      ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, size) => ListenableBuilder(
            // Rebuilds the filter badge while typing and the export progress.
            listenable:
                Listenable.merge([_exporter, _amount, _name, _reference]),
            builder: (context, _) => ListPageScaffold<ListTransaction>(
              header: PageHeader(
                icon: Icons.swap_horiz,
                title: 'party_accounts.title'.tr,
                subtitle: 'party_accounts.subtitle'.tr,
                actions: _headerActions,
              ),
              filters: _filtersPanel(
                  size.maxWidth < ListLayoutBreakpoints.mobileBelow),
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
              minTableWidth: 1080,
              isLoading: _loading,
              items: _rows,
              columns: _columns,
              cardBuilder: _card,
              emptyState: AppEmptyState(
                icon: Icons.swap_horiz,
                title: 'party_accounts.no_transactions'.tr,
                subtitle: 'party_accounts.no_transactions_hint'.tr,
              ),
              onRefresh: _refresh,
              pagination: ListPagination(
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
              ),
            ),
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
