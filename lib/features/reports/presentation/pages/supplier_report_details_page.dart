import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print.dart';
import '../../data/supplier_report_details_source.dart';
import '../navigation/report_navigation.dart';
import '../export/supplier_report_details_export.dart';
import '../state/supplier_report_details_controller.dart';
import '../widgets/report_error_bar.dart';
import '../widgets/supplier_report/details/supplier_report_details_filters.dart';
import '../widgets/supplier_report/details/supplier_report_details_results.dart';

part '../state/supplier_report_details_print.dart';

class SupplierTransactionDetailsScreen extends StatefulWidget {
  const SupplierTransactionDetailsScreen({super.key, this.exportController});
  final ExportController? exportController;
  static const exportKey = ValueKey('supplier-report-details-export');
  static const refreshKey = ValueKey('supplier-report-details-refresh');
  static const backKey = ValueKey('supplier-report-details-back');
  static const printKey = ValueKey('supplier-report-details-print');
  static const filterToggleKey = ValueKey('supplier-report-details-toggle');
  @override
  State<SupplierTransactionDetailsScreen> createState() =>
      _SupplierTransactionDetailsScreenState();
}

class _SupplierTransactionDetailsScreenState
    extends State<SupplierTransactionDetailsScreen>
    with SupplierReportDetailsPrint<SupplierTransactionDetailsScreen> {
  late final SupplierReportDetailsController _details;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  @override
  bool initLoading = false;
  @override
  String get selectedSupplierName => _details.supplierName;
  @override
  List<SupplierTransaction> get filteredTransactions => _details.rows;
  @override
  TextEditingController get _fromDateController => _details.fromInput;
  @override
  TextEditingController get _toDateController => _details.toInput;
  String _tr(String key) => 'supplier_transaction_report.$key'.tr;

  @override
  void initState() {
    super.initState();
    final suppliers = context.read<SupplierProvider>();
    final auth = context.read<AuthModel>();
    final source = SupplierReportDetailsSource(suppliers.repository);
    _export = widget.exportController ?? ExportController();
    _details = SupplierReportDetailsController(
      selection: () => (
        id: suppliers.selectedSupplierId ?? '',
        name: suppliers.selectedSupplierName ?? ''
      ),
      readScope: () => source.scope(auth.token ?? ''),
      fetch: (query, page) => source.fetch(auth.token ?? '', query, page: page),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_details.query.hasSupplier) {
        ReportNavigation.openSupplierTransactionsReport();
        return;
      }
      _details.setFiltersVisible(MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow);
      _load();
    });
  }

  Future<void> _load() async {
    final revision = _details.errorRevision;
    await _details.load();
    if (mounted &&
        _details.error != null &&
        _details.errorRevision != revision) {
      AppToast.error(
          context,
          _tr('err_loading_transaction_data')
              .replaceAll('@error', '${_details.error}'));
    }
  }

  Future<void> _runExport() async {
    if (!_details.canExport || _export.busy || initLoading) return;
    var message = 'export_error';
    final success = await _export.run(context, createFile: () async {
      try {
        return await _details.export<File>(
          build: SupplierReportDetailsExport.build,
          progress: (page, last) => _export.setStage(_tr('export_fetching')
              .replaceAll('@page', '$page')
              .replaceAll('@total', '$last')),
        );
      } on SupplierReportDetailsExportCancelled {
        message = 'export_cancelled';
        rethrow;
      }
    }, shareText: _tr('transaction_details_title'));
    if (!success && mounted) {
      if (message == 'export_cancelled') {
        AppToast.warning(context, _tr(message));
      } else {
        AppToast.error(context, _tr(message));
      }
    }
  }

  @override
  void dispose() {
    _details.dispose();
    _tableScroll.dispose();
    if (widget.exportController == null) _export.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_details, _export]),
        builder: (context, _) => ListPageScaffold<SupplierTransaction>(
          header: PageHeader(
            icon: Icons.local_shipping_outlined,
            title: _tr('transaction_details_title'),
            subtitle: _tr('supplier_prefix')
                .replaceAll('@name', selectedSupplierName),
            leading: AppOutlinedButton(
                key: SupplierTransactionDetailsScreen.backKey,
                icon: Icons.arrow_back,
                label: _tr('back_to_report'),
                onPressed: ReportNavigation.openSupplierTransactionsReport),
            primaryActions: [
              AppPrimaryButton(
                  key: SupplierTransactionDetailsScreen.printKey,
                  icon: Icons.print_outlined,
                  label: _tr('print'),
                  onPressed: _printReport)
            ],
            actions: [
              HeaderAction.filters(
                  key: SupplierTransactionDetailsScreen.filterToggleKey,
                  showFilters: _details.showFilters,
                  showLabel: 'list.filters'.tr,
                  hideLabel: 'list.hide_filters'.tr,
                  badge: !_details.showFilters && _details.hasActiveFilters,
                  onPressed: () =>
                      _details.setFiltersVisible(!_details.showFilters)),
              HeaderAction(
                  key: SupplierTransactionDetailsScreen.exportKey,
                  icon: Icons.ios_share_rounded,
                  label: _export.busy
                      ? (_export.stage ?? 'list.exporting'.tr)
                      : 'list.export'.tr,
                  busy: _export.busy,
                  onPressed: _details.canExport && !initLoading && !_export.busy
                      ? _runExport
                      : null),
              HeaderAction(
                  key: SupplierTransactionDetailsScreen.refreshKey,
                  icon: Icons.refresh_rounded,
                  label: 'list.refresh'.tr,
                  onPressed: _load),
            ],
          ),
          showFilters: _details.showFilters,
          filters: supplierReportDetailsFilters(
            search: _details.searchInput,
            type: _details.type,
            payment: _details.payment,
            from: DateTime.tryParse(_details.fromInput.text),
            to: DateTime.tryParse(_details.toInput.text),
            onSearch: _details.filterChanged,
            onReset: _details.reset,
            onType: _details.selectType,
            onPayment: _details.selectPayment,
            onFrom: (date) => _details.selectDate(date, true),
            onTo: (date) => _details.selectDate(date, false),
          ),
          toolbar: _details.error == null
              ? null
              : ReportErrorBar(
                  message: _tr('err_loading_transaction_data')
                      .replaceAll('@error', '${_details.error}'),
                  retryLabel: _tr('retry'),
                  onRetry: _load),
          isLoading: _details.loading || initLoading,
          items: _details.rows,
          columns: supplierReportDetailsColumns(),
          cardBuilder: (row, _) => SupplierReportDetailsCard(row: row),
          minTableWidth: 1050,
          tableScrollController: _tableScroll,
          onRefresh: _load,
          emptyState: AppEmptyState(
              icon: Icons.account_balance_outlined,
              title: _tr('no_transactions_found'),
              subtitle: _tr('try_adjusting_filters')),
        ),
      );
}
