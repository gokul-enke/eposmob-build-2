import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_border.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/get_product_sales_report_model.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/screens/reports/product_sales_report/product_sales_report.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('mobile report keeps actions visible and toggles filters',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<ReportsProvider>(
            create: (_) => _ReportWithData(),
          ),
          ChangeNotifierProvider<CategoryProvider>(
            create: (_) => _CategoryWithData(),
          ),
          ChangeNotifierProvider<GridSelectionProvider>(
            create: (_) => _TestGridProvider(),
          ),
          ChangeNotifierProvider<CustomerProvider>(
            create: (_) => _TestCustomerProvider(
              customers: [
                CustomerListModelData(id: 10, name: 'First customer'),
                CustomerListModelData(id: 11, name: 'Second customer'),
              ],
            ),
          ),
        ],
        child: const GetMaterialApp(
          home: Scaffold(
            body: ProductSalesReportScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilterToggleButton), findsOneWidget);
    expect(find.byType(ExportShareButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-sales-report-filters')),
      findsNothing,
    );

    await tester.tap(find.byType(FilterToggleButton));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-sales-report-filters')),
      findsOneWidget,
    );
    expect(find.byType(ExportShareButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop uses the compact four-column report filter grid',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<ReportsProvider>(
            create: (_) => _ReportWithData(),
          ),
          ChangeNotifierProvider<CategoryProvider>(
            create: (_) => _CategoryWithData(),
          ),
          ChangeNotifierProvider<GridSelectionProvider>(
            create: (_) => _TestGridProvider(
              products: [
                GetProduct(productId: 1, productName: 'First product'),
                GetProduct(productId: 2, productName: 'Second product'),
              ],
            ),
          ),
          ChangeNotifierProvider<CustomerProvider>(
            create: (_) => _TestCustomerProvider(
              customers: [
                CustomerListModelData(id: 10, name: 'First customer'),
                CustomerListModelData(id: 11, name: 'Second customer'),
              ],
            ),
          ),
        ],
        child: const GetMaterialApp(
          home: Scaffold(
            body: ProductSalesReportScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const filterKeys = [
      'product-sales-report-category-filter',
      'product-sales-report-product-filter',
      'product-sales-report-from-filter',
      'product-sales-report-to-filter',
      'product-sales-report-customer-filter',
    ];
    final filterTops = filterKeys
        .map((key) => tester.getTopLeft(find.byKey(ValueKey(key))))
        .toList();

    for (final position in filterTops.skip(1).take(3)) {
      expect(position.dy, closeTo(filterTops.first.dy, 0.1));
    }

    final resetPosition = tester.getTopLeft(
      find.byKey(const ValueKey('product-sales-report-reset-button')),
    );
    final customerPosition = tester.getTopLeft(
      find.byKey(const ValueKey('product-sales-report-customer-filter')),
    );
    final customerBottom = tester.getBottomRight(
      find.byKey(const ValueKey('product-sales-report-customer-filter')),
    );
    final resetBottom = tester.getBottomRight(
      find.byKey(const ValueKey('product-sales-report-reset-button')),
    );
    expect(filterTops.last.dy, greaterThan(filterTops.first.dy));
    expect(resetPosition.dy, greaterThan(filterTops.last.dy));
    expect(resetBottom.dy, closeTo(customerBottom.dy, 0.1));
    expect(resetPosition.dx, greaterThan(customerPosition.dx));
    expect(
      find.byKey(const ValueKey('product-sales-report-search-button')),
      findsNothing,
    );

    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('product-sales-report-reset-button'),
            ),
          )
          .height,
      45,
    );

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-from-filter'),
        ),
        matching: find.byType(BuildBorderContainer),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(
                const ValueKey('product-sales-report-from-filter'),
              ),
              matching: find.byType(BuildBorderContainer),
            ),
          )
          .height,
      45,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-to-filter'),
        ),
        matching: find.byType(BuildBorderContainer),
      ),
      findsOneWidget,
    );
    final tableWidth = tester
        .getSize(
          find.byKey(const ValueKey('product-sales-report-table-width')),
        )
        .width;
    final summaryWidth = tester
        .getSize(
          find.byKey(const ValueKey('product-sales-report-summary')),
        )
        .width;
    expect(tableWidth, closeTo(summaryWidth, 0.1));
    expect(find.byIcon(Icons.monetization_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('product-sales-report-table-width')),
        matching: find.byType(Table),
      ),
      findsNWidgets(2),
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('product-sales-report-table-width')),
        matching: find.byType(BuildBoxShadowContainer),
      ),
      findsOneWidget,
    );

    final categoryDropdown = tester.widget<BuildDropDownWithSearch<Category>>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-category-filter'),
        ),
        matching: find.byType(BuildDropDownWithSearch<Category>),
      ),
    );
    final productDropdown = tester.widget<BuildDropDownWithSearch<GetProduct>>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-product-filter'),
        ),
        matching: find.byType(BuildDropDownWithSearch<GetProduct>),
      ),
    );
    expect(productDropdown.items, hasLength(2));
    final fromDateField = tester.widget<CalendarPickerTableCell>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-from-filter'),
        ),
        matching: find.byType(CalendarPickerTableCell),
      ),
    );
    final toDateField = tester.widget<CalendarPickerTableCell>(
      find.descendant(
        of: find.byKey(const ValueKey('product-sales-report-to-filter')),
        matching: find.byType(CalendarPickerTableCell),
      ),
    );
    final customerDropdown =
        tester.widget<BuildDropDownWithSearch<CustomerListModelData>>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-customer-filter'),
        ),
        matching: find.byType(BuildDropDownWithSearch<CustomerListModelData>),
      ),
    );
    expect(customerDropdown.items, hasLength(2));
    final orderedKeys = [
      ...filterKeys,
      'product-sales-report-reset-button',
    ];
    final traversalOrders = orderedKeys.map((key) {
      final orderWidget = tester.widget<FocusTraversalOrder>(
        find
            .ancestor(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(FocusTraversalOrder),
            )
            .first,
      );
      return (orderWidget.order as NumericFocusOrder).order;
    }).toList();
    expect(traversalOrders, [1, 2, 3, 4, 5, 6]);
    expect(categoryDropdown.openOnFocus, isTrue);
    expect(productDropdown.openOnFocus, isTrue);
    expect(customerDropdown.openOnFocus, isTrue);
    expect(fromDateField.openOnFocus, isFalse);
    expect(toDateField.openOnFocus, isFalse);

    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-from-filter'),
        ),
        matching: find.byType(CalendarPickerTableCell),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a category automatically reloads with its id',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reportsProvider = _CapturingReportProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider<ReportsProvider>.value(
            value: reportsProvider,
          ),
          ChangeNotifierProvider<CategoryProvider>(
            create: (_) => _CategoryWithData(),
          ),
          ChangeNotifierProvider<GridSelectionProvider>(
            create: (_) => _TestGridProvider(),
          ),
          ChangeNotifierProvider<CustomerProvider>(
            create: (_) => _TestCustomerProvider(),
          ),
        ],
        child: const GetMaterialApp(
          home: Scaffold(
            body: ProductSalesReportScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    reportsProvider.resetCapture();

    final categoryDropdown = tester.widget<BuildDropDownWithSearch<Category>>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-category-filter'),
        ),
        matching: find.byType(BuildDropDownWithSearch<Category>),
      ),
    );
    categoryDropdown.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(reportsProvider.requestedCategoryId, '88');
    expect(reportsProvider.requestCount, 1);

    final fromDateField = tester.widget<CalendarPickerTableCell>(
      find.descendant(
        of: find.byKey(
          const ValueKey('product-sales-report-from-filter'),
        ),
        matching: find.byType(CalendarPickerTableCell),
      ),
    );
    fromDateField.onDateSelected(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();

    expect(reportsProvider.requestedStartDate, '2026-09-01');
    expect(reportsProvider.requestCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reload clears stale report data and disables export',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reportsProvider = _FailAfterSuccessReportProvider();
    await tester.pumpWidget(
      _buildReportApp(reportsProvider: reportsProvider),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('product-sales-report-summary')),
      findsOneWidget,
    );

    reportsProvider.failNextRequest = true;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-sales-report-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-sales-report-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('product-sales-report-table-width')),
      findsNothing,
    );
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('queued pagination retains the requested page', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reportsProvider = _QueuedReportProvider();
    await tester.pumpWidget(
      _buildReportApp(reportsProvider: reportsProvider),
    );
    await tester.pumpAndSettle();

    final onPageChanged = tester
        .widget<PaginationControl>(find.byType(PaginationControl))
        .onPageChanged;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = refresh.onRefresh();
    await tester.pump();
    onPageChanged(3);
    await tester.pump();

    reportsProvider.completeRefresh();
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(reportsProvider.requestedPages, [1, 1, 3]);
    expect(
      tester
          .widget<PaginationControl>(find.byType(PaginationControl))
          .currentPage,
      3,
    );
  });

  testWidgets('invalid date range clears results and disables export',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildReportApp(reportsProvider: _ReportWithData()),
    );
    await tester.pumpAndSettle();

    final dateFields = tester
        .widgetList<CalendarPickerTableCell>(
          find.byType(CalendarPickerTableCell),
        )
        .toList();
    dateFields[1].onDateSelected(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();
    dateFields[0].onDateSelected(DateTime(2026, 9, 2));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-sales-report-invalid-date')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-sales-report-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('product-sales-report-table-width')),
      findsNothing,
    );
    expect(
        tester
            .widget<ExportShareButton>(find.byType(ExportShareButton))
            .enabled,
        isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('filter option failure is visible and retryable', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final customerProvider = _TestCustomerProvider(failLoading: true);

    await tester.pumpWidget(
      _buildReportApp(
        reportsProvider: _ReportWithData(),
        customerProvider: customerProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-sales-filter-options-error')),
      findsOneWidget,
    );
    expect(customerProvider.loadAttempts, 1);

    await tester.tap(
      find.byKey(const ValueKey('product-sales-filter-options-retry')),
    );
    await tester.pumpAndSettle();

    expect(customerProvider.loadAttempts, 2);
    expect(
      find.byKey(const ValueKey('product-sales-filter-options-error')),
      findsOneWidget,
    );
  });
}

