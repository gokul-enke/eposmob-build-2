/// Coverage for InvoiceProvider.fetchFailedZatcaCount, which backs the
/// dashboard "Failed Zatca Invoice" alert.
///
/// The alert is a compliance warning, so the paths that matter most are the
/// ones where the request does not succeed: those must leave the previously
/// known count untouched and report failure, so the caller can retry rather
/// than silently showing "no failures".
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_key': 'test-tenant',
      'active_store_id': 7,
    });
  });

  MockClient jsonClient(int status, String body,
      {void Function(http.Request)? onRequest}) {
    return MockClient((request) async {
      onRequest?.call(request);
      return http.Response(body, status,
          headers: {'content-type': 'application/json'});
    });
  }

  group('fetchFailedZatcaCount', () {
    test('reads data.total and reports success', () async {
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      expect(ok, isTrue);
      expect(provider.failedZatcaCount, 14);
    });

    test('requests only the failed invoices, one row, for the active store',
        () async {
      final provider = InvoiceProvider();
      late Uri captured;

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":0}}',
            onRequest: (request) => captured = request.url),
      );

      expect(captured.queryParameters['zatca_status'], 'failed');
      expect(captured.queryParameters['per_page'], '1');
      expect(captured.queryParameters['store_id'], '7');
    });

    test('sends the tenant and bearer headers', () async {
      final provider = InvoiceProvider();
      late Map<String, String> headers;

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":0}}',
            onRequest: (request) => headers = request.headers),
      );

      expect(headers['Authorization'], 'Bearer token');
      expect(headers['X-Tenant'], 'test-tenant');
    });

    test('parses a total that arrives as a string', () async {
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":"7"}}'),
      );

      expect(ok, isTrue);
      expect(provider.failedZatcaCount, 7);
    });

    test('reports failure when the total is missing', () async {
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{}}'),
      );

      expect(ok, isFalse);
      expect(provider.failedZatcaCount, 0);
    });

    test('reports failure and keeps the last count on 401', () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'stale-token',
        client: jsonClient(401, '{"message":"Unauthenticated."}'),
      );

      expect(ok, isFalse,
          reason: 'caller must be able to retry rather than assume zero');
      expect(provider.failedZatcaCount, 14,
          reason: 'a failed refresh must not wipe a known count');
    });

    test('reports failure and keeps the last count when the request throws',
        () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":3}}'),
      );

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) async => throw const _NetworkFailure()),
      );

      expect(ok, isFalse);
      expect(provider.failedZatcaCount, 3);
    });

    test('reports failure when the tenant key is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      expect(ok, isFalse);
      expect(provider.failedZatcaCount, 0);
    });

    test('does not request a tenant-wide count without an active store',
        () async {
      SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'});
      final provider = InvoiceProvider();
      var called = false;

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":0}}',
            onRequest: (_) => called = true),
      );

      expect(ok, isFalse);
      expect(called, isFalse);
      expect(provider.failedZatcaCount, 0);
    });
  });

  group('session scoping', () {
    test('drops a count belonging to another tenant', () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token-a',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );
      expect(provider.failedZatcaCount, 14);

      // Signing into a different tenant. The provider is app-scoped and
      // survives logout, so the previous count must not carry over — even
      // though a failed refresh normally keeps the last value.
      SharedPreferences.setMockInitialValues({
        'api_key': 'other-tenant',
        'active_store_id': 7,
      });

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token-b',
        client: MockClient((_) async => throw const _NetworkFailure()),
      );

      expect(ok, isFalse);
      expect(provider.failedZatcaCount, 0,
          reason: 'a count from another account must never be displayed');
    });

    test('publishes the cleared count before the request completes', () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token-a',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      SharedPreferences.setMockInitialValues({
        'api_key': 'other-tenant',
        'active_store_id': 7,
      });

      int? countWhenNotified;
      void listener() => countWhenNotified ??= provider.failedZatcaCount;
      provider.addListener(listener);

      await provider.fetchFailedZatcaCount(
        accessToken: 'token-b',
        client: jsonClient(200, '{"data":{"total":2}}'),
      );
      provider.removeListener(listener);

      expect(countWhenNotified, 0,
          reason: 'the first notification after a scope change must already '
              'show the cleared count, not the one from the previous account');
    });

    test('drops a count belonging to another store', () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      SharedPreferences.setMockInitialValues({
        'api_key': 'test-tenant',
        'active_store_id': 99,
      });

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) async => throw const _NetworkFailure()),
      );

      expect(provider.failedZatcaCount, 0);
    });

    test('discards a response whose scope changed mid-flight', () async {
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) async {
          // The user switches store while the request is in flight.
          SharedPreferences.setMockInitialValues({
            'api_key': 'test-tenant',
            'active_store_id': 99,
          });
          return http.Response('{"data":{"total":14}}', 200);
        }),
      );

      expect(ok, isFalse);
      expect(provider.failedZatcaCount, 0,
          reason: 'a stale response must not overwrite the new scope');
    });

    test('keeps the count across repeated fetches in the same scope', () async {
      final provider = InvoiceProvider();

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":14}}'),
      );

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) async => throw const _NetworkFailure()),
      );

      expect(provider.failedZatcaCount, 14,
          reason: 'same tenant and store, so a blip keeps the known count');
    });

    test('does not let an older overlapping request overwrite a newer count',
        () async {
      final provider = InvoiceProvider();
      final oldStarted = Completer<void>();
      final newStarted = Completer<void>();
      final oldResponse = Completer<http.Response>();
      final newResponse = Completer<http.Response>();

      final oldRequest = provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) {
          oldStarted.complete();
          return oldResponse.future;
        }),
      );
      await oldStarted.future;

      final newRequest = provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: MockClient((_) {
          newStarted.complete();
          return newResponse.future;
        }),
      );
      await newStarted.future;

      newResponse.complete(http.Response('{"data":{"total":7}}', 200));
      expect(await newRequest, isTrue);
      expect(provider.failedZatcaCount, 7);

      oldResponse.complete(http.Response('{"data":{"total":99}}', 200));
      expect(await oldRequest, isFalse);
      expect(provider.failedZatcaCount, 7);
    });
  });

  test('clears stale invoices when a filtered request fails', () async {
    final provider = InvoiceProvider();
    const successfulResponse = '''
      {"status":"success","message":"ok","data":{
        "current_page":1,"data":[{
          "id":1,"customer_id":1,"invoice_number":"INV-1",
          "type":"sale","company_id":1,"amount":"10.00",
          "invoice_date":"2026-09-07","due_date":"2026-09-07",
          "status":"paid","created_by":1,
          "created_at":"2026-09-07T00:00:00Z",
          "updated_at":"2026-09-07T00:00:00Z",
          "customer":{"id":1,"user_id":1,
            "user":{"id":1,"name":"Customer","email":"","phone":""}}
        }],"first_page_url":"","last_page_url":"",
        "last_page":1,"total":1,"per_page":20}}
    ''';

    await provider.listAllInvoices(
      accessToken: 'token',
      client: jsonClient(200, successfulResponse),
    );
    expect(provider.invoiceListDetails, hasLength(1));

    final result = await provider.listAllInvoices(
      accessToken: 'token',
      zatcaStatus: InvoiceProvider.zatcaFailedFilterValue,
      client: jsonClient(500, '{"message":"server error"}'),
    );

    expect(result, containsPair('status', 'error'));
    expect(provider.invoiceListDetails, isEmpty);
    expect(provider.filteredInvoices, isEmpty);
  });

  group('pending ZATCA status filter', () {
    test('is handed over once and then cleared', () {
      final provider = InvoiceProvider();

      expect(provider.consumePendingZatcaStatusFilter(), isNull);

      provider.requestZatcaStatusFilter(InvoiceProvider.zatcaFailedFilterValue);

      expect(provider.consumePendingZatcaStatusFilter(),
          InvoiceProvider.zatcaFailedFilterValue);
      expect(provider.consumePendingZatcaStatusFilter(), isNull,
          reason: 'the filter must not re-apply on a later normal visit');
    });
  });
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}
