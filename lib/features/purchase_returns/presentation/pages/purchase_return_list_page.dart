import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/core/ui/layout/list_page_scaffold.dart';
import 'package:pos_machine/features/purchases/data/purchase_list_export_snapshot.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_list_export_guard.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';
import '../../domain/models/purchase_return.dart';
import '../export/purchase_return_excel_export.dart';
import '../navigation/purchase_return_navigation.dart';
import '../state/purchase_return_list_controller.dart';
import '../widgets/list/purchase_return_list_view.dart';
import 'purchase_return_details_page.dart';

class PurchaseReturnListPage extends StatefulWidget {
  const PurchaseReturnListPage({super.key, this.exportController});
  final ExportController? exportController;
  @override
  State<PurchaseReturnListPage> createState() => _PurchaseReturnListPageState();
}

class _PurchaseReturnListPageState extends State<PurchaseReturnListPage> {
  late final PurchaseReturnListController controller;
  late final PurchaseProvider purchases;
  late final AuthModel auth;
  late final ExportController export;
  late final PurchaseListExportGuard exportGuard;
  final scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    purchases = context.read<PurchaseProvider>();
    auth = context.read<AuthModel>();
    controller = PurchaseReturnListController(
      fetch: (filter, page) => purchases.purchaseReturnProvider.fetchPage(
          accessToken: auth.token ?? '',
          page: page,
          supplierId: filter.supplierId,
          dateFrom: filter.dateFrom,
          dateTo: filter.dateTo),
      fetchSuppliers: () async {
        await purchases.listAllSuppliers(auth.token ?? '', null);
        return List.of(purchases.supplierList);
      },
      fallbackError: 'purchase_return.err_load'.tr,
      onError: (message) {
        if (mounted) AppToast.error(context, message);
      },
    );
    export = widget.exportController ?? ExportController();
    exportGuard = PurchaseListExportGuard([
      controller.supplierController,
      controller.fromDateController,
      controller.toDateController
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.update(() => controller.showFilters =
            MediaQuery.sizeOf(context).width >=
                ListLayoutBreakpoints.mobileBelow);
      }
    });
    controller.initialize(canLoad: auth.token?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    exportGuard.dispose();
    scrollController.dispose();
    if (widget.exportController == null) export.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: Listenable.merge([controller, export]),
        builder: (context, _) => PurchaseReturnListView(
            controller: controller,
            currency: currency,
            export: export,
            onExport: () => _runExport(currency),
            canExport: canViewPurchasePrice(context, listen: true),
            onReset: _reset,
            scrollController: scrollController,
            onCreate: PurchaseReturnNavigation.openCreate,
            onView: (item) => showDialog(
                context: context,
                builder: (_) => PurchaseReturnDetailsPage(returnData: item))));
  }

  Future<void> _reset() async {
    exportGuard.invalidate();
    controller.supplierSearchController.clear();
    await controller.resetFilters();
  }

  Future<void> _runExport(String currency) async {
    final ok =
        await export.run(context, createFile: () => _createExport(currency));
    if (!ok && mounted) {
      AppToast.error(context, 'purchase_return.export_error'.tr);
    }
  }

  Future<File> _createExport(String currency) async {
    if (!mounted) throw StateError('Purchase list has been removed');
    final filter = controller.filter;
    final token = auth.token ?? '';
    final check = await exportGuard.capture(
        session: purchases.purchaseReturnProvider.repository.api.session,
        token: () => auth.token,
        allowed: () => mounted && canViewPurchasePrice(context),
        configuration: () => (
              APPUrl.listPurchaseReturns,
              controller.filter.supplierId,
              controller.filter.dateFrom,
              controller.filter.dateTo,
              context.read<AppSettingsProvider>().appSettings?.currency
            ));
    final rows = await collectPurchaseExport<PurchaseReturnData>(
        checkScope: check,
        idOf: (e) => e.id,
        onProgress: (page, total) => export.setStage(
            'purchase_order.export_fetching'
                .trParams({'page': '$page', 'total': '$total'})),
        fetch: (page) async {
          final data = await purchases.purchaseReturnProvider.fetchPage(
              accessToken: token,
              supplierId: filter.supplierId,
              dateFrom: filter.dateFrom,
              dateTo: filter.dateTo,
              page: page);
          return PurchaseExportPage(data.currentPage, data.lastPage, data.data);
        });
    await check();
    final file = await exportPurchaseReturns(rows, currency);
    await check();
    return file;
  }
}
