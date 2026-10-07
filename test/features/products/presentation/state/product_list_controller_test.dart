import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/products/data/product_list_source.dart';
import 'package:pos_machine/features/products/presentation/state/product_list_controller.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<GetProduct> catalog;
  late ProductListController list;
  late List<int> deleted;
  setUp(() {
    catalog = List.generate(
        45,
        (i) => GetProduct(
            productId: i + 1,
            productName: 'Product ${i + 1}',
            barcode: '${i + 1}',
            categoryId: i < 25 ? 1 : 2,
            itemCode: 'SKU-${i + 1}',
            hsnCode: 'HSN-${i + 1}',
            price: ProductPrice(price: '${i + 1}.00')));
    deleted = [];
    list = ProductListController(
        source: ProductListSource(
            readCatalog: () => catalog,
            deleteProduct: (id) async {
              deleted.add(id);
              catalog.removeWhere((p) => p.productId == id);
              return true;
            }),
        ensureCategories: () async {});
  });
  tearDown(() => list.dispose());
  test('pagination and refresh match twenty-per-page and full reset', () async {
    await list.initialize();
    expect(list.totalPages, 3);
    list.goToPage(2);
    expect(list.rows.first.productId, 21);
    list.goToPage(99);
    expect(list.page, 2);
    list.name.text = 'Product 1';
    list.search();
    expect(list.page, 1);
    await list.refresh();
    expect(list.all, hasLength(45));
    expect(list.name.text, isEmpty);
  });
  testWidgets('Reset cancels pending debounce and clears every input',
      (tester) async {
    await list.initialize();
    for (final input in [
      list.name,
      list.price,
      list.barcode,
      list.hsn,
      list.itemCode
    ]) {
      input.text = 'missing';
    }
    list.categoryId = 2;
    list.property = 'COLOR';
    list.scheduleSearch();
    list.reset();
    await tester.pump(const Duration(milliseconds: 350));
    expect(list.hasFilters, isFalse);
    expect(list.all, hasLength(45));
    expect(list.page, 1);
  });
  testWidgets(
      'export flushes pending filters and otherwise preserves the displayed page',
      (tester) async {
    await list.initialize();
    list.goToPage(2);
    expect(list.exportSnapshot(), hasLength(45));
    expect(list.page, 2);
    list.categoryId = 2;
    list.scheduleSearch();
    final snapshot = list.exportSnapshot();
    expect(snapshot, hasLength(20));
    expect(list.page, 1);
    list.reset();
    expect(snapshot, hasLength(20));
    await tester.pump(const Duration(milliseconds: 350));
    expect(list.all, hasLength(45));
  });
  test('deletion uses the exact ID and clamps the last page', () async {
    await list.initialize();
    list.goToPage(3);
    catalog.removeRange(41, 45);
    expect(await list.delete(41), isTrue);
    expect(deleted, [41]);
    expect(list.page, 2);
    expect(list.totalPages, 2);
  });
  testWidgets(
      'property filters reset pagination and export the same frozen rows',
      (tester) async {
    for (var i = 0; i < 25; i++) {
      catalog[i] = catalog[i].copyWith(variants: [
        ProductVariant(id: i + 1, attributes: {'PRODUCT_COLOR': 'blue'}),
      ]);
    }
    await list.initialize();
    list.goToPage(3);
    list.selectProperty('PRODUCT_COLOR');
    expect(list.page, 1);
    expect(list.totalPages, 2);
    list.goToPage(2);
    expect(list.rows.map((p) => p.productId), [21, 22, 23, 24, 25]);
    final snapshot = list.exportSnapshot();
    expect(snapshot, hasLength(25));
    expect(list.page, 2);
    list.name.text = 'Product 25';
    list.scheduleSearch();
    expect(list.exportSnapshot().map((p) => p.productId), [25]);
    expect(list.page, 1);
    list.reset();
    await tester.pump(const Duration(milliseconds: 350));
    expect(list.property, isNull);
    expect(list.all, hasLength(45));
    expect(list.totalPages, 3);
    expect(snapshot, hasLength(25));
    list.selectProperty('SHOE_SIZE');
    expect(list.all, isEmpty);
    expect(list.canExport, isFalse);
    await list.refresh();
    expect(list.property, isNull);
    expect(list.all, hasLength(45));
  });
  test('directory outage retains local rows and can be retried', () async {
    var failed = true;
    final controller = ProductListController(
        source: list.source,
        ensureCategories: () async {
          if (failed) throw StateError('directory unavailable');
        });
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.rows, hasLength(20));
    expect(controller.error, isNotNull);
    expect(controller.canExport, isFalse);
    failed = false;
    await controller.initialize();
    expect(controller.error, isNull);
    expect(controller.canExport, isTrue);
  });
  test('late category completion after disposal does not notify', () async {
    final pending = Completer<void>();
    final controller = ProductListController(
        source: list.source, ensureCategories: () => pending.future);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.initialize();
    controller.dispose();
    pending.complete();
    await load;
    expect(notifications, 1);
  });
  test('an older directory failure cannot replace a successful retry',
      () async {
    final first = Completer<void>();
    var calls = 0;
    final controller = ProductListController(
        source: list.source,
        ensureCategories: () {
          return calls++ == 0 ? first.future : Future.value();
        });
    addTearDown(controller.dispose);
    final older = controller.initialize();
    await controller.initialize();
    first.completeError(StateError('old failure'));
    await older;
    expect(controller.error, isNull);
    expect(controller.canExport, isTrue);
  });
}