Widget _buildReportApp({
  required ReportsProvider reportsProvider,
  CustomerProvider? customerProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthModel()),
      ChangeNotifierProvider<ReportsProvider>.value(value: reportsProvider),
      ChangeNotifierProvider<CategoryProvider>(
        create: (_) => _CategoryWithData(),
      ),
      ChangeNotifierProvider<GridSelectionProvider>(
        create: (_) => _TestGridProvider(),
      ),
      ChangeNotifierProvider<CustomerProvider>(
        create: (_) => customerProvider ?? _TestCustomerProvider(),
      ),
    ],
    child: const GetMaterialApp(
      home: Scaffold(body: ProductSalesReportScreen()),
    ),
  );
}

class _CategoryWithData extends CategoryProvider {
  @override
  List<Category>? get category => [
        Category(categoryId: 88, categoryName: 'Juice'),
      ];

  @override
  Future<void> listAllCategory({
    String? filterName,
    String? filterParent,
    int? page,
    bool sellableOnly = true,
    bool scopeToActiveStore = true,
    bool force = false,
  }) async {}
}

class _CapturingReportProvider extends _ReportWithData {
  String? requestedCategoryId;
  String? requestedStartDate;
  int requestCount = 0;

  void resetCapture() {
    requestedCategoryId = null;
    requestedStartDate = null;
    requestCount = 0;
  }

