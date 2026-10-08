import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/products/presentation/export/product_list_excel.dart';
import 'package:pos_machine/models/get_product.dart';
import '../../../../test_support/app_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('product-workbook-');
    Get.addTranslations(EnglishTranslations().keys);
    Get.locale = const Locale('en');
  });
  tearDown(() async {
    Get.reset();
    await directory.delete(recursive: true);
  });
  for (final allowed in [false, true]) {
    test(
        'workbook columns obey cost permission and item-code setting: $allowed',
        () async {
      final file = await exportProductList([
        GetProduct(
            productId: 1,
            productName: 'First',
            barcode: '00012345',
            itemCode: '00067',
            price: ProductPrice(price: '10.250'),
            mrp: '12.500',
            stock: [Stock(purchasePrice: '3.750')]),
        GetProduct(
            productId: 2,
            productName: 'Second',
            purchasePrice: '4.125',
            stock: [Stock(purchasePrice: '99')]),
      ],
          canViewPurchasePrice: allowed,
          itemCodeEnabled: allowed,
          outputDirectory: directory);
      final rows =
          Excel.decodeBytes(await file.readAsBytes()).tables.values.single.rows;
      final headers = rows.first.map((c) => c?.value.toString()).toList();
      expect(rows, hasLength(3));
      expect(headers.contains('Purchase Price'), allowed);
      expect(headers.contains('Item Code'), allowed);
      expect(rows[1][headers.indexOf('Price')]?.value,
          const DoubleCellValue(10.25));
      expect(rows[1][headers.indexOf('Barcode')]?.value.toString(), '00012345');
      if (allowed) {
        expect(
            rows[1][headers.indexOf('Item Code')]?.value.toString(), '00067');
        final cost = headers.indexOf('Purchase Price');
        expect(rows[1][cost]?.value, const DoubleCellValue(3.75));
        expect(rows[2][cost]?.value, const DoubleCellValue(4.125));
      } else {
        expect(
            rows.expand((r) => r).any((c) =>
                ['3.75', '4.125', '99', '00067'].contains(c?.value.toString())),
            false);
      }
    });
  }
}
