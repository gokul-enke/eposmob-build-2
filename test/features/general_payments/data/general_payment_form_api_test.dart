import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/general_payments/data/general_payment_form_api.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_entry.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import '../../../test_support/network_fakes.dart';

const _accounts = 'https://x.test/api/v1/general-payment/account-options';
const _create = 'https://x.test/api/v1/general-payment/create-general-payment';

/// The live account-options answer for [type] (and loan direction).
Map<String, dynamic> accountOptions(String type, {String? loan}) => {
      'success': true,
      'data': {
        'entry_type': type,
        'loan_type': loan,
        'expense_accounts': loan == 'LOAN_REPAY'
            ? [
                {'id': 376, 'name': 'Loan Account'}
              ]
            : [
                {'id': 11, 'name': 'Cash Account'},
                {'id': 12, 'name': 'Bank Account'},
                {'id': 12, 'name': 'Bank Account again'},
                {'id': null, 'name': 'No id'},
              ],
        'payment_accounts': [
          {'id': 376, 'name': 'Loan Account'},
          {'name': 'No id'},
        ],
      },
    };

void main() {
  (GeneralPaymentFormApi, List<Uri>, List<Object?>) apiOf(
      {Object Function(Uri)? get,
      http.Response Function(Object? body)? post,
      FakeTenantSession session = const FakeTenantSession(storeId: 2)}) {
    final requests = <Uri>[], bodies = <Object?>[];
    return (
      GeneralPaymentFormApi(
          accountsEndpoint: () => _accounts,
          createEndpoint: () => _create,
          session: session,
          get: (url, {headers}) async {
            requests.add(url);
            expect(headers?['Authorization'], 'Bearer token');
            expect(headers?['X-Tenant'], 'tenant');
            final answer = get!(url);
            return answer is http.Response ? answer : jsonResponse(answer);
          },
          post: (url, {headers, body}) async {
            requests.add(url);
            expect(headers?['Accept'], 'application/json');
            expect(headers?['Content-Type'], 'application/json');
            bodies.add(jsonDecode(body as String));
            return post!(body);
          }),
      requests,
      bodies
    );
  }

  test('asks for the accounts of the entry type and loan direction', () async {
    final (api, requests, _) = apiOf(
        get: (url) => accountOptions(url.queryParameters['entry_type']!,
            loan: url.queryParameters['loan_type']));
    final loanIn = await api.accountOptions(
        accessToken: 'token', type: GeneralPaymentType.loan);
    expect(requests.last.queryParameters,
        {'entry_type': 'LOAN', 'loan_type': 'LOAN_IN'});
    expect(loanIn.debit, const [
      GeneralPaymentOption('11', 'Cash Account'),
      GeneralPaymentOption('12', 'Bank Account'),
    ]);
    expect(loanIn.credit, const [GeneralPaymentOption('376', 'Loan Account')]);
    final repay = await api.accountOptions(
        accessToken: 'token',
        type: GeneralPaymentType.loan,
        loan: GeneralPaymentLoan.repaid);
    expect(requests.last.queryParameters['loan_type'], 'LOAN_REPAY');
    expect(repay.debit.single.label, 'Loan Account');
    await api.accountOptions(
        accessToken: 'token',
        type: GeneralPaymentType.asset,
        loan: GeneralPaymentLoan.repaid);
    expect(requests.last.queryParameters, {'entry_type': 'ASSET'});
  });

  for (final (name, answer) in [
    ('accounts for another type', accountOptions('EXPENSE')),
    (
      'accounts for the other loan direction',
      accountOptions('LOAN', loan: 'LOAN_REPAY')
    ),
    ('a failed answer', {'success': false, 'data': {}}),
    ('an answer without data', {'success': true}),
  ]) {
    test('refuses $name', () async {
      final (api, _, _) = apiOf(get: (_) => answer);
      await expectLater(
          api.accountOptions(
              accessToken: 'token', type: GeneralPaymentType.loan),
          throwsFormatException);
    });
  }

  test('a server error when loading accounts throws', () async {
    final (api, _, _) = apiOf(get: (_) => http.Response('down', 500));
    await expectLater(
        api.accountOptions(
            accessToken: 'token', type: GeneralPaymentType.asset),
        throwsStateError);
  });

  test('saving posts the entry for the active store', () async {
    final (api, requests, bodies) = apiOf(
        post: (_) => jsonResponse({
              'success': true,
              'data': {'id': 190, 'reference_number': 'INC00008'}
            }, 201));
    final result = await api.create(
        accessToken: 'token',
        payload: {'entry_type': 'INCOME', 'amount': 5.0, 'store_id': 99});
    expect(requests.single.toString(), _create);
    expect(
        bodies.single, {'entry_type': 'INCOME', 'amount': 5.0, 'store_id': 2});
    expect(result, isA<GeneralPaymentSaved>());
    expect((result as GeneralPaymentSaved).reference, 'INC00008');
  });

  test('a save without a reference in the answer still counts', () async {
    final (api, _, _) =
        apiOf(post: (_) => jsonResponse({'message': 'Created'}));
    final result = await api.create(accessToken: 't', payload: const {});
    expect((result as GeneralPaymentSaved).reference, isNull);
  });

  for (final (name, response, message) in [
    (
      'a validation error gives its first field message',
      jsonResponse({
        'message': 'The given data was invalid.',
        'errors': {
          'amount': ['The amount must be at least 1.'],
          'category': ['Required']
        }
      }, 422),
      'The amount must be at least 1.'
    ),
    (
      'a refusal gives its message',
      jsonResponse({'success': false, 'message': 'Period is closed'}),
      'Period is closed'
    ),
    (
      'a page instead of JSON gives no message',
      http.Response('<html>', 500),
      null
    ),
  ]) {
    test(name, () async {
      final (api, _, _) = apiOf(post: (_) => response);
      final result = await api.create(accessToken: 't', payload: const {});
      expect(result, isA<GeneralPaymentRejected>());
      expect((result as GeneralPaymentRejected).message, message);
    });
  }

  test('a missing tenant sends nothing', () async {
    final (api, requests, _) =
        apiOf(session: const FakeTenantSession(key: null));
    await expectLater(
        api.create(accessToken: 't', payload: const {}), throwsStateError);
    await expectLater(
        api.accountOptions(accessToken: 't', type: GeneralPaymentType.expense),
        throwsStateError);
    expect(requests, isEmpty);
  });
}