  @override
  Future<GetProductSalesReportResponse> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
    bool updateState = true,
  }) async {
    requestedCategoryId = categoryId;
    requestedStartDate = startDate;
    requestCount++;
    return _ReportWithData.report;
  }
}

class _ReportWithData extends ReportsProvider {
  static const report = GetProductSalesReportResponse(
    status: 'success',
    message: 'Product Sales Report',
    data: ProductSalesReportData(
      entries: [
        ProductSalesReportEntry(
          productId: 1,
          productName: 'Test Product',
          category: 'Test Category',
          price: 10,
          salesCount: 2,
          totalPrice: 20,
        ),
      ],
      currency: 'SAR',
      summary: ProductSalesReportSummary(
        totalRevenue: 20,
        totalQuantity: 2,
      ),
      pagination: ProductSalesReportPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: 1,
      ),
    ),
  );

  @override
  Future<GetProductSalesReportResponse> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
    bool updateState = true,
  }) async =>
      report;
}

class _FailAfterSuccessReportProvider extends ReportsProvider {
  bool failNextRequest = false;

  @override
  Future<GetProductSalesReportResponse> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
    bool updateState = true,
  }) async {
    if (failNextRequest) throw StateError('reload failed');
    return _reportForPage(page);
  }
}

class _QueuedReportProvider extends ReportsProvider {
  final requestedPages = <int>[];
  final _refreshCompleter = Completer<GetProductSalesReportResponse>();

