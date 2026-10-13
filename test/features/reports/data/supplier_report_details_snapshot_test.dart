import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/reports/data/supplier_report_details_snapshot.dart';
import 'package:pos_machine/features/reports/data/supplier_report_details_source.dart';
import 'package:pos_machine/features/reports/domain/supplier_report_details_query.dart';
import 'package:pos_machine/features/suppliers/data/supplier_api.dart';
import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/resources/app_url.dart';
import '../../../test_support/network_fakes.dart';
import '../fixtures/supplier_report_details_fixture.dart';

const query = SupplierReportDetailsQuery(supplier: (id: '7', name: 'Supplier'));
void main() {
  test('View source retains endpoint, headers, supplier ID, dates and list_all',
      () async {
    Uri? url;
    Map<String, String>? requestHeaders;
    final source = SupplierReportDetailsSource(SupplierRepository(
        api: SupplierApi(
      session: const FakeTenantSession(storeId: 2),
      httpGet: (uri, {headers}) async {
        url = uri;
        requestHeaders = headers;
        return http.Response(jsonEncode(detailResponse()), 200);
      },
    )));
    await source.fetch(
        'token',
        const SupplierReportDetailsQuery(
            supplier: (id: '7', name: 'Supplier'),
            from: '2026-09-13',
            to: '2026-10-13'));
    expect(url!.path, Uri.parse(APPUrl.supplierTransactions).path);
    expect(url!.queryParameters, {
      'supplier_id': '7',
      'from_date': '2026-09-13',
      'to_date': '2026-10-13',
      'list_all': 'true',
      'store_id': '2'
    });
    expect(requestHeaders!['Authorization'], 'Bearer token');
    expect(requestHeaders!['X-Tenant'], isNotEmpty);
    await source.fetch('token', query, page: 2);
    expect(url!.queryParameters['page'], '2');
    expect(url!.queryParameters['type'], isNull); // Local Credit/Debit filter.
  });
  test(
      'display scopes by ID despite identical names and accepts numeric-string IDs',
      () {
    final group = detailGroup(7);
    group['transactions'][0]['id'] = '71';
    final rows = parseSupplierReportDetails(
        detailResponse(groups: [detailGroup(8), group]), query.supplier);
    expect(rows.single.id, 71);
    expect(
        parseSupplierReportDetails(
            detailResponse(groups: [detailGroup(8)]), query.supplier),
        isEmpty);
  });
  test(
      'all declared pages are fetched even when selected supplier is on a later page',
      () async {
    final calls = <int>[];
    final rows = await fetchSupplierReportDetailsSnapshot((page) async {
      calls.add(page);
      return detailResponse(
          page: page,
          last: 2,
          total: 2,
          groups: [detailGroup(page == 1 ? 8 : 7)]);
    }, query);
    expect(calls, [1, 2]);
    expect(rows.single.id, 71);
  });
  for (final legacy in [true, false]) {
    test(
        'complete single grouped/legacy snapshot $legacy keeps blank payment and exact amount',
        () async {
      final rows = await fetchSupplierReportDetailsSnapshot(
          (_) async => detailResponse(legacy: legacy), query);
      expect(rows.single.amount, '10.125');
      expect(rows.single.paymentMethod, '');
    });
  }
  test(
      'local filters use exact Credit/Debit/payment, contains search and inclusive dates',
      () async {
    final rows = parseSupplierReportDetails(
        detailResponse(groups: [
          detailGroup(7, rows: [
            detailRow(1,
                date: '2026-09-13',
                type: 'Debit',
                payment: 'CASH',
                amount: '45.50'),
            detailRow(2,
                date: '2026-10-13',
                type: 'Debit',
                payment: 'CASH',
                amount: '45.50'),
            detailRow(3, date: '2026-10-14', type: 'Debit', payment: 'CASH'),
            detailRow(4, date: '2026-10-13', type: 'Credit', payment: 'Cash'),
            detailRow(5, date: '2026-10-13', type: 'Debit', payment: 'Card'),
          ])
        ]),
        query.supplier);
    const filter = SupplierReportDetailsQuery(
        supplier: (id: '7', name: 'Supplier'),
        from: '2026-09-13',
        to: '2026-10-13',
        type: 'Debit',
        payment: 'Cash',
        search: '45.5');
    expect(filter.apply(rows).map((r) => r.id), [1, 2]);
    expect(
        const SupplierReportDetailsQuery(
                supplier: (id: '7', name: ''), search: 'vOuChEr')
            .apply(rows)
            .length,
        4);
  });
  test('name fallback rejects two suppliers sharing that name', () async {
    await expectLater(
        fetchSupplierReportDetailsSnapshot(
            (_) async =>
                detailResponse(groups: [detailGroup(7), detailGroup(8)]),
            const SupplierReportDetailsQuery(
                supplier: (id: '', name: 'Supplier'))),
        throwsFormatException);
  });
  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'missing amount': (r) => r.remove('amount'),
    'infinite amount': (r) => r['amount'] = 'Infinity',
    'invalid date': (r) => r['date'] = '2026-02-30',
    'missing currency': (r) => r.remove('currency'),
    'missing ID': (r) => r.remove('id'),
    'other supplier': (r) => r['supplier_id'] = 8,
    'missing status': (r) => r.remove('status'),
  };
  for (final entry in corruptions.entries) {
    test('export rejects ${entry.key}', () async {
      final row = detailRow(71);
      entry.value(row);
      await expectLater(
          fetchSupplierReportDetailsSnapshot(
              (_) async => detailResponse(groups: [
                    detailGroup(7, rows: [row])
                  ]),
              query),
          throwsFormatException);
    });
  }
  test('export rejects duplicate numeric-string transaction IDs', () async {
    final second = detailRow(71)..['id'] = '71';
    await expectLater(
        fetchSupplierReportDetailsSnapshot(
            (_) async => detailResponse(groups: [
                  detailGroup(7, rows: [detailRow(71), second])
                ]),
            query),
        throwsFormatException);
  });
  test('export rejects incomplete nested transactions', () async {
    final group = detailGroup(7)..['transaction_count'] = 2;
    await expectLater(
        fetchSupplierReportDetailsSnapshot(
            (_) async => detailResponse(groups: [group]), query),
        throwsFormatException);
  });
  for (final corruption in [
    'overlap',
    'changing pages',
    'missing metadata',
    'empty page',
    'wrong total',
    'later failure'
  ]) {
    test('export rejects $corruption without delivering partial rows',
        () async {
      await expectLater(
          fetchSupplierReportDetailsSnapshot((page) async {
            if (page == 2 && corruption == 'later failure') {
              throw StateError('network');
            }
            final result = detailResponse(
                page: page,
                last: 2,
                total: corruption == 'wrong total' ? 3 : 2,
                groups: [
                  detailGroup(page == 1 || corruption == 'overlap' ? 8 : 7)
                ]);
            if (page == 2) {
              final data = result['data'] as Map;
              if (corruption == 'changing pages') data['last_page'] = 3;
              if (corruption == 'missing metadata') data.remove('last_page');
              if (corruption == 'empty page') data['data'] = [];
            }
            return result;
          }, query),
          throwsA(corruption == 'later failure'
              ? isA<StateError>()
              : isA<FormatException>()));
    });
  }
}
