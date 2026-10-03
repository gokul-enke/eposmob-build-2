import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_model.dart';
import '../../providers/quotations_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../services/list_excel_export_service.dart';
import 'widgets/common_details_dialog.dart';

@visibleForTesting
const double proformaMobileBreakpoint = ListLayoutBreakpoints.mobileBelow;

@visibleForTesting
bool useProformaMobileLayout(double width) {
  return width < proformaMobileBreakpoint;
}

/// The proforma invoices list: header, filters, table/cards and pagination,
/// built on the shared [ListPageScaffold]. Pages come from the API.
class ProformaInvoiceListScreen extends StatefulWidget {
  const ProformaInvoiceListScreen({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('proforma-desktop-filters');
  static const filterToggleKey = ValueKey('proforma-list-filter-toggle');
  static const exportKey = ValueKey('proforma-list-export');
  static const refreshKey = ValueKey('proforma-list-refresh');

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
  late final SearchDebouncer _search = SearchDebouncer(() => _fetchInvoices());
  late final ExportController _export = widget.export ?? ExportController();
  final _tableController = ScrollController();
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
    // Filters start open on wide screens and closed on phones.
    if (!_visibilityInitialized) {
      _showFilters =
          !useProformaMobileLayout(MediaQuery.sizeOf(context).width);
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.export == null) _export.dispose();
    _tableController.dispose();
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

  /// Reloads the visible page, or page 1 when the inputs changed since it
  /// was loaded (a search was still waiting on the debounce).
  Future<void> _refreshInvoices() {
    _search.cancel();
    return _fetchInvoices(
        page: mapEquals(_filtersSnapshot(), _loadedFilters) ? _currentPage : 1);
  }

  Future<File> _createExport() async {
    _search.cancel();
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
        _export.setStage('proforma_invoice.export_fetching'
            .trParams({'page': '$page', 'total': '$last'}));
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
    if (mounted) _export.setStage('proforma_invoice.export_creating'.tr);
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

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'proforma_invoice.export_failed'.tr);
    }
  }

  void _resetFilters() {
    _search.cancel();
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
        key: ProformaInvoiceListScreen.filtersKey,
        title: 'proforma_invoice.find'.tr,
        hint: 'proforma_invoice.filter_hint'.tr,
        resetLabel: 'list.reset'.tr,
        onSearch: _search.schedule,
        onSubmit: _search.flush,
        onReset: _resetFilters,
        fields: [
          TextFilterField(
              controller: _invoiceNumberController,
              label: 'proforma_invoice.search_invoice_number_hint'.tr,
              hint: 'proforma_invoice.search_invoice_number_hint'.tr,
              icon: Icons.receipt_long_outlined),
          TextFilterField(
              controller: _customerSearchController,
              label: 'proforma_invoice.name_or_phone_hint'.tr,
              hint: 'proforma_invoice.name_or_phone_hint'.tr,
              icon: Icons.person_outline),
          DropdownFilterField<String>(
              label: 'proforma_invoice.status_label'.tr,
              icon: Icons.check_circle_outline,
              value: _selectedStatus,
              options: [
                for (final status in _statusOptions)
                  FilterOption(status, _getStatusLabel(status)),
              ],
              onChanged: (value) {
                _search.cancel();
                setState(() => _selectedStatus = value ?? 'All');
                _fetchInvoices();
              }),
        ],
      );

