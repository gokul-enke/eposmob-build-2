import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/admin_executive_report.dart';
import '../../domain/report_date_range.dart';

Future<File> exportAdminExecutives(
  List<SalesExecutiveReportData> rows, {
  required String currency,
  required ReportDateRange range,
  required DateTime loadedAt,
  Directory? outputDirectory,
}) {
  if (rows.isEmpty || !rows.every(completeAdminExecutiveRow)) {
    throw StateError('Admin executive export is incomplete');
  }
  ListExportColumn<SalesExecutiveReportData> money(
          String key, String? Function(SalesExecutiveReportData) get) =>
      ListExportColumn(
          label: 'exec_report.$key'.tr,
          value: (r, _) => get(r) == null ? null : double.parse(get(r)!));
  return ListExcelExportService.export<SalesExecutiveReportData>(
      items: List.of(rows),
      fileNamePrefix: 'admin-sales-executive-report',
      sheetName: 'Admin Executive Report',
      outputDirectory: outputDirectory,
      columns: [
        ListExportColumn(
            label: 'exec_report.header_exec_name'.tr, value: (r, _) => r.name),
        ListExportColumn(
            label: 'exec_report.header_phone'.tr, value: (r, _) => r.phone),
        ListExportColumn(
            label: 'exec_report.header_total_orders'.tr,
            value: (r, _) => r.orderCount),
        money('card_total_sales', (r) => r.totalSales),
        money('card_online_sales', (r) => r.onlineSales),
        money('card_cash_sales', (r) => r.cashSales),
        money('card_credit_sales', (r) => r.creditSales),
        money('card_collected_sales', (r) => r.collectedSales),
        money('card_upi_sales', (r) => r.upiSales),
        money('card_card_sales', (r) => r.cardSales),
        ListExportColumn(
            label: 'sales_executive_report.currency'.tr,
            value: (_, __) => currency),
        ListExportColumn(
            label: 'exec_report.filter_from_date'.tr,
            value: (_, __) => range.apiFrom),
        ListExportColumn(
            label: 'exec_report.filter_to_date'.tr,
            value: (_, __) => range.apiTo),
        ListExportColumn(
            label: 'exec_report.list_date_mode'.tr,
            value: (_, __) => range.isEmpty
                ? 'exec_report.list_today'.tr
                : 'exec_report.list_custom'.tr),
        ListExportColumn(
            label: 'exec_report.list_loaded_at'.tr,
            value: (_, __) => ReportDateRange.formatApi(loadedAt)),
      ]);
}
