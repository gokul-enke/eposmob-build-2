import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/core/ui/layout/list_page_scaffold.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';
import '../../data/purchase_list_export_snapshot.dart';
import '../../domain/models/purchase_order_model.dart';
import '../export/purchase_order_excel_export.dart';
import '../navigation/purchase_navigation.dart';
import '../state/purchase_list_export_guard.dart';
import '../state/purchase_order_list_controller.dart';
import '../state/purchase_provider.dart';
import '../widgets/list/purchase_order_list_view.dart';

class PurchaseOrderListPage extends StatefulWidget {
  const PurchaseOrderListPage({super.key, this.exportController});
  final ExportController? exportController;
  @override
  State<PurchaseOrderListPage> createState() => _PurchaseOrderListPageState();
}

class _PurchaseOrderListPageState extends State<PurchaseOrderListPage> {
  late final PurchaseProvider purchases;
  late final AuthModel auth;
  late final PurchaseOrderListController controller;
  late final ExportController export;
  late final PurchaseListExportGuard exportGuard;
  final scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    purchases = context.read<PurchaseProvider>();
    auth = context.read<AuthModel>();
    purchases.activePurchaseOrderDetails = null;
    purchases.voucherDetails = null;
    purchases.listPurchaseItemView = [];
    controller = PurchaseOrderListController(
      fetch: (filter, page) => purchases.repository.fetchOrdersPage(
          accessToken: _requireToken(),
          storeId: filter.storeId,
          supplierId: filter.supplierId,
          dateFrom: filter.dateFrom,
          dateTo: filter.dateTo,
          page: page),
      fetchStores: () async {
        await purchases.listAllStores(_requireToken(), null);
        return List.of(purchases.storeList);
      },
      fetchSuppliers: () async {
        await purchases.listAllSuppliers(_requireToken(), null);
        return List.of(purchases.supplierList);
      },
    );
    export = widget.exportController ?? ExportController();
    exportGuard = PurchaseListExportGuard([
      controller.supplierController,
      controller.storeController,
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

  String _requireToken() {
    final token = auth.token;
    if (token == null || token.isEmpty) {
      throw StateError('No active authentication session.');
    }
    return token;
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
    if (!canViewPurchasePrice(context, listen: true)) {
      return SafeArea(
          child: Center(
              child: Text('purchase_order.permission_required_view'.tr)));
    }
    final settings = context.watch<AppSettingsProvider>().appSettings;
    final currency = (settings?.currency.trim().isNotEmpty ?? false)
        ? settings!.currency.trim()
        : 'SAR';
    return ListenableBuilder(
        listenable: Listenable.merge([controller, export]),
        builder: (context, _) => PurchaseOrderListView(
            controller: controller,
            currency: currency,
            onCreate: () {
              purchases.activePurchaseOrderDetails = null;
              purchases.voucherDetails = null;
              purchases.listPurchaseItemView = [];
              PurchaseNavigation.openCreate();
            },
            onOpen: _handleOrderAction,
            export: export,
            onExport: () => _runExport(currency),
            onReset: _reset,
            scrollController: scrollController));
  }

  Future<void> _reset() async {
    exportGuard.invalidate();
    await controller.resetSearch();
  }

  Future<void> _runExport(String currency) async {
    final ok =
        await export.run(context, createFile: () => _createExport(currency));
    if (!ok && mounted) {
      AppToast.error(context, 'purchase_order.export_error'.tr);
    }
  }

  Future<File> _createExport(String currency) async {
    if (!mounted) throw StateError('Purchase list has been removed');
    final filter = controller.filter;
    final token = _requireToken();
    final check = await exportGuard.capture(
        session: purchases.repository.api.session,
        token: () => auth.token,
        allowed: () => mounted && canViewPurchasePrice(context),
        configuration: () => (
              APPUrl.listPurchaseOrder,
              controller.filter.storeId,
              controller.filter.supplierId,
              controller.filter.dateFrom,
              controller.filter.dateTo,
              context.read<AppSettingsProvider>().appSettings?.currency
            ));
    final rows = await collectPurchaseExport<PurchaseOrderData>(
        checkScope: check,
        idOf: (e) => e.id,
        onProgress: (page, total) => export.setStage(
            'purchase_order.export_fetching'
                .trParams({'page': '$page', 'total': '$total'})),
        fetch: (page) async {
          final model = await purchases.repository.fetchOrdersPage(
              accessToken: token,
              storeId: filter.storeId,
              supplierId: filter.supplierId,
              dateFrom: filter.dateFrom,
              dateTo: filter.dateTo,
              page: page);
          return PurchaseExportPage(
              model.data?.currentPage, model.data?.lastPage, model.data?.data);
        });
    await check();
    final file = await exportPurchaseOrders(rows, currency);
    await check();
    return file;
  }

  Future<void> _handleOrderAction(
      PurchaseOrderData item, int targetIndex) async {
    final token = auth.token;
    if (token == null) return;

    final provider = purchases;

    // If we have items in the list (new API format), use them for both View and Create/Receive
    if (item.items != null && item.items!.isNotEmpty) {
      // 1. Prepare data for CreatePurchaseOrderPage (index 82)
      // We map the item back to a Map format so the Screen's pre-population logic works even if detail API fails
      provider.activePurchaseOrderDetails = {
        'id': item.id,
        'voucher_number': item.voucherNumber,
        'purchase_date': item.purchaseDate,
        'amount_total': item.amountTotal,
        'discount': item.discount,
        'status': item.status,
        'items': item.items
            ?.map((i) => {
                  'id': i.id,
                  'category_id': i.categoryId,
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'product_variant_id': i.productVariantId,
                  'variant_name': i.variantName,
                  'store_id': i.storeId,
                  'supplier_id': i.supplierId,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'total_price': i.totalPrice,
                  'calculated_purchase_rate': i.calculatedPurchaseRate,
                  'tax_include': i.taxInclude ?? true,
                  'tax_include_purchase':
                      i.taxIncludePurchase ?? i.taxInclude ?? true,
                  'retail_price': i.retailPrice,
                  'wholesale_price': i.wholesalePrice,
                  'mrp': i.mrp,
                  'rack': i.rack,
                  'wholesale_min_unit': i.wholesaleMinUnit,
                  'pkg_mfg': i.pkgMfg,
                  'expiry_date': i.expiryDate,
                  'batch_number': i.batchNumber,
                  'purchase_unit_id': i.purchaseUnitId,
                  'purchase_unit_type': i.purchaseUnitType,
                  'purchase_unit_conversion_rate': i.purchaseUnitConversionRate,
                  'purchase_qty': i.purchaseQty,
                  'unit_prices': i.unitPrices,
                  'unit': i.unit,
                  'status': i.status,
                })
            .toList(),
        'store': item.store != null
            ? {'id': item.store?.id, 'name': item.store?.name}
            : null,
        'supplier': item.supplier != null
            ? {'id': item.supplier?.id, 'name': item.supplier?.name}
            : null,
        // Payment state fields (new)
        if (item.paidTotal != null) 'paid_total': item.paidTotal,
        if (item.outstandingAmount != null)
          'outstanding_amount': item.outstandingAmount,
        if (item.paymentStatus != null) 'payment_status': item.paymentStatus,
      };

      // 2. Prepare data for PurchaseDetailsPage (index 36)
      provider.listPurchaseItemView = item.items!
          .map((i) => PurchaseItem(
                id: i.id,
                productId: i.productId,
                name: i.productName,
                quantity: int.tryParse(i.quantity ?? "0") ?? 0,
                unitPrice: int.tryParse(i.unitPrice?.split('.')[0] ?? "0") ?? 0,
                unit: i.unit,
              ))
          .toList();

      provider.voucherDetails = VoucherDetail(
        id: item.id,
        voucherNumber: item.voucherNumber,
        purchaseDate: item.purchaseDate,
        amountTotal: int.tryParse(item.amountTotal?.split('.')[0] ?? "0") ?? 0,
        status: item.status,
      );

      provider.ListPurchaseModelDataDetails = ListPurchaseModelData(
        id: item.id,
        amountTotal: int.tryParse(item.amountTotal?.split('.')[0] ?? "0") ?? 0,
        status: item.status,
      );

      if (mounted) PurchaseNavigation.openIndex(targetIndex);
      return;
    }

    // Fallback: fetch details if items are missing in the list
    await provider.fetchPurchaseOrderDetails(
      accessToken: token,
      purchaseId: item.id.toString(),
    );

    // Navigate
    if (mounted) PurchaseNavigation.openIndex(targetIndex);
  }
}
