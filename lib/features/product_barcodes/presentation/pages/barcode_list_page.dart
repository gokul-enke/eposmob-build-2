import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/screens/print/barcode_printer_service.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import '../../data/barcode_list_source.dart';
import '../models/barcode_row.dart';
import '../state/barcode_list_controller.dart';
import '../export/barcode_list_export.dart';
import '../widgets/barcode_details_dialog.dart';
import '../widgets/barcode_list_filters.dart';
import '../widgets/barcode_list_views.dart';

class BarcodeListPage extends StatefulWidget {
  const BarcodeListPage(
      {super.key, this.exportController, this.exportDirectory});
  final ExportController? exportController;
  final Directory? exportDirectory;
  @override
  State<BarcodeListPage> createState() => _BarcodeListPageState();
}

class _BarcodeListPageState extends State<BarcodeListPage> {
  late final BarcodeListController _controller;
  late final ExportController _export;
  late final bool _ownsExport;
  final _tableScroll = ScrollController();
  bool? _showFilters;
  bool _isPrinting = false;
  @override
  void initState() {
    super.initState();
    _controller = BarcodeListController(LocalBarcodeListSource(
        context.read<LocalProductProvider>(),
        context.read<CategoryProvider>()));
    _ownsExport = widget.exportController == null;
    _export = widget.exportController ?? ExportController();
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) {
      _controller.initializing = false;
      setState(() {});
      AppToast.error(context, 'product_barcode.auth_token_missing'.tr);
      return;
    }
    await _controller.initialize();
    if (mounted && _controller.error != null) {
      AppToast.error(
          context,
          'product_barcode.error_loading_products'
              .trParams({'error': _controller.error.toString()}));
    }
  }

  Future<void> _refresh() async {
    if (_controller.error != null) {
      await _initialize();
    } else {
      _controller.refresh();
    }
  }

  Future<void> _exportRows() async {
    if (_export.busy || _controller.loading || _controller.error != null) {
      return;
    }
    _controller.flushSearch();
    // Freeze primitive cell values before asynchronous encoding/delivery.
    final snapshot = barcodeExportSnapshot(_controller.rows);
    if (snapshot.isEmpty) {
      AppToast.info(context, 'product_barcode.no_products_found'.tr);
      return;
    }
    final ok = await _export.run(context,
        createFile: () => exportBarcodeList(snapshot,
            outputDirectory: widget.exportDirectory));
    if (!ok && mounted) {
      AppToast.error(context, 'product_barcode.export_failed'.tr);
    }
  }

  Future<void> _handlePrintSelected(List<BarcodeRow> selectedRows) async {
    if (_isPrinting || _controller.loading) return;
    setState(() => _isPrinting = true);
    try {
      final validRows = selectedRows
          .where((row) => row.barcode != null && row.barcode!.trim().isNotEmpty)
          .toList();

      if (validRows.length < selectedRows.length) {
        final bool shouldContinue = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('product_barcode.missing_barcode_title'.tr),
                content: Text(
                  validRows.isEmpty
                      ? 'product_barcode.no_barcode_plural'.tr
                      : 'product_barcode.no_barcode_skip'.tr,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      validRows.isEmpty
                          ? 'product_barcode.close'.tr
                          : 'general.cancel'.tr,
                    ),
                  ),
                  if (validRows.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('product_barcode.continue_btn'.tr),
                    ),
                ],
              ),
            ) ??
            false;

        if (!shouldContinue || validRows.isEmpty) {
          return;
        }
      }

      final validProducts =
          validRows.map((r) => r.toProductForPrint()).toList();

      if (!mounted || _controller.loading) return;
      final BarcodePrintRequest? result = await showDialog<BarcodePrintRequest>(
        context: context,
        builder: (context) =>
            ConfirmBarcodePrintModal(selectedProducts: validProducts),
      );

      if (mounted &&
          !_controller.loading &&
          result != null &&
          result.items.isNotEmpty) {
        final barcodePrinterService = BarcodePrinterService(context);
        final printResult = await barcodePrinterService.printBarcodes(
          printItems: result.items,
          stickerSize: result.stickerSize,
          stickersPerRow: result.stickersPerRow,
          printRotationDegrees: result.printRotationDegrees,
          invertPrintColors: result.invertPrintColors,
        );

        if (mounted && printResult.isSuccess) {
          _controller.clearSelection();
        }
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handlePrintSingle(BarcodeRow row) async {
    if (_isPrinting || _controller.loading) return;
    setState(() => _isPrinting = true);
    try {
      if (row.barcode == null || row.barcode!.trim().isEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('product_barcode.missing_barcode_title'.tr),
            content: Text('product_barcode.no_barcode_single'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('general.cancel'.tr),
              ),
            ],
          ),
        );
        return;
      }

      final printProduct = row.toProductForPrint();

      if (!mounted || _controller.loading) return;
      final BarcodePrintRequest? result = await showDialog<BarcodePrintRequest>(
        context: context,
        builder: (context) =>
            ConfirmBarcodePrintModal(selectedProducts: [printProduct]),
      );

      if (mounted &&
          !_controller.loading &&
          result != null &&
          result.items.isNotEmpty) {
        final barcodePrinterService = BarcodePrinterService(context);
        final printResult = await barcodePrinterService.printBarcodes(
          printItems: result.items,
          stickerSize: result.stickerSize,
          stickersPerRow: result.stickersPerRow,
          printRotationDegrees: result.printRotationDegrees,
          invertPrintColors: result.invertPrintColors,
        );

        if (mounted && printResult.isSuccess) {
          _controller.clearSelection();
        }
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsExport) _export.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_controller, _export]),
        builder: (context, _) {
          final shown = _showFilters ??
              MediaQuery.sizeOf(context).width >=
                  ListLayoutBreakpoints.mobileBelow;
          return ListPageScaffold<BarcodeRow>(
            header: PageHeader(
                icon: Icons.qr_code_rounded,
                title: 'product_barcode.title'.tr,
                subtitle: 'product_barcode.subtitle'.tr,
                actions: [
                  HeaderAction(
                      key: const ValueKey('product-barcode-filter-toggle'),
                      icon: Icons.filter_alt_rounded,
                      label: 'product_barcode.filters'.tr,
                      active: shown,
                      badge: _controller.applied.isFiltered,
                      onPressed: () => setState(() => _showFilters = !shown)),
                  HeaderAction(
                      icon: Icons.ios_share_rounded,
                      label: _export.stage ?? 'product_barcode.export'.tr,
                      busy: _export.busy,
                      onPressed:
                          _controller.loading || _controller.error != null
                              ? null
                              : _exportRows),
                  HeaderAction(
                      icon: Icons.refresh_rounded,
                      label: 'product_barcode.refresh'.tr,
                      onPressed: _controller.loading ? null : _refresh),
                ]),
            filters: barcodeListFilters(
                name: _controller.name,
                barcode: _controller.barcode,
                categories: _controller.categories,
                categoryId: _controller.categoryId,
                loading: _controller.loading,
                onSearch: _controller.scheduleSearch,
                onSubmit: _controller.flushSearch,
                onReset: _controller.reset,
                onCategory: _controller.selectCategory),
            showFilters: shown,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'product_barcode.filters_title'.tr,
                collapsedSubtitle: 'product_barcode.filters_hint'.tr,
                expandedSubtitle: 'product_barcode.filters_hint'.tr),
            toolbar: BarcodeSelectionToolbar(
                pageSelected: _controller.pageSelected,
                selectedCount: _controller.selected.length,
                selectionEnabled:
                    !_controller.loading && _controller.pageRows.isNotEmpty,
                onSelectPage: _controller.selectPage,
                onClear: _controller.clearSelection,
                printing: _isPrinting,
                onPrint: _controller.loading
                    ? null
                    : () => _handlePrintSelected(
                        _controller.selected.values.toList())),
            isLoading: _controller.loading,
            items: _controller.pageRows,
            columns: barcodeListColumns(
                isSelected: _controller.isSelected,
                onSelected: _controller.setSelected,
                printing: _isPrinting,
                onView: (row) => showBarcodeDetails(context, row),
                onPrint: _handlePrintSingle),
            cardBuilder: (row, number) => BarcodeListCard(
                row: row,
                selected: _controller.isSelected(row),
                onSelected: (value) => _controller.setSelected(row, value),
                printing: _isPrinting,
                onView: () => showBarcodeDetails(context, row),
                onPrint: () => _handlePrintSingle(row)),
            emptyState: AppEmptyState(
                icon: Icons.qr_code_rounded,
                title: _controller.error == null
                    ? 'product_barcode.no_products_found'.tr
                    : 'product_barcode.load_failed'.tr,
                action: _controller.error == null
                    ? null
                    : AppOutlinedButton(
                        label: 'product_barcode.retry'.tr,
                        onPressed: _initialize)),
            onRefresh: _refresh,
            minTableWidth: 1200,
            tableScrollController: _tableScroll,
            pagination: ListPagination(
                currentPage: _controller.page,
                totalPages: _controller.totalPages,
                itemsPerPage: BarcodeListController.pageSize,
                onPageChanged: _controller.goToPage,
                countLabel: 'product_barcode.page_count'
                    .trParams({'count': '${_controller.pageRows.length}'})),
          );
        },
      );
}
