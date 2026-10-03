import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';

Map<String, Object?> _voucher(int id) => {
      'id': id,
      'voucher_number': '000$id',
      'voucher_date': '2026-10-01',
      'due_date': '2026-11-01',
      'amount': '126.125',
      'type': id <= 25 ? 'order' : 'refund',
      'status': id <= 25 ? 'paid' : 'pending',
      'payment_method': 'cash',
      'supplier': {
        'id': id <= 25 ? 7 : 8,
        'user': {'name': id <= 25 ? 'Test Supplier' : 'Other Supplier'}
      },
    };

class _Provider extends SupplierVoucherProvider {
  int requests = 0;
  bool failSecond = false;
  bool onlyOtherSupplier = false;
  @override
  Future<void> listAllSupplierVouchers({required String accessToken}) =>
      http.runWithClient(
          () => super.listAllSupplierVouchers(accessToken: accessToken),
          () => MockClient((request) async {
                requests++;
                final page = int.parse(request.url.queryParameters['page']!);
                if (failSecond && page == 2) {
                  return http.Response('failed', 500);
                }
                if (onlyOtherSupplier) {
                  return http.Response(
                      jsonEncode({
                        'status': 'success',
                        'data': {
                          'current_page': 1,
                          'last_page': 1,
                          'data': [for (int i = 26; i <= 30; i++) _voucher(i)]
                        }
                      }),
                      200);
                }
                return http.Response(
                    jsonEncode({
                      'status': 'success',
                      'data': {
                        'current_page': page,
                        'last_page': 2,
                        'data': [
                          for (int i = page == 1 ? 1 : 21;
                              i <= (page == 1 ? 20 : 30);
                              i++)
                            _voucher(i)
                        ]
                      }
                    }),
                    200);
              }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'test'}));

  test('all four filters and pagination use the same full cached export rows',
      () async {
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers.length, 30);
    expect(provider.voucherListDetails!.length, 20);
    provider.applyFilters(
        supplierId: 7, type: 'order', status: 'paid', voucherNumber: '000');
    expect(provider.filteredVouchers.length, 25);
    provider.goToPage(2);
    expect(provider.voucherListDetails!.length, 5);
    expect(provider.filteredVouchers.length, 25);
    expect(provider.requests, 2);
    provider.resetFilters();
    expect(provider.filteredVouchers.length, 30);
    expect(provider.currentPage, 1);
    expect(() => provider.filteredVouchers.clear(), throwsUnsupportedError);
  });
  test('refresh retains filters and failed later pages clear export rows',
      () async {
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    provider.applyFilters(type: 'refund');
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers.length, 5);
    provider.failSecond = true;
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers, isEmpty);
    expect(provider.voucherListDetails, isEmpty);
    expect(provider.loadError, isA<HttpException>());
    expect(provider.isLoading, isFalse);
  });
  test('missing tenant releases loading and exposes the load error', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.requests, 0);
    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNotNull);
  });

  test('overlapping refreshes share a single request and loading lifetime',
      () async {
    final provider = SupplierVoucherProvider();
    final started = Completer<void>();
    final response = Completer<http.Response>();
    int requests = 0;
    await http.runWithClient(() async {
      final first = provider.listAllSupplierVouchers(accessToken: 'test');
      await started.future;
      final second = provider.listAllSupplierVouchers(accessToken: 'test');
      expect(identical(first, second), isTrue);
      expect(provider.isLoading, isTrue);
      expect(requests, 1);
      response.complete(http.Response(
          jsonEncode({
            'status': 'success',
            'data': [_voucher(1)]
          }),
          200));
      await Future.wait([first, second]);
      expect(provider.isLoading, isFalse);
      expect(provider.filteredVouchers.length, 1);
      await provider.listAllSupplierVouchers(accessToken: 'test');
      expect(requests, 2);
    },
        () => MockClient((_) {
              requests++;
              if (!started.isCompleted) started.complete();
              return response.future;
            }));
  });

  for (final entry in <String, Object?>{
    'failed response status': {
      'status': 'failed',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': [_voucher(21)]
      }
    },
    'missing data': {'status': 'success'},
    'empty later page': {
      'status': 'success',
      'data': {'current_page': 2, 'last_page': 2, 'data': []}
    },
    'wrong page number': {
      'status': 'success',
      'data': {
        'current_page': 1,
        'last_page': 2,
        'data': [_voucher(21)]
      }
    },
    'changed page count': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 3,
        'data': [_voucher(21)]
      }
    },
    'invalid row': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': ['bad']
      }
    },
    'duplicate voucher': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': [_voucher(1)]
      }
    },
  }.entries) {
    test(
        'rejects HTTP 200 with ${entry.key} instead of exposing partial export',
        () async {
      final provider = SupplierVoucherProvider();
      await http.runWithClient(
          () => provider.listAllSupplierVouchers(accessToken: 'test'),
          () => MockClient((request) async => http.Response(
              jsonEncode(request.url.queryParameters['page'] == '1'
                  ? {
                      'status': 'success',
                      'data': {
                        'current_page': 1,
                        'last_page': 2,
                        'data': [_voucher(1)]
                      }
                    }
                  : entry.value),
              200)));
      expect(provider.loadError, isA<FormatException>());
      expect(provider.filteredVouchers, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  }
  test('flat and paginated empty successful responses are valid', () async {
    for (final data in [
      [],
      {'current_page': 1, 'last_page': 1, 'data': []}
    ]) {
      final provider = SupplierVoucherProvider();
      await http.runWithClient(
          () => provider.listAllSupplierVouchers(accessToken: 'test'),
          () => MockClient((_) async => http.Response(
              jsonEncode({'status': 'success', 'data': data}), 200)));
      expect(provider.loadError, isNull);
      expect(provider.filteredVouchers, isEmpty);
    }
  });

  test('creation should fetch a fresh list after an earlier refresh', () async {
    final provider = SupplierVoucherProvider();
    final started = Completer<void>();
    final oldResponse = Completer<http.Response>();
    var gets = 0;
    await http.runWithClient(() async {
      final refresh = provider.listAllSupplierVouchers(accessToken: 'test');
      await started.future;
      final creation = provider.createVoucher(
          supplierId: 7,
          type: 'refund',
          amount: 10,
          voucherDate: '2026-10-01',
          dueDate: '2026-10-01',
          status: 'paid',
          paymentMethodId: 1,
          voucherItems: [],
          accessToken: 'test');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      oldResponse.complete(
          http.Response(jsonEncode({'status': 'success', 'data': []}), 200));
      await refresh;
      expect((await creation)['success'], true);
      expect(gets, 2,
          reason: 'the pre-creation response cannot include the new voucher');
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                return http.Response('{"data": {}}', 201);
              }
              gets++;
              if (!started.isCompleted) started.complete();
              return gets == 1
                  ? await oldResponse.future
                  : http.Response(
                      jsonEncode({'status': 'success', 'data': []}), 200);
            }));
  });
}
