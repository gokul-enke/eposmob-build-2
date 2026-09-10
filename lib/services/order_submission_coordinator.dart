import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

abstract class SubmissionStore {
  Future<List<Map<String, dynamic>>> readAll();
  Future<void> write(Map<String, dynamic> record);
  Future<void> remove(String id);
}

class HiveSubmissionStore implements SubmissionStore {
  Box get _box => Hive.box('order_submissions');
  @override
  Future<List<Map<String, dynamic>>> readAll() async => _box
      .toMap()
      .entries
      .where((entry) => entry.key != '_active_cart_session')
      .map((entry) => Map<String, dynamic>.from(entry.value as Map))
      .toList();
  @override
  Future<void> write(Map<String, dynamic> record) async {
    await _box.put(record['id'], record);
    await _box.flush();
  }

  @override
  Future<void> remove(String id) async {
    await _box.delete(id);
    await _box.flush();
  }
}

enum SubmissionPhase {
  idle,
  saving,
  submitting,
  slow,
  unknown,
  confirmed,
  rejected
}

/// Owns the order POST deadline and durable recovery state. Retries are explicit
/// cashier actions, never automatic. No backend idempotency is assumed.
class OrderSubmissionCoordinator extends ChangeNotifier {
  OrderSubmissionCoordinator(
      {required SubmissionStore store,
      this.timeout = const Duration(seconds: 20)})
      : _store = store;

  static final instance =
      OrderSubmissionCoordinator(store: HiveSubmissionStore());
  final SubmissionStore _store;
  final Duration timeout;
  final Map<String, Map<String, dynamic>> _records = {};
  Future<void>? _hydration;
  Future<void>? _recordChanges;
  bool _busy = false;
  int _uiActions = 0;

