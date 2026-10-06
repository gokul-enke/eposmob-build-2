import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/supplier_report_source.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';
import 'package:pos_machine/features/suppliers/data/supplier_api.dart';
import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import '../../../test_support/network_fakes.dart';

void main() {
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
