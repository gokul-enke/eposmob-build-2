import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/resources/app_url.dart';

class RealtimeCatalogSnapshot {
  const RealtimeCatalogSnapshot({
    required this.products,
    required this.deletedProductIds,
  });

  final List<GetProduct> products;
  final Set<int> deletedProductIds;
}

class RealtimeEntityApi {
  RealtimeEntityApi({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 30),
    this.pageSize = 1000,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;
  final int pageSize;

  Map<String, String> _headers(RealtimeSyncSession session) => {
        'Authorization': 'Bearer ${session.accessToken}',
        'X-Tenant': session.tenantApiKey,
        'Accept': 'application/json',
      };

  Future<RealtimeCatalogSnapshot> fetchCatalog(
    RealtimeSyncSession session, {
    String? updatedFrom,
    String? updatedTo,
    bool allowFullFallback = true,
  }) async {
    final products = <GetProduct>[];
    final deleted = <int>{};
    var page = 1;

    while (true) {
      final queryParameters = <String, String>{
        'store_id': session.storeId.toString(),
        'page': page.toString(),
        'per_page': pageSize.toString(),
      };
      _addUpdatedAtRange(
        queryParameters,
        updatedFrom: updatedFrom,
        updatedTo: updatedTo,
      );
      final uri = Uri.parse(
        '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
        '/api/v1/product/executive/list-products',
      ).replace(
        queryParameters: queryParameters,
      );
      Map<String, dynamic> json;
      try {
        json = await _getObject(uri, session);
      } on _DeltaRangeUnsupported {
        if (updatedFrom != null && allowFullFallback) {
          return fetchCatalog(session, allowFullFallback: false);
        }
        rethrow;
      }
      final model = GetProductModel.fromJson(json);
      products.addAll(model.product ?? const <GetProduct>[]);
      deleted.addAll(model.deletedProductIds ?? const <int>[]);
      final pagination = model.pagination;
      if (pagination == null) break;
      final current = pagination.currentPage ?? page;
      final last = pagination.lastPage ?? current;
      if (current >= last) break;
      page++;
    }

    return RealtimeCatalogSnapshot(
      products: products,
      deletedProductIds: deleted,
    );
  }

  Future<List<CustomerListModelData>> fetchCustomers(
    RealtimeSyncSession session, {
    String? updatedFrom,
    String? updatedTo,
    bool allowFullFallback = true,
  }) async {
    final queryParameters = <String, String>{
      'store_id': session.storeId.toString(),
      'page': '1',
      'per_page': pageSize.toString(),
    };
    _addUpdatedAtRange(
      queryParameters,
      updatedFrom: updatedFrom,
      updatedTo: updatedTo,
    );
    final uri = Uri.parse(
      '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
      '/api/v1/customer/customer-searchbar',
    ).replace(
      queryParameters: queryParameters,
    );
    try {
      return CustomerListModel.fromJson(await _getObject(uri, session)).data ??
          const <CustomerListModelData>[];
    } on _DeltaRangeUnsupported {
      if (updatedFrom != null && allowFullFallback) {
        return fetchCustomers(session, allowFullFallback: false);
      }
      rethrow;
    }
  }

  Future<List<ListStockModelData>> fetchStocks(
    RealtimeSyncSession session, {
    String? updatedFrom,
    String? updatedTo,
    bool allowFullFallback = true,
  }) async {
    final stocks = <ListStockModelData>[];
    var page = 1;
    while (true) {
      final queryParameters = <String, String>{
        'store_id': session.storeId.toString(),
        'page': page.toString(),
        'per_page': pageSize.toString(),
      };
      _addUpdatedAtRange(
        queryParameters,
        updatedFrom: updatedFrom,
        updatedTo: updatedTo,
      );
      final uri = Uri.parse(
        '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
        '/api/v1/product/list-stocks',
      ).replace(
        queryParameters: queryParameters,
      );
      ListStockModel model;
      try {
        model = ListStockModel.fromJson(await _getObject(uri, session));
      } on _DeltaRangeUnsupported {
        if (updatedFrom != null && allowFullFallback) {
          return fetchStocks(session, allowFullFallback: false);
        }
        rethrow;
      }
      stocks.addAll(model.data ?? const <ListStockModelData>[]);
      if (model.pagination == null) break;
      final pagination = model.pagination!;
      final current = pagination.currentPage ?? page;
      final last = pagination.lastPage ?? current;
      if (current >= last) break;
      page++;
    }
    return stocks;
  }

  Future<Map<String, dynamic>> _getObject(
    Uri uri,
    RealtimeSyncSession session,
  ) async {
    final response = await _client
        .get(uri, headers: _headers(session))
        .timeout(requestTimeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RealtimeSyncException(
        'Entity refresh authorization failed (${response.statusCode}).',
        terminal: true,
      );
    }
    if (response.statusCode == 400 || response.statusCode == 422) {
      throw _DeltaRangeUnsupported(
        'Entity endpoint rejected updated_at_range (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RealtimeSyncException(
        'Entity refresh failed (${response.statusCode}) for ${uri.path}.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw RealtimeSyncException('Invalid JSON from ${uri.path}.');
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  void _addUpdatedAtRange(
    Map<String, String> queryParameters, {
    required String? updatedFrom,
    required String? updatedTo,
  }) {
    if (updatedFrom == null || updatedTo == null) return;
    if (DateTime.tryParse(updatedFrom) == null ||
        DateTime.tryParse(updatedTo) == null) {
      return;
    }
    final normalizedFrom = DateHelper.normalizeToApiDateTime(updatedFrom);
    final normalizedTo = DateHelper.normalizeToApiDateTime(updatedTo);
    queryParameters['updated_at_range'] = '$normalizedFrom,$normalizedTo';
  }
}

class _DeltaRangeUnsupported extends RealtimeSyncException {
  const _DeltaRangeUnsupported(super.message);
}
