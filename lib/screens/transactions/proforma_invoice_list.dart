import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../components/export_share_button.dart';
import '../../core/ui/app_surface.dart';
import '../../core/ui/list_page/filter_panel.dart';
import '../../core/ui/list_page/list_page_header.dart';
import '../../core/ui/list_page/list_page_scaffold.dart';
import '../../services/list_excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import '../../components/filter_toggle_button.dart';

import '../../providers/auth_model.dart';
import '../../providers/quotations_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/common_details_dialog.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

@visibleForTesting
const double proformaMobileBreakpoint = 700;

@visibleForTesting
bool useProformaMobileLayout(double width) {
  return width < proformaMobileBreakpoint;
}

class ProformaInvoiceListScreen extends StatefulWidget {
  const ProformaInvoiceListScreen({super.key});

  @override
  State<ProformaInvoiceListScreen> createState() =>
      _ProformaInvoiceListScreenState();
}

class _ProformaInvoiceListScreenState extends State<ProformaInvoiceListScreen> {
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  String _selectedStatus = 'All';
  bool _isLoading = false;
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  int _requestGeneration = 0;
  final _invoiceKey = GlobalKey<TextFilterFieldState>();
  final _customerKey = GlobalKey<TextFilterFieldState>();
  final _tableController = ScrollController();
  final _exportProgress = ValueNotifier<String?>(null);
  Map<String, String> _loadedFilters = {};
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  List<Map<String, dynamic>> _invoices = [];

  final List<String> _statusOptions = const [
    'All',
    'pending',
    'paid',
    'overdue',
    'order created',
  ];

