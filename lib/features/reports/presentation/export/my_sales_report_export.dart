import 'dart:io';

import 'package:get/get.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

/// Builds the My Sales Report workbook from the loaded rows.
///
/// [from] / [to] are the applied filter texts; [today] fills both when no
/// date was chosen (the API then reports today).
abstract final class MySalesReportExport {
  static Future<File> build(
    List<SalesExecutiveReportData> rows, {
    required String currency,
    required String? from,
    required String? to,
    required String today,
  }) {
    ListExportColumn<SalesExecutiveReportData> money(
            String key, String? Function(SalesExecutiveReportData) value) =>
        ListExportColumn(
            label: 'sales_executive_report.$key'.tr,
            value: (r, _) => ListExcelExportService.numericValue(value(r)));
    return ListExcelExportService.export<SalesExecutiveReportData>(
        items: List.of(rows),
        fileNamePrefix: 'my-sales-report',
        sheetName: 'My Sales Report',
        columns: [
          ListExportColumn(
              label: 'sales_executive_report.executive_name'.tr,
              value: (r, _) => r.name),
          ListExportColumn(
              label: 'sales_executive_report.phone'.tr,
              value: (r, _) => r.phone),
          ListExportColumn(
              label: 'sales_executive_report.total_orders'.tr,
              value: (r, _) => r.orderCount),
          money('total_sales', (r) => r.totalSales),
          money('online_sales', (r) => r.onlineSales),
          money('cash_sales', (r) => r.cashSales),
          money('credit_sales', (r) => r.creditSales),
          money('collected_sales', (r) => r.collectedSales),
          money('total_upi_sales', (r) => r.upiSales),
          money('total_card_sales', (r) => r.cardSales),
          money('total_payment_received', (r) => r.totalPaymentReceived),
          money(
              'total_amount_collected_on_sale', (r) => r.totalCollectedOnSale),
          money('total_credit_collected_prev', (r) => r.creditCollectedPrev),
          ListExportColumn(
              label: 'sales_executive_report.currency'.tr,
              value: (_, __) => currency),
          ListExportColumn(
              label: 'sales_executive_report.from_date'.tr,
              value: (_, __) => from ?? (to == null ? today : '')),
          ListExportColumn(
              label: 'sales_executive_report.to_date'.tr,
              value: (_, __) => to ?? (from == null ? today : '')),
        ]);
  }
}
