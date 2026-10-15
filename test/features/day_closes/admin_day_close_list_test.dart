import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/day_closes/data/admin_day_close_repository.dart';
import 'package:pos_machine/features/day_closes/domain/admin_day_close_list.dart';
import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/day_closes/presentation/state/admin_day_close_controller.dart';
import 'package:pos_machine/features/day_closes/presentation/export/day_close_list_excel.dart';
import 'admin_day_close_fixtures.dart';

String body(DayCloseListData page) => jsonEncode({
      'success': true,
      'data': page.rows
          .map((r) => {
                'id': r.id,
                'sales_executive': {
                  'id': r.salesExecutive?.id,
                  'name': r.salesExecutive?.name,
                  'phone': r.salesExecutive?.phone
                },
                'store': {'id': r.store?.id, 'name': r.store?.name},
                'business_date': r.businessDate,
                'closing_period': r.closingPeriod,
                'total_orders': r.totalOrders,
                'total_sales': r.totalSales,
                'total_online': r.totalOnline,
                'total_cash': r.totalCash,
                'total_credit': r.totalCredit,
              })
          .toList(),
      'pagination': {
        'total': page.total,
        'current_page': page.page,
        'last_page': page.pages,
        'per_page': page.perPage
      }
    });

void main() {
  test(
      'admin default uses current store, omits user; selected date/user are frozen',
      () async {
    final requests = <http.Request>[];
    final source =
        AdminDayCloseRepository(adminScope, client: MockClient((request) async {
      requests.add(request);
      final query = request.url.queryParameters;
      return http.Response(
          body(adminPage(
              int.parse(query['page']!),
              AdminDayCloseQuery(
                  executiveId: int.tryParse(query['user_id[]'] ?? '')))),
          200);
    }));
    await source.fetch(1, const AdminDayCloseQuery());
    await source.fetch(
        2, const AdminDayCloseQuery(date: '2026-10-07', executiveId: 911));
    expect(
        requests.first.url.queryParameters, {'store_id[]': '2', 'page': '1'});
    expect(requests.last.url.queryParameters, {
      'store_id[]': '2',
      'page': '2',
      'user_id[]': '911',
      'start_date': '2026-10-07',
      'end_date': '2026-10-07'
    });
    expect(requests.first.headers['Authorization'], 'Bearer test');
    expect(requests.first.headers['X-Tenant'], 'test');
  });
  test('executive lookup uses scalar store, numeric string IDs and names only',
      () async {
    final source =
        AdminDayCloseRepository(adminScope, client: MockClient((r) async {
      expect(r.url.queryParameters, {'store_id': '2'});
      return http.Response(
          jsonEncode({
            'status': 'success',
            'data': [
              {'id': '516', 'name': 'Same name'},
              {'id': 911, 'name': 'Same name'}
            ]
          }),
          200);
    }));
    expect((await source.fetchExecutives()).map((e) => e.id), [516, 911]);
  });
  for (final invalid in [
    {'status': 'error', 'data': []},
    {
      'status': 'success',
      'data': [
        {'id': 0, 'name': 'Bad'}
      ]
    },
    {
      'status': 'success',
      'data': [
        {'id': 1, 'name': 'A'},
        {'id': '1', 'name': 'B'}
      ]
    },
  ]) {
    test('lookup rejects malformed or duplicate options $invalid', () async {
      final source = AdminDayCloseRepository(adminScope,
          client:
              MockClient((_) async => http.Response(jsonEncode(invalid), 200)));
      await expectLater(source.fetchExecutives(), throwsFormatException);
    });
  }
  for (final code in [401, 403, 500]) {
    test('HTTP $code is an error rather than empty success', () async {
      final source = AdminDayCloseRepository(adminScope,
          client: MockClient(
              (_) async => http.Response('{"message":"Failed"}', code)));
      await expectLater(source.fetch(1, const AdminDayCloseQuery()),
          throwsA(isA<Exception>()));
    });
  }
  test(
      'empty success and numeric wire types parse; foreign selected user/store rejected',
      () async {
    var response = body(adminPage(1, const AdminDayCloseQuery(), total: 0));
    final source = AdminDayCloseRepository(adminScope,
        client: MockClient((_) async => http.Response(response, 200)));
    expect((await source.fetch(1, const AdminDayCloseQuery())).total, 0);
    final raw =
        jsonDecode(body(adminPage(1, const AdminDayCloseQuery()))) as Map;
    raw['data'][0]['id'] = '1';
    raw['data'][0]['sales_executive']['id'] = '516';
    raw['data'][0]['total_orders'] = '12';
    raw['data'][0]['total_sales'] = 256.25;
    response = jsonEncode(raw);
    expect(
        (await source.fetch(1, const AdminDayCloseQuery()))
            .rows
            .first
            .totalSales,
        '256.25');
    await expectLater(
        source.fetch(1, const AdminDayCloseQuery(executiveId: 911)),
        throwsFormatException);
    raw['data'][0]['store']['id'] = 99;
    response = jsonEncode(raw);
    await expectLater(
        source.fetch(1, const AdminDayCloseQuery()), throwsFormatException);
  });
  test('invalid query/missing store refuses network request', () async {
    final source = AdminDayCloseRepository(
        const AdminDayCloseScope(
            token: '',
            tenant: 'test',
            endpoint: 'https://example.test/list',
            executivesEndpoint: '',
            storeId: 2,
            actorId: 10),
        client:
            MockClient((_) async => throw StateError('Should not request')));
    await expectLater(
        source.fetch(1, const AdminDayCloseQuery()), throwsStateError);
    await expectLater(
        source.fetch(1, const AdminDayCloseQuery(date: '2026-02-30')),
        throwsFormatException);
  });
  test('snapshot covers different executives; repeat executive IDs are valid',
      () async {
    final source = FakeAdminSource();
    final rows = await adminDayCloseSnapshot(source, const AdminDayCloseQuery(),
        isCurrent: () async => true);
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(rows.map((r) => r.salesExecutive!.id), [516, 911, 516]);
    expect(source.calls, [(1, null, null), (2, null, null)]);
  });
  for (final issue in [
    'duplicate',
    'scope',
    'money',
    'infinite',
    'count',
    'total',
    'failure'
  ]) {
    test('snapshot rejects $issue on later pages', () async {
      final source = FakeAdminSource()
        ..fetchPage = (p, q) async {
          final data = adminPage(p, q);
          if (p == 2) {
            final row = data.rows.first;
            if (issue == 'duplicate') row.id = 1;
            if (issue == 'scope') row.store!.id = 99;
            if (issue == 'money') row.totalCash = null;
            if (issue == 'infinite') row.totalSales = 'NaN';
            if (issue == 'count') return adminPage(p, q, total: 2);
            if (issue == 'total') return adminPage(p, q, total: 4);
            if (issue == 'failure') throw StateError('Backend failed');
          }
          return data;
        };
      await expectLater(
          adminDayCloseSnapshot(source, const AdminDayCloseQuery(),
              isCurrent: () async => true),
          throwsStateError);
    });
  }
  test(
      'legacy missing business date is accepted; final scope cancellation fails',
      () async {
    final source = FakeAdminSource()
      ..fetchPage = (p, q) async {
        final data = adminPage(p, q);
        data.rows.first.businessDate = null;
        return data;
      };
    expect(
        (await adminDayCloseSnapshot(source, const AdminDayCloseQuery(),
                isCurrent: () async => true))
            .length,
        3);
    var checks = 0;
    await expectLater(
        adminDayCloseSnapshot(source, const AdminDayCloseQuery(),
            isCurrent: () async => ++checks < 3),
        throwsStateError);
  });
  test(
      'combined filters -> pagination -> Reset -> full reload -> export -> failed retry',
      () async {
    final source = FakeAdminSource();
    final c = AdminDayCloseController(() async => source);
    await c.refresh();
    await c.setQuery(
        const AdminDayCloseQuery(date: '2026-10-07', executiveId: 911));
    await c.load(page: 2);
    await c.reset();
    expect(c.query.executiveId, isNull);
    expect(c.query.date, isNull);
    expect(c.data!.page, 1);
    await adminDayCloseSnapshot(source, c.query,
        isCurrent: () async => c.matches(adminScope, c.query, c.revision));
    final previous = c.data;
    source.fetchPage = (_, __) async => throw StateError('Failure');
    await c.load(page: 2);
    expect(c.data, same(previous));
    expect(c.canExport, isFalse);
    source.fetchPage = null;
    await c.load();
    expect(c.data!.page, 2);
    await c.reset();
    expect(c.data!.page, 1);
    expect(
        source.calls,
        containsAllInOrder([
          (1, null, null),
          (1, '2026-10-07', 911),
          (2, '2026-10-07', 911),
          (1, null, null),
          (1, null, null),
          (2, null, null)
        ]));
    c.dispose();
  });
  test('late response cannot replace latest filters or restore disposed state',
      () async {
    final late = Completer<DayCloseListData>();
    final source = FakeAdminSource()..fetchPage = (_, __) => late.future;
    final c = AdminDayCloseController(() async => source);
    final old = c.load();
    await Future<void>.delayed(Duration.zero);
    source.fetchPage = null;
    await c.setQuery(const AdminDayCloseQuery(executiveId: 911));
    late.complete(adminPage(1, const AdminDayCloseQuery()));
    await old;
    expect(c.data!.rows.every((r) => r.salesExecutive!.id == 911), isTrue);
    c.dispose();
    await c.load();
  });
  test('disposed list and superseded lookup cannot publish late results',
      () async {
    final lateRows = Completer<DayCloseListData>();
    final lateOptions = Completer<List<AdminExecutiveOption>>();
    final source = FakeAdminSource()..fetchPage = (_, __) => lateRows.future;
    final c = AdminDayCloseController(() async => source);
    final pending = c.load();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    lateRows.complete(adminPage(1, const AdminDayCloseQuery()));
    await pending;
    expect(c.data, isNull);

    final lookupController = AdminDayCloseController(() async => source);
    source.lookup = () => lateOptions.future;
    final oldLookup = lookupController.loadExecutives();
    await Future<void>.delayed(Duration.zero);
    lookupController.invalidate();
    source.lookup = () async => [allExecutives.last];
    await lookupController.loadExecutives();
    lateOptions.complete([allExecutives.first]);
    await oldLookup;
    expect(lookupController.executives.single.id, 911);
    lookupController.dispose();
  });
  test(
      'store/account change clears rows, old executive choices and selected executive',
      () async {
    var source = FakeAdminSource();
    final c = AdminDayCloseController(() async => source);
    await c.refresh();
    await c.setQuery(const AdminDayCloseQuery(executiveId: 911));
    final revision = c.revision;
    source = FakeAdminSource(
        scope: const AdminDayCloseScope(
            token: 'new',
            tenant: 'other',
            endpoint: 'https://example.test/list',
            executivesEndpoint: 'https://example.test/executives',
            storeId: 3,
            actorId: 11));
    c.invalidate();
    expect(c.executives, isEmpty);
    expect(c.query.executiveId, isNull);
    expect(
        c.matches(
            adminScope, const AdminDayCloseQuery(executiveId: 911), revision),
        isFalse);
    await c.refresh();
    expect(source.calls.single, (1, null, null));
    c.dispose();
  });
  test(
      'lookup failure keeps valid data/export; missing selected lookup retains applied label',
      () async {
    final source = FakeAdminSource();
    final c = AdminDayCloseController(() async => source);
    await c.refresh();
    await c.setQuery(const AdminDayCloseQuery(executiveId: 911));
    source.lookup = () async => throw StateError('Failed');
    await c.loadExecutives();
    expect(c.canExport, isTrue);
    expect(c.executivesError, isNotNull);
    final calls = source.calls.length;
    source.lookup = () async => [allExecutives.first];
    await c.loadExecutives();
    expect(c.executives.map((e) => e.id), [516, 911]);
    expect(c.query.executiveId, 911);
    expect(source.calls.length, calls);
    c.dispose();
  });
  test('refresh preserves filter; shrunk pages recover the last available page',
      () async {
    final source = FakeAdminSource();
    final c = AdminDayCloseController(() async => source);
    await c.setQuery(
        const AdminDayCloseQuery(date: '2026-10-07', executiveId: 516));
    await c.load(page: 2);
    source.fetchPage = (p, q) async => adminPage(p, q, total: 1);
    await c.refresh();
    expect(c.data!.page, 1);
    expect(c.query.executiveId, 516);
    expect(source.calls.sublist(source.calls.length - 2),
        [(2, '2026-10-07', 516), (1, '2026-10-07', 516)]);
    c.dispose();
  });
  test(
      'admin workbook keeps close ID and executive ID separate, money numeric and phone text',
      () async {
    final dir = await Directory.systemTemp.createTemp('admin-day-close-test-');
    try {
      final rows = adminPage(1, const AdminDayCloseQuery()).rows;
      rows.first.totalSales = '256.25';
      final file = await exportDayCloseList(rows, 'SAR',
          outputDirectory: dir,
          fileNamePrefix: 'admin-daily-sales-records',
          includeExecutiveId: true);
      expect(file.path, contains('admin-daily-sales-records'));
      final row = Excel.decodeBytes(await file.readAsBytes())
          .tables['Daily Sales Closes']!
          .rows[1];
      expect(row[0]!.value, TextCellValue('1'));
      expect(row[1]!.value, TextCellValue('516'));
      expect(row[3]!.value, TextCellValue('0012345678'));
      expect(row[7]!.value, const DoubleCellValue(256.25));
      expect(row[13]!.value, TextCellValue('2026-10-05 to 2026-10-07'));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
