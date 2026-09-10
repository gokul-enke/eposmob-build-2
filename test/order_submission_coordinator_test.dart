import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'test_support/memory_submission_store.dart';

void main() {
  late MemorySubmissionStore store;
  late OrderSubmissionCoordinator coordinator;
  final endpoint =
      Uri.parse('https://example.invalid/api/v1/order/add-to-order');
  const payload = {
    'items': [
      {'product_id': 1, 'quantity': 1}
    ],
    'customer_id': 7,
    'phone': 'private',
    'comment': 'private',
    'paid_methods': [
      {'method': 'cash', 'amount': 10}
    ]
  };
  Future<Map<String, dynamic>> submit(Future<http.Response> Function() send) =>
      coordinator.submit(
          endpoint: endpoint,
          payload: payload,
          headers: {'Authorization': 'secret'},
          scope: 'test',
          send: send);

  setUp(() {
    store = MemorySubmissionStore();
    coordinator = OrderSubmissionCoordinator(store: store);
  });

  test('stock refresh never removes a log, including failure and repeat',
      () async {
    await submit(() async => http.Response('unavailable', 503));
    final id = coordinator.ordersToReview.single['id'] as String;
    store.failRemovals = true;
    await expectLater(
        coordinator.reconcileStock(id, (_) async {
          throw StateError('disk unavailable');
        }),
        throwsStateError);
    expect(coordinator.isBusy, isFalse);
    for (var i = 0; i < 2; i++) {
      await coordinator.reconcileStock(id, (current) async {
        expect(current(), isTrue);
        expect(coordinator.isBusy, isTrue);
      });
    }
    expect(store.records.containsKey(id), isTrue);
  });

  test('stock refresh invalidates its scope check when the store changes',
      () async {
    await submit(() async => http.Response('unavailable', 503));
    final id = coordinator.ordersToReview.single['id'] as String;
    await coordinator.reconcileStock(id, (current) async {
      coordinator.selectScope('different-store');
      expect(current(), isFalse);
    });
    expect(store.records.containsKey(id), isTrue);
    expect(coordinator.isBusy, isFalse);
  });

  testWidgets(
      'persists before POST, returns fast success and awaits durable cleanup before removing record',
      (tester) async {
    var posts = 0;
    final result = await submit(() async {
      posts++;
      expectSync(store.records.length, 1);
      final snapshot = store.records.values.single['snapshot'] as Map;
      expectSync(snapshot.containsKey('phone'), isFalse);
      expectSync(snapshot.containsKey('comment'), isFalse);
      return http.Response('{"order_id":1,"order_number":"TEST1"}', 201);
    });
    expect(posts, 1);
    expect(result['order_id'], 1);
    final flush = Completer<void>();
    final cleanup =
        coordinator.completeLocalCleanup(result, () => flush.future);
    await tester.pump();
    expect(store.records.length, 1);
    flush.complete();
    await cleanup;
    expect(store.records, isEmpty);
    expect(coordinator.phase, SubmissionPhase.idle);
  });

  testWidgets(
      'double submission cannot send twice; slow state appears at five seconds',
      (tester) async {
    final response = Completer<http.Response>();
    var posts = 0;
    final first = submit(() {
      posts++;
      return response.future;
    });
    final second = await submit(() {
      posts++;
      return response.future;
    });
    await tester.pump();
    expect(second['status'], 'busy');
    expect(posts, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(coordinator.phase, SubmissionPhase.slow);
    response.complete(http.Response('{"order_id":2}', 201));
    await tester.pump();
    await first;
  });

  testWidgets('disk failure before POST sends nothing', (tester) async {
    store.failWrites = true;
    var posts = 0;
    final result = await submit(() async {
      posts++;
      return http.Response('{}', 200);
    });
    expect(posts, 0);
    expect(result['status'], 'storage_error');
    expect(store.records, isEmpty);
  });

  testWidgets('restart retains uncertain request and allows an explicit retry',
      (tester) async {
    final result = await submit(() async {
      throw StateError('connection lost');
    });
    expect(result['outcome_unknown'], isTrue);
    coordinator = OrderSubmissionCoordinator(store: store);
    var posts = 0;
    final next = await submit(() async {
      posts++;
      return http.Response('{"order_id":3}', 201);
    });
    expect(posts, 1);
    expect(next['submission_id'], isNot(result['submission_id']));
    expect(store.records.length, 2);
    expect(store.records[result['submission_id']]?['state'], 'pending');
    expect(coordinator.phase, SubmissionPhase.confirmed);
  });

  testWidgets(
      'definitive validation rejection can be corrected; server error stays uncertain',
      (tester) async {
    final rejected = await submit(
        () async => http.Response('{"message":"Insufficient stock"}', 422));
    expect(rejected['http_status'], 422);
    expect(store.records, isEmpty);
    final uncertain = await submit(
        () async => http.Response('{"message":"Internal server error"}', 500));
    expect(uncertain['outcome_unknown'], isTrue);
    expect(store.records.length, 1);
  });

  testWidgets('late response does not change another store scope',
      (tester) async {
    final response = Completer<http.Response>();
    final first = submit(() => response.future);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect((await first)['timed_out'], isTrue);
    coordinator.selectScope('other-store');
    response.complete(http.Response('{"order_id":4}', 201));
    await tester.pump();
    expect(coordinator.pending, isNull);
    expect(coordinator.phase, SubmissionPhase.idle);
    coordinator.selectScope('test');
    expect(coordinator.pending?['order_id'], '4');
  });

  testWidgets(
      'legacy unresolved carts can retry; known confirmations remain protected',
      (tester) async {
    final original = await submit(() async => throw StateError('lost'));
    var posts = 0;
    Future<Map<String, dynamic>> sale(String id) => coordinator.submit(
        endpoint: endpoint,
        payload: payload,
        headers: const {},
        scope: 'test',
        cartSessionId: id,
        send: () async {
          posts++;
          return http.Response('{"order_id":8}', 201);
        });
    expect((await sale('legacy'))['submission_id'],
        isNot(original['submission_id']));
    expect(posts, 1);
    final fresh = await sale('fresh');
    expect(posts, 2);
    await coordinator.markReviewed(fresh['submission_id'] as String);
    expect(coordinator.ordersToReview.length, 2);
    await sale('fresh');
    expect(posts, 2);
  });

  testWidgets('each uncertain retry retains a distinct attempt across restart',
      (tester) async {
    var posts = 0;
    Future<Map<String, dynamic>> sale(String id) => coordinator.submit(
        endpoint: endpoint,
        payload: payload,
        headers: const {},
        scope: 'test',
        cartSessionId: id,
        send: () async {
          posts++;
          throw StateError('lost connection');
        });
    final first = await sale('sale-one');
    coordinator.dismissNotification();
    final second = await sale('sale-two');
    expect(posts, 2);
    expect(first['submission_id'], isNot(second['submission_id']));
    expect(coordinator.ordersToReview.length, 2);
    coordinator = OrderSubmissionCoordinator(store: store);
    final originalAgain = await sale('sale-one');
    final newerAgain = await sale('sale-two');
    expect(posts, 4);
    expect(originalAgain['submission_id'], isNot(first['submission_id']));
    expect(newerAgain['submission_id'], isNot(second['submission_id']));
    expect(store.records.length, 4);
  });

  testWidgets('late result cannot replace progress of a retry of the same cart',
      (tester) async {
    final oldResponse = Completer<http.Response>();
    final newResponse = Completer<http.Response>();
    Future<Map<String, dynamic>> sale(String id, Future<http.Response> reply) =>
        coordinator.submit(
            endpoint: endpoint,
            payload: payload,
            headers: const {},
            scope: 'test',
            cartSessionId: id,
            send: () => reply);
    final oldSale = sale('old', oldResponse.future);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await oldSale;
    final newSale = sale('old', newResponse.future);
    await tester.pump();
    oldResponse.complete(http.Response('{"order_id":10}', 201));
    await tester.pump();
    expect(coordinator.phase, SubmissionPhase.submitting);
    expect(coordinator.pending?['state'], 'pending');
    expect(
        coordinator.ordersToReview.any((r) => r['order_id'] == '10'), isTrue);
    newResponse.complete(http.Response('{"order_id":11}', 201));
    await tester.pump();
    expect((await newSale)['order_id'], 11);
  });
  testWidgets(
      'removed uncertain logs stay removed after late success and restart',
      (tester) async {
    final response = Completer<http.Response>();
    final pending = submit(() => response.future);
    await tester.pump();
    final id = coordinator.ordersToReview.single['id'] as String;
    await expectLater(coordinator.removeReviewLog(id), throwsStateError);
    expect(store.records.length, 1);
    await tester.pump(const Duration(seconds: 20));
    await pending;
    await coordinator.removeReviewLog(id);
    expect(coordinator.ordersToReview, isEmpty);
    response.complete(http.Response('{"order_id":21}', 201));
    await tester.pump();
    expect(store.records, isEmpty);
    expect(coordinator.phase, SubmissionPhase.idle);
    final restarted = OrderSubmissionCoordinator(store: store);
    await restarted.hydrate();
    restarted.selectScope('test');
    expect(restarted.ordersToReview, isEmpty);
  });

  testWidgets('removal is scoped and a storage failure keeps the review log',
      (tester) async {
    final result = await submit(() async => throw StateError('lost'));
    final id = result['submission_id'] as String;
    coordinator.selectScope('other-store');
    await coordinator.removeReviewLog(id);
    expect(store.records.length, 1);
    coordinator.selectScope('test');
    store.failRemovals = true;
    await expectLater(coordinator.removeReviewLog(id), throwsStateError);
    expect(coordinator.ordersToReview.length, 1);
    store.failRemovals = false;
    await coordinator.removeReviewLog(id);
    expect(store.records, isEmpty);
  });
}
