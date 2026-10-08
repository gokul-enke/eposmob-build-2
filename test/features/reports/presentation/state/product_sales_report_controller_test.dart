import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import 'package:pos_machine/features/reports/domain/product_sales_query.dart';
import 'package:pos_machine/features/reports/presentation/state/product_sales_report_controller.dart';
import '../../support/product_sales_fixtures.dart';

ProductSalesReportController controller(
        {ProductSalesFetch? fetch,
        ProductSalesDirectory? categories,
        ProductSalesDirectory? products,
        ProductSalesDirectory? customers,
        Future<ProductSalesScope> Function()? scope}) =>
    ProductSalesReportController(
        fetch: fetch ??
            (_, page, size) async => productReport(page, perPage: size),
        readScope: scope ?? () async => productSalesScope,
        fetchCategories: categories ?? () async => [categoryOption],
        fetchProducts: products ?? () async => [productOption],
        fetchCustomers: customers ?? () async => [customerOption]);

void main() {
  test('partial directory failure cannot overlap its pending snapshot on Retry',
      () async {
    final pendingProducts = Completer<List<ProductSalesOption>>();
    final pendingReport = Completer<GetProductSalesReportResponse>();
    var productLoads = 0, customerLoads = 0;
    var failCustomers = true;
    final c = controller(
        fetch: (_, p, s) => pendingReport.future,
        products: () {
          productLoads++;
          return pendingProducts.future;
        },
        customers: () async {
          customerLoads++;
          if (failCustomers) throw StateError('directory');
          return [customerOption];
        });
    addTearDown(c.dispose);
    final initial = c.initialize();
    await Future<void>.delayed(Duration.zero);
    pendingReport.complete(productReport(1));
    await Future<void>.delayed(Duration.zero);
    expect(c.optionsLoading, isTrue);
    expect(c.optionsFailed, isTrue);
    expect(c.canExport, isTrue);
    await c.loadOptions();
    expect(productLoads, 1);
    expect(customerLoads, 1);
    pendingProducts.complete([productOption]);
    await initial;
    expect(c.optionsLoading, isFalse);
    failCustomers = false;
    await c.loadOptions();
    expect(productLoads, 2);
    expect(customerLoads, 2);
    expect(c.optionsFailed, isFalse);
    expect(c.customers, [customerOption]);
  });
  test(
      'every filter, category-product dependency and Reset retain request contract',
      () async {
    final calls = <({ProductSalesQuery query, int page, int size})>[];
    final c = controller(fetch: (q, p, s) async {
      calls.add((query: q, page: p, size: s));
      return productReport(p);
    });
    addTearDown(c.dispose);
    await c.initialize();
    await c.selectCategory(categoryOption);
    await c.selectProduct(productOption);
    await c.selectCustomer(customerOption);
    await c.selectDate(DateTime(2026, 9, 1), true);
    await c.selectDate(DateTime(2026, 9, 30), false);
    expect(calls.last.query.categoryId, '88');
    expect(calls.last.query.productId, '9');
    expect(calls.last.query.customerId, '7');
    expect(calls.last.query.from, '2026-09-01');
    expect(calls.last.query.to, '2026-09-30');
    expect(calls.every((v) => v.size == 25), isTrue);
    await c.selectCategory(const ProductSalesOption(id: '99', label: 'Other'));
    expect(c.product, isNull);
    expect(c.visibleProducts, isEmpty);
    await c.reset();
    expect(c.query.active, isFalse);
    expect(c.page, 1);
    await c.goToPage(2);
    await c.reset();
    await c.retry();
    expect(calls.last.page, 1);
  });
  test('inverted dates clear results and never reach API; Reset recovers',
      () async {
    var calls = 0;
    final c = controller(fetch: (_, p, s) async {
      calls++;
      return productReport(p);
    });
    addTearDown(c.dispose);
    await c.initialize();
    await c.selectDate(DateTime(2026, 9, 1), false);
    final previous = calls;
    await c.selectDate(DateTime(2026, 9, 2), true);
    expect(calls, previous);
    expect(c.report, isNull);
    expect(c.canExport, isFalse);
    expect(c.errorKey, 'product_sales_report.invalid_date_range');
    await c.reset();
    expect(c.errorKey, isNull);
    expect(c.canExport, isTrue);
  });
  test('serialized queue drops stale refresh and keeps newest page/filter',
      () async {
    final pending = Completer<GetProductSalesReportResponse>();
    final pages = <int>[];
    final c = controller(fetch: (_, p, s) {
      pages.add(p);
      return pages.length == 2
          ? pending.future
          : Future.value(productReport(p));
    });
    addTearDown(c.dispose);
    await c.initialize();
    final refresh = c.retry();
    await Future<void>.delayed(Duration.zero);
    await c.load(requestedPage: 3);
    pending.complete(productReport(1));
    await refresh;
    expect(pages, [1, 1, 3]);
    expect(c.page, 3);
    expect(c.loading, isFalse);
  });
  test('failed filter after page two retries page one; export stays disabled',
      () async {
    var fail = false;
    final pages = <int>[];
    final c = controller(fetch: (_, p, s) async {
      pages.add(p);
      if (fail) throw StateError('network');
      return productReport(p);
    });
    addTearDown(c.dispose);
    await c.initialize();
    await c.goToPage(2);
    fail = true;
    await c.selectCustomer(customerOption);
    expect(c.report, isNull);
    expect(c.canExport, isFalse);
    await c.goToPage(3);
    expect(pages.last, 1);
    fail = false;
    await c.retry();
    expect(pages.last, 1);
    expect(c.page, 1);
  });
  test(
      'partial options failure retains successful options and leaves table usable',
      () async {
    var fail = true;
    final c = controller(customers: () async {
      if (fail) throw StateError('directory');
      return [customerOption];
    });
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.optionsFailed, isTrue);
    expect(c.products, [productOption]);
    expect(c.categories, [categoryOption]);
    expect(c.report, isNotNull);
    expect(c.canExport, isTrue);
    fail = false;
    await c.loadOptions();
    expect(c.optionsFailed, isFalse);
    expect(c.customers, [customerOption]);
  });
  test('delayed options do not block table; disposed results never notify',
      () async {
    final pending = Completer<List<ProductSalesOption>>();
    final c = controller(customers: () => pending.future);
    var notifications = 0;
    c.addListener(() => notifications++);
    final initial = c.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(c.optionsLoading, isTrue);
    expect(c.canExport, isTrue);
    c.dispose();
    final count = notifications;
    pending.complete([customerOption]);
    await initial;
    expect(notifications, count);
  });
  test(
      'export uses all filtered pages in batches of 250 without changing visible data',
      () async {
    final calls = <({ProductSalesQuery query, int size})>[];
    final c = controller(fetch: (q, p, s) async {
      calls.add((query: q, size: s));
      return productReport(p, perPage: s);
    });
    addTearDown(c.dispose);
    await c.initialize();
    await c.selectCategory(categoryOption);
    final visible = c.report;
    final result = await c.export(build: (rows) async => rows);
    expect(result.length, 3);
    expect(c.report, same(visible));
    expect(
        calls.skip(2).every((v) => v.size == 250 && v.query.categoryId == '88'),
        isTrue);
  });
  for (final mutation in ['filter', 'scope', 'dispose']) {
    test('$mutation during workbook creation cancels delivery', () async {
      var scope = productSalesScope;
      final c = controller(scope: () async => scope);
      await c.initialize();
      await expectLater(c.export(build: (_) async {
        if (mutation == 'filter') {
          await c.selectCustomer(customerOption);
        }
        if (mutation == 'scope') {
          scope = (
            token: 'other',
            tenant: 'tenant',
            storeId: 1,
            endpoint: 'endpoint'
          );
        }
        if (mutation == 'dispose') c.dispose();
        return 'file';
      }), throwsStateError);
      if (mutation != 'dispose') c.dispose();
    });
  }
}