  String _getStatusLabel(String value) {
    switch (value) {
      case 'All':
        return 'proforma_invoice.status_all'.tr;
      case 'pending':
        return 'proforma_invoice.status_pending'.tr;
      case 'paid':
        return 'proforma_invoice.status_paid'.tr;
      case 'overdue':
        return 'proforma_invoice.status_overdue'.tr;
      case 'order created':
        return 'proforma_invoice.status_order_created'.tr;
      default:
        return UiCodeLabels.status(value);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchInvoices();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobile;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _tableController.dispose();
    _exportProgress.dispose();
    _invoiceNumberController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  Map<String, String> _filtersSnapshot() => {
        if (_invoiceNumberController.text.trim().isNotEmpty)
          'invoice_number': _invoiceNumberController.text.trim(),
        if (_customerSearchController.text.trim().isNotEmpty)
          'customer_search': _customerSearchController.text.trim(),
        if (_selectedStatus != 'All') 'status': _selectedStatus,
      };

  ({List<Map<String, dynamic>> rows, int current, int last, int? total})
      _parsePage(Map<String, dynamic> response, int requestedPage) {
    final data = response['data'];
    if (data is! Map || data['data'] is! List) {
      throw const FormatException('Invalid proforma invoice response');
    }
    final current = _parseInt(data['current_page']);
    final last = _parseInt(data['last_page']);
    final total = data.containsKey('total') ? _parseInt(data['total']) : null;
    if (data.containsKey('total') && (total == null || total < 0)) {
      throw const FormatException('Invalid proforma total');
    }
    if (current != requestedPage ||
        last == null ||
        last < current! ||
        last < 1) {
      throw const FormatException('Invalid proforma pagination');
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in data['data'] as List) {
      if (item is! Map) {
        throw const FormatException('Invalid proforma invoice row');
      }
      rows.add(Map<String, dynamic>.from(item));
    }
    if (rows.isEmpty && (current > 1 || current < last || (total ?? 0) > 0)) {
      throw const FormatException('Missing proforma invoice page');
    }
    return (rows: rows, current: current, last: last, total: total);
  }

  Future<void> _fetchInvoices(
      {int page = 1, Map<String, String>? filters}) async {
    if (!mounted) return;
    final request = ++_requestGeneration;
    final snapshot = filters ?? _filtersSnapshot();
    final provider = context.read<QuotationsProvider>();
    final token = context.read<AuthModel>().token ?? '';
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await provider.fetchProformaInvoices(
          accessToken: token,
          filters: {
            ...snapshot,
            'page': '$page',
            'per_page': '20'
          }).timeout(const Duration(seconds: 30));
      final result = _parsePage(response, page);
      if (!mounted || request != _requestGeneration) return;
      setState(() {
        _invoices = result.rows;
        _currentPage = result.current;
        _lastPage = result.last;
        _loadedFilters = Map.of(snapshot);
      });
    } catch (error) {
      if (mounted && request == _requestGeneration) {
        setState(() => _errorMessage = '$error');
      }
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelPendingSearches() {
    _invoiceKey.currentState?.cancelPendingSearch();
    _customerKey.currentState?.cancelPendingSearch();
  }

  Future<void> _refreshInvoices() {
    _cancelPendingSearches();
    return _fetchInvoices(
        page: mapEquals(_filtersSnapshot(), _loadedFilters) ? _currentPage : 1);
  }

  Future<File> _createExport() async {
    _cancelPendingSearches();
    final snapshot = _filtersSnapshot();
    final provider = context.read<QuotationsProvider>();
    final token = context.read<AuthModel>().token ?? '';
    if (!mapEquals(snapshot, _loadedFilters)) {
      await _fetchInvoices(filters: snapshot);
      if (!mounted || _errorMessage != null) {
        throw StateError('Could not apply proforma filters');
      }
    }
    final items = <Map<String, dynamic>>[];
    final ids = <int>{};
    int last = 1;
    int? expectedTotal;
    for (int page = 1; page <= last; page++) {
      if (mounted) {
        _exportProgress.value = 'proforma_invoice.export_fetching'
            .trParams({'page': '$page', 'total': '$last'});
      }
      final response = await provider.fetchProformaInvoices(
          accessToken: token,
          filters: {
            ...snapshot,
            'page': '$page',
            'per_page': '1000'
          }).timeout(const Duration(seconds: 30));
      final result = _parsePage(response, page);
      if (page > 1 && (result.last != last || result.total != expectedTotal)) {
        throw const FormatException(
            'Proforma pagination changed during export');
      }
      last = result.last;
      expectedTotal = result.total;
      for (final row in result.rows) {
        final id = _parseInt(row['id']);
        if (id == null || id <= 0) {
          throw const FormatException('Invalid proforma invoice ID');
        }
        if (!ids.add(id)) {
          throw const FormatException('Duplicate proforma invoice rows');
        }
        items.add(row);
      }
    }
    if (expectedTotal != null && items.length != expectedTotal) {
      throw const FormatException(
          'Proforma export count does not match API total');
    }
    if (mounted) _exportProgress.value = 'proforma_invoice.export_creating'.tr;
    return ListExcelExportService.export<Map<String, dynamic>>(
        items: items,
        fileNamePrefix: 'proforma-invoices',
        sheetName: 'proforma_invoice.title'.tr,
        columns: [
          ListExportColumn(
              label: 'proforma_invoice.invoice_number_label'.tr,
              value: (v, _) => _text(v['invoice_number'])),
          ListExportColumn(
              label: 'proforma_invoice.customer_label'.tr,
              value: (v, _) => _text(_mapValue(v['customer'])['name'])),
          ListExportColumn(
              label: 'proforma_invoice.field_quotation_number'.tr,
              value: (v, _) =>
                  _text(_mapValue(v['quotation'])['quotation_number'])),
          ListExportColumn(
              label: 'proforma_invoice.field_invoice_date'.tr,
              value: (v, _) => _text(v['invoice_date'])),
          ListExportColumn(
              label: 'proforma_invoice.field_due_date'.tr,
              value: (v, _) => _text(v['due_date'])),
          ListExportColumn(
              label: 'proforma_invoice.field_amount'.tr,
              value: (v, _) =>
                  ListExcelExportService.numericValue(v['amount']?.toString())),
          ListExportColumn(
              label: 'proforma_invoice.status_label'.tr,
              value: (v, _) => _getStatusLabel(_text(v['status']))),
        ]);
  }

  void _resetFilters() {
    _cancelPendingSearches();
    setState(() {
      _invoiceNumberController.clear();
      _customerSearchController.clear();
      _selectedStatus = 'All';
      _currentPage = 1;
    });
    _fetchInvoices();
  }

  Future<void> _showDetails(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'];
    if (invoiceId == null) {
      showScaffoldError(
          context: context,
          message: 'proforma_invoice.invoice_id_not_found'.tr);
      return;
    }

    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final response = await Provider.of<QuotationsProvider>(
        context,
        listen: false,
      ).fetchProformaInvoiceDetails(
        accessToken: authProvider.token ?? '',
        invoiceId: invoiceId,
      );
      if (!mounted) return;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _openDetailsDialog(data);
      } else if (data is Map) {
        _openDetailsDialog(Map<String, dynamic>.from(data));
      } else {
        showScaffoldError(
            context: context, message: 'proforma_invoice.details_not_found'.tr);
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
            context: context,
            message: 'proforma_invoice.failed_load_details'.tr);
      }
    }
  }

