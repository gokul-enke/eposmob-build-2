import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/suppliers/data/supplier_api.dart';
import 'package:pos_machine/features/suppliers/data/supplier_payloads.dart';

import '../../../test_support/network_fakes.dart';

void main() {
  group('fetchAll', () {
    test('sends name and store filters and parses suppliers', () async {
      Uri? requested;
      final api = SupplierApi(
        httpGet: (url, {headers}) async {
          requested = url;
          return jsonResponse({
            'status': 'success',
            'message': 'ok',
            'data': [
              {'id': 4, 'name': 'Acme', 'current_balance': '12.5'},
            ],
          });
        },
        session: const FakeTenantSession(storeId: 3),
      );

      final suppliers = await api.fetchAll('t', name: 'Ac');

      expect(
        requested!.queryParameters,
        {'supplier_name': 'Ac', 'store_id': '3'},
      );
      expect(suppliers!.single.currentBalance, 12.5);
    });

    test('non-200 returns null; a missing API key throws', () async {
      final refused = SupplierApi(
        httpGet: (url, {headers}) async => http.Response('nope', 500),
        session: const FakeTenantSession(),
      );
      expect(await refused.fetchAll('t'), isNull);

      final noKey = SupplierApi(session: const FakeTenantSession(key: null));
      await expectLater(noKey.fetchAll('t'), throwsA(isA<HttpException>()));
    });
  });

  test('transactions use the `type` key and skip empty filters', () async {
    Uri? requested;
    final api = SupplierApi(
      httpGet: (url, {headers}) async {
        requested = url;
        return jsonResponse({'status': 'success', 'data': []});
      },
      session: const FakeTenantSession(storeId: null),
    );
    await api.fetchTransactions(
      't',
      supplierId: '9',
      transactionType: 'credit',
      fromDate: '',
      page: 2,
    );
    expect(requested!.queryParameters, {
      'supplier_id': '9',
      'type': 'credit',
      'list_all': 'true',
      'page': '2',
    });
  });

  group('mutations', () {
    SupplierApi api(Future<http.Response> Function() respond) => SupplierApi(
          httpPost: (url, {headers, body}) => respond(),
          session: const FakeTenantSession(),
        );

    test('success returns the decoded body', () async {
      final result =
          await api(() async => jsonResponse({'status': 'success'}, 201))
              .create('t', const {});
      expect(result, {'status': 'success'});
    });

    test('update only accepts 200', () async {
      final result =
          await api(() async => jsonResponse({'status': 'success'}, 201))
              .update('t', const {});
      expect(result['status'], 'error');
    });

    test('server errors map message and data', () async {
      final result = await api(() async => jsonResponse({
            'message': 'Phone taken',
            'data': {
              'phone': ['taken'],
            },
          }, 422)).create('t', const {});
      expect(result, {
        'status': 'error',
        'message': 'Phone taken',
        'errors': {
          'phone': ['taken'],
        },
      });
    });

    test('non-JSON and network failures become error maps', () async {
      final html = await api(() async => http.Response('<html>', 502))
          .create('t', const {});
      expect(html['message'], contains('502'));
      final offline = await api(() async => throw const SocketException('x'))
          .create('t', const {});
      expect(offline['message'], startsWith('Network error'));
    });
  });

  test('payloads keep the server field names', () {
    expect(
      jsonDecode(jsonEncode(SupplierPayloads.create(
        name: 'A',
        email: 'e',
        phone: 'p',
        balance: '4.5',
        paymentStatus: 'to_pay',
        address: 'x',
        altPhone: '',
        taxNumber: ' T1 ',
      ))),
      {
        'name': 'A',
        'email': 'e',
        'phone': 'p',
        'balance': 4.5,
        'type': 1,
        'address': 'x',
        'alt_phone': '',
        'tax_number': 'T1',
        'payment_type': 'to_pay',
        'kyc': [],
      },
    );
    expect(
      SupplierPayloads.update(id: 2, name: 'A', phone: 'p', balance: 1),
      {'id': 2, 'name': 'A', 'phone': 'p', 'balance': 1.0},
    );
  });
}
