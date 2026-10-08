import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/quotations/data/quotation_list_repository.dart';
import 'package:pos_machine/features/quotations/domain/quotation_list_query.dart';

class TestSession extends TenantSession {
  int store = 4, reads = 0;
  @override
  Future<String?> apiKey() async {
    reads++;
    return 'tenant';
  }

  @override
  Future<int?> activeStoreId() async => store;
}

Map<String, Object?> envelope(int page,
        {int last = 2,
        int total = 2,
        int? id,
        int? from,
        bool success = true}) =>
    {
      'success': success,
      'data': {
        'current_page': page,
        'last_page': last,
        'from': from ?? page,
        'total': total,
        'per_page': 1,
        'data': [
          {
            'id': id ?? page,
            'quotation_number': 'QTN-000$page',
            'customer': {'id': 8, 'name': 'Buyer', 'phone': '00123'},
            'store': 'Main',
            'status': 'pending'
          }
        ]
      }
    };

void main() {
  test(
      'all existing parameters, exact dates, status case, tenant and fallback store',
      () async {
    final session = TestSession();
    final seen = <Uri>[];
    final repository = QuotationListRepository(
        session: session,
        get: (uri, {headers}) async {
          seen.add(uri);
          expect(headers, {
            'Authorization': 'Bearer token',
            'Content-Type': 'application/json',
            'X-Tenant': 'tenant'
          });
          return http.Response(jsonEncode(envelope(1)), 200);
        });
    final query = QuotationListQuery(
        number: 'QTN-001',
        customerId: '8',
        status: 'Pending',
        quotationDate: DateTime(2026, 9, 28),
        expiryDate: DateTime(2026, 10, 28));
    final result = await repository.fetch('token', query, 1);
    expect(seen.single.queryParameters, {
      'store_id': '4',
      'quotation_number': 'QTN-001',
      'customer_id': '8',
      'status': 'Pending',
      'quotation_date_from': '2026-09-28',
      'quotation_date_to': '2026-09-28',
      'expiry_date_from': '2026-10-28',
      'expiry_date_to': '2026-10-28',
      'page': '1'
    });
    expect(result.rows.single.customer, 'Buyer');
    await repository.fetch('token', const QuotationListQuery(storeId: 9), 1);
    expect(seen.last.queryParameters, {'store_id': '9', 'page': '1'});
  });
  test(
      'all-page export freezes scope and filter values without shared provider mutation',
      () async {
    final session = TestSession();
    final seen = <Map<String, String>>[];
    final progress = <int>[];
    final repository = QuotationListRepository(
        session: session,
        get: (uri, {headers}) async {
          seen.add(uri.queryParameters);
          session.store = 99;
          return http.Response(
              jsonEncode(envelope(int.parse(uri.queryParameters['page']!))),
              200);
        });
    final rows = await repository.snapshot(
        'token', const QuotationListQuery(number: 'QTN'),
        progress: (page, last) => progress.add(page));
    expect(rows.map((row) => row.id), [1, 2]);
    expect(
        seen.every(
            (q) => q['store_id'] == '4' && q['quotation_number'] == 'QTN'),
        isTrue);
    expect(session.reads, 1);
    expect(progress, [1, 2]);
    expect(() => rows.clear(), throwsUnsupportedError);
  });
  for (final failure in [
    'duplicate',
    'missing-id',
    'changed-total',
    'changed-last',
    'wrong-page',
    'offset',
    'http',
    'empty',
    'incomplete'
  ]) {
    test('export rejects $failure on a later page', () async {
      final repository = QuotationListRepository(
          session: TestSession(),
          get: (uri, {headers}) async {
            final page = int.parse(uri.queryParameters['page']!);
            if (page == 2 && failure == 'http') {
              return http.Response('offline', 503);
            }
            final data = envelope(page);
            final wrapper = data['data'] as Map<String, Object?>;
            if (page == 2) {
              switch (failure) {
                case 'duplicate':
                  (wrapper['data'] as List).first['id'] = 1;
                case 'missing-id':
                  (wrapper['data'] as List).first['id'] = null;
                case 'changed-total':
                  wrapper['total'] = 3;
                case 'changed-last':
                  wrapper['last_page'] = 3;
                case 'wrong-page':
                  wrapper['current_page'] = 1;
                case 'offset':
                  wrapper['from'] = 1;
                case 'empty':
                  wrapper['data'] = [];
                case 'incomplete':
                  (data['data'] as Map)['total'] = 3;
              }
            }
            if (failure == 'incomplete') wrapper['total'] = 3;
            return http.Response(jsonEncode(data), 200);
          });
      await expectLater(
          repository.snapshot('token', const QuotationListQuery()),
          throwsA(anything));
    });
  }
  test(
      'exact export page limit succeeds; larger declared exports stop on page one',
      () async {
    var requests = 0;
    var last = QuotationListRepository.maximumExportPages;
    final repository = QuotationListRepository(
        session: TestSession(),
        get: (uri, {headers}) async {
          requests++;
          return http.Response(
              jsonEncode(envelope(int.parse(uri.queryParameters['page']!),
                  last: last, total: last)),
              200);
        });
    expect(await repository.snapshot('token', const QuotationListQuery()),
        hasLength(last));
    expect(requests, last);
    requests = 0;
    last++;
    await expectLater(repository.snapshot('token', const QuotationListQuery()),
        throwsStateError);
    expect(requests, 1);
  });
  for (final body in [
    '{}',
    '{"success":false,"data":{"data":[]}}',
    '{"success":true,"data":{}}',
    'invalid'
  ]) {
    test('malformed or failed envelope is an error: $body', () async {
      final repository = QuotationListRepository(
          session: TestSession(),
          get: (_, {headers}) async => http.Response(body, 200));
      await expectLater(
          repository.fetch('token', const QuotationListQuery(), 1),
          throwsA(anything));
    });
  }
  test('valid empty success and legacy unpaginated single page are accepted',
      () async {
    final repository = QuotationListRepository(
        session: TestSession(),
        get: (_, {headers}) async =>
            http.Response('{"status":"success","data":{"data":[]}}', 200));
    expect(
        (await repository.fetch('token', const QuotationListQuery(), 1)).rows,
        isEmpty);
    expect(await repository.snapshot('token', const QuotationListQuery()),
        isEmpty);
  });
}
