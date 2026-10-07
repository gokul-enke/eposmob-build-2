import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/features/product_barcodes/data/barcode_list_source.dart';
import 'package:pos_machine/features/product_barcodes/domain/barcode_list_query.dart';
import 'package:pos_machine/features/product_barcodes/presentation/state/barcode_list_controller.dart';
import 'package:pos_machine/features/product_barcodes/presentation/export/barcode_list_export.dart';

class Source extends ChangeNotifier implements BarcodeListSource {
  List<GetProduct> all = List.generate(
      45,
      (i) => GetProduct(
          productId: i + 1,
          productName: 'Product $i',
          barcode: '000$i',
          categoryId: i.isEven ? 1 : 2));
  List<GetProduct> filtered = [];
  int requests = 0, loads = 0, reads = 0;
  @override
  int version = 0;
  Future<List<BarcodeCategory>> Function()? load;
  @override
  List<GetProduct> get products {
    reads++;
    return filtered;
  }

  @override
  Future<List<BarcodeCategory>> categories() async {
    loads++;
    return load == null
        ? [const BarcodeCategory(1, 'Food'), const BarcodeCategory(2, 'Other')]
        : await load!();
  }

  @override
  void apply(BarcodeListQuery query) {
    requests++;
    filtered = all
        .where((p) =>
            (query.categoryId == null || query.categoryId == p.categoryId) &&
            (p.productName ?? '')
                .toLowerCase()
                .contains(query.name.trim().toLowerCase()) &&
            [
              p.barcode,
              ...?p.variants?.map((v) => v.barcode),
              ...?p.saleUnits?.map((u) => u.barcode)
            ].any((b) => (b ?? '')
                .toLowerCase()
                .contains(query.barcode.trim().toLowerCase())))
        .toList();
    version++;
    notifyListeners();
  }

  void signalUnchanged() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Source source;
  late BarcodeListController controller;
  setUp(() {
    source = Source();
    controller = BarcodeListController(source);
  });
  tearDown(() {
    controller.dispose();
    source.dispose();
  });

