import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/stock/data/stock_list_snapshot.dart';
import 'package:pos_machine/features/stock/domain/stock_list_query.dart';
import 'package:pos_machine/features/stock/presentation/export/stock_list_excel.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import '../../../test_support/app_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  StockListQuery query(
          {String name = '',
          String? category,
          String? barcode,
          String? rack,
          String? store,
          String? status,
          bool variants = false}) =>
      StockListQuery(
          name: name,
          category: category,
          barcode: barcode,
          rack: rack,
          store: store,
          status: status,
          includeVariants: variants);
  final catalogue = List.generate(
      65,
      (i) => ListStockModelData(
          stockId: i + 1,
          productName: i % 2 == 0 ? 'Apple' : 'Pear',
          categoryName: i % 2 == 0 ? 'Produce' : 'Fresh',
          variantName: i % 3 == 0 ? 'Large' : 'Small',
          productVariantId: i + 2,
          barCode: '000$i',
          rack: i % 2 == 0 ? 'A1' : 'B2',
          storeName: i % 2 == 0 ? 'Main' : 'Other',
          qty: i.toDouble(),
          stockStatus: [
            'Low Stock',
            'Out of Stock',
            'At Reorder Level'
          ][i % 3]));
  for (final filter in [
    query(),
    query(name: 'aPp'),
    query(name: 'Large', variants: false),
    query(name: 'Large', variants: true),
    query(category: 'pRoduce'),
    query(barcode: '001'),
    query(rack: 'a'),
    query(store: 'mAin'),
    query(status: 'out of stock'),
    query(
        category: 'All Categories',
        store: 'All Stores',
        status: 'All Statuses'),
    query(name: 'Apple', rack: 'a1', status: 'Low Stock', variants: true),
  ]) {
    test(
        'snapshot matches every provider page for ${filter.name}/${filter.category}/${filter.barcode}/${filter.rack}/${filter.store}/${filter.status}/${filter.includeVariants}',
        () {
      final provider = StockProvider()..applyRealtimeStocks(catalogue);
      addTearDown(provider.dispose);
      provider.applyStockFiltersLocally(
          filterName: filter.name,
          filterCategory: filter.category,
          filterBarcode: filter.barcode,
          filterRack: filter.rack,
          filterStore: filter.store,
          filterStatus: filter.status,
          includeVariants: filter.includeVariants);
      final ids = <int?>[];
      for (var page = 1; page <= provider.stockTotalPages; page++) {
        provider.goToStockPage(page);
        ids.addAll(provider.listStockModelDataList!.map((s) => s.stockId));
      }
      final beforePage = provider.stockCurrentPage;
      expect(
          stockListSnapshot(provider.allStocks!, filter).map((s) => s.stockId),
          ids);
      expect(provider.stockCurrentPage, beforePage);
    });
  }
  test(
      'secondary filter is ANDed and snapshot stays frozen after realtime replacement',
      () {
    final provider = StockProvider()..applyRealtimeStocks(catalogue);
    addTearDown(provider.dispose);
    final filters = query(name: 'Large', variants: true);
    provider.applyStockFiltersLocally(
        filterName: 'Large',
        filterNameSecondary: 'Apple',
        includeVariants: true);
    final snapshot =
        stockListSnapshot(provider.allStocks!, filters, secondaryName: 'Apple');
    expect(snapshot.map((s) => s.stockId),
        provider.listStockModelDataList!.map((s) => s.stockId));
    provider.applyRealtimeStocks([]);
    expect(snapshot, isNotEmpty);
    expect(() => snapshot.clear(), throwsUnsupportedError);
  });
  for (final costPermission in [false, true]) {
    for (final variants in [false, true]) {
      test(
          'Excel preserves all entries and values; cost=$costPermission variants=$variants',
          () async {
        Get.testMode = true;
        Get.addTranslations(EnglishTranslations().keys);
        Get.locale = const Locale('en');
        addTearDown(Get.reset);
        final directory =
            await Directory.systemTemp.createTemp('stock-list-excel-');
        addTearDown(() => directory.delete(recursive: true));
        final rows = List<ListStockModelData>.of(catalogue);
        rows[0] = rows[0].copyWith(
            barCode: '0000123',
            retailPrice: '12.345',
            mrp: 'invalid',
            purchaseRate: '7.89',
            qty: 1.234567);
        final file = await exportStockListExcel(rows,
            canViewPurchasePrice: costPermission,
            variantEnabled: variants,
            outputDirectory: directory);
        final sheet =
            Excel.decodeBytes(await file.readAsBytes()).tables.values.single;
        expect(sheet.rows, hasLength(66));
        final headers =
            sheet.rows.first.map((c) => c?.value.toString()).toList();
        String? first(String label) =>
            sheet.rows[1][headers.indexOf(label)]?.value.toString();
        expect(headers.contains('Purchase Price'), costPermission);
        expect(headers.contains('Product Variant'), variants);
        expect(first('Barcode'), '0000123');
        expect(first('Retail Price'), '12.345');
        expect(first('MRP'), 'invalid');
        expect(first('Quantity'), '1.234567');
        if (costPermission) expect(first('Purchase Price'), '7.89');
        expect(sheet.rows.last.first?.value.toString(), '65');
      });
    }
  }
}
