import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/features/product_barcodes/presentation/models/barcode_row.dart';
import 'package:pos_machine/features/product_barcodes/presentation/models/barcode_rows.dart';
import 'package:pos_machine/features/product_barcodes/presentation/export/barcode_list_export.dart';
import '../../../../test_support/app_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.addTranslations(EnglishTranslations().keys);
    Get.locale = const Locale('en');
  });
  tearDown(Get.reset);

  test(
      'exports base, variant and sale-unit as separate rows with exact prices and text identifiers',
      () async {
    final product = GetProduct(
        productId: 1,
        productName: 'Rice',
        barcode: '00001',
        sku: '00002',
        price: ProductPrice(price: '6.125'),
        mrp: '8.250',
        numberOfProductsAvailable: '2.125',
        variants: [
          ProductVariant(
              id: 4, active: true, barcode: '00003', price: 9.75, quantity: 3)
        ],
        saleUnits: [
          SaleUnit(id: 5, unitName: 'BOX', barcode: '00004', price: 24.5)
        ]);
    final dir = await Directory.systemTemp.createTemp('barcode-xlsx-');
    addTearDown(() => dir.delete(recursive: true));
    final snapshot =
        barcodeExportSnapshot(expandProductsToBarcodeRows([product]));
    final file = await exportBarcodeList(snapshot, outputDirectory: dir);
    final rows =
        Excel.decodeBytes(await file.readAsBytes()).tables.values.single.rows;
    expect(rows.length, 4);
    expect(rows.first.map((cell) => cell!.value.toString()).toList(), [
      'No',
      'Product Name',
      'Barcode',
      'Category',
      'Qty',
      'Price',
      'MRP',
      'SKU'
    ]);
    expect(rows[1][2]!.value, TextCellValue('00001'));
    expect(rows[1][7]!.value, TextCellValue('00002'));
    expect(rows[2][2]!.value, TextCellValue('00003'));
    expect(rows[2][5]!.value, const DoubleCellValue(9.75));
    expect(rows[3][1]!.value, TextCellValue('Rice (BOX)'));
    expect(rows[3][2]!.value, TextCellValue('00004'));
    expect(rows[3][5]!.value, const DoubleCellValue(24.5));
    expect(rows[1][6]!.value, const DoubleCellValue(8.25));
  });
  test(
      'snapshot freezes nested mutable stock quantity before encoding and preserves unknowns',
      () {
    final stock = [Stock(id: 1, productVariantId: null, quantity: 2.125)];
    final product = GetProduct(
        productId: 1,
        barcode: '0001',
        stock: stock,
        variants: [ProductVariant(id: 2, active: true)]);
    final row = BarcodeRow(product: product);
    final snapshot = barcodeExportSnapshot([row]);
    expect(snapshot.single[3], 2.125);
    stock.clear();
    expect(row.quantity, '0');
    expect(snapshot.single[3], 2.125);
    expect(snapshot.single[4], 'N/A');
    expect(() => snapshot.add([]), throwsUnsupportedError);
    expect(() => snapshot.single[1] = 'changed', throwsUnsupportedError);
  });
  test('all added listing strings exist in English, Arabic and Malayalam', () {
    final keys = [
      'filters',
      'export',
      'refresh',
      'filters_title',
      'filters_hint',
      'all_categories',
      'search_category',
      'export_failed',
      'load_failed',
      'retry',
      'page_count',
      'select',
      'copy_barcode'
    ];
    for (final language in ['en', 'ar', 'ml']) {
      final strings = translationSection(language, 'product_barcode');
      for (final key in keys) {
        expect(
            strings[key],
            isA<String>()
                .having((value) => value.isNotEmpty, 'not empty', isTrue));
      }
    }
  });
}
