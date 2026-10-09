import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/features/reports/domain/admin_executive_report.dart';
import 'package:pos_machine/features/reports/domain/report_date_range.dart';
import 'package:pos_machine/features/reports/data/admin_executive_repository.dart';
import 'package:pos_machine/features/reports/presentation/state/admin_executive_controller.dart';
import 'package:pos_machine/features/reports/presentation/export/admin_executive_excel.dart';

const scope = AdminExecutiveScope(
    token: 'test',
    tenant: 'tenant',
    storeId: 7,
    actorId: 4,
    role: 'company_admin',
    endpoint: 'https://example.test/report');
Map<String, dynamic> raw(String name) => {
      'name': name,
      'phone': '001234',
      'order_count': 2,
      'total_sales': '10.125',
      'online_sales': '5',
      'cash_sales': '2',
      'credit_sales': '3.125',
      'collected_sales': '7',
      'payment_breakdown': {'UPI': '4', 'CARD': '1'}
    };
List<SalesExecutiveReportData> rows([String name = 'Alice']) =>
    parseAdminExecutiveReport({
      'status': 'success',
      'data': [raw(name)]
    });

class Source implements AdminExecutiveSource {
  Source(this.scope, this.callback);
  @override
  final AdminExecutiveScope scope;
  final Future<List<SalesExecutiveReportData>> Function(ReportDateRange)
      callback;
  @override
  Future<List<SalesExecutiveReportData>> fetch(ReportDateRange range) =>
      callback(range);
}

