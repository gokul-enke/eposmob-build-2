import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../components/export_share_button.dart';
import '../../../components/filter_toggle_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_surface.dart';
import '../../../core/ui/list_page/filter_panel.dart';
import '../../../core/ui/list_page/list_page_header.dart';
import '../../../core/ui/list_page/list_page_scaffold.dart';
import '../../../models/sales_executive_report.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/sales_executive_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../services/list_excel_export_service.dart';

@visibleForTesting
List<SalesExecutiveReportData> parseMySalesReport(dynamic response) {
  if (response is! Map<String, dynamic> ||
      response['status'] != 'success' ||
      response['data'] is! List) {
    throw const FormatException('Invalid My Sales Report response.');
  }
  for (final row in response['data'] as List) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid sales report row.');
    }
    for (final key in [
      'total_sales',
      'totalSales',
      'online_sales',
      'onlineSales',
      'upi_sales',
      'upiSales',
      'card_sales',
      'cardSales',
      'cash_sales',
      'cashSales',
      'credit_sales',
      'creditSales',
      'collected_sales',
      'collectedSales',
      'total_payment_received',
      'payment_received',
      'totalPaymentReceived',
      'credit_collected_prev',
      'prev_balance_collected',
      'creditCollectedPrev',
      'total_collected_on_sale',
      'totalCollectedOnSale'
    ]) {
      final value = row[key];
      if (value == null) continue;
      final amount = double.tryParse(value.toString());
      if (amount == null || !amount.isFinite) {
        throw const FormatException('Invalid sales report amount.');
      }
    }
    final count = row['order_count'] ?? row['orderCount'];
    if (count != null &&
        (int.tryParse(count.toString()) == null ||
            int.parse(count.toString()) < 0)) {
      throw const FormatException('Invalid sales report order count.');
    }
    final breakdown = row['payment_breakdown'];
    if (breakdown != null &&
        breakdown is! Map &&
        !(breakdown is List && breakdown.isEmpty)) {
      throw const FormatException('Invalid payment breakdown.');
    }
    if (breakdown is Map) {
      for (final key in ['UPI', 'CARD']) {
        final value = breakdown[key];
        if (value != null) {
          final amount = double.tryParse(value.toString());
          if (amount == null || !amount.isFinite) {
            throw const FormatException('Invalid payment breakdown amount.');
          }
        }
      }
    }
  }
  return List.unmodifiable(
      SalesExecutiveReportModel.fromJson(response).data ?? []);
}

typedef _DateRange = ({String? from, String? to});

class SalesExecutiveReportScreen extends StatefulWidget {
  const SalesExecutiveReportScreen({super.key});
  @override
  State<SalesExecutiveReportScreen> createState() =>
      _SalesExecutiveReportScreenState();
}

