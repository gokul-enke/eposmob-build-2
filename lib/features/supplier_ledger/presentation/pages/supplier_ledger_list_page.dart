import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import '../state/supplier_ledger_details_action.dart';
import '../../data/supplier_ledger_repository.dart';
import '../state/supplier_ledger_list_controller.dart';
import '../widgets/supplier_ledger_filters.dart';
import '../widgets/supplier_ledger_rows.dart';
import '../export/supplier_ledger_excel.dart';

class SupplierLedgerListPage extends StatefulWidget {
  const SupplierLedgerListPage({super.key, this.export});
  final ExportController? export;
  static const filterToggleKey =
      ValueKey('supplier-transactions-filter-toggle');
  static const exportKey = ValueKey('supplier-transactions-export');
  static const refreshKey = ValueKey('supplier-transactions-refresh');
  @override
  State<SupplierLedgerListPage> createState() => _SupplierLedgerListPageState();
}

class _SupplierLedgerListPageState extends State<SupplierLedgerListPage>
    with SupplierLedgerRowActions<SupplierLedgerListPage> {
  static const _pageSize = SupplierLedgerListController.pageSize;
  late final SupplierLedgerListController list;
  late final ExportController _export = widget.export ?? ExportController();
  late final rows = SupplierLedgerRows(
      onCopy: _copyReference, onView: showTransactionDetails);
  bool _showFilters = true;
  bool _visibilityInitialized = false;
  @override
  void initState() {
    super.initState();
    list = SupplierLedgerListController(
        SupplierLedgerRepository(context.read<TransactionProvider>()),
        onError: (error) {
      if (mounted) {
        AppToast.error(
            context,
            'supplier_transactions.error_loading'
                .trParams({'error': '$error'}));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      list.repository.setAccessToken(context.read<AuthModel>().token ?? '');
      await list.fetchPage(1);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    list.dispose();
    _export.dispose();
    super.dispose();
  }

  Future<File> _createExport() async {
    _export.setStage('supplier_transactions.exporting'.tr);
    final items = await list.exportRows(onProgress: (page, total) {
      if (mounted) {
        _export.setStage('supplier_transactions.export_fetching'
            .trParams({'page': '$page', 'total': '$total'}));
      }
    });
    if (mounted) {
      _export.setStage('supplier_transactions.export_creating'.tr);
    }
    return createSupplierLedgerExcel(items);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context,
        createFile: _createExport, shareText: 'supplier_transactions.title'.tr);
    if (!exported && mounted) {
      AppToast.error(context, 'supplier_transactions.export_failed'.tr);
    }
  }

  void _copyReference(TransactionModel tx) {
    Clipboard.setData(ClipboardData(text: tx.reference));
    AppToast.success(context, 'supplier_transactions.ref_copied'.tr);
  }

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions({required bool canExport}) => [
        HeaderAction(
          key: SupplierLedgerListPage.filterToggleKey,
          icon: _showFilters
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          label: _showFilters
              ? 'supplier_transactions.hide_filters'.tr
              : 'supplier_transactions.filters'.tr,
          onPressed: () => setState(() => _showFilters = !_showFilters),
          active: _showFilters,
          badge: !_showFilters && list.hasActiveFilters,
        ),
        HeaderAction(
          key: SupplierLedgerListPage.exportKey,
          icon: Icons.ios_share_rounded,
          label: _export.busy
              ? (_export.stage ?? 'supplier_transactions.exporting'.tr)
              : 'supplier_transactions.export'.tr,
          onPressed: canExport ? _runExport : null,
          busy: _export.busy,
        ),
        HeaderAction(
          key: SupplierLedgerListPage.refreshKey,
          icon: Icons.refresh_rounded,
          label: 'list.refresh'.tr,
          onPressed: list.refresh,
        ),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_export, list]),
        builder: (context, _) {
          final items = list.items;
          final loading = list.loading;
          final currentPage = list.currentPage;
          return ListPageScaffold<TransactionModel>(
            minTableWidth: 1200,
            header: PageHeader(
              icon: Icons.swap_horiz_rounded,
              title: 'supplier_transactions.title'.tr,
              subtitle: 'supplier_transactions.subtitle'.tr,
              actions: _headerActions(
                canExport:
                    !list.loading && !list.hasLoadError && items.isNotEmpty,
              ),
            ),
            showFilters: _showFilters,
            filters: SupplierLedgerFilters(list).build(list.statuses),
            isLoading: loading,
            items: items,
            onRefresh: list.refresh,
            onRowTap: showTransactionDetails,
            cardBuilder: rows.card,
            columns: rows.columns(),
            emptyState: AppEmptyState(
              icon: Icons.search_off_rounded,
              title: (list.hasActiveFilters
                      ? 'supplier_transactions.no_filter_match'
                      : 'supplier_transactions.no_transactions')
                  .tr,
              action: list.hasActiveFilters
                  ? AppOutlinedButton(
                      label: 'supplier_transactions.btn_reset_filters'.tr,
                      icon: Icons.restart_alt_rounded,
                      onPressed: list.resetSearch,
                    )
                  : null,
            ),
            pagination: ListPagination(
              currentPage: currentPage,
              totalPages: list.totalPages,
              itemsPerPage: _pageSize,
              onPageChanged: list.fetchPage,
              countLabel: 'supplier_transactions.count_on_page'
                  .trParams({'count': '${items.length}'}),
            ),
          );
        },
      );
}
