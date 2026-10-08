import 'package:flutter/foundation.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';

/// One page of a customer's orders.
@immutable
class CustomerOrdersPage {
  const CustomerOrdersPage({
    required this.orders,
    required this.currentPage,
    required this.totalPages,
  });

  final List<ListOrderModelData> orders;
  final int currentPage;
  final int totalPages;
}

/// Loads one page of orders, e.g. through `SalesProvider.fetchOrders`.
typedef CustomerOrdersFetcher = Future<CustomerOrdersPage> Function({
  required String accessToken,
  required int customerId,
  required int page,
});

/// Loads and pages a customer's orders.
///
/// [errorKey] is a translation key so the controller stays free of GetX.
class CustomerOrdersController extends ChangeNotifier {
  CustomerOrdersController({
    required CustomerOrdersFetcher fetch,
    required String? Function() readToken,
    required int? customerId,
  })  : _fetch = fetch,
        _readToken = readToken,
        _customerId = customerId;

  static const errNoCustomerId = 'customer_orders.err_no_customer_id';
  static const errLoginAgain = 'customer_orders.err_login_again';
  static const errLoad = 'customer_orders.err_load';

  final CustomerOrdersFetcher _fetch;
  final String? Function() _readToken;

  int? _customerId;
  List<ListOrderModelData> _orders = const [];
  bool _isLoading = false;
  String? _errorKey;
  int _currentPage = 1;
  int _totalPages = 1;
  int _requestSeq = 0;
  bool _disposed = false;

  List<ListOrderModelData> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorKey => _errorKey;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  /// Pagination is shown only for a loaded, non-empty, multi-page list.
  bool get showPagination =>
      !_isLoading && _errorKey == null && _orders.isNotEmpty && _totalPages > 1;

  Future<void> setCustomer(int? customerId) {
    _customerId = customerId;
    return load(page: 1);
  }

  Future<void> load({required int page}) async {
    final customerId = _customerId;
    final token = _readToken();
    final request = ++_requestSeq;

    if (customerId == null || token == null || token.isEmpty) {
      _isLoading = false;
      _orders = const [];
      _errorKey = customerId == null ? errNoCustomerId : errLoginAgain;
      _notify();
      return;
    }

    _isLoading = true;
    _errorKey = null;
    _notify();

    try {
      final result = await _fetch(
        accessToken: token,
        customerId: customerId,
        page: page,
      );
      if (request != _requestSeq || _disposed) return;
      _orders = List<ListOrderModelData>.of(result.orders);
      _currentPage = result.currentPage;
      _totalPages = result.totalPages;
      _errorKey = null;
    } catch (error) {
      if (request != _requestSeq || _disposed) return;
      debugPrint('Failed to load customer orders: $error');
      _orders = const [];
      _errorKey = errLoad;
    }
    _isLoading = false;
    _notify();
  }

  Future<void> retry() => load(page: _currentPage);

  void goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    load(page: page);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
