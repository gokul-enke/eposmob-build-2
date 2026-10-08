import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/quotations/data/quotation_list_repository.dart';
import 'package:pos_machine/features/quotations/domain/quotation_list_query.dart';

class SimpleSession extends TenantSession {
  int store = 2;
  @override
  Future<String?> apiKey() async => 'tenant';
  @override
  Future<int?> activeStoreId() async => store;
}

/// Exact metadata shape returned by the running app's quotation endpoint.
Map<String, Object?> simple(int page, {int pages = 3, int size = 15}) {
  final length = page < pages ? size : 2;
  return {
    'status': 'success',
    'message': 'Quotations fetched successfully',
    'data': {
      'current_page': page,
      'data': List.generate(
          length,
          (i) => {
                'id': (page - 1) * size + i + 1,
                'quotation_number': 'QTN-${(page - 1) * size + i + 1}'
              }),
      'first_page_url': 'https://example.com/api/v1/quotations?page=1',
      'from': (page - 1) * size + 1,
      'next_page_url': page < pages
          ? 'https://example.com/api/v1/quotations?page=${page + 1}'
          : null,
      'path': 'https://example.com/api/v1/quotations',
      'per_page': size,
      'prev_page_url': page > 1
          ? 'https://example.com/api/v1/quotations?page=${page - 1}'
          : null,
      'to': (page - 1) * size + length,
    }
  };
}

void main() {
  test(
      'simple-paginator exposes next pages and exports beyond the first 15 rows',
      () async {
    final seen = <Map<String, String>>[];
    final progress = <int>[];
    final session = SimpleSession();
    final repository = QuotationListRepository(
        session: session,
        get: (uri, {headers}) async {
          seen.add(uri.queryParameters);
          session.store = 99;
          return http.Response(
              jsonEncode(simple(int.parse(uri.queryParameters['page']!))), 200);
        });
    const query = QuotationListQuery(storeId: 2, number: 'QTN');
    final first = await repository.fetch('token', query, 1);
    expect(first.rows, hasLength(15));
    expect(first.totalPagesKnown, isFalse);
    expect(first.hasNext, isTrue);
    final second = await repository.fetch('token', query, 2);
    expect(second.current, 2);
    expect(second.hasNext, isTrue);
    expect((await repository.fetch('token', query, 3)).hasNext, isFalse);
    seen.clear();
    final rows = await repository.snapshot('token', query,
        progress: (page, _) => progress.add(page));
    expect(rows, hasLength(32));
    expect(rows.map((q) => q.id), List.generate(32, (i) => i + 1));
    expect(progress, [1, 2, 3]);
    expect(seen.map((q) => q['page']), ['1', '2', '3']);
    expect(
        seen.every(
            (q) => q['store_id'] == '2' && q['quotation_number'] == 'QTN'),
        isTrue);
  });
  test('exact empty 500 envelope becomes zero-result page and empty export',
      () async {
    final repository = QuotationListRepository(
        session: SimpleSession(),
        get: (_, {headers}) async => http.Response(
            '{"status":"failed","message":"No quotations found","data":[]}',
            500));
    final result = await repository.fetch(
        'token', const QuotationListQuery(storeId: 32), 1);
    expect(result.rows, isEmpty);
    expect(result.total, 0);
    expect(result.hasNext, isFalse);
    expect(
        await repository.snapshot(
            'token', const QuotationListQuery(storeId: 32)),
        isEmpty);
  });
  for (final body in [
    '{"status":"failed","message":"Server error","data":[]}',
    '{"status":"failed","message":"No quotations found","data":null}',
    '{"status":"failed","message":"No quotations found","data":[{"id":1}]}',
    '<html>Server error</html>',
  ]) {
    test('ordinary 500 remains an error: $body', () async {
      final repository = QuotationListRepository(
          session: SimpleSession(),
          get: (_, {headers}) async => http.Response(body, 500));
      await expectLater(
          repository.fetch('token', const QuotationListQuery(), 1),
          throwsA(isA<Exception>()));
    });
  }
  for (final failure in [
    'duplicate',
    'empty',
    'http',
    'page-size',
    'next-link'
  ]) {
    test('simple-paginator export rejects $failure instead of truncating',
        () async {
      final repository = QuotationListRepository(
          session: SimpleSession(),
          get: (uri, {headers}) async {
            final page = int.parse(uri.queryParameters['page']!);
            if (page == 2 && failure == 'http') {
              return http.Response('offline', 500);
            }
            final result = simple(page);
            final wrapper = result['data'] as Map<String, Object?>;
            if (page == 2) {
              switch (failure) {
                case 'duplicate':
                  (wrapper['data'] as List).first['id'] = 1;
                case 'empty':
                  wrapper['data'] = [];
                case 'page-size':
                  wrapper['per_page'] = 7;
                case 'next-link':
                  wrapper['next_page_url'] =
                      'https://example.com/api/v1/quotations?page=2';
              }
            }
            return http.Response(jsonEncode(result), 200);
          });
      await expectLater(
          repository.snapshot('token', const QuotationListQuery()),
          throwsA(anything));
    });
  }
  test(
      'simple-paginator bound permits exact limit and never requests page 1001',
      () async {
    var pages = QuotationListRepository.maximumExportPages;
    var requests = 0;
    final repository = QuotationListRepository(
        session: SimpleSession(),
        get: (uri, {headers}) async {
          requests++;
          return http.Response(
              jsonEncode(simple(int.parse(uri.queryParameters['page']!),
                  pages: pages, size: 2)),
              200);
        });
    expect(await repository.snapshot('token', const QuotationListQuery()),
        hasLength(pages * 2));
    expect(requests, pages);
    pages++;
    requests = 0;
    await expectLater(repository.snapshot('token', const QuotationListQuery()),
        throwsStateError);
    expect(requests, QuotationListRepository.maximumExportPages);
  });
}