class _SalesExecutiveReportScreenState
    extends State<SalesExecutiveReportScreen> {
  final fromDateController = TextEditingController(),
      toDateController = TextEditingController();
  final _table = ScrollController();
  bool _showFilters = true, _loading = false;
  int _request = 0, _page = 1;
  String? _error;
  String _loadedDay = '';
  String get _currency =>
      context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
  _DateRange? _loadedRange;
  List<SalesExecutiveReportData> _reports = [];
  _DateRange get _range => (
        from: fromDateController.text.isEmpty ? null : fromDateController.text,
        to: toDateController.text.isEmpty ? null : toDateController.text
      );
  int get _pages => ((_reports.length + 19) ~/ 20).clamp(1, 2147483647);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showFilters = MediaQuery.sizeOf(context).width >= 768);
      _fetch();
    });
  }

  @override
  void dispose() {
    _request++;
    fromDateController.dispose();
    toDateController.dispose();
    _table.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final range = _range;
    final from = DateTime.tryParse(range.from ?? ''),
        to = DateTime.tryParse(range.to ?? '');
    final request = ++_request;
    if (from != null && to != null && from.isAfter(to)) {
      setState(() {
        _loading = false;
        _error = 'sales_executive_report.from_date_after_to_date'.tr;
      });
      return;
    }
    final provider = context.read<SalesExecutiveProvider>();
    final day = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await provider.getSalesExecutiveReport(
          context: context,
          fromDate: range.from,
          toDate: range.to,
          updateState: false);
      final rows = parseMySalesReport(response);
      if (!mounted || request != _request) return;
      setState(() {
        _reports = rows;
        _loadedRange = range;
        _loadedDay = day;
        _page = 1;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'sales_executive_report.load_error'.tr);
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  void _reset() {
    fromDateController.clear();
    toDateController.clear();
    setState(() {});
    _fetch();
  }

  Future<void> _selectDateTime(bool from) async {
    final controller = from ? fromDateController : toDateController;
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
      key: ValueKey(from ? 'my-sales-from-date' : 'my-sales-to-date'),
      controller: from ? fromDateController : toDateController,
      readOnly: true,
      onTap: () => _selectDateTime(from),
      decoration: listFilterDecoration(
          from
              ? 'sales_executive_report.from_date'.tr
              : 'sales_executive_report.to_date'.tr,
          Icons.calendar_today_outlined));
  String _money(String? raw) =>
      '$_currency ${double.parse(raw ?? '0').toStringAsFixed(2)}';
  Future<File> _export() async {
    if (_loading ||
        _error != null ||
        _loadedRange == null ||
        _loadedRange != _range ||
        _reports.isEmpty) {
      throw StateError('Sales report is unavailable.');
    }
    final rows = List<SalesExecutiveReportData>.of(_reports);
    final range = _loadedRange!;
    final day = _loadedDay, currency = _currency;
    ListExportColumn<SalesExecutiveReportData> money(
            String key, String? Function(SalesExecutiveReportData) value) =>
        ListExportColumn(
            label: 'sales_executive_report.$key'.tr,
            value: (r, _) => ListExcelExportService.numericValue(value(r)));
    return ListExcelExportService.export<SalesExecutiveReportData>(
        items: rows,
        fileNamePrefix: 'my-sales-report',
        sheetName: 'My Sales Report',
        columns: [
          ListExportColumn(
              label: 'sales_executive_report.executive_name'.tr,
              value: (r, _) => r.name),
          ListExportColumn(
              label: 'sales_executive_report.phone'.tr,
              value: (r, _) => r.phone),
          ListExportColumn(
              label: 'sales_executive_report.total_orders'.tr,
              value: (r, _) => r.orderCount),
          money('total_sales', (r) => r.totalSales),
          money('online_sales', (r) => r.onlineSales),
          money('cash_sales', (r) => r.cashSales),
          money('credit_sales', (r) => r.creditSales),
          money('collected_sales', (r) => r.collectedSales),
          money('total_upi_sales', (r) => r.upiSales),
          money('total_card_sales', (r) => r.cardSales),
          money('total_payment_received', (r) => r.totalPaymentReceived),
          money(
              'total_amount_collected_on_sale', (r) => r.totalCollectedOnSale),
          money('total_credit_collected_prev', (r) => r.creditCollectedPrev),
          ListExportColumn(
              label: 'sales_executive_report.currency'.tr,
              value: (_, __) => currency),
          ListExportColumn(
              label: 'sales_executive_report.from_date'.tr,
              value: (_, __) => range.from ?? (range.to == null ? day : '')),
          ListExportColumn(
              label: 'sales_executive_report.to_date'.tr,
              value: (_, __) => range.to ?? (range.from == null ? day : '')),
        ]);
  }

  Widget _card(SalesExecutiveReportData r, int index) => AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TableCells.identity(r.name ?? 'sales_executive_report.na'.tr),
        const SizedBox(height: 12),
        Text('${'sales_executive_report.phone'.tr}: ${r.phone ?? '—'}'),
        Text(
            '${'sales_executive_report.total_orders'.tr}: ${r.orderCount ?? 0}'),
        for (final entry in <String, String?>{
          'total_sales': r.totalSales,
          'online_sales': r.onlineSales,
          'cash_sales': r.cashSales,
          'credit_sales': r.creditSales,
          'collected_sales': r.collectedSales
        }.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                  '${'sales_executive_report.${entry.key}'.tr}: ${_money(entry.value)}')),
        TableCells.viewButton(() => _showExecutiveDetails(r))
      ]));

  @override
  Widget build(BuildContext context) {
    context.select<AppSettingsProvider, String?>(
        (provider) => provider.appSettings?.currency);
    return LayoutBuilder(
        builder: (context, size) => ListPageScaffold<SalesExecutiveReportData>(
              header: ListPageHeader(
                  icon: Icons.assessment_outlined,
                  title: 'sales_executive_report.title'.tr,
                  subtitle: 'sales_executive_report.subtitle'.tr,
                  onRefresh: _fetch,
                  extraActions: [
                    FilterToggleButton(
                        key: const ValueKey(
                            'sales-executive-report-filter-toggle'),
                        showFilters: _showFilters,
                        hasActiveFilters:
                            _range.from != null || _range.to != null,
                        activeFiltersListenable: Listenable.merge(
                            [fromDateController, toDateController]),
                        activeFiltersBuilder: () =>
                            _range.from != null || _range.to != null,
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                        showTooltip: 'sales_executive_report.filters'.tr,
                        hideTooltip: 'sales_executive_report.hide'.tr),
                    ExportShareButton(
                        key: const ValueKey('my-sales-export'),
                        createFile: _export,
                        label: 'supplier_transactions.export'.tr,
                        loadingLabel:
                            'supplier_transactions.export_creating'.tr,
                        tooltip: 'sales_executive_report.export_tooltip'.tr,
                        errorMessage: 'sales_executive_report.export_error'.tr,
                        mimeType:
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                        compact: size.maxWidth < 560,
                        enabled: !_loading &&
                            _error == null &&
                            _loadedRange == _range &&
                            _reports.isNotEmpty),
                  ]),
              filters: FilterPanel(
                  key: const ValueKey('sales-executive-report-filters'),
                  title: 'sales_executive_report.find'.tr,
                  hint: 'sales_executive_report.filter_hint'.tr,
                  onReset: _reset,
                  fields: [_dateField(true), _dateField(false)]),
              showFilters: _showFilters,
              toolbar: _error == null
                  ? null
                  : Row(children: [
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.red))),
                      TextButton(
                          onPressed: _fetch,
                          child: Text('sales_executive_report.retry'.tr))
                    ]),
              tableScrollController: _table,
              tableMinWidth: 1400,
              isLoading: _loading,
              items: _reports.skip((_page - 1) * 20).take(20).toList(),
              columns: [
                TableColumnDef(
                    label: 'sales_executive_report.executive_name'.tr,
                    flex: 2,
                    cellBuilder: (r, _) => TableCells.identity(
                        r.name ?? 'sales_executive_report.na'.tr)),
                TableColumnDef(
                    label: 'sales_executive_report.phone'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) => TableCells.text(r.phone ?? '')),
                TableColumnDef(
                    label: 'sales_executive_report.total_orders'.tr,
                    cellBuilder: (r, _) =>
                        TableCells.text('${r.orderCount ?? 0}')),
                TableColumnDef(
                    label: 'sales_executive_report.total_sales'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) =>
                        TableCells.text(_money(r.totalSales))),
                TableColumnDef(
                    label: 'sales_executive_report.online_sales'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) =>
                        TableCells.text(_money(r.onlineSales))),
                TableColumnDef(
                    label: 'sales_executive_report.cash_sales'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) =>
                        TableCells.text(_money(r.cashSales))),
                TableColumnDef(
                    label: 'sales_executive_report.credit_sales'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) =>
                        TableCells.text(_money(r.creditSales))),
                TableColumnDef(
                    label: 'sales_executive_report.collected_sales'.tr,
                    flex: 1.3,
                    cellBuilder: (r, _) =>
                        TableCells.text(_money(r.collectedSales))),
                TableColumnDef(
                    label: 'sales_executive_report.actions'.tr,
                    cellBuilder: (r, _) =>
                        TableCells.viewButton(() => _showExecutiveDetails(r))),
              ],
              cardBuilder: _card,
              emptyState: Center(
                  child: Text('sales_executive_report.no_report_data'.tr)),
              onRefresh: _fetch,
              currentPage: _page,
              totalPages: _pages,
              itemsPerPage: 20,
              countLabel: 'sales_executive_report.page_count'.trParams({
                'count': '${_reports.skip((_page - 1) * 20).take(20).length}'
              }),
              onPageChanged: (page) {
                if (!_loading) {
                  setState(() => _page = page.clamp(1, _pages));
                }
              },
            ));
  }

  void _showExecutiveDetails(SalesExecutiveReportData report) {
    final currency = _currency;
    // Get date range or default to today
    String dateRange;
    if ((_loadedRange?.from ?? "").isNotEmpty &&
        (_loadedRange?.to ?? "").isNotEmpty) {
      dateRange = '${(_loadedRange?.from ?? "")} - ${(_loadedRange?.to ?? "")}';
    } else if ((_loadedRange?.from ?? "").isNotEmpty) {
      dateRange = (_loadedRange?.from ?? "");
    } else if ((_loadedRange?.to ?? "").isNotEmpty) {
      dateRange = (_loadedRange?.to ?? "");
    } else {
      dateRange = _loadedDay;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                        'sales_executive_report.executive_details'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s20,
                          0.30,
                          Colors.black,
                        ),
                      )),
                      Container(
                        decoration: BoxDecoration(
                          color: ColorManager.kPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                'sales_executive_report.back'.tr,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s14,
                                  0.20,
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Executive Information Section
                        _buildSection(
                          title:
                              'sales_executive_report.executive_information'.tr,
                          children: [
                            _buildInfoRow(
                              _buildInfoItem(
                                  'sales_executive_report.name'.tr,
                                  report.name ??
                                      'sales_executive_report.na'.tr),
                              _buildInfoItem(
                                  'sales_executive_report.phone'.tr,
                                  report.phone ??
                                      'sales_executive_report.na'.tr),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              _buildInfoItem(
                                  'sales_executive_report.date_range'.tr,
                                  dateRange),
                              _buildInfoItem(
                                'sales_executive_report.total_orders'.tr,
                                (report.orderCount ?? 0).toString(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Financial Summary Section
                        _buildSection(
                          title: 'sales_executive_report.financial_summary'.tr,
                          children: [
                            _buildFinancialItem(
                              'sales_executive_report.total_sales'.tr,
                              '$currency ${report.formattedTotalSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_payment_received'
                                  .tr,
                              '$currency ${report.formattedTotalPaymentReceived}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_amount_collected_on_sale'
                                  .tr,
                              '$currency ${report.formattedTotalCollectedOnSale}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_credit_collected_prev'
                                  .tr,
                              '$currency ${report.formattedCollectedSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_upi_sales'.tr,
                              '$currency ${report.formattedUpiSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_card_sales'.tr,
                              '$currency ${report.formattedCardSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_online_sales'.tr,
                              '$currency ${report.formattedOnlineSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_cash_sales'.tr,
                              '$currency ${report.formattedCashSales}',
                            ),
                            _buildFinancialItem(
                              'sales_executive_report.total_credit_amount'.tr,
                              '$currency ${report.formattedCreditSales}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.24,
              Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(Widget item1, Widget item2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: item1),
        const SizedBox(width: 16),
        Expanded(child: item2),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.18,
            Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.20,
            Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFinancialItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.18,
                Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.20,
              Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
