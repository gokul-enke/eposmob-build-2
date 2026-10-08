import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../../domain/models/product_sales_report.dart';

abstract final class ProductSalesReportExport {
  static Future<File> build(List<ProductSalesReportEntry> entries) =>
      ListExcelExportService.export<ProductSalesReportEntry>(
          items: entries,
          fileNamePrefix: 'product-sales-report',
          sheetName: 'Product Sales',
          columns: [
            ListExportColumn(
                label: 'product_sales_report.col_category_name'.tr,
                value: (item, _) => item.category),
            ListExportColumn(
                label: 'product_sales_report.col_product_name'.tr,
                value: (item, _) => item.productName),
            ListExportColumn(
                label: 'product_sales_report.col_price'.tr,
                value: (item, _) => item.price),
            ListExportColumn(
                label: 'product_sales_report.col_total_amount'.tr,
                value: (item, _) => item.totalPrice),
            ListExportColumn(
                label: 'product_sales_report.col_products_sold'.tr,
                value: (item, _) => item.salesCount),
          ]);
}
