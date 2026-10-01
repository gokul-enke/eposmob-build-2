import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'api_key': 'test'}));
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
              if (request.method == 'POST')
                return http.Response('{"data": {}}', 201);
              gets++;
              if (!started.isCompleted) started.complete();
              return gets == 1
                  ? await oldResponse.future
                  : http.Response(
                      jsonEncode({'status': 'success', 'data': []}), 200);
            }));
  });
  for (final scenario in ['page count changes', 'duplicate rows']) {
    test('export should reject $scenario', () async {
      final provider = TransactionProvider()..setAccessToken('test');
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
                      'last_page':
                          scenario == 'page count changes' && page == 2 ? 3 : 2,
                      'total':
                          scenario == 'page count changes' && page == 2 ? 3 : 2,
                      'data': [
                        {'id': scenario == 'duplicate rows' ? 1 : page}
                      ],
                    },
                  }),
                  200);
            }),
          ),
          throwsFormatException);
    });
  }
}
