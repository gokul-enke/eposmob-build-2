import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../widgets/sales_list_rows.dart';

Future<File> exportSalesListExcel(List<ListOrderModelData> rows,
        {Directory? outputDirectory, bool isOnlineSales = false}) =>
    ListExcelExportService.export(
      items: rows,
      sheetName:
          (isOnlineSales ? 'sales.online_orders_list' : 'sales.orders_list').tr,
      fileNamePrefix: isOnlineSales ? 'online-orders' : 'sales-orders',
      outputDirectory: outputDirectory,
      columns: <ListExportColumn<ListOrderModelData>>[
        ListExportColumn(
            label: 'sales.si_no'.tr, value: (_, index) => index + 1),
        ListExportColumn(
            label: 'sales.order_number_short'.tr,
            value: (row, _) => row.orderNumber),
        ListExportColumn(
            label: 'sales.list_receipt_number'.tr,
            value: (row, _) => row.receiptNumber),
        ListExportColumn(
            label: 'billing.customer'.tr,
            value: (row, _) => salesCustomer(row)),
        ListExportColumn(
            label: 'sales.date_col'.tr, value: (row, _) => salesDate(row)),
        ListExportColumn(
            label: 'sales.items_col'.tr,
            value: (row, _) => row.cartItems?.length ?? 0),
        ListExportColumn(
            label: 'sales.amount_col'.tr,
            value: (row, _) =>
                ListExcelExportService.numericValue(row.grantTotal)),
        ListExportColumn(
            label: 'sales.status'.tr, value: (row, _) => row.status),
      ],
    );