void main() {
  test('sales executive and unavailable session never call API', () async {
    var calls = 0;
    for (final denied in [
      const AdminExecutiveScope(
          token: 'test',
          tenant: 'tenant',
          storeId: 7,
          actorId: 4,
          role: 'sales_executive',
          endpoint: 'https://example.test/report'),
      const AdminExecutiveScope(
          token: '',
          tenant: 'tenant',
          storeId: 7,
          actorId: 4,
          role: 'company_admin',
          endpoint: 'https://example.test/report'),
      const AdminExecutiveScope(
          token: 'test',
          tenant: 'tenant',
          storeId: 0,
          actorId: 4,
          role: 'company_admin',
          endpoint: 'https://example.test/report'),
    ]) {
      final repo =
          AdminExecutiveRepository(denied, client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      await expectLater(repo.fetch(ReportDateRange.empty), throwsStateError);
    }
    expect(calls, 0);
  });
  test('today and open custom ranges preserve exact scoped API contract',
      () async {
    final seen = <http.Request>[];
    final repo =
        AdminExecutiveRepository(scope, client: MockClient((request) async {
      seen.add(request);
      return http.Response(jsonEncode({'status': 'success', 'data': []}), 200);
    }));
    await repo.fetch(ReportDateRange.empty);
    expect(seen.last.url.queryParameters,
        {'store_id': '7', 'dateFilter': 'today'});
    final from = DateTime(2026, 10, 1, 13, 14, 15);
    await repo.fetch(ReportDateRange(from: from));
    expect(seen.last.url.queryParameters, {
      'store_id': '7',
      'dateFilter': 'custom',
      'dateFrom': '2026-10-01 13:14:15'
    });
    await repo.fetch(ReportDateRange(to: from));
    expect(seen.last.url.queryParameters, {
      'store_id': '7',
      'dateFilter': 'custom',
      'dateTo': '2026-10-01 13:14:15'
    });
    expect(seen.last.headers['Authorization'], 'Bearer test');
    expect(seen.last.headers['X-Tenant'], 'tenant');
    await expectLater(
        repo.fetch(ReportDateRange(from: from, to: DateTime(2020))),
        throwsFormatException);
    expect(seen.length, 3);
  });
  for (final status in [401, 403, 500]) {
    test('HTTP $status is not an empty result', () async {
      final repo = AdminExecutiveRepository(scope,
          client: MockClient((_) async =>
              http.Response('{"status":"success","data":[]}', status)));
      await expectLater(repo.fetch(ReportDateRange.empty), throwsA(anything));
    });
  }
  for (final invalid in [
    {'status': 'error', 'data': []},
    {'status': 'success', 'data': {}},
    {
      'status': 'success',
      'data': [null]
    }
  ]) {
    test('reject malformed payload $invalid', () {
      expect(() => parseAdminExecutiveReport(invalid), throwsFormatException);
    });
  }
  for (final bad in ['NaN', 'Infinity', 'oops']) {
    test('reject invalid financial amount $bad', () {
      final row = raw('A')..['cash_sales'] = bad;
      expect(
          () => parseAdminExecutiveReport({
                'status': 'success',
                'data': [row]
              }),
          throwsFormatException);
    });
  }
  test('missing finances stay null, aliases work, duplicates remain legitimate',
      () {
    final missing = parseAdminExecutiveReport({
      'status': 'success',
      'data': [
        {'name': 'A', 'phone': '0'}
      ]
    }).single;
    expect(missing.totalSales, isNull);
    expect(missing.orderCount, isNull);
    expect(completeAdminExecutiveRow(missing), false);
    final alias = parseAdminExecutiveReport({
      'status': 'success',
      'data': [
        {
          'name': 'A',
          'phone': '0',
          'orderCount': 1,
          'totalSales': '4',
          'onlineSales': '1',
          'cashSales': '1',
          'creditSales': '2',
          'collectedSales': '2',
          'payment_breakdown': []
        }
      ]
    }).single;
    expect(completeAdminExecutiveRow(alias), true);
    expect(alias.upiSales, isNull);
    final dup = parseAdminExecutiveReport({
      'status': 'success',
      'data': [raw('A'), raw('A')]
    });
    expect(dup.length, 2);
    expect(filterAdminExecutives(rows('Alice'), '  ALI '), hasLength(1));
  });
  test('filter to date to Reset to refresh and export sequence', () async {
    final ranges = <ReportDateRange>[];
    var fail = false;
    final source = Source(scope, (r) async {
      ranges.add(r);
      if (fail) throw StateError('offline');
      return [...rows(), ...rows('Bob')];
    });
    final c = AdminExecutiveController(() async => source);
    addTearDown(c.dispose);
    await c.load();
    c.setName('bob');
    expect(c.rows.single.name, 'Bob');
    await c.setRange(ReportDateRange(from: DateTime(2026)));
    expect(c.rows.single.name, 'Bob');
    await c.reset();
    expect(c.range.isEmpty, true);
    expect(c.name, '');
    expect(c.rows.length, 2);
    expect(c.canExport, true);
    fail = true;
    await c.load();
    expect(c.rows.length, 2);
    expect(c.canExport, false);
    expect(c.error, isNotNull);
    fail = false;
    await c.load();
    expect(c.canExport, true);
    await c.reset();
    expect(ranges.length, 6);
    expect(ranges.last.isEmpty, true);
  });
  test('local search during request does not lose fresh results', () async {
    final pending = Completer<List<SalesExecutiveReportData>>();
    final c = AdminExecutiveController(
        () async => Source(scope, (_) => pending.future));
    addTearDown(c.dispose);
    final task = c.load();
    await Future<void>.delayed(Duration.zero);
    c.setName('bob');
    pending.complete([...rows(), ...rows('Bob')]);
    await task;
    expect(c.rows.single.name, 'Bob');
    expect(c.canExport, true);
  });
  test('late success and errors never overwrite Reset', () async {
    final first = Completer<List<SalesExecutiveReportData>>();
    var calls = 0;
    final source = Source(scope,
        (_) => ++calls == 1 ? first.future : Future.value(rows('Fresh')));
    final c = AdminExecutiveController(() async => source);
    addTearDown(c.dispose);
    final old = c.load();
    await Future<void>.delayed(Duration.zero);
    await c.reset();
    first.completeError(StateError('old'));
    await old;
    expect(c.rows.single.name, 'Fresh');
    expect(c.error, isNull);
  });
  test('account scope changes while request is running reload safely',
      () async {
    final pending = Completer<List<SalesExecutiveReportData>>();
    var source = Source(scope, (_) => pending.future);
    final c = AdminExecutiveController(() async => source);
    addTearDown(c.dispose);
    final task = c.load();
    await Future<void>.delayed(Duration.zero);
    source = Source(
        const AdminExecutiveScope(
            token: 'new',
            tenant: 'new',
            storeId: 8,
            actorId: 5,
            role: 'company_admin',
            endpoint: 'https://example.test/report'),
        (_) async => rows('New account'));
    pending.complete(rows('Old account'));
    await task;
    expect(c.rows.single.name, 'New account');
    expect(c.matches(scope, c.revision), false);
  });
  test('disposed controller ignores response', () async {
    final pending = Completer<List<SalesExecutiveReportData>>();
    final c = AdminExecutiveController(
        () async => Source(scope, (_) => pending.future));
    final task = c.load();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    pending.complete(rows());
    await task;
    expect(c.rows, isEmpty);
  });
  test(
      'workbook includes all matching rows, typed money, text phone and applied metadata',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('admin-executive-test-');
    addTearDown(() => directory.delete(recursive: true));
    final data = List.generate(25, (i) => rows('Executive $i').single);
    final file = await exportAdminExecutives(data,
        currency: 'SAR',
        range: ReportDateRange(from: DateTime(2026, 10, 1, 13, 14, 15)),
        loadedAt: DateTime(2026, 10, 9, 9),
        outputDirectory: directory);
    final sheet = Excel.decodeBytes(await file.readAsBytes())
        .tables['Admin Executive Report']!;
    expect(sheet.rows.length, 26);
    expect(sheet.rows[1][1]!.value, TextCellValue('001234'));
    expect(sheet.rows[1][2]!.value, const IntCellValue(2));
    expect(sheet.rows[1][3]!.value, const DoubleCellValue(10.125));
    expect(sheet.rows[1][10]!.value, TextCellValue('SAR'));
    expect(sheet.rows[1][11]!.value, TextCellValue('2026-10-01 13:14:15'));
    expect(sheet.rows[1][12]?.value, isNull);
  });
}
