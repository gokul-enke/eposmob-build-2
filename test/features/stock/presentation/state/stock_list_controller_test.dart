import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/stock/domain/stock_list_query.dart';
import 'package:pos_machine/features/stock/presentation/state/stock_list_controller.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/providers/stock_provider.dart';

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
  testWidgets(
      'reload restoration retains all applied filters and pending edits',
      (tester) async {
    await controller.load('token');
    controller.stockNameController.text = 'apple';
    controller.categoryController.text = 'Produce';
    controller.barcodeController.text = '123';
    controller.rackController.text = 'A';
    controller.storeController.text = 'Main';
    controller.stockStatusController.text = 'Low Stock';
    variants = true;
    controller.search();
    final applied = submitted!;
    controller.stockNameController.text = 'pear';
    controller.scheduleSearch();
    submitted = null;
    controller.restoreAppliedFilters();
    expect(submitted, same(applied));
    expect(
        submitted!.sameFiltersAs(const StockListQuery(
            name: 'apple',
            category: 'Produce',
            barcode: '123',
            rack: 'A',
            store: 'Main',
            status: 'Low Stock',
            includeVariants: true)),
        isTrue);
    expect(controller.stockNameController.text, 'pear');
    await tester.pump(const Duration(milliseconds: 300));
    expect(submitted!.name, 'pear');
    expect(submitted!.category, 'Produce');
    expect(submitted!.includeVariants, isTrue);
  });
  test('restore does not filter an uninitialized or loading page', () async {
    controller.search();
    submitted = null;
    controller.restoreAppliedFilters();
    expect(submitted, isNull);
    await controller.load('token');
    submitted = null;
    controller.loading = true;
    controller.restoreAppliedFilters();
    expect(submitted, isNull);
  });
  test(
      'refresh restores filters before a store failure and retains them on retry',
      () async {
    controller.dispose();
    final stocks = StockProvider();
    addTearDown(stocks.dispose);
    var failStores = false;
    controller = StockListController(
        ensureCategories: () async {},
        fetchStocks: (_) async {
          stocks.applyRealtimeStocks([
            ListStockModelData(stockId: 1, productName: 'Apple'),
            ListStockModelData(stockId: 2, productName: 'Pear'),
          ]);
          // Match loadAllStocks resetting the provider's applied filters.
          stocks.applyStockFiltersLocally(page: 1);
        },
        fetchStores: (_) async {
          expect(stocks.stockFilterName, controller.stockNameController.text);
          if (failStores) throw StateError('store request failed');
        },
        readCategoryNames: () => [],
        readStoreNames: () => [],
        applyFilters: (query) => stocks.applyStockFiltersLocally(
            filterName: query.name, includeVariants: query.includeVariants),
        resetFilters: stocks.resetStockFilters,
        readVariantEnabled: () => false);
    await controller.load('token');
    controller.stockNameController.text = 'Pear';
    controller.search();
    failStores = true;
    await expectLater(controller.load('token'), throwsStateError);
    expect(controller.stockNameController.text, 'Pear');
    expect(stocks.stockFilterName, 'Pear');
    expect(stocks.listStockModelDataList!.map((s) => s.productName), ['Pear']);
    expect(controller.loading, isFalse);
    expect(controller.loadError, isNotNull);
    failStores = false;
    await controller.load('token');
    expect(controller.loadError, isNull);
    expect(stocks.listStockModelDataList!.map((s) => s.productName), ['Pear']);
    controller.reset();
    expect(stocks.listStockModelDataList!.map((s) => s.productName),
        ['Apple', 'Pear']);
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
  testWidgets('undone or equivalent debounce edits do not reapply filters',
      (tester) async {
    controller.stockNameController.text = 'Apple';
    controller.search();
    final original = submitted;
    controller.stockNameController.text = 'AppleX';
    controller.scheduleSearch();
    controller.stockNameController.text = 'Apple';
    controller.scheduleSearch();
    expect(controller.flushSearch(), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(identical(submitted, original), isTrue);
    controller.stockNameController.text = 'APPLE';
    controller.scheduleSearch();
    await tester.pump(const Duration(milliseconds: 300));
    expect(identical(submitted, original), isTrue);
    // A feature setting change is a real change, even with the same text.
    variants = true;
    controller.scheduleSearch();
    expect(controller.flushSearch(), isTrue);
    expect(submitted!.includeVariants, isTrue);
    expect(identical(submitted, original), isFalse);
  });
  testWidgets('debounce flush, reset and disposal cancel pending searches',
      (tester) async {
    controller.stockNameController.text = 'apple';
    controller.scheduleSearch();
    await tester.pump(const Duration(milliseconds: 299));
    expect(submitted, isNull);
    expect(controller.flushSearch(), isTrue);
    expect(submitted!.name, 'apple');
    expect(controller.flushSearch(), isFalse);
    controller.stockNameController.text = 'pear';
    controller.scheduleSearch();
    controller.reset();
    await tester.pump(const Duration(milliseconds: 300));
    expect(submitted!.name, 'apple');
    expect(controller.query.name, isEmpty);
    controller.scheduleSearch();
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 300));
    expect(submitted!.name, 'apple');
    // Replace disposed ownership for the shared tearDown.
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
}
