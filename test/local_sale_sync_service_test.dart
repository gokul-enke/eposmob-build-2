import 'dart:async';

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

  test('links a durable sale to its source cart for crash recovery', () async {
    final service = LocalSaleSyncService(
      store: _MemoryOutbox(),
      sender: (_, __, ___) async => http.Response('{}', 500),
    );

    await _enqueue(service);

    expect(service.hasRecordedCartSession('cart-1'), isTrue);
    expect(service.hasRecordedCartSession('another-cart'), isFalse);
  });
}
