import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/consumed_stocks_report.dart';
import '../../domain/consumed_stocks_report_query.dart';

abstract final class ConsumedStocksReportExport {
  static Future<File> build(
          List<ConsumedStockData> rows, ConsumedStocksReportQuery query,
          {Directory? outputDirectory}) =>
      ListExcelExportService.export<ConsumedStockData>(
          items: List.of(rows),
          fileNamePrefix: 'consumed-stocks-report',
          sheetName: 'Consumed Stocks',
          outputDirectory: outputDirectory,
          columns: [
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_no'.tr,
                value: (_, i) => i + 1),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_product'.tr,
                value: (r, _) => r.product),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_store'.tr,
                value: (r, _) => r.store),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_quantity_withdrawn'.tr,
                value: (r, _) =>
                    ListExcelExportService.numericValue(r.quantityWithdrawn)),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_new_quantity'.tr,
                value: (r, _) => ListExcelExportService.numericValue(
                    r.newQuantity?.toString())),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_withdrawn_by'.tr,
                value: (r, _) => r.withdrawnBy),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.col_date_time'.tr,
                value: (r, _) => r.createdAt),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.applied_product_id'.tr,
                value: (_, __) => query.productId),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.applied_store_id'.tr,
                value: (_, __) => query.storeId),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.applied_from'.tr,
                value: (_, __) => query.apiFrom),
            ListExportColumn<ConsumedStockData>(
                label: 'consumed_stocks_report.applied_until'.tr,
                value: (_, __) => query.apiUntil),
          ]);
}
