import 'dart:convert';

import 'package:http/http.dart' as http;
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
    RealtimeSyncSession session,
  ) async {
    final products = <GetProduct>[];
    final deleted = <int>{};
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
        '/api/v1/product/executive/list-products',
      ).replace(
        queryParameters: {
          'store_id': session.storeId.toString(),
          'page': page.toString(),
          'per_page': pageSize.toString(),
        },
      );
      final json = await _getObject(uri, session);
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
    RealtimeSyncSession session,
  ) async {
    final uri = Uri.parse(
      '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
      '/api/v1/customer/customer-searchbar',
    ).replace(
      queryParameters: {
        'store_id': session.storeId.toString(),
        'page': '1',
        'per_page': pageSize.toString(),
      },
    );
    return CustomerListModel.fromJson(await _getObject(uri, session)).data ??
        const <CustomerListModelData>[];
  }

  Future<List<ListStockModelData>> fetchStocks(
    RealtimeSyncSession session,
  ) async {
    final stocks = <ListStockModelData>[];
    var page = 1;
    while (true) {
      final uri = Uri.parse(
        '${APPUrl.normalizeBaseUrl(session.backendBaseUrl)}'
        '/api/v1/product/list-stocks',
      ).replace(
        queryParameters: {
          'store_id': session.storeId.toString(),
          'page': page.toString(),
          'per_page': pageSize.toString(),
        },
      );
      final model = ListStockModel.fromJson(await _getObject(uri, session));
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
}
