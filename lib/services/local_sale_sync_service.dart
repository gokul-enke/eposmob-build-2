import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String localSaleOutboxName = 'local_sale_outbox';

enum LocalSaleSyncState {
  queued,
  sending,
  synced,
  needsReview,
  rejected,
}

enum LocalSaleSurface {
  supermarketDesktop,
  mobileBilling,
  restaurant,
  attender,
  kiosk,
  legacy,
}

enum LocalSaleOperation {
  confirmedSale,
  confirmExistingOrder,
  kitchenOrder,
}

extension LocalSaleSyncStateValue on LocalSaleSyncState {
  String get value => switch (this) {
        LocalSaleSyncState.queued => 'queued',
        LocalSaleSyncState.sending => 'sending',
        LocalSaleSyncState.synced => 'synced',
        LocalSaleSyncState.needsReview => 'needs_review',
        LocalSaleSyncState.rejected => 'rejected',
      };

  static LocalSaleSyncState parse(Object? value) => switch (value) {
        'sending' => LocalSaleSyncState.sending,
        'synced' => LocalSaleSyncState.synced,
        'needs_review' => LocalSaleSyncState.needsReview,
        'rejected' => LocalSaleSyncState.rejected,
        _ => LocalSaleSyncState.queued,
      };
}

class LocalSaleSyncRecord {
  const LocalSaleSyncRecord({
    required this.localOrderId,
    required this.localOrderNumber,
    required this.sourceCartSessionId,
    required this.surface,
    required this.operation,
    required this.state,
    required this.payload,
    required this.createdAt,
    this.updatedAt,
    this.message,
    this.serverOrderId,
    this.serverOrderNumber,
    this.httpStatus,
  });

  final String localOrderId;
  final String localOrderNumber;
  final String sourceCartSessionId;
  final LocalSaleSurface surface;
  final LocalSaleOperation operation;
  final LocalSaleSyncState state;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String? updatedAt;
  final String? message;
  final String? serverOrderId;
  final String? serverOrderNumber;
  final int? httpStatus;

  bool get requestMayHaveReachedServer =>
      state == LocalSaleSyncState.needsReview;

  LocalSaleSyncRecord copyWith({
    LocalSaleSyncState? state,
    String? updatedAt,
    String? message,
    String? serverOrderId,
    String? serverOrderNumber,
    int? httpStatus,
  }) {
    return LocalSaleSyncRecord(
      localOrderId: localOrderId,
      localOrderNumber: localOrderNumber,
      sourceCartSessionId: sourceCartSessionId,
      surface: surface,
      operation: operation,
      state: state ?? this.state,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      message: message ?? this.message,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      serverOrderNumber: serverOrderNumber ?? this.serverOrderNumber,
      httpStatus: httpStatus ?? this.httpStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'local_order_id': localOrderId,
        'local_order_number': localOrderNumber,
        'source_cart_session_id': sourceCartSessionId,
        'surface': surface.name,
        'operation': operation.name,
        'state': state.value,
        'payload': payload,
        'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
        if (message != null) 'message': message,
        if (serverOrderId != null) 'server_order_id': serverOrderId,
        if (serverOrderNumber != null) 'server_order_number': serverOrderNumber,
        if (httpStatus != null) 'http_status': httpStatus,
      };

  factory LocalSaleSyncRecord.fromJson(Map<String, dynamic> json) {
    return LocalSaleSyncRecord(
      localOrderId: json['local_order_id'].toString(),
      localOrderNumber: json['local_order_number']?.toString() ?? '',
      sourceCartSessionId: json['source_cart_session_id']?.toString() ?? '',
      surface: LocalSaleSurface.values.firstWhere(
        (value) => value.name == json['surface'],
        orElse: () => LocalSaleSurface.legacy,
      ),
      operation: LocalSaleOperation.values.firstWhere(
        (value) => value.name == json['operation'],
        orElse: () => LocalSaleOperation.confirmedSale,
      ),
      state: LocalSaleSyncStateValue.parse(json['state']),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: json['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      updatedAt: json['updated_at']?.toString(),
      message: json['message']?.toString(),
      serverOrderId: json['server_order_id']?.toString(),
      serverOrderNumber: json['server_order_number']?.toString(),
      httpStatus: json['http_status'] is int
          ? json['http_status'] as int
          : int.tryParse(json['http_status']?.toString() ?? ''),
    );
  }
}

abstract class LocalSaleOutboxStore {
  Future<List<Map<String, dynamic>>> readAll();
  Future<void> write(Map<String, dynamic> record);
  Future<void> remove(String localOrderId);
}

class HiveLocalSaleOutboxStore implements LocalSaleOutboxStore {
  Box get _box => Hive.box(localSaleOutboxName);

  @override
  Future<List<Map<String, dynamic>>> readAll() async => _box.values
      .whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value))
      .toList();

