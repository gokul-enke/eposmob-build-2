import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/models/customer_list.dart';
import 'customer_api.dart';
import 'customer_cache.dart';
import 'customer_payloads.dart';

/// Server-side filters for [CustomerRepository.list].
@immutable
class CustomerQuery {
  const CustomerQuery({
    this.name,
    this.email,
    this.phone,
    this.ageRange,
    this.sortAscending = false,
    this.page = 1,
    this.loadAll = false,
  });

  final String? name;
  final String? email;
  final String? phone;
  final String? ageRange;
  final bool sortAscending;
  final int page;

  /// Fetch every page (the full directory) instead of one page.
  final bool loadAll;

  Map<String, String> toQueryParameters({int? storeId}) {
    final query = <String, String>{
      'page': loadAll ? '1' : page.toString(),
      if (sortAscending) 'sort_asc': 'true',
      if (loadAll) 'per_page': CustomerApi.loadAllPageSize.toString(),
    };
    void putIfNotEmpty(String key, String? value) {
      if (value != null && value.isNotEmpty) query[key] = value;
    }

    putIfNotEmpty('filter_name', name);
    putIfNotEmpty('filter_email', email);
    putIfNotEmpty('filter_phone', phone);
    putIfNotEmpty('filter_age_range', ageRange);
    if (storeId != null) query['store_id'] = storeId.toString();
    return query;
  }
}

/// Outcome of [CustomerRepository.list].
sealed class CustomerListResult {
  const CustomerListResult();

  /// The response map the legacy provider API returned for this outcome.
  Map<String, dynamic> get legacyResponse;
}

/// The full directory, from the server or (offline) from the cache.
class CustomerDirectoryLoaded extends CustomerListResult {
  const CustomerDirectoryLoaded({
    required this.customers,
    required this.fromCache,
    required this.response,
  });

  final List<CustomerListModelData> customers;
  final bool fromCache;
  final Map<String, dynamic> response;

  @override
  Map<String, dynamic> get legacyResponse => response;
}

/// One server page.
class CustomerPageLoaded extends CustomerListResult {
  const CustomerPageLoaded({required this.customers, required this.response});

  final List<CustomerListModelData>? customers;
  final Map<String, dynamic> response;

  @override
  Map<String, dynamic> get legacyResponse => response;
}

/// Nothing could be loaded.
class CustomerListFailed extends CustomerListResult {
  const CustomerListFailed(this.message);

  final String message;

  @override
  Map<String, dynamic> get legacyResponse =>
      {'status': 'error', 'message': message};
}

/// Single entry point to customer data: combines [CustomerApi] with the
/// offline [CustomerCache].
class CustomerRepository {
  CustomerRepository({
    CustomerApi? api,
    CustomerCache cache = const CustomerCache(),
  })  : api = api ?? CustomerApi(),
        _cache = cache;

  static const cacheMessage = 'Loaded customers from local cache';

  final CustomerApi api;
  final CustomerCache _cache;

  static Map<String, dynamic> _cachedResponse(
    List<CustomerListModelData> customers,
  ) =>
      {
        'status': 'success',
        'message': cacheMessage,
        'data': customers.map((customer) => customer.toJson()).toList(),
      };

  Future<CustomerListResult?> _fromCache(int? storeId) async {
    final cached = await _cache.load(storeId);
    if (cached == null || cached.isEmpty) return null;
    return CustomerDirectoryLoaded(
      customers: cached,
      fromCache: true,
      response: _cachedResponse(cached),
    );
  }