  @override
  Future<GetProductSalesReportResponse> fetchProductSalesReport({
    required String accessToken,
    String? categoryId,
    String? productId,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 25,
    bool updateState = true,
  }) {
    requestedPages.add(page);
    if (requestedPages.length == 2) return _refreshCompleter.future;
    return Future.value(_reportForPage(page));
  }

  void completeRefresh() => _refreshCompleter.complete(_reportForPage(1));
}

GetProductSalesReportResponse _reportForPage(int page) {
  return GetProductSalesReportResponse(
    status: 'success',
    message: 'Product Sales Report',
    data: ProductSalesReportData(
      entries: [
        ProductSalesReportEntry(
          productId: page,
          productName: 'Product $page',
          category: 'Category',
          price: 10,
          salesCount: page.toDouble(),
          totalPrice: (10 * page).toDouble(),
        ),
      ],
      currency: 'SAR',
      summary: ProductSalesReportSummary(
        totalRevenue: (10 * page).toDouble(),
        totalQuantity: page.toDouble(),
      ),
      pagination: ProductSalesReportPagination(
        currentPage: page,
        lastPage: 3,
        perPage: 25,
        total: 3,
      ),
    ),
  );
}

class _TestCustomerProvider extends CustomerProvider {
  _TestCustomerProvider({
    this.customers = const [],
    this.failLoading = false,
  });

  final List<CustomerListModelData> customers;
  final bool failLoading;
  int loadAttempts = 0;

  @override
  Future<void> fetchCustomers({
    required String accessToken,
    String? customerName,
    bool listAll = true,
  }) async {}

  @override
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot({
    required String accessToken,
  }) async {
    loadAttempts++;
    if (failLoading) throw const HttpException('customer loading failed');
    return customers;
  }
}

class _TestGridProvider extends GridSelectionProvider {
  _TestGridProvider({this.products = const []});

  final List<GetProduct> products;

  @override
  Future<void> listAllProducts({
    int? categoryId,
    String? filterName,
    String? filterCategory,
    String? filterBarcode,
    String? filterPrice,
    String? filterCreatedBy,
    String? filterProperties,
    String? filterStore,
    String? filterSupplier,
    int page = 1,
  }) async {}

  @override
  Future<void> listAllProductsAPI({int? categoryId, String? barCode}) async {}

  @override
  Future<List<GetProduct>> listAllProductsForReportFilter() async => products;
}
