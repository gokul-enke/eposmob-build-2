import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../data/supplier_report_source.dart';
import '../../domain/supplier_report.dart';
import '../export/supplier_transactions_report_export.dart';
import '../navigation/report_navigation.dart';
import '../state/supplier_transactions_report_controller.dart';
import '../widgets/report_error_bar.dart';
import '../widgets/supplier_report/supplier_report_filters.dart';
import '../widgets/supplier_report/supplier_report_mobile_card.dart';
import '../widgets/supplier_report/supplier_report_table.dart';

class SupplierTransactionsReportPage extends StatefulWidget {
  const SupplierTransactionsReportPage({super.key, this.exportController});
  final ExportController? exportController;
  static const filterToggleKey =
      ValueKey('supplier-transactions-report-filter-toggle');
  static const exportKey = ValueKey('supplier-transactions-report-export');
  static const refreshKey = ValueKey('supplier-transactions-report-refresh');
  @override
  State<SupplierTransactionsReportPage> createState() =>
      _SupplierTransactionsReportPageState();
}

class _SupplierTransactionsReportPageState
    extends State<SupplierTransactionsReportPage> {
  int _shownErrorRevision = 0;
  late final AuthModel _auth;
  late final SupplierProvider _suppliers;
  late final SupplierTransactionsReportController _report;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  String _tr(String key) => 'supplier_transaction_report.$key'.tr;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _suppliers = context.read<SupplierProvider>();
    _export = widget.exportController ?? ExportController();
    final source = SupplierReportSource(_suppliers.repository);
    _report = SupplierTransactionsReportController(
        fetchDirectory: () => source.directory(_auth.token ?? ''),
        readScope: () => source.scope(_auth.token ?? ''),
        fetch: (query, page) => source.fetch(_auth.token ?? '', query, page));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _report.setFiltersVisible(MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow);
      _run(_report.initialize());
    });
  }

  String get _errorMessage =>
      _report.errorKey!.tr.replaceAll('@error', '${_report.error ?? ''}');
  Future<void> _run(Future<void> operation) async {
    await operation;
    if (!mounted ||
        _report.errorKey == null ||
        _shownErrorRevision == _report.errorRevision) {
      return;
    }
    _shownErrorRevision = _report.errorRevision;
    if (_report.errorKey ==
        'supplier_transaction_report.from_date_after_to_date') {
      AppToast.warning(context, _errorMessage);
    } else {
      AppToast.error(context, _errorMessage);
    }
  }

  void _view(SupplierTransactionSummary summary) {
    _suppliers
      ..setSelectedSupplierName(SupplierTransactionsReportExport.name(summary))
      ..setSelectedSupplierId(summary.supplierId);
    ReportNavigation.openSupplierTransactionDetails();
  }

  Future<File> _createExport() async {
    return _report.export(build: (rows) async {
      if (!mounted) throw StateError('Supplier report was closed.');
      return SupplierTransactionsReportExport.build(rows);
    }, progress: (page, total) {
      if (mounted) {
        _export.setStage(_tr('export_fetching')
            .replaceAll('@page', '$page')
            .replaceAll('@total', '$total'));
      }
    });
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context,
        createFile: _createExport, shareText: _tr('title'));
    if (!exported && mounted) AppToast.error(context, _tr('export_error'));
  }

  @override
  void dispose() {
    _report.dispose();
    _tableScroll.dispose();
    if (widget.exportController == null) _export.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_report, _export]),
        builder: (context, _) => ListPageScaffold<SupplierTransactionSummary>(
          minTableWidth: 1050,
          tableScrollController: _tableScroll,
          header: PageHeader(
            icon: Icons.local_shipping_outlined,
            title: _tr('title'),
            subtitle: _tr('subtitle'),
            actions: [
              HeaderAction(
                  key: SupplierTransactionsReportPage.filterToggleKey,
                  icon: _report.showFilters
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                  label: _report.showFilters
                      ? 'list.hide_filters'.tr
                      : 'list.filters'.tr,
                  active: _report.showFilters,
                  badge: !_report.showFilters && _report.hasActiveFilters,
                  onPressed: () =>
                      _report.setFiltersVisible(!_report.showFilters)),
              HeaderAction(
                  key: SupplierTransactionsReportPage.exportKey,
                  icon: Icons.ios_share_rounded,
                  label: _export.busy
                      ? (_export.stage ?? 'list.exporting'.tr)
                      : 'list.export'.tr,
                  busy: _export.busy,
                  onPressed:
                      _report.canExport && !_export.busy ? _runExport : null),
              HeaderAction(
                  key: SupplierTransactionsReportPage.refreshKey,
                  icon: Icons.refresh_rounded,
                  label: 'list.refresh'.tr,
                  onPressed: () => _run(_report.retry())),
            ],
          ),
          showFilters: _report.showFilters,
          filters: SupplierReportFilters(
              suppliers: _report.suppliers,
              selectedSupplierId: _report.selectedSupplierId,
              fromInput: _report.fromInput,
              toInput: _report.toInput,
              onReset: () => _run(_report.reset()),
              onSupplier: (value) => _run(_report.selectSupplier(value)),
              onDate: (date, from) => _run(_report.selectDate(date, from))),
          toolbar: _report.errorKey == null
              ? null
              : ReportErrorBar(
                  message: _errorMessage,
                  retryLabel: _tr('retry'),
                  onRetry: () => _run(_report.retry())),
          isLoading: _report.loading || _report.initializing,
          items: _report.rows.values.toList(),
          columns: supplierReportColumns(onView: _view),
          cardBuilder: (row, _) =>
              SupplierReportMobileCard(summary: row, onView: _view),
          onRowTap: _view,
          onRefresh: () => _run(_report.retry()),
          emptyState: AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: _tr('no_supplier_transactions'),
              subtitle: _tr('try_refreshing'),
              action: _report.hasActiveFilters
                  ? AppOutlinedButton(
                      label: 'list.reset'.tr,
                      icon: Icons.restart_alt_rounded,
                      onPressed: () => _run(_report.reset()))
                  : null),
          pagination: ListPagination(
              currentPage: _report.page,
              totalPages: _report.pages,
              itemsPerPage: _report.perPage,
              onPageChanged: (page) => _run(_report.goToPage(page)),
              countLabel:
                  _tr('count').replaceAll('@count', '${_report.rows.length}')),
        ),
      );
}
