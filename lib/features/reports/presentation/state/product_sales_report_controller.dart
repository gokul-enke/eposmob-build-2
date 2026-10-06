import 'package:flutter/foundation.dart';
import '../../data/product_sales_snapshot.dart';
import '../../domain/models/product_sales_report.dart';
import '../../domain/product_sales_query.dart';

typedef ProductSalesFetch = Future<GetProductSalesReportResponse> Function(
    ProductSalesQuery query, int page, int perPage);
typedef ProductSalesDirectory = Future<List<ProductSalesOption>> Function();

/// Local page inputs and a serialized latest-request-wins report queue.
class ProductSalesReportController extends ChangeNotifier {
  ProductSalesReportController(
      {required this.fetch,
      required this.readScope,
      required this.fetchCategories,
      required this.fetchProducts,
      required this.fetchCustomers});
  final ProductSalesFetch fetch;
  final Future<ProductSalesScope> Function() readScope;
  final ProductSalesDirectory fetchCategories, fetchProducts, fetchCustomers;
  List<ProductSalesOption> categories = const [],
      products = const [],
      customers = const [];
  ProductSalesOption? category, product, customer;
  DateTime? from, to;
  GetProductSalesReportResponse? report;
  bool loading = false,
      optionsLoading = false,
      optionsFailed = false,
      showFilters = true;
  String? errorKey;
  int page = 1, errorRevision = 0, _generation = 0, _optionsGeneration = 0;
  int _requestedPage = 1;
  int filterResetRevision = 0;
  bool _worker = false, _disposed = false;
  ({ProductSalesQuery query, int page, int generation})? _pending;
  ProductSalesQuery? _loaded;
  ProductSalesScope? _loadedScope;
  static String date(DateTime? value) => value == null
      ? ''
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  ProductSalesQuery get query => ProductSalesQuery(
      categoryId: category?.id,
      productId: product?.id,
      customerId: customer?.id,
      from: date(from),
      to: date(to));
  List<ProductSalesOption> get visibleProducts => category == null
      ? products
      : products.where((p) => p.categoryId == category!.id).toList();
  bool get canExport =>
      !_disposed &&
      !loading &&
      errorKey == null &&
      (report?.data.entries.isNotEmpty ?? false) &&
      _loaded?.matches(query) == true;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setFilters(bool value) {
    if (_disposed) return;
    showFilters = value;
    _notify();
  }

  Future<void> initialize() async {
    await Future.wait([load(), loadOptions()]);
  }

  Future<void> loadOptions() async {
    if (_disposed || optionsLoading) return;
    final generation = ++_optionsGeneration;
    optionsLoading = true;
    optionsFailed = false;
    _notify();
    Future<void> read(ProductSalesDirectory fetch,
        void Function(List<ProductSalesOption>) assign) async {
      try {
        final result = await fetch();
        if (!_disposed && generation == _optionsGeneration) {
          assign(List.unmodifiable(result));
        }
      } catch (_) {
        if (!_disposed && generation == _optionsGeneration) {
          optionsFailed = true;
        }
      }
    }

    await Future.wait([
      read(fetchCategories, (v) => categories = v),
      read(fetchProducts, (v) => products = v),
      read(fetchCustomers, (v) => customers = v)
    ]);
    if (_disposed || generation != _optionsGeneration) return;
    optionsLoading = false;
    _notify();
  }

  Future<void> load({int? requestedPage}) async {
    if (_disposed) return;
    final snapshot = query, target = requestedPage ?? 1;
    _requestedPage = target;
    final generation = ++_generation;
    report = null;
    errorKey = null;
    if (!snapshot.valid) {
      _pending = null;
      loading = false;
      errorKey = 'product_sales_report.invalid_date_range';
      errorRevision++;
      _notify();
      return;
    }
    _pending = (query: snapshot, page: target, generation: generation);
    loading = true;
    _notify();
    if (_worker) return;
    _worker = true;
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        try {
          final scope = await readScope();
          if (_disposed || request.generation != _generation) continue;
          final result = await fetch(request.query, request.page, 25);
          if (_disposed || request.generation != _generation) continue;
          if (scope != await readScope()) {
            throw StateError('Product sales session changed.');
          }
          if (_disposed || request.generation != _generation) continue;
          report = result;
          page = result.data.pagination.currentPage;
          _loaded = request.query;
          _loadedScope = scope;
        } catch (_) {
          if (_disposed || request.generation != _generation) continue;
          errorKey = 'product_sales_report.error_unavailable';
          errorRevision++;
        }
      }
    } finally {
      _worker = false;
      if (!_disposed && _pending == null) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> selectCategory(ProductSalesOption? value) {
    if (_disposed) return Future.value();
    category = value;
    if (product?.categoryId != value?.id) product = null;
    return load();
  }

  Future<void> selectProduct(ProductSalesOption? value) {
    if (_disposed) return Future.value();
    product = value;
    return load();
  }

  Future<void> selectCustomer(ProductSalesOption? value) {
    if (_disposed) return Future.value();
    customer = value;
    return load();
  }

  Future<void> selectDate(DateTime? value, bool start) {
    if (_disposed) return Future.value();
    if (start) {
      from = value;
    } else {
      to = value;
    }
    return load();
  }

  Future<void> reset() {
    if (_disposed) return Future.value();
    filterResetRevision++;
    category = product = customer = null;
    from = to = null;
    page = _requestedPage = 1;
    return load();
  }

  Future<void> retry() => load(requestedPage: _requestedPage);
  Future<void> goToPage(int value) async {
    if (!_disposed &&
        !loading &&
        report != null &&
        value >= 1 &&
        value <= report!.data.pagination.lastPage) {
      await load(requestedPage: value);
    }
  }

  Future<T> export<T>(
      {required Future<T> Function(List<ProductSalesReportEntry>) build,
      void Function(int page, int total)? progress}) async {
    if (!canExport) throw StateError('Product sales report unavailable.');
    final snapshot = query, scope = _loadedScope, generation = _generation;
    Future<void> check() async {
      if (_disposed || generation != _generation || !snapshot.matches(query)) {
        throw StateError('Product sales filters changed during export.');
      }
      final current = await readScope();
      if (_disposed || generation != _generation || scope != current) {
        throw StateError('Product sales session changed during export.');
      }
    }

    final entries = await productSalesSnapshot((page) async {
      await check();
      final result = await fetch(snapshot, page, 250);
      await check();
      return result;
    }, progress: progress);
    final output = await build(entries);
    await check();
    return output;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_optionsGeneration;
    _pending = null;
    super.dispose();
  }
}