  Widget _copyButton(String text, {required bool quotation}) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      color: AppColors.muted,
      tooltip: (quotation
              ? 'proforma_invoice.copy_quotation'
              : 'proforma_invoice.copy_invoice')
          .tr,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        AppToast.success(
            context,
            (quotation
                    ? 'proforma_invoice.quotation_number_copied'
                    : 'proforma_invoice.invoice_number_copied')
                .tr);
      });

  /// Table cell: the reference with a copy button (when there is one).
  Widget _reference(dynamic value, {required bool quotation}) {
    final text = _text(value);
    return Row(children: [
      Expanded(child: TableCells.text(text)),
      if (text != '-') _copyButton(text, quotation: quotation),
    ]);
  }

  /// Card line: label, reference and a copy button (when there is one).
  Widget _referenceInfo(String label, dynamic value,
      {required bool quotation}) {
    final text = _text(value);
    return InfoRow(
        label: label,
        value: text,
        trailing: text == '-' ? null : _copyButton(text, quotation: quotation));
  }

  Widget _status(String status) => AppBadge(
      label: _getStatusLabel(status),
      tone: switch (status.toLowerCase()) {
        'paid' || 'order created' => AppBadgeTone.success,
        'overdue' => AppBadgeTone.danger,
        'pending' => AppBadgeTone.warning,
        _ => AppBadgeTone.neutral,
      });

  Widget _avatar(String name, double size) =>
      AppAvatar(name: name == '-' ? '' : name, semanticLabel: name, size: size);

  Widget _card(Map<String, dynamic> invoice, int number) {
    final customer = _text(_mapValue(invoice['customer'])['name']);
    return AppListCard(
      title: customer,
      leading: _avatar(customer, 40),
      trailing: _status(_text(invoice['status'])),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _referenceInfo('proforma_invoice.invoice_number_label'.tr,
            invoice['invoice_number'],
            quotation: false),
        _referenceInfo('proforma_invoice.field_quotation_number'.tr,
            _mapValue(invoice['quotation'])['quotation_number'],
            quotation: true),
        const SizedBox(height: AppSpacing.xs),
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.event_outlined,
              label: 'proforma_invoice.field_invoice_date'.tr,
              value: _text(invoice['invoice_date'])),
          AppMetric(
              icon: Icons.event_busy_outlined,
              label: 'proforma_invoice.field_due_date'.tr,
              value: _text(invoice['due_date'])),
        ]),
        InfoRow(
            label: 'proforma_invoice.field_amount'.tr,
            value: _text(invoice['amount'])),
      ]),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: () => _showDetails(invoice),
    );
  }

  List<TableColumnDef<Map<String, dynamic>>> _columns() => [
        TableColumnDef(
            label: 'proforma_invoice.invoice_number_label'.tr,
            flex: 1.7,
            cellBuilder: (v, _) =>
                _reference(v['invoice_number'], quotation: false)),
        TableColumnDef(
            label: 'proforma_invoice.customer_label'.tr,
            flex: 2,
            cellBuilder: (v, _) {
              final name = _text(_mapValue(v['customer'])['name']);
              return TableCells.avatarName(
                  name: name, avatar: _avatar(name, 36));
            }),
        TableColumnDef(
            label: 'proforma_invoice.field_quotation_number'.tr,
            flex: 1.7,
            cellBuilder: (v, _) => _reference(
                _mapValue(v['quotation'])['quotation_number'],
                quotation: true)),
        TableColumnDef(
            label: 'proforma_invoice.field_invoice_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => TableCells.text(_text(v['invoice_date']))),
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
            cellBuilder: (v, _) =>
                TableCells.widget(_status(_text(v['status'])))),
        TableColumnDef(
            label: 'proforma_invoice.col_actions'.tr,
            flex: 1.1,
            cellBuilder: (v, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => _showDetails(v))),
      ];

  /// Shown while the last load failed: the rows on screen may not match
  /// the filters, so export stays off until a retry succeeds.
  Widget _staleRowsWarning() => AppSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('proforma_invoice.stale_rows_warning'.tr,
            style: const TextStyle(color: AppColors.red)),
        TextButton.icon(
            onPressed: () => _fetchInvoices(),
            icon: const Icon(Icons.refresh),
            label: Text('proforma_invoice.retry'.tr)),
      ]));

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions() => [
        HeaderAction(
            key: ProformaInvoiceListScreen.filterToggleKey,
            icon: _showFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            label: _showFilters
                ? 'proforma_invoice.hide_filters'.tr
                : 'proforma_invoice.show_filters'.tr,
            onPressed: () => setState(() => _showFilters = !_showFilters),
            active: _showFilters,
            badge: !_showFilters && _hasActiveFilters),
        HeaderAction(
            key: ProformaInvoiceListScreen.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'proforma_invoice.export_creating'.tr)
                : 'proforma_invoice.export_tooltip'.tr,
            onPressed:
                !_isLoading && _errorMessage == null && _invoices.isNotEmpty
                    ? _runExport
                    : null,
            busy: _export.busy),
        HeaderAction(
            key: ProformaInvoiceListScreen.refreshKey,
            icon: Icons.refresh_rounded,
            label: 'list.refresh'.tr,
            onPressed: _refreshInvoices),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge(
          [_export, _invoiceNumberController, _customerSearchController]),
      builder: (context, _) => ListPageScaffold<Map<String, dynamic>>(
            header: PageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'proforma_invoice.title'.tr,
                subtitle: 'proforma_invoice.subtitle'.tr,
                actions: _headerActions()),
            filters: _filters(),
            showFilters: _showFilters,
            isLoading: _isLoading,
            items: _invoices,
            toolbar: _errorMessage == null ? null : _staleRowsWarning(),
            minTableWidth: 1250,
            tableScrollController: _tableController,
            columns: _columns(),
            cardBuilder: _card,
            emptyState: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'proforma_invoice.no_invoices_found'.tr),
            onRefresh: _refreshInvoices,
            pagination: ListPagination(
                currentPage: _currentPage,
                totalPages: _lastPage,
                itemsPerPage: 20,
                countLabel: 'proforma_invoice.page_count'
                    .trParams({'count': '${_invoices.length}'}),
                onPageChanged: (page) {
                  // New inputs (a search still waiting) start on page 1.
                  _search.cancel();
                  _fetchInvoices(
                      page: mapEquals(_filtersSnapshot(), _loadedFilters)
                          ? page
                          : 1);
                }),
          ));

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