  @override
  Future<void> write(Map<String, dynamic> record) async {
    await _box.put(record['local_order_id'], record);
    await _box.flush();
  }

  @override
  Future<void> remove(String localOrderId) async {
    await _box.delete(localOrderId);
    await _box.flush();
  }
}

typedef LocalSaleHttpSender = Future<http.Response> Function(
  Uri endpoint,
  Map<String, String> headers,
  String body,
);

/// Owns the one and only initial server attempt for locally confirmed sales.
///
/// There is deliberately no automatic retry API here. Without backend
/// idempotency a lost response cannot prove that the sale was not committed,
/// so every ambiguous result remains visible for human reconciliation.
class LocalSaleSyncService extends ChangeNotifier {
  LocalSaleSyncService({
    required LocalSaleOutboxStore store,
    LocalSaleHttpSender? sender,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _store = store,
        _sender = sender ?? _defaultSender;

  static final LocalSaleSyncService instance = LocalSaleSyncService(
    store: HiveLocalSaleOutboxStore(),
  );

  final LocalSaleOutboxStore _store;
  final LocalSaleHttpSender _sender;
  final Duration requestTimeout;
  final Map<String, LocalSaleSyncRecord> _records = {};
  Future<void>? _hydration;
  Future<void> _submissionTail = Future<void>.value();

  List<LocalSaleSyncRecord> get records {
    final values = _records.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(values);
  }

  LocalSaleSyncRecord? recordFor(String localOrderId) => _records[localOrderId];

  bool hasRecordedCartSession(String cartSessionId) =>
      cartSessionId.isNotEmpty &&
      _records.values.any(
        (record) => record.sourceCartSessionId == cartSessionId,
      );

  int get unresolvedCount => _records.values
      .where((record) => record.state != LocalSaleSyncState.synced)
      .length;

  Future<void> hydrate() => _hydration ??= _load();

  Future<void> _load() async {
    final stored = await _store.readAll();
    for (final json in stored) {
      var record = LocalSaleSyncRecord.fromJson(json);
      if (record.state == LocalSaleSyncState.sending) {
        record = record.copyWith(
          state: LocalSaleSyncState.needsReview,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          message: 'The app closed before the server response was verified. '
              'Check the admin panel before trying this sale again.',
        );
        await _store.write(record.toJson());
      } else if (record.state == LocalSaleSyncState.queued) {
        record = record.copyWith(
          state: LocalSaleSyncState.needsReview,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          message: 'The app closed before the first server attempt started. '
              'The sale is safe on this device and needs review.',
        );
        await _store.write(record.toJson());
      }
      _records[record.localOrderId] = record;
    }
    notifyListeners();
  }

  Future<LocalSaleSyncRecord> enqueue({
    required String localOrderId,
    required String localOrderNumber,
    required String sourceCartSessionId,
    required LocalSaleSurface surface,
    LocalSaleOperation operation = LocalSaleOperation.confirmedSale,
    required Map<String, dynamic> payload,
  }) async {
    await hydrate();
    if (_records.containsKey(localOrderId)) {
      throw StateError('This local sale already has a sync record.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final durablePayload = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(payload)) as Map,
    );
    final record = LocalSaleSyncRecord(
      localOrderId: localOrderId,
      localOrderNumber: localOrderNumber,
      sourceCartSessionId: sourceCartSessionId,
      surface: surface,
      operation: operation,
      state: LocalSaleSyncState.queued,
      payload: durablePayload,
      createdAt: now,
      updatedAt: now,
      message: 'Saved locally. Waiting for the first server attempt.',
    );
    await _store.write(record.toJson());
    _records[localOrderId] = record;
    notifyListeners();
    return record;
  }

  Future<LocalSaleSyncRecord> submitOnce({
    required String localOrderId,
    required String accessToken,
    String? tenantKey,
    Uri? endpoint,
  }) {
    // The current backend can reuse an active cart for the same customer/store.
    // Serialize initial submissions so two quickly confirmed sales cannot mutate
    // that server cart concurrently.
    final result = _submissionTail.then((_) => _submitOnceImpl(
          localOrderId: localOrderId,
          accessToken: accessToken,
          tenantKey: tenantKey,
          endpoint: endpoint,
        ));
    _submissionTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  /// Reopens an ambiguous sale for exactly one new attempt after an operator
  /// has verified that it is absent from the backend. This only changes the
  /// durable state to [LocalSaleSyncState.queued]; callers must then invoke
  /// [submitOnce] and must not retry automatically.
  Future<LocalSaleSyncRecord> authorizeRetryAfterVerification(
    String localOrderId,
  ) async {
    await hydrate();
    final record = _records[localOrderId];
    if (record == null) {
      throw StateError('Local sale sync record was not found.');
    }
    if (record.state != LocalSaleSyncState.needsReview) {
      throw StateError(
        'Only a sale needing review can be retried after verification.',
      );
    }
    return _update(
      record.copyWith(
        state: LocalSaleSyncState.queued,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        message: 'Retry authorized after the operator verified that the sale '
            'is not present in the backend.',
      ),
    );
  }

  Future<LocalSaleSyncRecord> _submitOnceImpl({
    required String localOrderId,
    required String accessToken,
    String? tenantKey,
    Uri? endpoint,
  }) async {
    await hydrate();
    final original = _records[localOrderId];
    if (original == null) {
      throw StateError('Local sale sync record was not found.');
    }
    if (original.state != LocalSaleSyncState.queued) return original;

    final apiKey = tenantKey ??
        (await SharedPreferences.getInstance()).getString('api_key');
    if (accessToken.trim().isEmpty || apiKey == null || apiKey.trim().isEmpty) {
      return _update(
        original.copyWith(
          state: LocalSaleSyncState.needsReview,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          message: 'The sale is saved locally but was not sent because the '
              'login or tenant session is unavailable.',
        ),
      );
    }

    final sending = await _update(
      original.copyWith(
        state: LocalSaleSyncState.sending,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        message: 'Sending to the server…',
      ),
    );

    try {
      final response = await _sender(
        endpoint ?? Uri.parse(APPUrl.addToOrderUrl),
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        jsonEncode(sending.payload),
      ).timeout(requestTimeout);

      Map<String, dynamic> data = const {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // An unreadable response is ambiguous, even when the transport worked.
      }

      final responseData = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : const <String, dynamic>{};
      final orderId = data['order_id'] ??
          data['orders_id'] ??
          responseData['order_id'] ??
          responseData['orders_id'] ??
          original.payload['order_id'];
      final orderNumber = data['order_number'] ?? responseData['order_number'];
      final updateSucceeded = original.operation ==
              LocalSaleOperation.confirmExistingOrder &&
          (data['status']?.toString().toLowerCase() == 'success' ||
              responseData['status']?.toString().toLowerCase() == 'success' ||
              data['success'] == true);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          (orderId != null || updateSucceeded)) {
        return _update(
          sending.copyWith(
            state: LocalSaleSyncState.synced,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
            message: 'Synced successfully.',
            serverOrderId: orderId?.toString(),
            serverOrderNumber: orderNumber?.toString(),
            httpStatus: response.statusCode,
          ),
        );
      }

      if (response.statusCode == 400 || response.statusCode == 422) {
        return _update(
          sending.copyWith(
            state: LocalSaleSyncState.rejected,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
            message: data['message']?.toString() ??
                'The server rejected this sale. Review its details.',
            httpStatus: response.statusCode,
          ),
        );
      }

      return _needsReview(
        sending,
        message: data['message']?.toString() ??
            'The server result could not be verified. Check the admin panel '
                'before trying this sale again.',
        httpStatus: response.statusCode,
      );
    } catch (error) {
      debugPrint(
        '[LocalSaleSync] outcome_unverified localOrder=$localOrderId '
        'type=${error.runtimeType}',
      );
      return _needsReview(
        sending,
        message: 'The server result could not be verified. The sale is safe '
            'on this device; check the admin panel before trying it again.',
      );
    }
  }

  Future<LocalSaleSyncRecord> _needsReview(
    LocalSaleSyncRecord record, {
    required String message,
    int? httpStatus,
  }) {
    return _update(
      record.copyWith(
        state: LocalSaleSyncState.needsReview,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        message: message,
        httpStatus: httpStatus,
      ),
    );
  }

  Future<LocalSaleSyncRecord> markNeedsReviewBeforeSend(
    String localOrderId, {
    required String message,
  }) async {
    await hydrate();
    final record = _records[localOrderId];
    if (record == null) {
      throw StateError('Local sale sync record was not found.');
    }
    if (record.state != LocalSaleSyncState.queued) return record;
    return _needsReview(record, message: message);
  }

  Future<LocalSaleSyncRecord> _update(LocalSaleSyncRecord record) async {
    await _store.write(record.toJson());
    _records[record.localOrderId] = record;
    notifyListeners();
    return record;
  }

  Future<void> remove(String localOrderId) async {
    final record = _records[localOrderId];
    if (record != null && record.state != LocalSaleSyncState.synced) {
      throw StateError('An unsynced sale cannot be removed.');
    }
    await _store.remove(localOrderId);
    _records.remove(localOrderId);
    notifyListeners();
  }

  static Future<http.Response> _defaultSender(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) {
    return http.post(endpoint, headers: headers, body: body);
  }
}