  /// Loads one page or (with [CustomerQuery.loadAll]) the full directory.
  /// A loaded directory is written to the cache; when the server can't be
  /// reached (or no API key is stored) a full-directory request falls back
  /// to the cache.
  Future<CustomerListResult> list(
    String accessToken,
    CustomerQuery query,
  ) async {
    final apiKey = await api.session.apiKey();
    final storeId = await api.session.activeStoreId();

    if (apiKey == null) {
      final cached = query.loadAll ? await _fromCache(storeId) : null;
      return cached ??
          const CustomerListFailed(CustomerApi.missingApiKeyMessage);
    }

    final queryParameters = query.toQueryParameters(storeId: storeId);
    try {
      if (query.loadAll) {
        final directory = await api.fetchDirectory(
          accessToken: accessToken,
          apiKey: apiKey,
          queryParameters: queryParameters,
        );
        await _cache.save(storeId, directory.customers);
        return CustomerDirectoryLoaded(
          customers: List.of(directory.customers),
          fromCache: false,
          response: directory.toJson(),
        );
      }
      final page = await api.fetchPage(
        accessToken: accessToken,
        apiKey: apiKey,
        queryParameters: queryParameters,
      );
      return CustomerPageLoaded(
        customers: page.model.data,
        response: page.payload,
      );
    } catch (error) {
      debugPrint('[CustomerRepository] list failed: $error');
      final cached = query.loadAll ? await _fromCache(storeId) : null;
      return cached ?? CustomerListFailed('Error: $error');
    }
  }

  /// The full directory sorted by display label. Falls back to the cache;
  /// throws when neither source has customers.
  Future<List<CustomerListModelData>> snapshot(String accessToken) async {
    final apiKey = await api.session.apiKey();
    final storeId = await api.session.activeStoreId();
    List<CustomerListModelData> sorted(List<CustomerListModelData> source) =>
        List.of(source)
          ..sort((left, right) => left.displayLabel
              .toLowerCase()
              .compareTo(right.displayLabel.toLowerCase()));

    if (apiKey == null) {
      final cached = await _cache.load(storeId);
      if (cached != null && cached.isNotEmpty) return sorted(cached);
      throw const HttpException(CustomerApi.missingApiKeyMessage);
    }

    try {
      final directory = await api.fetchDirectory(
        accessToken: accessToken,
        apiKey: apiKey,
        queryParameters: const CustomerQuery(loadAll: true)
            .toQueryParameters(storeId: storeId),
      );
      return sorted(directory.customers);
    } catch (_) {
      final cached = await _cache.load(storeId);
      if (cached != null && cached.isNotEmpty) return sorted(cached);
      rethrow;
    }
  }

  Future<void> saveToCache(
    int? storeId,
    List<CustomerListModelData> customers,
  ) =>
      _cache.save(storeId, customers);

  Future<void> clearCache() async =>
      _cache.clear(await api.session.activeStoreId());

  Future<dynamic> create(
    String accessToken,
    CustomerFields fields, {
    required String storeId,
  }) =>
      api.create(
          accessToken, CustomerPayloads.create(fields, storeId: storeId));

  Future<dynamic> update(
    String accessToken,
    int customerId,
    CustomerFields fields, {
    int? storeId,
  }) =>
      api.update(
        accessToken,
        CustomerPayloads.update(customerId, fields, storeId: storeId),
      );

  Future<dynamic> findByPhone(String accessToken, String phone) =>
      api.findByPhone(accessToken, phone);

  Future<dynamic> findByName(String accessToken, String name) =>
      api.findByName(accessToken, name);

  /// The decoded response, plus the parsed customer when it succeeded.
  Future<({dynamic response, CustomerListModelData? customer})> fetchById(
    String accessToken,
    int customerId,
  ) async {
    final response = await api.fetchById(accessToken, customerId);
    CustomerListModelData? customer;
    if (response is Map && response['status'] == 'success') {
      customer = CustomerListModelData.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
    }
    return (response: response, customer: customer);
  }

  Future<dynamic> addAddress(
    String accessToken,
    Map<String, dynamic> addressData,
  ) =>
      api.addAddress(accessToken, addressData);

  Future<dynamic> updateAddress(
    String accessToken,
    int addressId,
    Map<String, dynamic> addressData,
  ) =>
      api.updateAddress(accessToken, addressId, addressData);
}
