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

/// One HTTP attempt for a local sale, kept so an operator can see exactly what
/// was sent and what the server answered. Auth headers are never stored.
class LocalSaleSyncAttempt {
  const LocalSaleSyncAttempt({
    required this.number,
    required this.startedAt,
    required this.endpoint,
    required this.requestBody,
    this.finishedAt,
    this.httpStatus,
    this.responseBody,
    this.error,
    this.outcome,
  });

  /// Responses beyond this length are cut so one large reply cannot bloat the
  /// outbox box.
  static const int maxResponseLength = 100000;

  /// A successful response is only kept for reference, so it is stored much
  /// shorter. Rejections and failures keep up to [maxResponseLength].
  static const int maxSyncedResponseLength = 2000;

  final int number;
  final String startedAt;
  final String endpoint;

  /// The exact JSON string sent as the request body.
  final String requestBody;
  final String? finishedAt;
  final int? httpStatus;

  /// The raw response body, or null when no response arrived.
  final String? responseBody;

  /// Transport failure (timeout, no connection, app closed) when no response
  /// was received.
  final String? error;

  /// The sync state this attempt produced, e.g. `synced` or `rejected`.
  final String? outcome;

  bool get isFinished => finishedAt != null;

  LocalSaleSyncAttempt finish({
    required LocalSaleSyncState outcome,
    int? httpStatus,
    String? responseBody,
    String? error,
  }) {
    final limit = outcome == LocalSaleSyncState.synced
        ? maxSyncedResponseLength
        : maxResponseLength;
    final body = responseBody != null && responseBody.length > limit
        ? '${responseBody.substring(0, limit)}\n…[truncated]'
        : responseBody;
    return LocalSaleSyncAttempt(
      number: number,
      startedAt: startedAt,
      endpoint: endpoint,
      requestBody: requestBody,
      finishedAt: DateTime.now().toUtc().toIso8601String(),
      httpStatus: httpStatus,
      responseBody: body,
      error: error,
      outcome: outcome.value,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'started_at': startedAt,
        'endpoint': endpoint,
        'request_body': requestBody,
        if (finishedAt != null) 'finished_at': finishedAt,
        if (httpStatus != null) 'http_status': httpStatus,
        if (responseBody != null) 'response_body': responseBody,
        if (error != null) 'error': error,
        if (outcome != null) 'outcome': outcome,
      };

  factory LocalSaleSyncAttempt.fromJson(Map<String, dynamic> json) {
    return LocalSaleSyncAttempt(
      number: json['number'] is int
          ? json['number'] as int
          : int.tryParse(json['number']?.toString() ?? '') ?? 0,
      startedAt: json['started_at']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      requestBody: json['request_body']?.toString() ?? '',
      finishedAt: json['finished_at']?.toString(),
      httpStatus: json['http_status'] is int
          ? json['http_status'] as int
          : int.tryParse(json['http_status']?.toString() ?? ''),
      responseBody: json['response_body']?.toString(),
      error: json['error']?.toString(),
      outcome: json['outcome']?.toString(),
    );
  }
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
    this.attempts = const [],
    this.dismissedAt,
    this.dismissNote,
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

  /// Every server attempt, oldest first.
  final List<LocalSaleSyncAttempt> attempts;

  /// Set when an operator removed the sale from Sales → Confirmed Orders. The
  /// record and its attempt log stay on the device for audit.
  final String? dismissedAt;
  final String? dismissNote;

  bool get isDismissed => dismissedAt != null;

  bool get requestMayHaveReachedServer =>
      state == LocalSaleSyncState.needsReview;

  /// A sale the operator may send again from Sales → Confirmed Orders.
  bool get canRetry =>
      state == LocalSaleSyncState.needsReview ||
      state == LocalSaleSyncState.rejected;

  LocalSaleSyncRecord copyWith({
    LocalSaleSyncState? state,
    String? updatedAt,
    String? message,
    String? serverOrderId,
    String? serverOrderNumber,
    int? httpStatus,
    List<LocalSaleSyncAttempt>? attempts,
    String? dismissedAt,
    String? dismissNote,
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
      attempts: attempts ?? this.attempts,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      dismissNote: dismissNote ?? this.dismissNote,
    );
  }

  /// Closes the newest attempt with its result.
  List<LocalSaleSyncAttempt> attemptsWithLastFinished({
    required LocalSaleSyncState outcome,
    int? httpStatus,
    String? responseBody,
    String? error,
  }) {
    if (attempts.isEmpty || attempts.last.isFinished) return attempts;
    return [
      ...attempts.take(attempts.length - 1),
      attempts.last.finish(
        outcome: outcome,
        httpStatus: httpStatus,
        responseBody: responseBody,
        error: error,
      ),
    ];
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
        if (attempts.isNotEmpty)
          'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
        if (dismissedAt != null) 'dismissed_at': dismissedAt,
        if (dismissNote != null) 'dismiss_note': dismissNote,
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
      attempts: (json['attempts'] as List? ?? const [])
          .whereType<Map>()
          .map((value) =>
              LocalSaleSyncAttempt.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      dismissedAt: json['dismissed_at']?.toString(),
      dismissNote: json['dismiss_note']?.toString(),
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
      .where((record) =>
          record.state != LocalSaleSyncState.synced && !record.isDismissed)
      .length;

  /// How long a synced sale stays on the device after its last update. It is
  /// kept for reprints and for investigating disputes during rollout.
  static const Duration syncedRetention = Duration(days: 30);

  Future<void> hydrate() => _hydration ??= _load();

  /// Deletes synced records last updated more than [retention] ago and
  /// returns their local order ids, so the caller can delete the matching
  /// local sale snapshots. Records that are not synced, or were removed by an
  /// operator, are never pruned.
  Future<List<String>> pruneSynced({
    Duration retention = syncedRetention,
    DateTime? now,
  }) async {
    await hydrate();
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(retention);
    final expired = _records.values
        .where((record) {
          if (record.state != LocalSaleSyncState.synced ||
              record.isDismissed) {
            return false;
          }
          final updated =
              DateTime.tryParse(record.updatedAt ?? record.createdAt);
          return updated != null && updated.toUtc().isBefore(cutoff);
        })
        .map((record) => record.localOrderId)
        .toList();
    if (expired.isEmpty) return const [];

    for (final id in expired) {
      await _store.remove(id);
      _records.remove(id);
    }
    notifyListeners();
    return expired;
  }

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
          attempts: record.attemptsWithLastFinished(
            outcome: LocalSaleSyncState.needsReview,
            error: 'The app closed before a response arrived.',
          ),
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

  /// Reopens a needs-review or rejected sale for exactly one new attempt,
  /// sending the same stored payload. An ambiguous sale must first be verified
  /// as absent from the backend; a rejected one is retried after its cause is
  /// fixed. This only changes the durable state to
  /// [LocalSaleSyncState.queued]; callers must then invoke [submitOnce] and
  /// must not retry automatically.
  Future<LocalSaleSyncRecord> authorizeRetryAfterVerification(
    String localOrderId,
  ) async {
    await hydrate();
    final record = _records[localOrderId];
    if (record == null) {
      throw StateError('Local sale sync record was not found.');
    }
    if (!record.canRetry || record.isDismissed) {
      throw StateError(
        'Only a sale needing review or rejected by the server can be retried.',
      );
    }
    return _update(
      record.copyWith(
        state: LocalSaleSyncState.queued,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        message: record.state == LocalSaleSyncState.rejected
            ? 'Retry requested by the operator after a server rejection.'
            : 'Retry authorized after the operator verified that the sale '
                'is not present in the backend.',
      ),
    );
  }

  /// Takes a needs-review or rejected sale off the attention list after the
  /// operator resolved it outside the app, e.g. found it already in the admin
  /// panel after a timeout. Nothing is deleted: the sale, its state and the
  /// attempt log remain for audit, and it is never sent again.
  Future<LocalSaleSyncRecord> dismiss(
    String localOrderId, {
    required String note,
  }) async {
    await hydrate();
    final record = _records[localOrderId];
    if (record == null) {
      throw StateError('Local sale sync record was not found.');
    }
    if (!record.canRetry) {
      throw StateError(
        'Only a sale needing review or rejected by the server can be removed.',
      );
    }
    return _update(
      record.copyWith(
        dismissedAt: DateTime.now().toUtc().toIso8601String(),
        dismissNote: note,
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
      debugPrint(
        '[LocalSaleSync] not sent bill=${original.localOrderNumber} '
        'reason=missing ${accessToken.trim().isEmpty ? 'login token' : 'tenant key'}',
      );
      return _update(
        original.copyWith(
          state: LocalSaleSyncState.needsReview,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          message: 'The sale is saved locally but was not sent because the '
              'login or tenant session is unavailable.',
        ),
      );
    }

    // A retry from Confirmed Orders passes no endpoint, so it must follow the
    // operation: confirming an existing order is an update, not a new order.
    final target = endpoint ??
        Uri.parse(original.operation == LocalSaleOperation.confirmExistingOrder
            ? APPUrl.updateOrderUrl
            : APPUrl.addToOrderUrl);
    final requestBody = jsonEncode(original.payload);
    final now = DateTime.now().toUtc().toIso8601String();

    // The attempt is stored before the request so an app crash mid-request
    // still shows what was sent.
    final sending = await _update(
      original.copyWith(
        state: LocalSaleSyncState.sending,
        updatedAt: now,
        message: 'Sending to the server…',
        attempts: [
          ...original.attempts,
          LocalSaleSyncAttempt(
            number: original.attempts.length + 1,
            startedAt: now,
            endpoint: target.toString(),
            requestBody: requestBody,
          ),
        ],
      ),
    );

    final attemptNumber = sending.attempts.length;
    debugPrint(
      '[LocalSaleSync] → POST $target '
      'bill=${original.localOrderNumber} attempt=$attemptNumber',
    );
    debugPrint('[LocalSaleSync]   body: ${_debugSnippet(requestBody)}');
    final stopwatch = Stopwatch()..start();

    // Prints the outcome line once the record is classified and stored.
    Future<LocalSaleSyncRecord> logged(
      Future<LocalSaleSyncRecord> result,
    ) async {
      final record = await result;
      final last = record.attempts.isEmpty ? null : record.attempts.last;
      debugPrint(
        '[LocalSaleSync] ← ${last?.httpStatus ?? 'no response'} '
        'in ${stopwatch.elapsedMilliseconds}ms '
        'bill=${record.localOrderNumber} attempt=$attemptNumber '
        'outcome=${record.state.value}',
      );
      if (last?.responseBody != null) {
        debugPrint(
          '[LocalSaleSync]   response: ${_debugSnippet(last!.responseBody!)}',
        );
      } else if (last?.error != null) {
        debugPrint('[LocalSaleSync]   error: ${last!.error}');
      }
      return record;
    }

    try {
      final response = await _sender(
        target,
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        requestBody,
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
        return logged(_update(
          sending.copyWith(
            state: LocalSaleSyncState.synced,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
            message: 'Synced successfully.',
            serverOrderId: orderId?.toString(),
            serverOrderNumber: orderNumber?.toString(),
            httpStatus: response.statusCode,
            attempts: sending.attemptsWithLastFinished(
              outcome: LocalSaleSyncState.synced,
              httpStatus: response.statusCode,
              responseBody: response.body,
            ),
          ),
        ));
      }

      // Validation and authorization failures are refused before an order is
      // created, so they are definite rejections rather than ambiguous.
      if (const [400, 401, 403, 422].contains(response.statusCode)) {
        return logged(_update(
          sending.copyWith(
            state: LocalSaleSyncState.rejected,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
            message: data['message']?.toString() ??
                'The server rejected this sale. Review its details.',
            httpStatus: response.statusCode,
            attempts: sending.attemptsWithLastFinished(
              outcome: LocalSaleSyncState.rejected,
              httpStatus: response.statusCode,
              responseBody: response.body,
            ),
          ),
        ));
      }

      return logged(_needsReview(
        sending,
        message: data['message']?.toString() ??
            'The server result could not be verified. Check the admin panel '
                'before trying this sale again.',
        httpStatus: response.statusCode,
        responseBody: response.body,
      ));
    } catch (error) {
      debugPrint(
        '[LocalSaleSync] outcome_unverified localOrder=$localOrderId '
        'type=${error.runtimeType}',
      );
      return logged(_needsReview(
        sending,
        message: 'The server result could not be verified. The sale is safe '
            'on this device; check the admin panel before trying it again.',
        error: error is TimeoutException
            ? 'No response within ${requestTimeout.inSeconds}s (timeout).'
            : error.toString(),
      ));
    }
  }

  /// Console output is capped so large bodies do not flood the log. The full
  /// bodies remain in the attempt log.
  static const int debugSnippetLength = 1000;

  static String _debugSnippet(String text) => text.length <= debugSnippetLength
      ? text
      : '${text.substring(0, debugSnippetLength)}… '
          '[${text.length - debugSnippetLength} more chars]';

  Future<LocalSaleSyncRecord> _needsReview(
    LocalSaleSyncRecord record, {
    required String message,
    int? httpStatus,
    String? responseBody,
    String? error,
  }) {
    return _update(
      record.copyWith(
        state: LocalSaleSyncState.needsReview,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        message: message,
        httpStatus: httpStatus,
        attempts: record.attemptsWithLastFinished(
          outcome: LocalSaleSyncState.needsReview,
          httpStatus: httpStatus,
          responseBody: responseBody,
          error: error,
        ),
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

  /// Removes a sale the server clearly rejected so the cashier can correct the
  /// still-intact cart and confirm it again. Used only by online-first
  /// confirmation, where the rejected sale never left the checkout screen.
  Future<void> discardRejected(String localOrderId) async {
    await hydrate();
    final record = _records[localOrderId];
    if (record == null) return;
    if (record.state != LocalSaleSyncState.rejected) {
      throw StateError('Only a rejected sale can be discarded.');
    }
    await _store.remove(localOrderId);
    _records.remove(localOrderId);
    notifyListeners();
  }

  /// Finishes a rejection rollback that the app closed in the middle of:
  /// removes the rejected records of [cartSessionId] and returns their local
  /// order ids, so the caller can delete the matching local sale snapshots
  /// and keep the still-editable cart. Only online-first confirmation can
  /// leave a rejected record on the cart it came from.
  Future<List<String>> discardRejectedForCartSession(
    String cartSessionId,
  ) async {
    await hydrate();
    if (cartSessionId.isEmpty) return const [];
    final rejected = _records.values
        .where((record) =>
            record.sourceCartSessionId == cartSessionId &&
            record.state == LocalSaleSyncState.rejected)
        .map((record) => record.localOrderId)
        .toList();
    if (rejected.isEmpty) return const [];

    for (final id in rejected) {
      await _store.remove(id);
      _records.remove(id);
    }
    notifyListeners();
    return rejected;
  }

  static Future<http.Response> _defaultSender(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) {
    return http.post(endpoint, headers: headers, body: body);
  }
}
