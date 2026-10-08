import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/purchase_order_model.dart';
import '../widgets/list/purchase_order_list_view.dart';

Future<File> exportPurchaseOrders(
        List<PurchaseOrderData> rows, String currency) =>
    ListExcelExportService.export<PurchaseOrderData>(
        items: rows,
        fileNamePrefix: 'purchase-orders',
        sheetName: 'Purchase Orders',
        columns: [
          ListExportColumn(
              label: 'purchase_order.sl_col'.tr, value: (_, i) => i + 1),
          ListExportColumn(
              label: 'purchase_order.purchase_date'.tr,
              value: (e, _) => e.purchaseDate),
          ListExportColumn(
              label: 'purchase_order.store'.tr, value: (e, _) => e.store?.name),
          ListExportColumn(
              label: 'purchase_order.supplier'.tr,
              value: (e, _) => e.supplier?.name),
          ListExportColumn(
              label: 'purchase_order.total_price'.tr,
              value: (e, _) =>
                  ListExcelExportService.numericValue(e.amountTotal)),
          ListExportColumn(
              label: 'purchase_order.currency'.tr, value: (_, __) => currency),
          ListExportColumn(
              label: 'purchase_order.received_items_col'.tr,
              value: (e, _) => PurchaseOrderListView.receivedLabel(e)),
        ]);
