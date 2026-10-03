import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/reports/domain/my_sales_report.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/reports/support/report_fixtures.dart';

/// `SalesExecutiveProvider.getSalesExecutiveReport` as My Sales Report uses
/// it (`updateState: false`).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'test', 'active_store_id': 7}));

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('test', 1))
        ],
        child: MaterialApp(home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }))));
    return context;
  }

  testWidgets('keeps shared state, sends the date contract and the saved store',
      (tester) async {
    final provider = SalesExecutiveProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);
    final context = await pumpContext(tester);
    final requests = <http.Request>[];
    await tester.runAsync(() => http.runWithClient(() async {
          await provider.getSalesExecutiveReport(
              context: context, updateState: false);
          await provider.getSalesExecutiveReport(
              context: context,
              fromDate: '2026-09-01 10:00:00',
              updateState: false);
        },
            () => MockClient((request) async {
                  requests.add(request);
                  return http.Response(jsonEncode(salesReport()), 200);
                })));
    expect(requests, hasLength(2));
    expect(requests[0].url.queryParameters['dateFilter'], 'today');
    expect(requests[1].url.queryParameters['dateFilter'], 'custom');
    expect(requests[1].url.queryParameters['dateFrom'], '2026-09-01 10:00:00');
    expect(requests[0].url.queryParameters['store_id'], '7');
    expect(requests[0].headers['X-Tenant'], 'test');
    expect(provider.salesExecutiveReportList, isEmpty);
    expect(notifications, 0);
  });

  testWidgets('an HTTP failure is never accepted as a report', (tester) async {
    final provider = SalesExecutiveProvider();
    final context = await pumpContext(tester);
    final result = await tester.runAsync(() => http.runWithClient(
        () => provider.getSalesExecutiveReport(
            context: context, updateState: false),
        () => MockClient(
            (_) async => http.Response(jsonEncode(salesReport()), 500))));
    expect(result['status'], 'error');
    expect(() => parseMySalesReport(result), throwsFormatException);
    expect(provider.reportError, isNull);
  });
}
