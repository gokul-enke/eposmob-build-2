import '../../data/proforma_list_repository.dart';
import '../state/proforma_list_controller.dart';
import '../widgets/proforma_list_filters.dart';
import '../widgets/proforma_list_rows.dart';
import '../export/proforma_list_excel.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list/proforma_row_actions.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';

/// The proforma invoices list: header, filters, table/cards and pagination,
/// built on the shared [ListPageScaffold]. Pages come from the API.
class ProformaListPage extends StatefulWidget {
  const ProformaListPage({super.key, this.export});

  /// Replaces the export controller (tests).
  final ExportController? export;

  static const filtersKey = ValueKey('proforma-desktop-filters');
  static const filterToggleKey = ValueKey('proforma-list-filter-toggle');
  static const exportKey = ValueKey('proforma-list-export');
  static const refreshKey = ValueKey('proforma-list-refresh');

  @override
  State<ProformaListPage> createState() => _ProformaListPageState();
}

class _ProformaListPageState extends State<ProformaListPage>
    with ProformaRowActions<ProformaListPage> {
  late final ProformaListController controller;
  bool _showFilters = true, _visibilityInitialized = false;
  late final ExportController _export = widget.export ?? ExportController();
  final _tableController = ScrollController();
  @override
  void initState() {
    super.initState();
    controller = ProformaListController(
        ProformaListRepository(context.read<QuotationsProvider>()),
        readToken: () => context.read<AuthModel>().token ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.fetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Filters start open on wide screens and closed on phones.
    if (!_visibilityInitialized) {
      _showFilters =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    if (widget.export == null) _export.dispose();
    _tableController.dispose();
    super.dispose();
  }

  Future<File> _createExport() async {
    final items = await controller.export(onProgress: (page, total) {
      if (mounted) {
        _export.setStage('proforma_invoice.export_fetching'
            .trParams({'page': '$page', 'total': '$total'}));
      }
    });
    if (mounted) _export.setStage('proforma_invoice.export_creating'.tr);
    return exportProformaListExcel(items);
  }

  Future<void> _runExport() async {
    final exported = await _export.run(context, createFile: _createExport);
    if (!exported && mounted) {
      AppToast.error(context, 'proforma_invoice.export_failed'.tr);
    }
  }

  bool get _hasActiveFilters => controller.filters.isNotEmpty;
  Widget _filters() =>
      ProformaListFilters(controller, filtersKey: ProformaListPage.filtersKey)
          .build();
  ProformaListRows get _rows => ProformaListRows(
      onView: showProformaDetails,
      onCopy: (text, quotation) {
        Clipboard.setData(ClipboardData(text: text));
        AppToast.success(
            context,
            (quotation
                    ? 'proforma_invoice.quotation_number_copied'
                    : 'proforma_invoice.invoice_number_copied')
                .tr);
      });

  /// Shown while the last load failed: the rows on screen may not match
  /// the filters, so export stays off until a retry succeeds.
  Widget _staleRowsWarning() => AppSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('proforma_invoice.stale_rows_warning'.tr,
            style: const TextStyle(color: AppColors.red)),
        TextButton.icon(
            onPressed: () => controller.fetch(),
            icon: const Icon(Icons.refresh),
            label: Text('proforma_invoice.retry'.tr)),
      ]));

  /// Filters, Export, Refresh — left to right.
  List<HeaderAction> _headerActions() => [
        HeaderAction(
            key: ProformaListPage.filterToggleKey,
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
            key: ProformaListPage.exportKey,
            icon: Icons.ios_share_rounded,
            label: _export.busy
                ? (_export.stage ?? 'proforma_invoice.export_creating'.tr)
                : 'proforma_invoice.export_tooltip'.tr,
            onPressed: !controller.loading &&
                    controller.errorMessage == null &&
                    controller.rows.isNotEmpty
                ? _runExport
                : null,
            busy: _export.busy),
        HeaderAction(
            key: ProformaListPage.refreshKey,
            icon: Icons.refresh_rounded,
            label: 'list.refresh'.tr,
            onPressed: controller.refresh),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        _export,
        controller.invoiceNumber,
        controller.customerSearch
      ]),
      builder: (context, _) => ListPageScaffold<Map<String, dynamic>>(
            header: PageHeader(
                icon: Icons.receipt_long_outlined,
                title: 'proforma_invoice.title'.tr,
                subtitle: 'proforma_invoice.subtitle'.tr,
                actions: _headerActions()),
            filters: _filters(),
            showFilters: _showFilters,
            isLoading: controller.loading,
            items: controller.rows,
            toolbar:
                controller.errorMessage == null ? null : _staleRowsWarning(),
            minTableWidth: 1250,
            tableScrollController: _tableController,
            columns: _rows.columns(),
            cardBuilder: _rows.card,
            emptyState: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'proforma_invoice.no_invoices_found'.tr),
            onRefresh: controller.refresh,
            pagination: ListPagination(
                currentPage: controller.currentPage,
                totalPages: controller.lastPage,
                itemsPerPage: 20,
                countLabel: 'proforma_invoice.page_count'
                    .trParams({'count': '${controller.rows.length}'}),
                onPageChanged: controller.goToPage),
          ));
}
