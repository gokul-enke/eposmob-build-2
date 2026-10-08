import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../widgets/day_close_list_rows.dart';

Future<File> exportDayCloseList(List<DailySalesCloseData> rows, String currency,
        {Directory? outputDirectory}) =>
    ListExcelExportService.export<DailySalesCloseData>(
        items: rows,
        fileNamePrefix: 'daily-sales-closes',
        sheetName: 'Daily Sales Closes',
        outputDirectory: outputDirectory,
        columns: [
          ListExportColumn(
              label: 'daily_sales_close.list_id'.tr,
              value: (r, _) => '${r.id}'),
          ListExportColumn(
              label: 'daily_sales_close.sales_executive'.tr,
              value: (r, _) => r.salesExecutive?.name ?? ''),
          ListExportColumn(
              label: 'daily_sales_close.phone'.tr,
              value: (r, _) => r.salesExecutive?.phone ?? ''),
          ListExportColumn(
              label: 'daily_sales_close.store'.tr,
              value: (r, _) => r.store?.name ?? ''),
          ListExportColumn(
              label: 'daily_sales_close.business_date'.tr,
              value: (r, _) => r.businessDate),
          ListExportColumn(
              label: 'daily_sales_close.total_orders'.tr,
              value: (r, _) => r.totalOrders),
          ListExportColumn(
              label: 'daily_sales_close.total_sales'.tr,
              value: (r, _) => double.parse(r.totalSales!)),
          ListExportColumn(
              label: 'daily_sales_close.online_sales'.tr,
              value: (r, _) => double.parse(r.totalOnline!)),
          ListExportColumn(
              label: 'daily_sales_close.cash_sales'.tr,
              value: (r, _) => double.parse(r.totalCash!)),
          ListExportColumn(
              label: 'daily_sales_close.credit_amount'.tr,
              value: (r, _) => double.parse(r.totalCredit!)),
          ListExportColumn(
              label: 'daily_sales_close.list_currency'.tr,
              value: (r, _) => currency),
          ListExportColumn(
              label: 'daily_sales_close.status'.tr,
              value: (r, _) => dayCloseStatusLabel(r.status)),
          ListExportColumn(
              label: 'daily_sales_close.closing_period_details'.tr,
              value: (r, _) => r.closingPeriod ?? ''),
          ListExportColumn(
              label: 'daily_sales_close.opening_date'.tr,
              value: (r, _) => r.openingDate ?? ''),
          ListExportColumn(
              label: 'daily_sales_close.closing_date'.tr,
              value: (r, _) => r.closingDate ?? ''),
        ]);