  /// Keep billing alive through its success/printing callback, beyond the POST.
  /// This lease does not count as a second request in submit().
  VoidCallback holdCheckoutUi() {
    _uiActions++;
    notifyListeners();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _uiActions--;
      notifyListeners();
    };
  }

  String? _scope;
  String? _activeAttemptId;
  final Set<String> _dismissed = {};
  SubmissionPhase phase = SubmissionPhase.idle;
  String? persistenceError;

  static String scopeFor(Uri endpoint, String tenant, int? storeId) => sha256
      .convert(utf8.encode('${endpoint.origin}|$tenant|${storeId ?? 0}'))
      .toString();

  Map<String, dynamic>? get pending {
    final active = _records[_activeAttemptId];
    if (active?['scope'] == _scope && active?['reviewed'] != true) {
      return active;
    }
    for (final record in _records.values) {
      if (record['scope'] == _scope && record['reviewed'] != true) {
        return record;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get ordersToReview => _records.values
      .where((r) => r['scope'] == _scope && r['reviewed'] != true)
      .map((r) => Map<String, dynamic>.unmodifiable(r))
      .toList()
      .reversed
      .toList();

  bool get notificationDismissed =>
      pending == null || _dismissed.contains(pending!['id']);
  void dismissNotification() {
    for (final record in ordersToReview) {
      _dismissed.add(record['id'] as String);
    }
    notifyListeners();
  }

  Future<void> markReviewed(String id) => _changeRecord(() async {
        final record = _records[id];
        if (record == null || record['state'] != 'confirmed') return;
        final updated = {...record, 'reviewed': true};
        await _store.write(updated);
        _records[id] = updated;
        dismissNotification();
      });

  // Serialize late responses with manual deletion so a removed log cannot
  // reappear after an outstanding response finishes writing to disk.
  Future<void> _changeRecord(Future<void> Function() action) {
    final result =
        (_recordChanges ?? Future<void>.value()).then((_) => action());
    _recordChanges =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> removeReviewLog(String id) => _changeRecord(() async {
        final record = _records[id];
        if (record == null || record['scope'] != _scope) return;
        if (_busy && _activeAttemptId == id) {
          throw StateError('This order is still being submitted.');
        }
        await _store.remove(id);
        _records.remove(id);
        if (!_busy) _restorePhase();
        notifyListeners();
      });

  bool get isBusy => _busy || _uiActions > 0;

  /// Holds the checkout gate during an explicit authoritative stock refresh.
  /// No record is removed, so failures and repeated refreshes remain reviewable.
  Future<void> reconcileStock(String id,
      Future<void> Function(bool Function() isCurrent) refresh) async {
    final scope = _scope;
    if (isBusy || scope == null || _records[id]?['scope'] != scope) {
      throw StateError('Finish the current operation before refreshing stock.');
    }
    _busy = true;
    notifyListeners();
    try {
      await refresh(() => _scope == scope && _records[id]?['scope'] == scope);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool isCartAwaitingReview(String cartId) => _records.values.any((record) =>
      record['scope'] == _scope &&
      record['state'] == 'pending' &&
      (record['cart_session_id'] ?? 'legacy') == cartId);
  void selectScope(String scope) {
    if (_scope == scope) return;
    _scope = scope;
    _restorePhase();
    notifyListeners();
  }

  Future<void> hydrate() => _hydration ??= _load();
  Future<void> _load() async {
    for (final record in await _store.readAll()) {
      // An interrupted POST has an unknown outcome, even if the process died
      // before sending. Retain it for review; never resend on launch.
      _records[record['id'] as String] = record;
    }
    _restorePhase();
    notifyListeners();
  }

  void _restorePhase() {
    phase = pending == null
        ? SubmissionPhase.idle
        : pending!['state'] == 'confirmed'
            ? SubmissionPhase.confirmed
            : SubmissionPhase.unknown;
  }

  void _setPhase(SubmissionPhase value, String scope) {
    if (_scope != scope) return;
    phase = value;
    notifyListeners();
  }

  Map<String, dynamic> _unknown(String id, {bool timedOut = false}) => {
        'status': 'unknown',
        'outcome_unknown': true,
        'timed_out': timedOut,
        'submission_id': id,
        'message': 'Order confirmation wasn’t received. You can retry. '
            'The earlier attempt is saved in Sales → Orders to review.',
      };

  Future<Map<String, dynamic>> submit(
      {required Uri endpoint,
      required Map<String, dynamic> payload,
      required Map<String, String> headers,
      String? localDraftId,
      String? cartSessionId,
      String? saleTotal,
      required String scope,
      required Future<http.Response> Function() send}) async {
    // Taken synchronously before reading preferences/storage or sending HTTP.
    if (_busy) {
      return {
        'status': 'busy',
        'message': 'An order is already being confirmed.'
      };
    }
    _busy = true;
    Timer? slowTimer;
    final clock = Stopwatch()..start();
    try {
      await hydrate();
      selectScope(scope);
      Map<String, dynamic>? existing;
      for (final record in _records.values) {
        // Uncertain attempts never block an explicit cashier retry. A known
        // confirmation still needs cleanup/reprinting rather than another POST.
        if (record['scope'] != scope || record['state'] != 'confirmed') {
          continue;
        }
        final sameDraft =
            localDraftId != null && record['local_draft_id'] == localDraftId;
        final sameCart = record['cart_session_id'] == cartSessionId;
        // Legacy records belong to the cart restored from the previous build.
        // An explicit new cart receives a new durable identity.
        final legacyCart =
            record['cart_session_id'] == null && cartSessionId == 'legacy';
        final restoredCopy = (cartSessionId?.startsWith('draft:') ?? false) &&
            record['local_draft_id'] == null &&
            jsonEncode((record['snapshot'] as Map)['items']) ==
                jsonEncode(payload['items']);
        if (sameDraft || sameCart || legacyCart || restoredCopy) {
          existing = record;
          break;
        }
      }
      if (existing != null) {
        _activeAttemptId = existing['id'] as String;
        return existing['state'] == 'confirmed'
            ? {
                'status': 'review_required',
                'submission_id': existing['id'],
                'message':
                    'An earlier order was confirmed. Review it before billing again.'
              }
            : _unknown(existing['id'] as String);
      }
      final id = List.generate(
          16,
          (_) => Random.secure()
              .nextInt(256)
              .toRadixString(16)
              .padLeft(2, '0')).join();
      // Snapshot only the fields needed to compare/recover the sale, never
      // authorization headers, customer phone/address or free-text comments.
      final snapshot = jsonDecode(jsonEncode({
        for (final key in [
          'items',
          'customer_id',
          'store_id',
          'payment_method',
          'paid_methods',
          'paid_amount',
          'balance',
          'discount_amount',
          'delivery_charge'
        ])
          if (payload.containsKey(key)) key: payload[key],
      })) as Map<String, dynamic>;
      final record = <String, dynamic>{
        'id': id,
        'scope': scope,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'state': 'pending',
        'local_draft_id': localDraftId,
        'cart_session_id': cartSessionId,
        'total': saleTotal,
        'snapshot': snapshot
      };
      persistenceError = null;
      _setPhase(SubmissionPhase.saving, scope);
      try {
        await _store.write(record);
      } catch (_) {
        persistenceError = 'We couldn’t save this order on your device. '
            'Nothing was sent. Check local storage before trying again.';
        _setPhase(SubmissionPhase.rejected, scope);
        return {'status': 'storage_error', 'message': persistenceError};
      }
      _records[id] = record;
      _activeAttemptId = id;
      _setPhase(SubmissionPhase.submitting, scope);
      slowTimer = Timer(const Duration(seconds: 5),
          () => _setPhase(SubmissionPhase.slow, scope));
      final requestClock = Stopwatch()..start();
      // Observe the source future as well as its bounded wait. A late response
      // updates only this record; it never modifies the active UI cart.
      final result = _receive(send, record, requestClock);
      try {
        return await result.timeout(timeout);
      } on TimeoutException {
        _setPhase(SubmissionPhase.unknown, scope);
        return _unknown(id, timedOut: true);
      }
    } catch (_) {
      return {
        'status': 'storage_error',
        'message':
            'Order recovery data could not be loaded. Nothing was sent. Restart CloudPOS.'
      };
    } finally {
      slowTimer?.cancel();
      _busy = false;
      debugPrint(
          '[Checkout] operation_ms=${clock.elapsedMilliseconds} phase=${phase.name}');
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _receive(Future<http.Response> Function() send,
      Map<String, dynamic> record, Stopwatch clock) async {
    final id = record['id'] as String;
    final scope = record['scope'] as String;
    try {
      final response = await send();
      debugPrint(
          '[Checkout] request_ms=${clock.elapsedMilliseconds} http=${response.statusCode}');
      final decoded = jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['order_id'] != null) {
        record['state'] = 'confirmed';
        record['order_id'] = data['order_id'].toString();
        record['order_number'] = data['order_number']?.toString();
        try {
          await _changeRecord(() async {
            if (_records.containsKey(id)) await _store.write(record);
          });
        } catch (_) {
          // The original durable pending record remains a restart safeguard.
          persistenceError =
              'The order was confirmed, but its local record could not be updated.';
        }
        if (_activeAttemptId == id && _records.containsKey(id)) {
          _setPhase(SubmissionPhase.confirmed, scope);
        }
        notifyListeners();
        return {...data, 'submission_id': id};
      }
      // These contract-level rejections precede creation. A server error,
      // ambiguous 2xx body or transport failure cannot prove no sale was saved.
      if ([400, 401, 403, 422].contains(response.statusCode) &&
          data['message'] is String) {
        await _changeRecord(() async {
          if (!_records.containsKey(id)) return;
          await _store.remove(id);
          _records.remove(id);
          if (_activeAttemptId == id) {
            _setPhase(SubmissionPhase.rejected, scope);
          }
        });
        return {...data, 'http_status': response.statusCode};
      }
    } catch (error) {
      debugPrint('[Checkout] response_unverified type=${error.runtimeType} '
          'request_ms=${clock.elapsedMilliseconds}');
      // Keep the durable pending record on any inconclusive result.
    }
    if (_activeAttemptId == id && _records.containsKey(id)) {
      _setPhase(SubmissionPhase.unknown, scope);
    }
    notifyListeners();
    return _unknown(id);
  }

  /// Called only after the corresponding confirmed cart cleanup is durable.
  Future<void> acknowledge(String id) => _changeRecord(() async {
        if (_records[id]?['state'] != 'confirmed') return;
        await _store.remove(id);
        _records.remove(id);
        _restorePhase();
        notifyListeners();
      });

  Future<void> completeLocalCleanup(
      dynamic response, Future<void> Function() flush) async {
    final id = response is Map ? response['submission_id'] : null;
    if (id is! String) return;
    try {
      await flush();
      await acknowledge(id);
    } catch (_) {
      persistenceError =
          'The order was confirmed. Local cleanup needs attention; do not bill it again.';
      notifyListeners();
    }
  }
}
