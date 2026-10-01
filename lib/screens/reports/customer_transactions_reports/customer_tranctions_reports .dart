// ignore_for_file: file_names
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../components/export_share_button.dart';
import '../../../components/filter_toggle_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_surface.dart';
import '../../../core/ui/list_page/filter_panel.dart';
import '../../../core/ui/list_page/list_page_header.dart';
import '../../../core/ui/list_page/list_page_scaffold.dart';
import '../../../models/customer_list.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/invoice_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../services/customer_report_snapshot.dart';
import '../../../services/list_excel_export_service.dart';

typedef _Filters = ({String? customer, String? from, String? to});

class CustomerTransactionsReportScreen extends StatefulWidget {
  const CustomerTransactionsReportScreen({super.key});
  @override
  State<CustomerTransactionsReportScreen> createState() => _ReportState();
}

class _ReportState extends State<CustomerTransactionsReportScreen> {
  final _from = TextEditingController(), _to = TextEditingController();
  final _table = ScrollController();
  final _progress = ValueNotifier<String?>(null);
  bool _showFilters = true, _loading = false;
  int _request = 0, _page = 1, _pages = 1, _perPage = 20, _requestedPage = 1;
  String? _error;
  _Filters? _loaded;
  List<CustomerReportRow> _rows = [];
  _Filters get _filters => (
        customer: context.read<CustomerProvider>().selectedCustomerId,
        from: _from.text.isEmpty ? null : _from.text,
        to: _to.text.isEmpty ? null : _to.text
      );
  String tr(String key) => 'customer_transaction_report.$key'.tr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showFilters = MediaQuery.sizeOf(context).width >= 768);
      _fetch();
      _loadCustomers();
    });
  }

  Future<void> _loadCustomers() async {
    final customers = context.read<CustomerProvider>();
    final token = context.read<AuthModel>().token ?? '';
    try {
      await customers.fetchCustomers(accessToken: token, listAll: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('customer_load_error'))));
      }
    }
  }

  @override
  void dispose() {
    _request++;
    _from.dispose();
    _to.dispose();
    _table.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<dynamic> _get(
          InvoiceProvider provider, String token, _Filters filters, int page) =>
      provider.listAllTransaction(
          accessToken: token,
          customerId: filters.customer,
          dateFrom: filters.from,
          dateTo: filters.to,
          page: page,
          updateState: false);

  Future<void> _fetch([int page = 1]) async {
    final filters = _filters, request = ++_request;
    _requestedPage = page;
    final from = DateTime.tryParse(filters.from ?? ''),
        to = DateTime.tryParse(filters.to ?? '');
    if (from != null && to != null && from.isAfter(to)) {
      setState(() {
        _loading = false;
        _error = tr('from_date_after_to_date');
      });
      return;
    }
    final provider = context.read<InvoiceProvider>(),
        token = context.read<AuthModel>().token ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = CustomerReportPage.parse(
          await _get(provider, token, filters, page), page);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = result.rows;
        _page = result.current;
        _pages = result.last;
        _perPage = result.perPage;
        _loaded = filters;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = tr('load_error'));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_fetch(), _loadCustomers()]);
  }

  void _reset() {
    _from.clear();
    _to.clear();
    final customers = context.read<CustomerProvider>();
    customers.setSelectedCustomerId(null);
    customers.setSelectedCustomerName(null);
    _fetch();
  }

  Future<void> _date(bool from) async {
    final controller = from ? _from : _to;
    final previous = DateTime.tryParse(controller.text) ?? DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: previous,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (!mounted || date == null) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(previous));
    if (!mounted || time == null) return;
    setState(() => controller.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime(date.year, date.month, date.day, time.hour, time.minute)));
    await _fetch();
  }

  Widget _dateField(bool from) => TextFormField(
      key: ValueKey(from ? 'customer-report-from' : 'customer-report-to'),
      controller: from ? _from : _to,
      readOnly: true,
      onTap: () => _date(from),
      decoration: listFilterDecoration(
          tr(from ? 'from_date' : 'to_date'), Icons.calendar_today_outlined));
  bool get _canExport =>
      !_loading && _error == null && _rows.isNotEmpty && _loaded == _filters;
  Future<File> _export() async {
    if (!_canExport) throw StateError('Customer report is unavailable.');
    final filters = _loaded!;
    final provider = context.read<InvoiceProvider>(),
        token = context.read<AuthModel>().token ?? '';
    final labels = [
      'customer_id',
      'customer_name_col',
      'total_debit_col',
      'total_credit_col',
      'balance',
      'transactions'
    ].map(tr).toList();
    final unknown = tr('unknown_customer');
    try {
      final rows = await fetchCustomerReportSnapshot(
          (page) => _get(provider, token, filters, page),
          progress: (page, total) {
        if (mounted) {
          _progress.value = tr('export_fetching')
              .replaceAll('@page', '$page')
              .replaceAll('@total', '$total');
        }
      });
      return await ListExcelExportService.export<CustomerReportRow>(
          items: rows,
          fileNamePrefix: 'customer-transactions-report',
          sheetName: 'Customer Transactions',
          columns: [
            ListExportColumn(label: labels[0], value: (r, _) => r.id ?? ''),
            ListExportColumn(
                label: labels[1],
                value: (r, _) => r.name.isEmpty ? unknown : r.name),
            ListExportColumn(label: labels[2], value: (r, _) => r.debit),
            ListExportColumn(label: labels[3], value: (r, _) => r.credit),
            ListExportColumn(label: labels[4], value: (r, _) => r.balance),
            ListExportColumn(label: labels[5], value: (r, _) => r.count)
          ]);
    } finally {
      if (mounted) _progress.value = null;
    }
  }

  String _name(CustomerReportRow row) =>
      row.name.isEmpty ? tr('unknown_customer') : row.name;
  void _view(CustomerReportRow row) {
    // Details use the ID to distinguish customers with identical names.
    final customers = context.read<CustomerProvider>();
    customers.setSelectedCustomerId(row.id);
    customers.setSelectedCustomerName(_name(row));
    context.read<TransactionProvider>().setCustomerName(_name(row));
    Get.put(SideBarController()).index.value = 66;
  }

  Widget _card(CustomerReportRow row, int _) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(_name(row)),
        const SizedBox(height: 12),
        Text('${tr('total_debit_col')}: ${row.debit.toStringAsFixed(2)}'),
        Text('${tr('total_credit_col')}: ${row.credit.toStringAsFixed(2)}'),
        Row(children: [
          Text('${tr('balance')}: '),
          TableCells.amount(row.balance)
        ]),
        Text('${tr('transactions')}: ${row.count}'),
        const SizedBox(height: 8),
        TableCells.viewButton(() => _view(row))
      ]));
  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>();
    final items = customers.allCustomers ?? <CustomerListModelData>[];
    CustomerListModelData? selected;
    for (final item in items) {
      if (item.id?.toString() == customers.selectedCustomerId) selected = item;
    }
    return LayoutBuilder(
        builder: (context, size) => ListPageScaffold<CustomerReportRow>(
            header: ListPageHeader(
                icon: Icons.people_alt_outlined,
                title: tr('title'),
                subtitle: tr('subtitle'),
                onRefresh: _refresh,
                extraActions: [
                  FilterToggleButton(
                      key: const ValueKey(
                          'customer-transactions-report-filter-toggle'),
                      showFilters: _showFilters,
                      hasActiveFilters: _filters.customer != null ||
                          _filters.from != null ||
                          _filters.to != null,
                      activeFiltersListenable: Listenable.merge([_from, _to]),
                      activeFiltersBuilder: () =>
                          _filters.customer != null ||
                          _filters.from != null ||
                          _filters.to != null,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      showTooltip: tr('filters'),
                      hideTooltip: tr('hide')),
                  ExportShareButton(
                      key: const ValueKey('customer-report-export'),
                      createFile: _export,
                      label: 'supplier_transactions.export'.tr,
                      loadingLabel: 'supplier_transactions.export_creating'.tr,
                      tooltip: tr('export_tooltip'),
                      errorMessage: tr('export_error'),
                      progressLabel: _progress,
                      enabled: _canExport,
                      compact: size.maxWidth < 560,
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
                ]),
            filters: FilterPanel(
                key: const ValueKey('customer-transactions-report-filters'),
                title: tr('find'),
                hint: tr('filter_hint'),
                onReset: _reset,
                fields: [
                  DropdownSearch<CustomerListModelData>(
                      items: (filter, props) => items,
                      selectedItem: selected,
                      compareFn: (a, b) => a.id == b.id,
                      itemAsString: (c) => c.name?.trim().isNotEmpty == true
                          ? c.name!
                          : tr('unknown_customer'),
                      decoratorProps: DropDownDecoratorProps(
                          decoration: listFilterDecoration(
                              tr('customer'), Icons.person_outline)),
                      suffixProps: const DropdownSuffixProps(
                          clearButtonProps: ClearButtonProps(isVisible: true)),
                      popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                              decoration: listFilterDecoration(
                                  tr('search_customer_hint'), Icons.search))),
                      onChanged: (c) {
                        customers.setSelectedCustomerId(c?.id?.toString());
                        customers.setSelectedCustomerName(c?.name);
                        _fetch();
                      }),
                  _dateField(true),
                  _dateField(false)
                ]),
            showFilters: _showFilters,
            toolbar: _error == null
                ? null
                : Row(children: [
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.red))),
                    TextButton(
                        onPressed: () => _fetch(_requestedPage),
                        child: Text(tr('retry')))
                  ]),
            tableScrollController: _table,
            tableMinWidth: 1050,
            isLoading: _loading,
            items: _rows,
            columns: [
              TableColumnDef(
                  label: tr('customer_name_col'),
                  flex: 2,
                  cellBuilder: (r, _) => TableCells.identity(_name(r))),
              TableColumnDef(
                  label: tr('total_debit_col'),
                  cellBuilder: (r, _) =>
                      TableCells.text(r.debit.toStringAsFixed(2))),
              TableColumnDef(
                  label: tr('total_credit_col'),
                  cellBuilder: (r, _) =>
                      TableCells.text(r.credit.toStringAsFixed(2))),
              TableColumnDef(
                  label: tr('balance'),
                  cellBuilder: (r, _) => TableCells.amount(r.balance)),
              TableColumnDef(
                  label: tr('transactions'),
                  cellBuilder: (r, _) => TableCells.text('${r.count}')),
              TableColumnDef(
                  label: tr('action_col'),
                  cellBuilder: (r, _) => TableCells.viewButton(() => _view(r)))
            ],
            cardBuilder: _card,
            emptyState: Center(child: Text(tr('no_customer_transactions'))),
            onRefresh: _refresh,
            currentPage: _page,
            totalPages: _pages,
            itemsPerPage: _perPage,
            countLabel: tr('count').replaceAll('@count', '${_rows.length}'),
            onPageChanged: (page) {
              if (!_loading) _fetch(page);
            }));
  }
}
