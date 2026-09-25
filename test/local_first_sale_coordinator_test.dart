import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/services/local_first_sale_coordinator.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

class _MemoryOutbox implements LocalSaleOutboxStore {
  _MemoryOutbox(this.events, {this.failWrites = false});

  final List<String> events;
  final bool failWrites;
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
    events.add('outbox:${record['state']}');
    if (failWrites) throw StateError('disk full');
    rows[record['local_order_id'] as String] =
        Map<String, dynamic>.from(record);
  }
}

OrderSubmissionPayload _payload() => OrderSubmissionPayload(
      items: const [
        {'product_id': 1, 'quantity': 1}
      ],
      transactionNumber: 'TX',
      paymentMethods: const ['CASH'],
      paidMethods: const [
        {'method': 'CASH', 'amount': 10}
      ],
      balanceAmount: '0',
      status: 'confirmed',
    );

void main() {
  test('enforces persist, commit, print, then background send ordering',
      () async {
    final events = <String>[];
    final store = _MemoryOutbox(events);
    final outbox = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async {
        events.add('send');
        return http.Response('{"order_id":5,"order_number":"INV-5"}', 201);
      },
    );
    final coordinator = LocalFirstSaleCoordinator(outbox);

    final result = await coordinator.confirm<String>(
      surface: LocalSaleSurface.mobileBilling,
      sourceCartSessionId: 'cart-1',
      payload: _payload(),
      accessToken: 'token',
      tenantKey: 'tenant',
      persistLocalSale: () {
        events.add('persist');
        return const LocalSaleIdentity(
          value: 'local sale',
          localOrderId: 'local-1',
          localOrderNumber: 'CONF-1',
        );
      },
      flushLocalPersistence: () async => events.add('flush'),
      commitLocalWorkspace: (_) => events.add('commit'),
      rollbackLocalSale: (_) => events.add('rollback'),
      printLocalReceipt: (_) => events.add('print'),
    );
    final sync = await result.backgroundSync;

    expect(sync.state, LocalSaleSyncState.synced);
    expect(
      events,
      [
        'persist',
        'flush',
        'outbox:queued',
        'commit',
        'flush',
        'print',
        'outbox:sending',
        'send',
        'outbox:synced',
      ],
    );
  });

  test('a print failure does not prevent the one background attempt', () async {
    var sends = 0;
    final outbox = LocalSaleSyncService(
      store: _MemoryOutbox([]),
      sender: (_, __, ___) async {
        sends++;
        return http.Response('{"order_id":5}', 201);
      },
    );
    final result = await LocalFirstSaleCoordinator(outbox).confirm<String>(
      surface: LocalSaleSurface.restaurant,
      sourceCartSessionId: 'cart-1',
      payload: _payload(),
      accessToken: 'token',
      tenantKey: 'tenant',
      persistLocalSale: () => const LocalSaleIdentity(
        value: 'sale',
        localOrderId: 'local-1',
        localOrderNumber: 'CONF-1',
      ),
      flushLocalPersistence: () async {},
      commitLocalWorkspace: (_) {},
      rollbackLocalSale: (_) {},
      printLocalReceipt: (_) => throw StateError('printer offline'),
    );

    expect(result.printSucceeded, isFalse);
    expect(result.printError, isA<StateError>());
    await result.backgroundSync;
    expect(sends, 1);
  });

  test('manual offline mode saves locally without starting an API request',
      () async {
    final events = <String>[];
    var sends = 0;
    final outbox = LocalSaleSyncService(
      store: _MemoryOutbox(events),
      sender: (_, __, ___) async {
        sends++;
        return http.Response('{"order_id":5}', 201);
      },
    );

    final result = await LocalFirstSaleCoordinator(outbox).confirm<String>(
      surface: LocalSaleSurface.supermarketDesktop,
      sourceCartSessionId: 'cart-offline',
      payload: _payload(),
      accessToken: 'token',
      attemptServerSync: false,
      persistLocalSale: () {
        events.add('persist');
        return const LocalSaleIdentity(
          value: 'sale',
          localOrderId: 'local-offline-1',
          localOrderNumber: '2-01-260916-0001',
        );
      },
      flushLocalPersistence: () async => events.add('flush'),
      commitLocalWorkspace: (_) => events.add('commit'),
      rollbackLocalSale: (_) => events.add('rollback'),
      printLocalReceipt: (_) => events.add('print'),
    );

    final record = await result.backgroundSync;
    expect(sends, 0);
    expect(record.state, LocalSaleSyncState.needsReview);
    expect(record.message, contains('Offline Mode is enabled'));
    expect(
      events,
      [
        'persist',
        'flush',
        'outbox:queued',
        'commit',
        'flush',
        'print',
        'outbox:needs_review',
      ],
    );
  });

  test('existing-order operation enqueues the update body, not create fields',
      () async {
    final store = _MemoryOutbox([]);
    final outbox = LocalSaleSyncService(
      store: store,
      sender: (_, __, ___) async => http.Response('{"status":"success"}', 200),
    );
    final payload = OrderSubmissionPayload(
      items: const [
        {'product_id': 1, 'quantity': 1}
      ],
      orderId: '501',
      transactionNumber: 'TX',
      status: 'confirmed',
    );

    final result = await LocalFirstSaleCoordinator(outbox).confirm<String>(
      surface: LocalSaleSurface.attender,
      operation: LocalSaleOperation.confirmExistingOrder,
      sourceCartSessionId: 'cart-1',
      payload: payload,
      accessToken: 'token',
      tenantKey: 'tenant',
      endpoint: Uri.parse('https://pos.example.test/update'),
      persistLocalSale: () => const LocalSaleIdentity(
        value: 'sale',
        localOrderId: 'local-1',
        localOrderNumber: 'CONF-1',
      ),
      flushLocalPersistence: () async {},
      commitLocalWorkspace: (_) {},
      rollbackLocalSale: (_) {},
    );

    expect(store.rows['local-1']?['payload']['order_id'], '501');
    expect(store.rows['local-1']?['payload'].containsKey('items'), isFalse);
    expect((await result.backgroundSync).state, LocalSaleSyncState.synced);
  });

  test('background attempt outlives the initiating adapter', () async {
    final response = Completer<http.Response>();
    final sendStarted = Completer<void>();
    final outbox = LocalSaleSyncService(
      store: _MemoryOutbox([]),
      sender: (_, __, ___) {
        sendStarted.complete();
        return response.future;
      },
    );

    final result = await LocalFirstSaleCoordinator(outbox).confirm<String>(
      surface: LocalSaleSurface.mobileBilling,
      sourceCartSessionId: 'cart-1',
      payload: _payload(),
      accessToken: 'token',
      tenantKey: 'tenant',
      persistLocalSale: () => const LocalSaleIdentity(
        value: 'sale',
        localOrderId: 'local-1',
        localOrderNumber: 'CONF-1',
      ),
      flushLocalPersistence: () async {},
      commitLocalWorkspace: (_) {},
      rollbackLocalSale: (_) {},
    );

    await sendStarted.future;
    expect(outbox.recordFor('local-1')?.state, LocalSaleSyncState.sending);
    response.complete(http.Response('{"order_id":5}', 201));
    expect(
      (await result.backgroundSync).state,
      LocalSaleSyncState.synced,
    );
  });

  test('outbox failure rolls back the local record and sends nothing',
      () async {
    final events = <String>[];
    var sends = 0;
    final outbox = LocalSaleSyncService(
      store: _MemoryOutbox(events, failWrites: true),
      sender: (_, __, ___) async {
        sends++;
        return http.Response('{"order_id":5}', 201);
      },
    );

    await expectLater(
      LocalFirstSaleCoordinator(outbox).confirm<String>(
        surface: LocalSaleSurface.kiosk,
        sourceCartSessionId: 'cart-1',
        payload: _payload(),
        accessToken: 'token',
        tenantKey: 'tenant',
        persistLocalSale: () => const LocalSaleIdentity(
          value: 'sale',
          localOrderId: 'local-1',
          localOrderNumber: 'CONF-1',
        ),
        flushLocalPersistence: () async => events.add('flush'),
        commitLocalWorkspace: (_) => events.add('commit'),
        rollbackLocalSale: (_) => events.add('rollback'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(events, ['flush', 'outbox:queued', 'rollback', 'flush']);
    expect(sends, 0);
  });
}
