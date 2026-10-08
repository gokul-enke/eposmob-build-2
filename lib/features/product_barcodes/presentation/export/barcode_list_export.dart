import 'dart:io';
import 'package:get/get.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';
import '../models/barcode_row.dart';

/// Only primitive values: later catalogue edits cannot change an in-flight file.
List<List<Object?>> barcodeExportSnapshot(List<BarcodeRow> rows) =>
    List.unmodifiable([
      for (final row in rows)
        List<Object?>.unmodifiable([
          row.displayName,
          row.barcode,
          row.product.category?.name,
          ListExcelExportService.numericValue(row.quantity),
          ListExcelExportService.numericValue(row.priceDisplay),
          ListExcelExportService.numericValue(row.mrpDisplay),
          row.sku,
        ]),
    ]);

Future<File> exportBarcodeList(List<List<Object?>> snapshot,
    {Directory? outputDirectory}) {
  final keys = [
    'product_name',
    'barcode',
    'category',
    'qty',
    'col_price',
    'mrp',
    'col_sku'
  ];
  return ListExcelExportService.export<List<Object?>>(
    items: snapshot,
    fileNamePrefix: 'product-barcodes',
    sheetName: 'product_barcode.title'.tr,
    outputDirectory: outputDirectory,
    columns: [
      ListExportColumn(
          label: 'product_barcode.col_no'.tr, value: (_, index) => index + 1),
      for (var i = 0; i < keys.length; i++)
        ListExportColumn(
            label: 'product_barcode.${keys[i]}'.tr, value: (row, _) => row[i]),
    ],
  );
}
