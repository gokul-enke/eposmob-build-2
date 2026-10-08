import 'package:flutter/foundation.dart';

import '../../data/sales_action_response.dart';
import '../../data/sales_repository.dart';
import '../../domain/models/list_sales_order.dart';
import '../../domain/sales_order_query.dart';

mixin SalesOrderDirectory on ChangeNotifier {
  SalesRepository get repository;
  bool get isOnlineSalesNavigation;
  List<ListOrderModelData> _orders = [];
  List<ListOrderModelData> get orders => _orders;
  int currentPage = 1;
  int totalPages = 1;
  int paginationFrom = 1;
  int _ordersRequestSeq = 0;
  String? _ordersError;
  String? get ordersError => _ordersError;
  Map<String, dynamic>? _lastOrdersQuery;
  void applyRealtimeOrders(List<ListOrderModelData> orders) {
    // Supersede any in-flight fetch so its response cannot overwrite this list.
    _ordersRequestSeq++;
    _orders = List<ListOrderModelData>.from(orders);
    currentPage = 1;
    totalPages = 1;
    paginationFrom = _orders.isEmpty ? 0 : 1;
    notifyListeners();
  }

  Future<void> fetchOrders({
    required String accessToken,
    int? storeId,
    String? orderNumber,
    String? filterName,
    String? date,
    String? from,
    String? until,
    String? businessDate,
    int? customerId,
    int? productId,
    String? filterStatus,
    String? filterPrice,
    String? filterEmail,
    String? filterPhone,
    String? filterStore,
    String? filterCreatedBy,
    int? page,
    bool? filterOnlineSales,
  }) async {
    final requestId = ++_ordersRequestSeq;
    final query = SalesOrderQuery(
        storeId: storeId,
        orderNumber: orderNumber,
        filterName: filterName,
        date: date,
        from: from,
        until: until,
        businessDate: businessDate,
        customerId: customerId,
        productId: productId,
        filterStatus: filterStatus,
        filterPrice: filterPrice,
        filterEmail: filterEmail,
        filterPhone: filterPhone,
        filterStore: filterStore,
        filterCreatedBy: filterCreatedBy,
        page: page,
        filterOnlineSales: filterOnlineSales);
    final Map<String, dynamic> requestQuery = {
      'storeId': storeId,
      'orderNumber': orderNumber,
      'filterName': filterName,
      'date': date,
      'from': from,
      'until': until,
      'businessDate': businessDate,
      'customerId': customerId,
      'productId': productId,
      'filterStatus': filterStatus,
      'filterPrice': filterPrice,
      'filterEmail': filterEmail,
      'filterPhone': filterPhone,
      'filterStore': filterStore,
      'filterCreatedBy': filterCreatedBy,
      'page': page,
      'filterOnlineSales': filterOnlineSales,
    };
    try {
      final model = await repository.orders.fetchOrders(accessToken, query);
      if (requestId != _ordersRequestSeq) return;
      final pagination = model.pagination;
      if (pagination != null) {
        currentPage = pagination.currentPage ?? 1;
        totalPages = pagination.totalPages ?? 1;
        var from = pagination.from ?? 1;
        if (from <= 0)
          from =
              ((currentPage - 1) * (_orders.isNotEmpty ? _orders.length : 1)) +
                  1;
        paginationFrom = from;
      } else {
        currentPage = 1;
        totalPages = 1;
        paginationFrom = 1;
      }
      _orders = model.data ?? [];
      _ordersError = null;
      _lastOrdersQuery = requestQuery;
      notifyListeners();
    } catch (error) {
      if (requestId == _ordersRequestSeq) {
        _ordersError = SalesActionResponse.apiErrorMessage(error,
            fallback: 'Failed to load orders');
        notifyListeners();
      }
      rethrow;
    }
  }

  Object? _activeListOwner;
  Future<void> Function()? _activeListRefresh;

  /// The mounted listing owns its own rows; notifications must refresh that
  /// collection rather than replaying an unrelated detail/provider query.
  void attachListRefresh(Object owner, Future<void> Function() refresh) {
    _activeListOwner = owner;
    _activeListRefresh = refresh;
  }

  void detachListRefresh(Object owner) {
    if (!identical(owner, _activeListOwner)) return;
    _activeListOwner = null;
    _activeListRefresh = null;
  }

  Future<void> refreshOrdersForRealtime({
    required String accessToken,
    required int storeId,
  }) {
    final activeRefresh = _activeListRefresh;
    if (activeRefresh != null) return activeRefresh();
    final lastQuery = _lastOrdersQuery;

    // Replay the query the user is currently looking at. Refreshing with only
    // the store id while keeping the page number could land on a page that does
    // not exist in the unfiltered result set and blank the list.
    if (lastQuery != null) {
      return fetchOrders(
        accessToken: accessToken,
        storeId: lastQuery['storeId'] as int?,
        orderNumber: lastQuery['orderNumber'] as String?,
        filterName: lastQuery['filterName'] as String?,
        date: lastQuery['date'] as String?,
        from: lastQuery['from'] as String?,
        until: lastQuery['until'] as String?,
        businessDate: lastQuery['businessDate'] as String?,
        customerId: lastQuery['customerId'] as int?,
        productId: lastQuery['productId'] as int?,
        filterStatus: lastQuery['filterStatus'] as String?,
        filterPrice: lastQuery['filterPrice'] as String?,
        filterEmail: lastQuery['filterEmail'] as String?,
        filterPhone: lastQuery['filterPhone'] as String?,
        filterStore: (lastQuery['filterStore'] as String?) ??
            (lastQuery['storeId'] == null ? storeId.toString() : null),
        filterCreatedBy: lastQuery['filterCreatedBy'] as String?,
        page:
            (lastQuery['page'] as int?) ?? (currentPage > 0 ? currentPage : 1),
        filterOnlineSales: lastQuery['filterOnlineSales'] as bool?,
      );
    }

    return fetchOrders(
      accessToken: accessToken,
      filterStore: storeId.toString(),
      page: currentPage > 0 ? currentPage : 1,
      filterOnlineSales: isOnlineSalesNavigation ? true : null,
    );
  }
}
