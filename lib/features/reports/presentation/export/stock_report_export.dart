import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/stock_report.dart';
import '../../domain/stock_report_display.dart';

abstract final class StockReportExport {
  static Future<File> build(List<StockReportData> rows,
      {required bool showCosts}) {
    String tr(String key) => 'stock_report.$key'.tr;
    return ListExcelExportService.export<StockReportData>(
        items: rows,
        fileNamePrefix: 'stock-report',
        sheetName: 'Stock Report',
        columns: [
          ListExportColumn(label: tr('col_no'), value: (_, i) => i + 1),
          ListExportColumn(
              label: tr('col_product_name'), value: (r, _) => r.name),
          ListExportColumn(
              label: tr('col_category'),
              value: (r, _) => r.categoryName ?? '-'),
          ListExportColumn(
              label: tr('col_stores'), value: (r, _) => r.storeCount ?? 1),
          ListExportColumn(
              label: tr('col_barcode'), value: (r, _) => r.barcode ?? '-'),
          ListExportColumn(
              label: tr('col_retail_price'),
              value: (r, _) => stockReportExportNumber(r.retailPrice)),
          ListExportColumn(
              label: tr('col_mrp'),
              value: (r, _) => stockReportExportNumber(r.mrp)),
          if (showCosts)
            ListExportColumn(
                label: tr('col_purchase_price'),
                value: (r, _) => stockReportExportNumber(r.purchasePrice)),
          ListExportColumn(
              label: tr('col_current_stock'),
              value: (r, _) => stockReportExportNumber(r.totalQuantity)),
          ListExportColumn(
              label: tr('unit'),
              value: (r, _) => r.unit ?? 'general.default_unit'.tr),
          if (showCosts)
            ListExportColumn(
                label: tr('col_stock_value'),
                value: (r, _) => stockReportExportNumber(r.stockValue)),
          ListExportColumn(
              label: tr('col_retail_value'),
              value: (r, _) => stockReportExportNumber(r.retailValue)),
          ListExportColumn(
              label: tr('col_expiry_date'),
              value: (r, _) => stockReportExpiry(r.expiryDate)),
        ]);
  }
}
