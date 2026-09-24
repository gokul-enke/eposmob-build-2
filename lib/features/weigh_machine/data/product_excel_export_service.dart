import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pos_machine/features/weigh_machine/data/plu_export_service.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/models/get_product.dart';

enum ProductExcelField {
  name('Product Name'),
  category('Category'),
  barcode('Barcode'),
  price('Price'),
  mrp('MRP'),
  unit('Unit'),
  sku('SKU'),
  purchasePrice('Purchase Price'),
  arabicName('Arabic Name');

  const ProductExcelField(this.label);
  final String label;

  /// Pre-ticked in the export dialog; users add the other columns they need.
  static const defaults = <ProductExcelField>[name];

  /// [storeId] picks which store's stock rows supply the SKU.
  CellValue? value(GetProduct product, {int? storeId}) {
    switch (this) {
      case name:
        return TextCellValue(product.productName ?? '');
      case category:
        return TextCellValue(product.category?.name ?? '');
      case barcode:
        return TextCellValue(product.barcode ?? '');
      case price:
        return _number(product.price?.price);
      case mrp:
        return _number(product.mrp);
      case unit:
        return TextCellValue(product.unit ?? '');
      case sku:
        return TextCellValue(PluCsv.skuOf(product, storeId: storeId) ?? '');
      case purchasePrice:
        return _number(product.purchasePrice);
      case arabicName:
        final names = product.names;
        return TextCellValue(names is Map ? names['ar']?.toString() ?? '' : '');
    }
  }

  static CellValue? _number(Object? raw) {
    final value = double.tryParse(raw?.toString() ?? '');
    return value == null ? null : DoubleCellValue(value);
  }
}

class ProductExcelExportService {
  static Future<File> export(
    List<GetProduct> products,
    List<ProductExcelField> fields,
  ) async {
    if (products.isEmpty) throw StateError('There are no products to export.');
    if (fields.isEmpty) throw StateError('Choose at least one field.');

    final storeId = await PluExportService.instance.activeStoreId();
    final rows = <List<CellValue?>>[
      [for (final field in fields) TextCellValue(field.label)],
      for (final product in products)
        [for (final field in fields) field.value(product, storeId: storeId)],
    ];
    final bytes = await Isolate.run(() => _encodeWorkbook(rows, fields.length));
    final directory =
        Directory(await PluExportService.instance.directoryPath());
    if (!await directory.exists()) {
      throw FileSystemException('Save folder is unavailable', directory.path);
    }
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fileName = 'products-${now.year}-${two(now.month)}-${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}-${now.millisecond}.xlsx';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

List<int> _encodeWorkbook(List<List<CellValue?>> rows, int columnCount) {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Products');
  final sheet = excel['Products'];
  for (var index = 0; index < columnCount; index++) {
    sheet.setColumnWidth(index, 20);
  }
  for (final row in rows) {
    sheet.appendRow(row);
  }
  final encoded = excel.encode() ??
      (throw StateError('Could not encode product workbook.'));

  // excel 4.0.6 writes the cells but leaves the worksheet dimension at A1.
  // Readers that trust that metadata then show only the first cell.
  final archive = ZipDecoder().decodeBytes(encoded);
  const worksheetPath = 'xl/worksheets/sheet1.xml';
  final worksheet = archive.findFile(worksheetPath);
  if (worksheet == null) {
    throw StateError('Product workbook is missing its worksheet.');
  }
  final xml = utf8.decode(worksheet.content as List<int>);
  final dimension = RegExp(r'<dimension ref="[^"]*"\s*/>');
  if (!dimension.hasMatch(xml)) {
    throw StateError('Product workbook has no worksheet dimension.');
  }
  final lastColumn = String.fromCharCode('A'.codeUnitAt(0) + columnCount - 1);
  final corrected = xml.replaceFirst(
    dimension,
    '<dimension ref="A1:$lastColumn${rows.length}"/>',
  );
  final correctedBytes = utf8.encode(corrected);
  archive.addFile(ArchiveFile(
    worksheetPath,
    correctedBytes.length,
    correctedBytes,
  ));
  return ZipEncoder().encode(archive) ??
      (throw StateError('Could not finalize product workbook.'));
}
