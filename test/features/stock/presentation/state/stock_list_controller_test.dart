import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/stock/domain/stock_list_query.dart';
import 'package:pos_machine/features/stock/presentation/state/stock_list_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late StockListQuery? submitted;
  late StockListController controller;
  var variants = false;
  setUp(() {
    calls = [];
    submitted = null;
    variants = false;
    controller = StockListController(
        ensureCategories: () async {
          calls.add('categories');
        },
        fetchStocks: (token) async {
          calls.add('stocks:$token');
        },
        fetchStores: (token) async {
          calls.add('stores:$token');
        },
        readCategoryNames: () => ['Zulu', '', 'Alpha'],
        readStoreNames: () => ['Store B', 'Store A', 'Store B', ''],
        applyFilters: (query) {
          submitted = query;
        },
        resetFilters: () {
          calls.add('reset');
        },
        readVariantEnabled: () => variants);
  });
  tearDown(() {
    controller.dispose();
  });
  test(
      'initial load retains request order, sorted options and duplicate category semantics',
      () async {
    await controller.load('token');
    expect(calls, ['categories', 'stocks:token', 'stores:token']);
    expect(controller.categories, ['All Categories', 'Alpha', 'Zulu']);
    expect(controller.stores, ['All Stores', 'Store A', 'Store B']);
    expect(controller.initialized, isTrue);
    expect(controller.loading, isFalse);
  });
  test(
      'every filter and variant setting reaches the existing provider boundary',
      () {
    controller.stockNameController.text = 'apple';
    controller.categoryController.text = 'Produce';
    controller.barcodeController.text = '123';
    controller.rackController.text = 'A';
    controller.storeController.text = 'Main';
    controller.stockStatusController.text = 'Low Stock';
    variants = true;
    controller.search();
    expect(submitted!.name, 'apple');
    expect(submitted!.category, 'Produce');
    expect(submitted!.barcode, '123');
    expect(submitted!.rack, 'A');
    expect(submitted!.store, 'Main');
    expect(submitted!.status, 'Low Stock');
    expect(submitted!.includeVariants, isTrue);
    expect(controller.hasActiveFilters, isTrue);
    controller.reset();
    controller.search();
    expect(calls, ['reset']);
    expect(controller.hasActiveFilters, isFalse);
    expect(submitted!.name, '');
    expect(submitted!.category, isNull);
    expect(submitted!.barcode, isNull);
    expect(submitted!.rack, isNull);
    expect(submitted!.store, isNull);
    expect(submitted!.status, isNull);
  });
  test('request failure releases loading and allows retry', () async {
    controller.dispose();
    var fails = true;
    controller = StockListController(
        ensureCategories: () async {},
        fetchStocks: (_) async {
          if (fails) throw StateError('network');
        },
        fetchStores: (_) async {},
        readCategoryNames: () => [],
        readStoreNames: () => [],
        applyFilters: (_) {},
        resetFilters: () {},
        readVariantEnabled: () => false);
    await expectLater(controller.load('token'), throwsStateError);
    expect(controller.loading, isFalse);
    expect(controller.initialized, isFalse);
    fails = false;
    await controller.load('token');
    expect(controller.initialized, isTrue);
  });
  test(
      'disposing during category fetch prevents subsequent requests and notifications',
      () async {
    controller.dispose();
    final pending = Completer<void>();
    var requests = 0, notifications = 0;
    controller = StockListController(
        ensureCategories: () => pending.future,
        fetchStocks: (_) async {
          requests++;
        },
        fetchStores: (_) async {
          requests++;
        },
        readCategoryNames: () => [],
        readStoreNames: () => [],
        applyFilters: (_) {},
        resetFilters: () {},
        readVariantEnabled: () => false);
    controller.addListener(() {
      notifications++;
    });
    final operation = controller.load('token');
    controller.dispose();
    pending.complete();
    await operation;
    expect(requests, 0);
    expect(notifications, 1);
    // Replacement keeps the common tearDown ownership unambiguous.
    controller = StockListController(
        ensureCategories: () async {},
        fetchStocks: (_) async {},
        fetchStores: (_) async {},
        readCategoryNames: () => [],
        readStoreNames: () => [],
        applyFilters: (_) {},
        resetFilters: () {},
        readVariantEnabled: () => false);
  });
  test('missing token performs no requests and leaves loading false', () async {
    await expectLater(controller.load(''), throwsStateError);
    expect(calls, isEmpty);
    expect(controller.loading, isFalse);
  });
}
