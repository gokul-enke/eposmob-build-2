import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/supplier_report_source.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';
import 'package:pos_machine/features/suppliers/data/supplier_api.dart';
import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/features/reports/presentation/state/supplier_transactions_report_controller.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../test_support/network_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real API export stops before page two if active store changes',
      () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'active_store_id': 1});
    final calls = <String>[];
    final source = SupplierReportSource(
        SupplierRepository(api: SupplierApi(httpGet: (url, {headers}) async {
      final store = url.queryParameters['store_id']!;
      calls.add(store);
      final page = int.parse(url.queryParameters['page']!);
      if (calls.length == 2) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('active_store_id', 2);
      }
      expect(headers!['Authorization'], 'Bearer token');
      expect(headers['X-Tenant'], 'tenant');
      return jsonResponse({
        'status': 'success',
        'data': {
          'current_page': page,
          'last_page': 2,
          'per_page': 1,
          'total': 2,
          'data': [
            {
              'supplier_id': page + 6,
              'supplier_name': 'Store $store supplier',
              'total_debit': 10,
              'total_credit': 1,
              'balance': -9,
              'transactions': [{}],
            }
          ],
        }
      });
    })));
    final controller = SupplierTransactionsReportController(
        fetchDirectory: () async => [],
        readScope: () => source.scope('token'),
        fetch: (query, page) => source.fetch('token', query, page));
    addTearDown(controller.dispose);
    await controller.load();
    await expectLater(controller.exportRows(), throwsStateError);
    expect(calls, ['1', '1']);
    expect(controller.rows['7']!.displayName, 'Store 1 supplier');
  });
  test('scope reader uses the repository session and current endpoint',
      () async {
    final source = SupplierReportSource(SupplierRepository(
        api: SupplierApi(
            session: const FakeTenantSession(key: 't', storeId: 4))));
    expect(await source.scope('token'), (
      token: 'token',
      tenant: 't',
      storeId: 4,
      endpoint: APPUrl.supplierTransactions,
    ));
  });
  test(
      'report source retains HTTP filters, paginator, token and tenant/store scope',
      () async {
    Uri? requested;
    Map<String, String>? sentHeaders;
    final source = SupplierReportSource(SupplierRepository(
        api: SupplierApi(
      session: const FakeTenantSession(key: 'tenant', storeId: 4),
      httpGet: (url, {headers}) async {
        requested = url;
        sentHeaders = headers;
        return jsonResponse({'data': []});
      },
    )));
    await source.fetch(
        'token',
        const SupplierReportQuery(
            supplierId: '7', fromDate: '2026-09-01', toDate: '2026-10-01'),
        2);
    expect(requested!.queryParameters, {
      'supplier_id': '7',
      'from_date': '2026-09-01',
      'to_date': '2026-10-01',
      'list_all': 'false',
      'page': '2',
      'store_id': '4'
    });
    expect(sentHeaders!['Authorization'], 'Bearer token');
    expect(sentHeaders!['X-Tenant'], 'tenant');
  });
  test(
      'directory maps every supplier to a local choice without filtering provider state',
      () async {
    final source = SupplierReportSource(SupplierRepository(
        api: SupplierApi(
      session: const FakeTenantSession(),
      httpGet: (url, {headers}) async => jsonResponse({
        'status': 'success',
        'data': [
          {'id': 7, 'name': 'Supplier'}
        ]
      }),
    )));
    final result = await source.directory('token');
    expect(result.single.id, '7');
    expect(result.single.name, 'Supplier');
  });
}
