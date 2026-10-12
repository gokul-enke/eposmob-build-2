import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/services/local_sale_sync_service.dart';

class _MemoryOutbox implements LocalSaleOutboxStore {
  final Map<String, Map<String, dynamic>> rows = {};

  @override
  Future<List<Map<String, dynamic>>> readAll() async =>
      rows.values.map(Map<String, dynamic>.from).toList();

  @override
  Future<void> remove(String localOrderId) async {
    rows.remove(localOrderId);
  }

  @override
  Future<void> write(Map<String, dynamic> record) async {
    rows[record['local_order_id'] as String] =
        Map<String, dynamic>.from(record);
  }
}

const _endpoint = 'https://pos.example.test/api/order';

Future<LocalSaleSyncRecord> _enqueue(LocalSaleSyncService service) {
  return service.enqueue(
    localOrderId: 'local-1',
    localOrderNumber: 'CONF-1',
    sourceCartSessionId: 'cart-1',
    surface: LocalSaleSurface.supermarketDesktop,
    payload: {
      'items': [
        {'product_id': 7, 'quantity': 2}
      ],
      'customer_id': 3,
      'balance': '0',
    },
  );
}

void main() {
  test('overlapping batches are blocked until the active batch finishes',
      () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final service = LocalSaleSyncService(
        store: _MemoryOutbox(),
        sender: (_, __, ___) {
          started.complete();
          return response.future;
        });
    await _enqueue(service);
    final first = service.syncAfterVerification(
        localOrderIds: ['local-1'],
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint));
    await started.future;
    expect(service.isBatchSyncing, isTrue);
    await expectLater(
        service.syncAfterVerification(
            localOrderIds: ['local-1'], accessToken: 'token'),
        throwsStateError);
    response.complete(http.Response('{"order_id":91}', 201));
    expect((await first).synced, 1);
    expect(service.isBatchSyncing, isFalse);
  });

  test('edited request survives restart and preserves previous attempt bodies',
      () async {
    final store = _MemoryOutbox();
    final sent = <String>[];
    final service = LocalSaleSyncService(
        store: store,
        sender: (_, __, body) async {
          sent.add(body);
          return http.Response('{"message":"Invalid shipped ID"}', 422);
        });
    await _enqueue(service);
    await service.submitOnce(
        localOrderId: 'local-1',
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint));
    final edited = {
      ...service.recordFor('local-1')!.payload,
      'order_id': 81,
      'shipped_id': 12,
      'issued_at': '2026-10-08T10:00:00Z'
    };
    await service.updateRequestPayload('local-1', edited);
    edited['items'] = [];
    expect(service.recordFor('local-1')!.state, LocalSaleSyncState.rejected);
    expect(service.recordFor('local-1')!.payload['items'], isNotEmpty);
    final restarted = LocalSaleSyncService(
        store: store,
        sender: (_, __, body) async {
          sent.add(body);
          return http.Response('{"order_id":81,"order_number":"INV-81"}', 201);
        });
    await restarted.hydrate();
    await restarted.authorizeRetryAfterVerification('local-1');
    final result = await restarted.submitOnce(
        localOrderId: 'local-1',
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint));
    expect(jsonDecode(sent.last)['shipped_id'], 12);
    expect(jsonDecode(sent.last)['issued_at'], '2026-10-08T10:00:00Z');
    expect(result.attempts.first.requestBody, sent.first);
    expect(result.attempts.last.requestBody, sent.last);
    expect(result.attempts.length, 2);
    expect(() => restarted.updateRequestPayload('local-1', {'order_id': 99}),
        throwsStateError);
  });

  test('cannot edit a sending request or an empty or dismissed request',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final service = LocalSaleSyncService(
        store: _MemoryOutbox(),
        sender: (_, __, ___) {
          started.complete();
          return response.future;
        });
    await _enqueue(service);
    await expectLater(
        service.updateRequestPayload('local-1', {}), throwsStateError);
    final pending = service.submitOnce(
        localOrderId: 'local-1',
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint));
    await started.future;
    await expectLater(service.updateRequestPayload('local-1', {'order_id': 9}),
        throwsStateError);
    response.complete(http.Response('{"message":"Invalid"}', 422));
    await pending;
    await service.dismiss('local-1', note: 'Resolved externally');
    await expectLater(service.updateRequestPayload('local-1', {'order_id': 9}),
        throwsStateError);
  });

  test(
      'bulk sync attempts unique eligible sales once and continues through failures',
      () async {
    final store = _MemoryOutbox();
    final sentIds = <String>[];
    var active = 0;
    var maxActive = 0;
    final service = LocalSaleSyncService(
        store: store,
        sender: (_, __, body) async {
          final id = jsonDecode(body)['test_id'] as String;
          sentIds.add(id);
          active++;
          if (active > maxActive) maxActive = active;
          await Future<void>.delayed(Duration.zero);
          active--;
          if (id == 'rejected') {
            return http.Response('{"message":"Invalid date"}', 422);
          }
          if (id == 'review') throw StateError('Connection lost');
          return http.Response('{"order_id":91}', 201);
        });
    for (final id in ['synced', 'rejected', 'review', 'dismissed', 'success']) {
      await service.enqueue(
          localOrderId: id,
          localOrderNumber: id,
          sourceCartSessionId: id,
          surface: LocalSaleSurface.mobileBilling,
          payload: {'test_id': id});
    }
    await service.submitOnce(
        localOrderId: 'synced',
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint));
    await service.markNeedsReviewBeforeSend('dismissed',
        message: 'Needs review');
    await service.dismiss('dismissed', note: 'Resolved');
    sentIds.clear();
    final progress = <int>[];
    final result = await service.syncAfterVerification(
        localOrderIds: [
          'synced',
          'rejected',
          'review',
          'missing',
          'dismissed',
          'success',
          'success'
        ],
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint),
        prepareSale: (id) async {
          throw StateError('Preparation failed');
        },
        onProgress: (done, total) {
          expect(total, 6);
          progress.add(done);
        });
    expect(sentIds, ['rejected', 'review', 'success']);
    expect(maxActive, 1);
    expect(result.synced, 1);
    expect(result.rejected, 1);
    expect(result.needsReview, 1);
    expect(result.skipped, 2);
    expect(result.failed, 1);
    expect(progress, [1, 2, 3, 4, 5, 6]);
  });

  test('persists the exact payload and records a successful first attempt',
      () async {
    final store = _MemoryOutbox();
    var sends = 0;
    late String sentBody;
    final service = LocalSaleSyncService(
      store: store,
      sender: (endpoint, headers, body) async {
        sends++;
        sentBody = body;
        expect(headers['Authorization'], 'Bearer token');
        return http.Response(
          '{"order_id":91,"order_number":"INV-91"}',
          201,
        );
      },
    );

    await _enqueue(service);
    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(sends, 1);
    expect(sentBody, contains('"product_id":7'));
    expect(result.state, LocalSaleSyncState.synced);
    expect(result.serverOrderId, '91');
    expect(result.serverOrderNumber, 'INV-91');
    expect(store.rows['local-1']?['state'], 'synced');
  });

  test('a clear validation response is rejected, not ambiguous', () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async =>
          http.Response('{"message":"Insufficient stock"}', 422),
    );
    await _enqueue(service);

    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(result.state, LocalSaleSyncState.rejected);
    expect(result.message, 'Insufficient stock');
  });

  for (final status in [401, 403]) {
    test('an authorization failure ($status) is rejected, not ambiguous',
        () async {
      final service = LocalSaleSyncService(
        store: _MemoryOutbox(),
        sender: (_, __, ___) async =>
            http.Response('{"message":"Unauthenticated."}', status),
      );
      await _enqueue(service);

      final result = await service.submitOnce(
        localOrderId: 'local-1',
        accessToken: 'token',
        tenantKey: 'tenant',
        endpoint: Uri.parse(_endpoint),
      );

      expect(result.state, LocalSaleSyncState.rejected);
      expect(result.message, 'Unauthenticated.');
      expect(result.httpStatus, status);
    });
  }

  test('an interrupted rejection rollback is finished for its cart only',
      () async {
    final store = _MemoryOutbox();
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async =>
          http.Response('{"message":"Insufficient stock"}', 422),
    );
    await _enqueue(service);
    await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    // A restart finds the rejected record still stored.
    final restarted = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    expect(
        await restarted.discardRejectedForCartSession('another-cart'), isEmpty);
    expect(restarted.hasRecordedCartSession('cart-1'), isTrue);

    expect(
        await restarted.discardRejectedForCartSession('cart-1'), ['local-1']);
    expect(restarted.hasRecordedCartSession('cart-1'), isFalse);
    expect(store.rows, isEmpty);
  });

  test('a sale that may have reached the server is never rolled back',
      () async {
    final store = _MemoryOutbox();
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('oops', 500),
    );
    await _enqueue(service);
    await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(await service.discardRejectedForCartSession('cart-1'), isEmpty);
    expect(service.hasRecordedCartSession('cart-1'), isTrue);
    expect(store.rows['local-1']?['state'], 'needs_review');
  });

  test('existing-order confirmation accepts the update endpoint success shape',
      () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async =>
          http.Response('{"status":"success","message":"Updated"}', 200),
    );
    await service.enqueue(
      localOrderId: 'local-1',
      localOrderNumber: 'CONF-1',
      sourceCartSessionId: 'cart-1',
      surface: LocalSaleSurface.attender,
      operation: LocalSaleOperation.confirmExistingOrder,
      payload: {'order_id': '501', 'status': 'confirmed'},
    );

    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(result.state, LocalSaleSyncState.synced);
    expect(result.serverOrderId, '501');
  });

  test('an ambiguous server response is retained and never sent twice',
      () async {
    var sends = 0;
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async {
        sends++;
        return http.Response('server error', 500);
      },
    );
    await _enqueue(service);

    final first = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    final second = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(first.state, LocalSaleSyncState.needsReview);
    expect(second.state, LocalSaleSyncState.needsReview);
    expect(sends, 1);
  });

  test('an operator-verified missing sale can be retried exactly once',
      () async {
    var sends = 0;
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async {
        sends++;
        return sends == 1
            ? http.Response('server error', 500)
            : http.Response('{"order_id":92,"order_number":"INV-92"}', 201);
      },
    );
    await _enqueue(service);

    final first = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(first.state, LocalSaleSyncState.needsReview);

    final authorized = await service.authorizeRetryAfterVerification('local-1');
    expect(authorized.state, LocalSaleSyncState.queued);

    final retry = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(retry.state, LocalSaleSyncState.synced);
    expect(retry.serverOrderNumber, 'INV-92');
    expect(sends, 2);
  });

  test('a timeout becomes needs-review without a retry', () async {
    var sends = 0;
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      requestTimeout: const Duration(milliseconds: 5),
      sender: (_, __, ___) {
        sends++;
        return Completer<http.Response>().future;
      },
    );
    await _enqueue(service);

    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(result.state, LocalSaleSyncState.needsReview);
    expect(sends, 1);
  });

  test('restart converts an interrupted sending record to needs-review',
      () async {
    final store = _MemoryOutbox();
    store.rows['local-1'] = {
      'local_order_id': 'local-1',
      'local_order_number': 'CONF-1',
      'source_cart_session_id': 'cart-1',
      'surface': 'supermarketDesktop',
      'operation': 'confirmedSale',
      'state': 'sending',
      'payload': {'items': []},
      'created_at': '2026-09-14T00:00:00.000Z',
    };
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    await service.hydrate();

    expect(
      service.recordFor('local-1')?.state,
      LocalSaleSyncState.needsReview,
    );
    expect(store.rows['local-1']?['state'], 'needs_review');
  });

  test('restart exposes an initial attempt that never started', () async {
    final store = _MemoryOutbox();
    store.rows['local-1'] = {
      'local_order_id': 'local-1',
      'local_order_number': 'CONF-1',
      'source_cart_session_id': 'cart-1',
      'surface': 'supermarketDesktop',
      'operation': 'confirmedSale',
      'state': 'queued',
      'payload': {'items': []},
      'created_at': '2026-09-14T00:00:00.000Z',
    };
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    await service.hydrate();

    expect(
      service.recordFor('local-1')?.state,
      LocalSaleSyncState.needsReview,
    );
    expect(store.rows['local-1']?['state'], 'needs_review');
  });

  test('an unsynced sale cannot be deleted from the audit list', () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async => http.Response('{}', 500),
    );
    await _enqueue(service);

    expect(
      () => service.remove('local-1'),
      throwsA(isA<StateError>()),
    );
    expect(service.recordFor('local-1'), isNotNull);
  });

  test('a never-sent legacy request can be deleted, a sent one cannot',
      () async {
    final store = _MemoryOutbox();
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );
    Future<void> enqueueLegacy(String id) => service.enqueue(
          localOrderId: id,
          localOrderNumber: id,
          sourceCartSessionId: id,
          surface: LocalSaleSurface.legacy,
          payload: {'order_id': 1},
        );
    await enqueueLegacy('legacy-unsent');
    await service.remove('legacy-unsent');
    expect(service.recordFor('legacy-unsent'), isNull);
    expect(store.rows.containsKey('legacy-unsent'), isFalse);

    await enqueueLegacy('legacy-sent');
    await service.submitOnce(
      localOrderId: 'legacy-sent',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(service.recordFor('legacy-sent')!.isUnsentLegacy, isFalse);
    expect(() => service.remove('legacy-sent'), throwsStateError);
  });

  test('links a durable sale to its source cart for crash recovery', () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    await _enqueue(service);

    expect(service.hasRecordedCartSession('cart-1'), isTrue);
    expect(service.hasRecordedCartSession('another-cart'), isFalse);
  });

  test('logs the exact request and response of every attempt', () async {
    final store = _MemoryOutbox();
    var sends = 0;
    final sentBodies = <String>[];
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, body) async {
        sends++;
        sentBodies.add(body);
        return sends == 1
            ? http.Response('{"message":"Out of stock"}', 422)
            : http.Response('{"order_id":93,"order_number":"INV-93"}', 201);
      },
    );
    await _enqueue(service);

    final first = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(first.state, LocalSaleSyncState.rejected);

    // A rejected sale can be retried by the operator.
    await service.authorizeRetryAfterVerification('local-1');
    final retry = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(retry.state, LocalSaleSyncState.synced);

    expect(retry.attempts, hasLength(2));
    expect(retry.attempts[0].number, 1);
    expect(retry.attempts[0].requestBody, sentBodies[0]);
    expect(retry.attempts[0].httpStatus, 422);
    expect(retry.attempts[0].responseBody, '{"message":"Out of stock"}');
    expect(retry.attempts[0].outcome, 'rejected');
    expect(retry.attempts[0].endpoint, _endpoint);
    expect(retry.attempts[1].requestBody, sentBodies[1]);
    expect(retry.attempts[1].httpStatus, 201);
    expect(retry.attempts[1].outcome, 'synced');
    expect(retry.attempts[1].isFinished, isTrue);

    // The log survives a restart.
    final reloaded = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );
    await reloaded.hydrate();
    final stored = reloaded.recordFor('local-1')!;
    expect(stored.attempts, hasLength(2));
    expect(stored.attempts[0].responseBody, '{"message":"Out of stock"}');
    expect(stored.attempts[1].requestBody, sentBodies[1]);
  });

  test('logs a timeout as an attempt with no response', () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      requestTimeout: const Duration(milliseconds: 5),
      sender: (_, __, ___) => Completer<http.Response>().future,
    );
    await _enqueue(service);

    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    expect(result.attempts, hasLength(1));
    expect(result.attempts.single.httpStatus, isNull);
    expect(result.attempts.single.responseBody, isNull);
    expect(result.attempts.single.error, contains('timeout'));
    expect(result.attempts.single.outcome, 'needs_review');
  });

  test('restart closes an attempt that never got a response', () async {
    final store = _MemoryOutbox();
    store.rows['local-1'] = {
      'local_order_id': 'local-1',
      'local_order_number': 'CONF-1',
      'source_cart_session_id': 'cart-1',
      'surface': 'supermarketDesktop',
      'operation': 'confirmedSale',
      'state': 'sending',
      'payload': {'items': []},
      'created_at': '2026-09-14T00:00:00.000Z',
      'attempts': [
        {
          'number': 1,
          'started_at': '2026-09-14T00:00:01.000Z',
          'endpoint': _endpoint,
          'request_body': '{"items":[]}',
        },
      ],
    };
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    await service.hydrate();

    final attempt = service.recordFor('local-1')!.attempts.single;
    expect(attempt.isFinished, isTrue);
    expect(attempt.outcome, 'needs_review');
    expect(attempt.error, contains('app closed'));
    expect(attempt.requestBody, '{"items":[]}');
  });

  test('a verified sale can be removed from the list but keeps its log',
      () async {
    final store = _MemoryOutbox();
    final service = LocalSaleSyncService(
      store: store,
      requestTimeout: const Duration(milliseconds: 5),
      sender: (_, __, ___) => Completer<http.Response>().future,
    );
    await _enqueue(service);
    await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    expect(service.unresolvedCount, 1);

    final dismissed =
        await service.dismiss('local-1', note: 'Found in admin panel.');

    expect(dismissed.isDismissed, isTrue);
    expect(dismissed.state, LocalSaleSyncState.needsReview);
    expect(dismissed.attempts, hasLength(1));
    expect(service.unresolvedCount, 0);
    expect(store.rows['local-1']?['dismiss_note'], 'Found in admin panel.');
    expect(
      () => service.authorizeRetryAfterVerification('local-1'),
      throwsStateError,
    );
  });

  test('a sale still waiting for its first attempt cannot be removed',
      () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async => http.Response('{}', 500),
    );
    await _enqueue(service);

    expect(
      () => service.dismiss('local-1', note: 'x'),
      throwsStateError,
    );
  });

  test('prunes only synced sales older than the retention period', () async {
    Map<String, dynamic> row(String id, String state, String updatedAt,
            {bool dismissed = false}) =>
        {
          'local_order_id': id,
          'local_order_number': id,
          'source_cart_session_id': 'cart-$id',
          'surface': 'supermarketDesktop',
          'operation': 'confirmedSale',
          'state': state,
          'payload': {'items': []},
          'created_at': updatedAt,
          'updated_at': updatedAt,
          if (dismissed) 'dismissed_at': updatedAt,
        };
    final store = _MemoryOutbox();
    store.rows['old-synced'] =
        row('old-synced', 'synced', '2026-08-01T00:00:00Z');
    store.rows['new-synced'] =
        row('new-synced', 'synced', '2026-09-20T00:00:00Z');
    store.rows['old-rejected'] =
        row('old-rejected', 'rejected', '2026-08-01T00:00:00Z');
    store.rows['old-review'] =
        row('old-review', 'needs_review', '2026-08-01T00:00:00Z');
    store.rows['old-removed'] = row(
        'old-removed', 'needs_review', '2026-08-01T00:00:00Z',
        dismissed: true);
    final service = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    final pruned = await service.pruneSynced(
      now: DateTime.utc(2026, 9, 29),
    );

    expect(pruned, ['old-synced']);
    expect(store.rows.keys, isNot(contains('old-synced')));
    expect(service.recordFor('old-synced'), isNull);
    expect(
      store.rows.keys,
      containsAll(['new-synced', 'old-rejected', 'old-review', 'old-removed']),
    );
  });

  test('stores a shorter response for synced attempts only', () async {
    final longTail = 'x' * 5000;
    var sends = 0;
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async {
        sends++;
        return sends == 1
            ? http.Response('{"message":"bad","pad":"$longTail"}', 422)
            : http.Response('{"order_id":94,"pad":"$longTail"}', 201);
      },
    );
    await _enqueue(service);
    await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );
    await service.authorizeRetryAfterVerification('local-1');
    final result = await service.submitOnce(
      localOrderId: 'local-1',
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse(_endpoint),
    );

    final rejected = result.attempts[0].responseBody!;
    final synced = result.attempts[1].responseBody!;
    expect(rejected.length, greaterThan(5000));
    expect(synced, endsWith('[truncated]'));
    expect(
      synced.length,
      lessThan(LocalSaleSyncAttempt.maxSyncedResponseLength + 20),
    );
  });

  test('a retried existing-order confirmation goes to update-order', () async {
    late Uri sentTo;
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (endpoint, __, ___) async {
        sentTo = endpoint;
        return http.Response('{"status":"success"}', 200);
      },
    );
    await service.enqueue(
      localOrderId: 'local-2',
      localOrderNumber: 'CONF-2',
      sourceCartSessionId: 'cart-2',
      surface: LocalSaleSurface.attender,
      operation: LocalSaleOperation.confirmExistingOrder,
      payload: {'order_id': 55, 'items': []},
    );

    final result = await service.submitOnce(
      localOrderId: 'local-2',
      accessToken: 'token',
      tenantKey: 'tenant',
    );

    expect(sentTo.path, endsWith('/api/v1/order/update-order'));
    expect(result.state, LocalSaleSyncState.synced);
  });
}
