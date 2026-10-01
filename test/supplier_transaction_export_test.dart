import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/transaction_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
      () => SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'}));

  test('export fetches all matching pages without changing the visible page',
      () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    final requests = <http.Request>[];
    var notifications = 0;
    provider.addListener(() => notifications++);
    final items = await http.runWithClient(
        () => provider.fetchTransactionsForExport(
              supplierId: '7',
              transactionType: 'Invoice',
              type: 'Credit',
            ),
        () => MockClient((request) async {
              requests.add(request);
              final page = int.parse(request.url.queryParameters['page']!);
              return http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': {
                      'current_page': page,
                      'last_page': 2,
                      'data': [
                        {
                          'id': page,
                          'supplier_id': 7,
                          'amount': '250.00',
                          'reference': 'INV-$page',
                          'supplier': {
                            'id': 7,
                            'user': {'name': 'Test Supplier'}
                          }
                        }
                      ],
                    }
                  }),
                  200);
            }));
    expect(items.map((tx) => tx.reference), ['INV-1', 'INV-2']);
    expect(items.map((tx) => tx.siNo), [1, 2]);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.url.queryParameters['supplier_id'], '7');
      expect(request.url.queryParameters['transaction_type'], 'Invoice');
      expect(request.url.queryParameters['type'], 'Credit');
      expect(request.url.queryParameters['per_page'], '50');
      expect(request.headers['X-Tenant'], 'test-tenant');
      expect(request.headers['Authorization'], 'Bearer test-token');
    }
    expect(provider.transactionCurrentPage, 1);
    expect(provider.listTransactionModelDataList, isEmpty);
    expect(provider.getSupplierOptions(), ['All Suppliers']);
    expect(provider.transactionIsLoading, isFalse);
    expect(notifications, 0);
  });

  test(
      'a failed later page rejects the export instead of returning partial data',
      () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    await expectLater(
        http.runWithClient(
            () => provider.fetchTransactionsForExport(),
            () => MockClient((request) async {
                  if (request.url.queryParameters['page'] == '2') {
                    return http.Response('{}', 403);
                  }
                  return http.Response(
                      jsonEncode({
                        'status': 'success',
                        'data': {
                          'current_page': 1,
                          'last_page': 2,
                          'data': [
                            {'id': 1}
                          ],
                        }
                      }),
                      200);
                })),
        throwsException);
  });

  test('an empty later page rejects an incomplete export', () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    await expectLater(
        http.runWithClient(
            () => provider.fetchTransactionsForExport(),
            () => MockClient((request) async {
                  final page = int.parse(request.url.queryParameters['page']!);
                  return http.Response(
                      jsonEncode({
                        'status': 'success',
                        'data': {
                          'current_page': page,
                          'last_page': 2,
                          'data': page == 1
                              ? [
                                  {'id': 1}
                                ]
                              : [],
                        }
                      }),
                      200);
                })),
        throwsFormatException);
  });

  test('missing pagination rejects the export', () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    await expectLater(
        http.runWithClient(
            () => provider.fetchTransactionsForExport(),
            () => MockClient((_) async => http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': {'data': []}
                }),
                200))),
        throwsFormatException);
  });

  test('Search and Status match across all pages and report page progress',
      () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    final progress = <List<int>>[];
    final result = await http.runWithClient(
        () => provider.fetchTransactionsForExport(
              search: 'find-me',
              status: 'FAIL',
              supplierName: 'target',
              onProgress: (page, total) => progress.add([page, total]),
            ),
        () => MockClient((request) async {
              expect(
                  request.url.queryParameters.containsKey('status'), isFalse);
              final page = int.parse(request.url.queryParameters['page']!);
              return http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': {
                      'current_page': page,
                      'last_page': 2,
                      'data': [
                        {
                          'id': page,
                          'reference': 'find-me',
                          'status': page == 1 ? 'SUCCESS' : 'FAIL',
                          'supplier': {
                            'user': {'name': 'Target Supplier'}
                          }
                        }
                      ],
                    }
                  }),
                  200);
            }));
    expect(result.map((tx) => tx.id), [2]);
    expect(progress, [
      [1, 2],
      [2, 2]
    ]);
  });
  for (final changedLastPage in [3, 1]) {
    test(
        'changed last_page $changedLastPage rejects export without mutating visible state',
        () async {
      final provider = TransactionProvider()..setAccessToken('test-token');
      final requestedPages = <int>[];
      final progress = <List<int>>[];
      var notifications = 0;
      provider.addListener(() => notifications++);
      await expectLater(
          http.runWithClient(
            () => provider.fetchTransactionsForExport(
                onProgress: (page, total) => progress.add([page, total])),
            () => MockClient((request) async {
              final page = int.parse(request.url.queryParameters['page']!);
              requestedPages.add(page);
              return http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': {
                      'current_page': page,
                      'last_page': page == 1 ? 2 : changedLastPage,
                      'data': [
                        {'id': page, 'reference': 'INV-$page'}
                      ],
                    }
                  }),
                  200);
            }),
          ),
          throwsFormatException);
      expect(requestedPages, [1, 2]);
      expect(progress, [
        [1, 2]
      ]);
      expect(provider.transactionCurrentPage, 1);
      expect(provider.listTransactionModelDataList, isEmpty);
      expect(provider.transactionIsLoading, isFalse);
      expect(notifications, 0);
    });
  }
  for (final duplicateIds in [
    <Object>[1, 1],
    <Object>[1, '1']
  ]) {
    for (final samePage in [true, false]) {
      test(
          'duplicate IDs $duplicateIds ${samePage ? 'within' : 'across'} pages reject export and preserve loaded state',
          () async {
        final provider = TransactionProvider()..setAccessToken('test-token');
        await http.runWithClient(
            () => provider.fetchTransactionsFromServerV2(page: 2),
            () => MockClient((_) async => http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': {
                    'current_page': 2,
                    'last_page': 3,
                    'data': [
                      {
                        'id': 99,
                        'reference': 'EXISTING',
                        'supplier': {
                          'id': 7,
                          'user': {'name': 'Existing Supplier'}
                        }
                      }
                    ]
                  }
                }),
                200)));
        final visible = provider.listTransactionModelDataList;
        final options = provider.getSupplierOptions();
        var notifications = 0;
        provider.addListener(() => notifications++);
        await expectLater(
            http.runWithClient(
                () => provider.fetchTransactionsForExport(
                    search: 'will-not-match'),
                () => MockClient((request) async {
                      final page =
                          int.parse(request.url.queryParameters['page']!);
                      final ids =
                          samePage ? duplicateIds : [duplicateIds[page - 1]];
                      return http.Response(
                          jsonEncode({
                            'status': 'success',
                            'data': {
                              'current_page': page,
                              'last_page': samePage ? 1 : 2,
                              'total': 2,
                              'data': [
                                for (final id in ids)
                                  {'id': id, 'reference': 'DUPLICATE'}
                              ]
                            }
                          }),
                          200);
                    })),
            throwsFormatException);
        expect(provider.listTransactionModelDataList, same(visible));
        expect(provider.listTransactionModelDataList!.single.reference,
            'EXISTING');
        expect(provider.transactionCurrentPage, 2);
        expect(provider.transactionTotalPages, 3);
        expect(provider.getSupplierOptions(), options);
        expect(provider.transactionIsLoading, false);
        expect(notifications, 0);
      });
    }
  }
  for (final id in [null, 0, -1, '', 'bad', 1.5, true]) {
    test('invalid ID $id rejects export', () async {
      final provider = TransactionProvider()..setAccessToken('test-token');
      await expectLater(
          http.runWithClient(
              () => provider.fetchTransactionsForExport(),
              () => MockClient((_) async => http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': {
                      'current_page': 1,
                      'last_page': 1,
                      'data': [
                        {'id': id}
                      ]
                    }
                  }),
                  200))),
          throwsFormatException);
    });
  }
  test(
      'unique numeric-string IDs with a repeated reference export successfully',
      () async {
    final provider = TransactionProvider()..setAccessToken('test-token');
    final rows = await http.runWithClient(
        () => provider.fetchTransactionsForExport(),
        () => MockClient((request) async {
              final page = int.parse(request.url.queryParameters['page']!);
              return http.Response(
                  jsonEncode({
                    'status': 'success',
                    'data': {
                      'current_page': page,
                      'last_page': 2,
                      'data': [
                        {'id': '$page', 'reference': 'SAME-INVOICE'}
                      ]
                    }
                  }),
                  200);
            }));
    expect(rows.map((row) => row.id), [1, 2]);
    expect(rows.map((row) => row.reference), ['SAME-INVOICE', 'SAME-INVOICE']);
  });
}
