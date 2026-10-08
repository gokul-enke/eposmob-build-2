import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/purchase_return.dart';

Future<File> exportPurchaseReturns(
        List<PurchaseReturnData> rows, String currency) =>
    ListExcelExportService.export<PurchaseReturnData>(
        items: rows,
        fileNamePrefix: 'purchase-returns',
        sheetName: 'Purchase Returns',
        columns: [
          ListExportColumn(
              label: 'purchase_return.reference'.tr,
              value: (e, _) => e.reference ?? e.id?.toString()),
          ListExportColumn(
              label: 'purchase_return.voucher_number'.tr,
              value: (e, _) => e.voucherNumber),
          ListExportColumn(
              label: 'purchase_return.supplier'.tr,
              value: (e, _) => e.supplier?.name),
          ListExportColumn(
              label: 'purchase_return.return_date'.tr,
              value: (e, _) => e.returnDate),
          ListExportColumn(
              label: 'purchase_return.total_amount'.tr,
              value: (e, _) => e.totalAmount),
          ListExportColumn(
              label: 'purchase_order.currency'.tr, value: (_, __) => currency),
          ListExportColumn(
              label: 'purchase_return.status'.tr,
              value: (e, _) => e.status == 'completed'
                  ? 'purchase_return.status_completed'.tr
                  : 'purchase_return.status_pending'.tr),
        ]);
