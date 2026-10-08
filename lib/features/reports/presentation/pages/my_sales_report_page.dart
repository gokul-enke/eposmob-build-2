import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:provider/provider.dart';

import '../export/my_sales_report_export.dart';
import '../state/my_sales_report_controller.dart';
import '../state/report_load_error.dart';
import '../widgets/my_sales/my_sales_table.dart';
import '../widgets/my_sales/sales_executive_details_dialog.dart';
import '../widgets/report_error_bar.dart';

/// My Sales Report: the signed-in executive's sales, payments and
/// collections for a date/time range (today when empty), with an Excel
/// export of the loaded rows. Built on the shared [ListPageScaffold].
class MySalesReportPage extends StatefulWidget {
  const MySalesReportPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filterToggleKey =
      ValueKey('sales-executive-report-filter-toggle');
  static const exportKey = ValueKey('my-sales-export');
  static const refreshKey = ValueKey('my-sales-refresh');
  static const filtersKey = ValueKey('sales-executive-report-filters');
  static const fromKey = ValueKey('my-sales-from-date');
  static const toKey = ValueKey('my-sales-to-date');

  @override
  State<MySalesReportPage> createState() => _MySalesReportPageState();
}

class _MySalesReportPageState extends State<MySalesReportPage> {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _dayFormat = DateFormat('MMMM dd, yyyy');

  late final MySalesReportController _report;
  late final ExportController _export = widget.export ?? ExportController();
  bool _showFilters = true;
  bool _visibilityInitialized = false;

  String _tr(String key) => 'sales_executive_report.$key'.tr;

  String get _currency =>
      context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';

  @override
  void initState() {
    super.initState();
    final sales = context.read<SalesExecutiveProvider>();
    _report = MySalesReportController(
      fetch: ({from, to}) => sales.getSalesExecutiveReport(
        context: context,
        fromDate: from,
        toDate: to,
        // The report keeps its own rows; don't replace the shared list.
        updateState: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report.load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      // Filters start open on wide screens and closed on phones.
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    _report.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  String get _loadedDay =>
      _report.loadedAt == null ? '' : _dayFormat.format(_report.loadedAt!);

  /// The applied range for the details dialog; today's date when open.
  String _dateRangeLabel() {
    final range = _report.loadedRange;
    final from = range?.apiFrom, to = range?.apiTo;
    if (from != null && to != null) return '$from - $to';
    return from ?? to ?? _loadedDay;
  }

  Future<File> _createExport() {
    if (!_report.canExport) {
      throw StateError('Sales report is unavailable.');
    }
    final range = _report.loadedRange!;
    return MySalesReportExport.build(
      _report.rows,
      currency: _currency,
      from: range.apiFrom,
      to: range.apiTo,
      today: _loadedDay,
    );
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context,
        createFile: _createExport, shareText: _tr('title'));
    if (!exported && mounted) AppToast.error(context, _tr('export_error'));
  }

  void _view(SalesExecutiveReportData row) => showSalesExecutiveDetailsDialog(
        context,
        report: row,
        currency: _currency,
        dateRange: _dateRangeLabel(),
      );

  FilterPanel _filters() => FilterPanel(
        key: MySalesReportPage.filtersKey,
        title: _tr('find'),
        hint: _tr('filter_hint'),
        resetLabel: 'list.reset'.tr,
        onSearch: () {},
        onReset: _report.reset,
        fields: [
          DateTimeFilterField(
            key: MySalesReportPage.fromKey,
            label: _tr('from_date'),
            value: _report.range.from,
            format: _dateFormat.format,
            onChanged: _report.setFrom,
          ),
          DateTimeFilterField(
            key: MySalesReportPage.toKey,
            label: _tr('to_date'),
            value: _report.range.to,
            format: _dateFormat.format,
            onChanged: _report.setTo,
          ),
        ],
      );

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions() => [
        HeaderAction(
          key: MySalesReportPage.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters ? 'list.hide_filters'.tr : 'list.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: !_showFilters && _report.hasActiveFilters,
        ),
        HeaderAction(
          key: MySalesReportPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'list.exporting'.tr)
              : 'list.export'.tr,
          onPressed: _report.canExport && !_export.busy ? _runExport : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: MySalesReportPage.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: _report.load,
        ),
      ];

  Widget? _errorBar() => switch (_report.error) {
        null => null,
        ReportLoadError.invertedRange => ReportErrorBar(
            message: _tr('from_date_after_to_date'),
            retryLabel: _tr('retry')),
        ReportLoadError.failed => ReportErrorBar(
            message: _tr('load_error'),
            retryLabel: _tr('retry'),
            onRetry: _report.load),
      };

  @override
  Widget build(BuildContext context) {
    // Rebuild (no refetch) when the store currency changes.
    final currency = context.select<AppSettingsProvider, String>(
        (settings) => settings.appSettings?.currency ?? 'INR');
    return ListenableBuilder(
      listenable: Listenable.merge([_report, _export]),
      builder: (context, _) {
        final rows = _report.pageRows;
        return ListPageScaffold<SalesExecutiveReportData>(
          minTableWidth: 1400,
          header: PageHeader(
            icon: Icons.assessment_outlined,
            title: _tr('title'),
            subtitle: _tr('subtitle'),
            actions: _headerActions(),
          ),
          showFilters: _showFilters,
          filters: _filters(),
          toolbar: _errorBar(),
          isLoading: _report.loading,
          items: rows,
          onRefresh: _report.load,
          onRowTap: _view,
          columns: mySalesColumns(currency: currency, onView: _view),
          cardBuilder: (row, _) => MySalesCard(
              row: row, currency: currency, onView: () => _view(row)),
          emptyState: AppEmptyState(
            icon: Icons.assessment_outlined,
            title: _tr('no_report_data'),
            subtitle: _tr('adjust_date_filters'),
          ),
          pagination: ListPagination(
            currentPage: _report.page,
            totalPages: _report.pages,
            itemsPerPage: MySalesReportController.pageSize,
            onPageChanged: _report.setPage,
            countLabel:
                _tr('page_count').replaceAll('@count', '${rows.length}'),
          ),
        );
      },
    );
  }
}
