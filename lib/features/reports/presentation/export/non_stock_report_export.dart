import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/non_stock_report.dart';
import '../../domain/non_stock_report_query.dart';

abstract final class NonStockReportExport {
  static List<ListExportColumn<NonStockReportData>> columns(
          NonStockReportQuery query) =>
      [
        ListExportColumn(
            label: 'non_stock_report.col_no'.tr, value: (_, i) => i + 1),
        ListExportColumn(
            label: 'non_stock_report.col_product_name'.tr,
            value: (r, _) => r.name),
        ListExportColumn(
            label: 'non_stock_report.col_category'.tr,
            value: (r, _) => r.categoryName),
        ListExportColumn(
            label: 'non_stock_report.col_store'.tr, value: (r, _) => r.store),
        ListExportColumn(
            label: 'non_stock_report.col_barcode'.tr,
            value: (r, _) => r.barcode),
        ListExportColumn(
            label: 'non_stock_report.col_current_stock'.tr,
            value: (r, _) => ListExcelExportService.numericValue(
                r.totalQuantity?.toString())),
        ListExportColumn(
            label: 'non_stock_report.col_reorder_level'.tr,
            value: (r, _) => ListExcelExportService.numericValue(
                r.reorderLevel?.toString())),
        ListExportColumn(
            label: 'non_stock_report.col_unit'.tr, value: (r, _) => r.unit),
        ListExportColumn(
            label: 'non_stock_report.col_status'.tr,
            value: (r, _) => UiCodeLabels.stockStatus(r.status)),
        ListExportColumn(
            label: 'non_stock_report.applied_store'.tr,
            value: (_, __) => query.store),
        ListExportColumn(
            label: 'non_stock_report.applied_category'.tr,
            value: (_, __) => query.category),
        ListExportColumn(
            label: 'non_stock_report.applied_product'.tr,
            value: (_, __) => query.product),
        ListExportColumn(
            label: 'non_stock_report.applied_barcode'.tr,
            value: (_, __) => query.barcode),
      ];
  static Future<File> build(
          List<NonStockReportData> rows, NonStockReportQuery query,
          {Directory? outputDirectory}) =>
      ListExcelExportService.export(
          items: List.of(rows),
          columns: columns(query),
          fileNamePrefix: 'non-stock-report',
          sheetName: 'Non-Stock Report',
          outputDirectory: outputDirectory);
}
