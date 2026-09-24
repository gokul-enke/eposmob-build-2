// Diagnostic coverage for slow checkout responses. Network and elapsed time
// are simulated; these tests never create orders on a tenant server.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/subscription/domain/company_subscription.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'test_support/memory_submission_store.dart';

// Isolate order requests from the constructor's unrelated cart refresh.
class _OrderRequestProvider extends CartProvider {
  _OrderRequestProvider()
      : super(
            submissionCoordinator:
                OrderSubmissionCoordinator(store: MemorySubmissionStore()));
  @override
  Future<void> getData() async {}
}

Future<dynamic> _confirm(CartProvider provider,
        {bool protectSubmission = true}) =>
    provider.addToOrderAPI(
      protectSubmission: protectSubmission,
      items: [
        {'product_id': 1, 'quantity': 1, 'price': 10, 'mrp': 10},
      ],
      cartIds: 0,
      accessToken: 'diagnostic-token',
      transactionId: '',
      totalPrice: '10',
      customerId: 1,
      paymentMethod: 'cash',
      paidAmount: '10',
      status: 'confirmed',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'api_key': 'diagnostic-tenant'});
    SubscriptionAccessRegistry.update(
      CompanySubscription.fromJson({'status': 'active'}),
      verificationFailed: false,
    );
  });

  tearDown(() {
    SubscriptionAccessRegistry.update(null, verificationFailed: true);
  });

  testWidgets(
      'other order workflows do not create supermarket recovery records',
      (tester) async {
    final provider = _OrderRequestProvider();
    final client =
        MockClient((_) async => http.Response('{"order_id":9}', 201));
    await http.runWithClient(
        () => _confirm(provider, protectSubmission: false), () => client);
    expect(provider.submissions.pending, isNull);
    expect(provider.submissions.phase, SubmissionPhase.idle);
    provider.dispose();
    client.close();
  });

  testWidgets('confirmation remains pending for a seven-second API response',
      (tester) async {
    final provider = _OrderRequestProvider();
    addTearDown(provider.dispose);
    final server = Completer<http.Response>();
    var posts = 0;
    final client = MockClient((request) {
      expectSync(request.method, 'POST');
      posts++;
      return server.future;
    });
    addTearDown(client.close);
    dynamic result;
    final confirmation = http.runWithClient(
        () => _confirm(provider), () => client)
      ..then((value) => result = value);
    await tester.pump();
    expect(posts, 1);
    await tester.pump(const Duration(seconds: 7));
    expect(result, isNull);
    server.complete(http.Response('{"order_id":42}', 201));
    await tester.pump();
    expect((await confirmation)['order_id'], 42);
  });

  testWidgets(
      '20-second timeout preserves a late successful order for recovery',
      (tester) async {
    final provider = _OrderRequestProvider();
    addTearDown(provider.dispose);
    final server = Completer<http.Response>();
    var serverFinished = false;
    var posts = 0;
    final client = MockClient((request) async {
      posts++;
      final response = await server.future;
      serverFinished = true;
      return response;
    });
    addTearDown(client.close);
    dynamic result;
    final confirmation = http.runWithClient(
        () => _confirm(provider), () => client)
      ..then((value) => result = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));
    final timeout = await confirmation;
    expect(timeout['timed_out'], isTrue);
    expect(timeout['message'], contains('You can retry'));
    expect(serverFinished, isFalse);
    expect(posts, 1, reason: 'No automatic retry should create another order.');
    server.complete(http.Response('{"order_id":43}', 201));
    await tester.pump();
    expect(serverFinished, isTrue);
    expect(provider.submissions.pending?['order_id'], '43');
    expect(provider.submissions.phase, SubmissionPhase.confirmed);
    expect(result['order_id'], isNull,
        reason: 'The late success is not reconciled by the timed-out call.');
  });

  testWidgets('saved-orders refresh still waits after two minutes',
      (tester) async {
    final provider = _OrderRequestProvider();
    addTearDown(provider.dispose);
    final server = Completer<http.Response>();
    var gets = 0;
    final client = MockClient((request) {
      expectSync(request.method, 'GET');
      gets++;
      return server.future;
    });
    addTearDown(client.close);
    dynamic result;
    final refresh = http.runWithClient(
      () => provider.listSavedOrders(
          accessToken: 'diagnostic-token', tableId: null),
      () => client,
    )..then((value) => result = value);
    await tester.pump();
    expect(gets, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(result, isNull,
        reason: 'Restaurant confirmation awaits this unbounded refresh.');
    server.complete(http.Response('{"data":{"data":[]}}', 200));
    await tester.pump();
    expect((await refresh)['status'], 'success');
  });
}
