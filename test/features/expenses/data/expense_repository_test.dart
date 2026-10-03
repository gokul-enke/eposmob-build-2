import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/data/expense_api.dart';
import 'package:pos_machine/features/expenses/data/expense_repository.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import '../../../test_support/network_fakes.dart';
import '../support/expense_fixtures.dart';

void main() {
  test(
      'successful provider creation makes exactly one refresh and retains active filters',
      () async {
    var gets = 0;
    var posts = 0;
    final api = ExpenseApi(
        session: const FakeTenantSession(),
        httpGet: (_, {headers}) async {
          gets++;
          return jsonResponse({
            'data': [row(1)]
          });
        },
        httpPost: (_, {headers, body}) async {
          posts++;
          return jsonResponse({'message': 'created'}, 201);
        });
    final provider = ExpenseProvider(repository: ExpenseRepository(api: api));
    provider.setReference('0001');
    expect(
        (await provider.createGeneralPayment(
            accessToken: 't', payload: {'entry_type': 'EXPENSE'}))['status'],
        'success');
    expect(gets, 1);
    expect(posts, 1);
    expect(provider.filterReference, '0001');
    expect(provider.allFiltered.length, 1);
    provider.dispose();
  });
  test('failed creation does not refresh or clear existing rows', () async {
    var gets = 0;
    final provider = ExpenseProvider(
        repository: ExpenseRepository(
            api: ExpenseApi(
                session: const FakeTenantSession(),
                httpGet: (_, {headers}) async {
                  gets++;
                  return jsonResponse({'data': []});
                },
                httpPost: (_, {headers, body}) async =>
                    jsonResponse({'message': 'failed'}, 422))));
    expect(
        (await provider
            .createGeneralPayment(accessToken: 't', payload: {}))['status'],
        'error');
    expect(gets, 0);
    provider.dispose();
  });
}
