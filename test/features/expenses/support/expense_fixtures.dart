import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';

Map<String, dynamic> row(int id) => {
      'reference_number': '000$id',
      'payment_date': '2026-10-01',
      'category_name': 'Rent',
      'expense_account_name': 'Office',
      'payment_account_name': 'Cash',
      'amount': 126.125,
      'status': 'SUCC',
      'payment_method_name': 'Cash',
      'description': 'Office rent',
      'notes': 'Paid',
    };
Map<String, dynamic> page(int current, {int last = 2, int total = 2}) => {
      'data': {
        'current_page': current,
        'last_page': last,
        'total': total,
        'data': [row(current)]
      }
    };
Future<void> load(ExpenseProvider provider,
        FutureOr<http.Response> Function(http.Request) handler) =>
    http.runWithClient(() => provider.fetchGeneralPayments(accessToken: 'test'),
        () => MockClient((request) async => await handler(request)));
http.Response response(Object body) => http.Response(jsonEncode(body), 200);
