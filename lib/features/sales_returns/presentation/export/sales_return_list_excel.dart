import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/sales_return_list.dart';

Future<File> exportSalesReturnList(
        List<SalesReturnOrder> rows, String currency) =>
    ListExcelExportService.export<SalesReturnOrder>(
      items: rows,
      fileNamePrefix: 'sales-return-orders',
      sheetName: 'Sales Returns',
      columns: [
        ListExportColumn(
            label: 'sales_return.list_return_id'.tr,
            value: (r, _) => '${r.id}'),
        ListExportColumn(
            label: 'sales_return.order_number'.tr,
            value: (r, _) => r.originalOrderNumber),
        ListExportColumn(
            label: 'sales_return.bill_number'.tr,
            value: (r, _) => r.receiptNumber ?? ''),
        ListExportColumn(
            label: 'sales_return.total_quantity'.tr,
            value: (r, _) => salesReturnQuantity(r)),
        ListExportColumn(
            label: 'sales_return.total_return_amount'.tr,
            value: (r, _) => double.parse(r.totalAmount)),
        ListExportColumn(
            label: 'sales_return.list_currency'.tr, value: (r, _) => currency),
        ListExportColumn(
            label: 'sales_return.status'.tr,
            value: (r, _) => r.status == 1
                ? 'sales_return.status_completed'.tr
                : 'sales_return.status_pending'.tr),
        ListExportColumn(
            label: 'sales_return.date'.tr,
            value: (r, _) => r.createdAt.toIso8601String()),
      ],
    );