  void _openDetailsDialog(Map<String, dynamic> data) {
    final customer = _mapValue(data['customer']);
    final quotation = _mapValue(data['quotation']);
    final items = data['items'] is List ? data['items'] as List : const [];

    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'proforma_invoice.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.invoice_number_label'.tr,
                _text(data['invoice_number']),
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.status_label'.tr,
                UiCodeLabels.status(_text(data['status']))),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.field_amount'.tr, _text(data['amount'])),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.field_invoice_date'.tr,
                _text(data['invoice_date'])),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.field_due_date'.tr, _text(data['due_date'])),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.customer_label'.tr, _text(customer['name'])),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.field_phone'.tr, _text(customer['phone']),
                copyable: true),
            CommonDetailsDialog.buildKeyValueRow(
                'proforma_invoice.field_quotation_number'.tr,
                _text(quotation['quotation_number'])),
          ],
        ],
        sectionTitle: 'proforma_invoice.items_title'.tr,
        tableContent: items.isEmpty
            ? Center(child: Text('proforma_invoice.no_items_found'.tr))
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.4),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  _detailsHeaderRow(),
                  ...items.map((item) {
                    final row = _mapValue(item);
                    return TableRow(
                      children: [
                        _dialogCell(_text(row['item_name'])),
                        _dialogCell(_text(row['quantity'])),
                        _dialogCell(_text(row['unit_amount'])),
                        _dialogCell(_text(row['total_amount'])),
                      ],
                    );
                  }),
                ],
              ),
      ),
    );
  }

  TableRow _detailsHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _StaticTableCell('proforma_invoice.col_item'.tr),
        _StaticTableCell('proforma_invoice.col_qty'.tr),
        _StaticTableCell('proforma_invoice.col_unit_amount'.tr),
        _StaticTableCell('proforma_invoice.col_total'.tr),
      ],
    );
  }

  Widget _dialogCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  bool get _hasActiveFilters => _filtersSnapshot().isNotEmpty;
  Widget _filters() => FilterPanel(
        key: const ValueKey('proforma-desktop-filters'),
        title: 'proforma_invoice.find'.tr,
        hint: 'proforma_invoice.filter_hint'.tr,
        onReset: _resetFilters,
        fields: [
          TextFilterField(
              key: _invoiceKey,
              controller: _invoiceNumberController,
              label: 'proforma_invoice.search_invoice_number_hint'.tr,
              icon: Icons.receipt_long_outlined,
              onSearch: () => _fetchInvoices()),
          TextFilterField(
              key: _customerKey,
              controller: _customerSearchController,
              label: 'proforma_invoice.name_or_phone_hint'.tr,
              icon: Icons.person_outline,
              onSearch: () => _fetchInvoices()),
          DropdownButtonFormField<String>(
              key: ValueKey(_selectedStatus),
              initialValue: _selectedStatus,
              isExpanded: true,
              decoration: listFilterDecoration(
                  'proforma_invoice.status_label'.tr,
                  Icons.check_circle_outline),
              items: [
                for (final status in _statusOptions)
                  DropdownMenuItem(
                      value: status, child: Text(_getStatusLabel(status)))
              ],
              onChanged: (value) {
                _cancelPendingSearches();
                setState(() => _selectedStatus = value ?? 'All');
                _fetchInvoices();
              }),
        ],
      );
  Widget _reference(dynamic value, {required bool quotation}) {
    final text = _text(value);
    return Row(children: [
      Expanded(child: TableCells.text(text)),
      if (text != '-')
        IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: (quotation
                    ? 'proforma_invoice.copy_quotation'
                    : 'proforma_invoice.copy_invoice')
                .tr,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showScaffold(
                  context: context,
                  message: (quotation
                          ? 'proforma_invoice.quotation_number_copied'
                          : 'proforma_invoice.invoice_number_copied')
                      .tr);
            })
    ]);
  }

  Widget _status(String status) {
    final color = _statusColor(status);
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_getStatusLabel(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))));
  }

  Widget _card(Map<String, dynamic> invoice, int number) => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableCells.identity(_text(_mapValue(invoice['customer'])['name'])),
        const SizedBox(height: 10),
        _reference(invoice['invoice_number'], quotation: false),
        _reference(_mapValue(invoice['quotation'])['quotation_number'],
            quotation: true),
        Text(
            '${'proforma_invoice.field_invoice_date'.tr}: ${_text(invoice['invoice_date'])}'),
        Text(
            '${'proforma_invoice.field_due_date'.tr}: ${_text(invoice['due_date'])}'),
        Text(
            '${'proforma_invoice.field_amount'.tr}: ${_text(invoice['amount'])}'),
        const SizedBox(height: 10),
        _status(_text(invoice['status'])),
        const SizedBox(height: 10),
        TableCells.viewButton(() => _showDetails(invoice)),
      ]));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, bounds) => ListPageScaffold<Map<String, dynamic>>(
            header: ListPageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'proforma_invoice.title'.tr,
                subtitle: 'proforma_invoice.subtitle'.tr,
                onRefresh: _refreshInvoices,
                extraActions: [
                  FilterToggleButton(
                      showFilters: _showFilters,
                      hasActiveFilters: _hasActiveFilters,
                      activeFiltersListenable: Listenable.merge([
                        _invoiceNumberController,
                        _customerSearchController
                      ]),
                      activeFiltersBuilder: () => _hasActiveFilters,
                      showTooltip: 'proforma_invoice.show_filters'.tr,
                      hideTooltip: 'proforma_invoice.hide_filters'.tr,
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters)),
                  ExportShareButton(
                      createFile: _createExport,
                      label: 'supplier_transactions.export'.tr,
                      loadingLabel: 'proforma_invoice.export_creating'.tr,
                      progressLabel: _exportProgress,
                      tooltip: 'proforma_invoice.export_tooltip'.tr,
                      errorMessage: 'proforma_invoice.export_failed'.tr,
                      enabled: !_isLoading &&
                          _errorMessage == null &&
                          _invoices.isNotEmpty,
                      compact: bounds.maxWidth < ListLayoutBreakpoints.header,
                      mimeType:
                          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                ]),
            filters: _filters(),
            showFilters: _showFilters,
            isLoading: _isLoading,
            items: _invoices,
            toolbar: _errorMessage == null
                ? null
                : AppSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text('proforma_invoice.stale_rows_warning'.tr,
                            style: const TextStyle(
                                color: ColorManager.kButtonRed)),
                        TextButton.icon(
                            onPressed: () => _fetchInvoices(),
                            icon: const Icon(Icons.refresh),
                            label: Text('proforma_invoice.retry'.tr))
                      ])),
            tableMinWidth: 1250,
            tableScrollController: _tableController,
            columns: [
              TableColumnDef(
                  label: 'proforma_invoice.invoice_number_label'.tr,
                  flex: 1.7,
                  cellBuilder: (v, _) =>
                      _reference(v['invoice_number'], quotation: false)),
              TableColumnDef(
                  label: 'proforma_invoice.customer_label'.tr,
                  flex: 2,
                  cellBuilder: (v, _) => TableCells.identity(
                      _text(_mapValue(v['customer'])['name']))),
              TableColumnDef(
                  label: 'proforma_invoice.field_quotation_number'.tr,
                  flex: 1.7,
                  cellBuilder: (v, _) => _reference(
                      _mapValue(v['quotation'])['quotation_number'],
                      quotation: true)),
              TableColumnDef(
                  label: 'proforma_invoice.field_invoice_date'.tr,
                  flex: 1.3,
                  cellBuilder: (v, _) =>
                      TableCells.text(_text(v['invoice_date']))),
              TableColumnDef(
                  label: 'proforma_invoice.field_due_date'.tr,
                  flex: 1.3,
                  cellBuilder: (v, _) => TableCells.text(_text(v['due_date']))),
              TableColumnDef(
                  label: 'proforma_invoice.field_amount'.tr,
                  flex: 1.2,
                  cellBuilder: (v, _) => TableCells.text(_text(v['amount']))),
              TableColumnDef(
                  label: 'proforma_invoice.status_label'.tr,
                  flex: 1.4,
                  cellBuilder: (v, _) => _status(_text(v['status']))),
              TableColumnDef(
                  label: 'proforma_invoice.col_actions'.tr,
                  flex: 1.1,
                  cellBuilder: (v, _) =>
                      TableCells.viewButton(() => _showDetails(v))),
            ],
            cardBuilder: _card,
            emptyState:
                Center(child: Text('proforma_invoice.no_invoices_found'.tr)),
            onRefresh: _refreshInvoices,
            currentPage: _currentPage,
            totalPages: _lastPage,
            itemsPerPage: 20,
            countLabel: 'proforma_invoice.page_count'
                .trParams({'count': '${_invoices.length}'}),
            onPageChanged: (page) {
              _cancelPendingSearches();
              _fetchInvoices(
                  page:
                      mapEquals(_filtersSnapshot(), _loadedFilters) ? page : 1);
            },
          ));
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'order created':
        return Colors.green;
      case 'overdue':
        return ColorManager.kButtonRed;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? '-' : text;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _StaticTableCell extends StatelessWidget {
  final String text;

  const _StaticTableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }
}