  test(
      'selection and page-only select-all survive pagination and filters, Reset clears',
      () async {
    await controller.initialize();
    controller.selectPage(true);
    expect(controller.selected.length, 20);
    controller.goToPage(2);
    expect(controller.pageSelected, isFalse);
    controller.selectPage(true);
    expect(controller.selected.length, 40);
    controller.selectPage(false);
    expect(controller.selected.length, 20);
    controller.selectCategory(2);
    expect(controller.rows.length, 22);
    expect(controller.selected.length, 20);
    controller.reset();
    expect(controller.selected, isEmpty);
    expect(controller.page, 1);
    expect(controller.rows.length, 45);
  });
  testWidgets('Reset cancels a pending edit and never reapplies it',
      (tester) async {
    await controller.initialize();
    controller.goToPage(2);
    controller.name.text = 'Product 4';
    controller.scheduleSearch();
    controller.reset();
    final requests = source.requests;
    await tester.pump(const Duration(seconds: 1));
    expect(source.requests, requests);
    expect(controller.name.text, isEmpty);
    expect(controller.rows.length, 45);
    expect(controller.page, 1);
  });
  testWidgets(
      'undone edit and case-only edit keep page; Next moves from that page',
      (tester) async {
    await controller.initialize();
    controller.goToPage(2);
    controller.name.text = 'x';
    controller.scheduleSearch();
    controller.name.clear();
    controller.scheduleSearch();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, 2);
    expect(source.requests, 1);
    controller.goToPage(3);
    expect(controller.page, 3);
    controller.name.text = 'product';
    controller.flushSearch();
    controller.goToPage(2);
    controller.name.text = 'PRODUCT';
    controller.scheduleSearch();
    controller.goToPage(3);
    expect(controller.page, 3);
    expect(source.requests, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, 3);
  });
  test('pagination after actual pending filter starts at page 1', () async {
    await controller.initialize();
    controller.goToPage(3);
    controller.name.text = 'Product 4';
    controller.scheduleSearch();
    controller.goToPage(4);
    expect(controller.page, 1);
    expect(controller.rows.length, 6);
    expect(controller.applied.name, 'Product 4');
  });
  test('selection, unchanged cache notification and paging do not expand again',
      () async {
    await controller.initialize();
    final rows = controller.rows;
    controller.setSelected(controller.rows.first, true);
    controller.goToPage(2);
    source.signalUnchanged();
    expect(identical(controller.rows, rows), isTrue);
    expect(source.reads, 1);
    controller.refresh();
    expect(source.reads, 2);
    expect(controller.page, 1);
  });
  test(
      'unchanged source notification repaints stock values without re-expansion',
      () async {
    source.all = [
      GetProduct(
          productId: 1,
          barcode: 'BASE',
          variants: [ProductVariant(id: 2)],
          stock: [Stock(id: 1, productVariantId: null, quantity: 3)])
    ];
    await controller.initialize();
    final rows = controller.rows;
    var notifications = 0;
    controller.addListener(() => notifications++);
    source.all.single.stock!.clear();
    source.signalUnchanged();
    expect(controller.rows.first.quantity, '0');
    expect(notifications, 1);
    expect(identical(controller.rows, rows), isTrue);
    expect(source.reads, 1);
  });

  test(
      'barcode matching returns the specific base, active variant or sale-unit row',
      () async {
    source.all = [
      GetProduct(productId: 1, barcode: 'BASE', variants: [
        ProductVariant(id: 2, barcode: 'VAR', active: true),
        ProductVariant(id: 3, barcode: 'HIDDEN', active: false)
      ], saleUnits: [
        SaleUnit(id: 4, unitName: 'BOX', barcode: 'UNIT'),
        SaleUnit(id: 5, barcode: 'BASE')
      ])
    ];
    await controller.initialize();
    expect(controller.rows.length, 3);
    for (final code in ['BASE', 'VAR', 'UNIT']) {
      controller.barcode.text = code;
      controller.flushSearch();
      expect(controller.rows.single.barcode, code);
    }
    controller.barcode.text = 'HIDDEN';
    controller.flushSearch();
    expect(controller.rows, isEmpty);
  });
  test(
      'export flushes pending filter and snapshots all pages without touching selection',
      () async {
    await controller.initialize();
    controller.setSelected(controller.rows.first, true);
    controller.goToPage(2);
    controller.name.text = 'Product';
    controller.scheduleSearch();
    controller.flushSearch();
    final snapshot = barcodeExportSnapshot(controller.rows);
    expect(snapshot.length, 45);
    expect(controller.pageRows.length, 20);
    expect(controller.selected.length, 1);
    expect(snapshot.first[1], '0000');
    expect(snapshot.last[0], 'Product 44');
  });
  test(
      'concurrent initialization shares one directory load and one filter request',
      () async {
    final pending = Completer<List<BarcodeCategory>>();
    source.load = () => pending.future;
    final first = controller.initialize();
    final second = controller.initialize();
    expect(source.loads, 1);
    pending.complete([]);
    await Future.wait([first, second]);
    expect(source.requests, 1);
    expect(controller.loading, isFalse);
  });
  test('failed initialization has a visible error and can retry', () async {
    source.load = () => Future.error(StateError('offline'));
    await controller.initialize();
    expect(controller.error, isNotNull);
    expect(source.requests, 0);
    source.load = null;
    await controller.initialize();
    expect(controller.error, isNull);
    expect(controller.rows.length, 45);
    expect(controller.loading, isFalse);
  });
  test('disposed initialization and debounce perform no late work', () async {
    final lateSource = Source();
    final pending = Completer<List<BarcodeCategory>>();
    lateSource.load = () => pending.future;
    final lateController = BarcodeListController(lateSource);
    final init = lateController.initialize();
    lateController.scheduleSearch();
    lateController.dispose();
    pending.complete([]);
    await init;
    expect(lateSource.requests, 0);
    lateSource.dispose();
  });
}
