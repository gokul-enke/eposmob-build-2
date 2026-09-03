/// Coverage for InvoiceProvider.fetchFailedZatcaCount, which backs the
/// dashboard "Failed Zatca Invoice" alert.
///
/// The alert is a compliance warning, so the paths that matter most are the
/// ones where the request does not succeed: those must leave the previously
/// known count untouched and report failure, so the caller can retry rather
/// than silently showing "no failures".
library;

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

  MockClient jsonClient(int status, String body, {void Function(http.Request)? onRequest}) {
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

    test('treats a missing total as zero rather than throwing', () async {
      final provider = InvoiceProvider();

      final ok = await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{}}'),
      );

      expect(ok, isTrue);
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

    test('omits store_id when no active store is set', () async {
      SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'});
      final provider = InvoiceProvider();
      late Uri captured;

      await provider.fetchFailedZatcaCount(
        accessToken: 'token',
        client: jsonClient(200, '{"data":{"total":0}}',
            onRequest: (request) => captured = request.url),
      );

      expect(captured.queryParameters.containsKey('store_id'), isFalse);
    });
  });

  group('pending ZATCA status filter', () {
    test('is handed over once and then cleared', () {
      final provider = InvoiceProvider();

      expect(provider.consumePendingZatcaStatusFilter(), isNull);

      provider.requestZatcaStatusFilter(
          InvoiceProvider.zatcaFailedFilterValue);

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
