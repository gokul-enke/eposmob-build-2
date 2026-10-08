import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/day_closes/data/day_close_list_repository.dart';
import 'package:pos_machine/features/day_closes/domain/day_close_list.dart';
import 'package:pos_machine/features/day_closes/presentation/export/day_close_list_excel.dart';
import 'package:pos_machine/features/day_closes/presentation/state/day_close_list_controller.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'day_close_fixtures.dart';

String response(
        {List<Map<String, dynamic>>? rows,
        int total = 1,
        int page = 1,
        int perPage = 20,
        int? pages,
        bool success = true}) =>
    jsonEncode({
      'success': success,
      'data': rows ?? [wireRow()],
      'pagination': {
        'total': total,
        'current_page': page,
        'per_page': perPage,
        'last_page': pages ?? (total == 0 ? 1 : (total / perPage).ceil())
      }
    });
Map<String, dynamic> wireRow() => {
      'id': '12',
      'sales_executive': {'id': '516', 'name': 'Executive', 'phone': '00123'},
      'store': {'id': '2', 'name': 'Store'},
      'business_date': '2026-10-07',
      'total_orders': '12',
      'total_sales': 256,
      'total_online': '183.00',
      'total_cash': '2.00',
      'total_credit': '71.00',
      'status': 'closed'
    };

void main() {
  test(
      'wire contract keeps user/store array parameters, date bounds and pending scalar parameters',
      () async {
    final queries = <Uri>[];
    final client = MockClient((request) async {
      queries.add(request.url);
      expect(request.headers['Authorization'], 'Bearer test');
      expect(request.headers['X-Tenant'], 'test');
      return http.Response(
          request.url.path.endsWith('/pending')
              ? jsonEncode({
                  'success': true,
                  'data': {'can_open_shift': true, 'pending_day_close': false}
                })
              : response(),
          200);
    });
    final repo = DayCloseListRepository(scope, client: client);
    final data = await repo.fetch(1, date: '2026-10-07');
    expect(queries.first.queryParameters, {
      'store_id[]': '2',
      'user_id[]': '516',
      'page': '1',
      'start_date': '2026-10-07',
      'end_date': '2026-10-07'
    });
    expect(data.rows.single.id, 12);
    expect(data.rows.single.totalSales, '256');
    expect(completeDayCloseRow(data.rows.single, scope), isTrue);
    expect((await repo.fetchPending()).canOpenShift, isTrue);
    expect(queries.last.queryParameters, {'store_id': '2', 'user_id': '516'});
    client.close();
  });
  test('empty success differs from HTTP, API and pagination failures',
      () async {
    expect(
        DayCloseListRepository.parse(response(rows: [], total: 0),
                requestedPage: 1)
            .rows,
        isEmpty);
    for (final body in [
      response(success: false),
      response(page: 2),
      response(pages: 2),
      jsonEncode({'success': true, 'data': []}),
      response(total: 0)
    ]) {
      expect(() => DayCloseListRepository.parse(body, requestedPage: 1),
          throwsFormatException);
    }
    final repo = DayCloseListRepository(scope,
        client: MockClient((_) async => http.Response('Server error', 500)));
    await expectLater(repo.fetch(1), throwsA(anything));
    final unsafe = DayCloseListRepository(const DayCloseListScope(
        token: '',
        tenant: '',
        endpoint: 'https://example.test',
        pendingEndpoint: 'https://example.test',
        storeId: 0,
        userId: 0));
    await expectLater(unsafe.fetch(1), throwsStateError);
  });
  test('pending permission cannot default to allowed when the API omits it',
      () async {
    final repo = DayCloseListRepository(scope,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {'pending_day_close': false}
            }),
            200)));
    await expectLater(repo.fetchPending(), throwsFormatException);
  });
  test(
      'snapshot covers all pages and rejects overlaps, missing amounts, scope leakage and changing counts',
      () async {
    final source = FakeDayCloseSource();
    final rows = await dayCloseListSnapshot(source, date: '2026-10-07');
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(source.calls, [(1, '2026-10-07'), (2, '2026-10-07')]);
    for (final mutate in <void Function(DailySalesCloseData)>[
      (r) => r.id = 1,
      (r) => r.totalCash = null,
      (r) => r.totalCredit = 'NaN',
      (r) => r.store!.id = 9,
      (r) => r.salesExecutive!.id = 1,
      (r) => r.totalOrders = -1,
      (r) => r.businessDate = '2026-02-31',
      (r) => r.status = null,
    ]) {
      source.fetchPage = (page, _) async {
        final data = pageData(page);
        if (page == 2) mutate(data.rows.single);
        return data;
      };
      await expectLater(dayCloseListSnapshot(source), throwsStateError);
    }
    source.fetchPage = (p, _) async => pageData(p, total: p == 1 ? 3 : 4);
    await expectLater(dayCloseListSnapshot(source), throwsStateError);
    source.fetchPage = (p, _) async =>
        DayCloseListData(rows: [], page: p, pages: 2, perPage: 2, total: 3);
    await expectLater(dayCloseListSnapshot(source), throwsStateError);
  });
  test('snapshot checks cancellation after the last page', () async {
    final source = FakeDayCloseSource();
    var current = true;
    source.fetchPage = (p, _) async {
      if (p == 2) current = false;
      return pageData(p);
    };
    await expectLater(
        dayCloseListSnapshot(source, isCurrent: () async => current),
        throwsStateError);
  });
  test(
      'filter/reset/load/pagination/failed retry preserves only matching results',
      () async {
    final source = FakeDayCloseSource();
    final controller = DayCloseListController(() async => source);
    await controller.refresh(firstPage: true);
    expect(controller.canExport, isTrue);
    await controller.load(page: 2);
    expect(controller.data!.page, 2);
    await controller.reset();
    expect(controller.data!.page, 1);
    source.fetchPage = (p, _) async {
      if (p == 2) throw StateError('offline');
      return pageData(p);
    };
    await controller.load(page: 2);
    expect(controller.data!.page, 1);
    expect(controller.requestedPage, 2);
    expect(controller.canExport, isFalse);
    source.fetchPage = null;
    await controller.load();
    expect(controller.data!.page, 2);
    source.fetchPage = (p, _) async => throw StateError('offline');
    await controller.setDate('2026-10-07');
    expect(controller.data, isNull);
    expect(controller.requestedPage, 1);
    expect(controller.error, isNotNull);
    source.fetchPage =
        (p, date) async => date == null ? pageData(p) : pageData(p, total: 0);
    await controller.load();
    expect(controller.data!.rows, isEmpty);
    await controller.reset();
    expect(controller.data!.rows.length, 2);
    expect(controller.date, isNull);
    expect(source.pendingCalls, 1);
    controller.dispose();
  });
  test(
      'pending failure does not clear rows and retry cannot duplicate list requests',
      () async {
    final source = FakeDayCloseSource()
      ..pendingResponse = () async => throw StateError('offline');
    final controller = DayCloseListController(() async => source);
    await controller.refresh();
    expect(controller.data!.total, 3);
    expect(controller.error, isNull);
    expect(controller.pending, isNull);
    expect(controller.pendingError, isNotNull);
    expect(controller.canExport, isTrue);
    source.pendingResponse = null;
    await controller.loadPending();
    expect(controller.pending!.canOpenShift, isTrue);
    expect(source.calls.length, 1);
    controller.dispose();
  });
  test(
      'out-of-order queries and pending responses never restore stale state after invalidation/disposal',
      () async {
    final old = Completer<DayCloseListData>(),
        pending = Completer<DayClosePendingStatus>();
    final source = FakeDayCloseSource()
      ..fetchPage = ((p, date) =>
          date == null ? old.future : Future.value(pageData(p, total: 0)))
      ..pendingResponse = () => pending.future;
    final controller = DayCloseListController(() async => source);
    final load = controller.load();
    final shift = controller.loadPending();
    await Future<void>.delayed(Duration.zero);
    controller.invalidate();
    await controller.setDate('2026-10-07');
    old.complete(pageData(1));
    pending.complete(pendingStatus());
    await Future.wait([load, shift]);
    expect(controller.data!.rows, isEmpty);
    expect(controller.pending, isNull);
    final later = Completer<DayCloseListData>();
    source.fetchPage = (_, __) => later.future;
    final disposed = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    later.complete(pageData(1));
    await disposed;
  });
  test('refresh recovers a page removed by catalogue shrinkage', () async {
    final source = FakeDayCloseSource();
    final controller = DayCloseListController(() async => source);
    await controller.load(page: 2);
    source.fetchPage = (p, _) async => pageData(p, total: 1);
    await controller.refresh();
    expect(controller.data!.page, 1);
    expect(controller.data!.total, 1);
    controller.dispose();
  });
  test(
      'store/auth changes invalidate export and pending state before loading the new scope',
      () async {
    final first = FakeDayCloseSource();
    final second = FakeDayCloseSource(
        scope: const DayCloseListScope(
            token: 'new',
            tenant: 'new',
            endpoint: 'https://example.test/list',
            pendingEndpoint: 'https://example.test/pending',
            storeId: 9,
            userId: 517));
    var current = first;
    final controller = DayCloseListController(() async => current);
    await controller.refresh();
    final revision = controller.revision;
    expect(controller.matches(scope, null, revision), isTrue);
    current = second;
    controller.invalidate();
    expect(controller.data, isNull);
    expect(controller.pending, isNull);
    expect(controller.matches(scope, null, revision), isFalse);
    await controller.refresh(firstPage: true);
    expect(second.calls, [(1, null)]);
    expect(second.pendingCalls, 1);
    controller.dispose();
  });
  test('late pending responses cannot restore an older draft', () async {
    final old = Completer<DayClosePendingStatus>();
    final source = FakeDayCloseSource()..pendingResponse = (() => old.future);
    final controller = DayCloseListController(() async => source);
    final earlier = controller.loadPending();
    await Future<void>.delayed(Duration.zero);
    source.pendingResponse =
        () async => pendingStatus(draft: OpenDraftModel(id: 82));
    await controller.loadPending();
    old.complete(pendingStatus(draft: OpenDraftModel(id: 81)));
    await earlier;
    expect(controller.pending!.openDraft!.id, 82);
    controller.dispose();
  });
  test('Excel preserves phone/identity/date text and numeric financial values',
      () async {
    final directory = await Directory.systemTemp.createTemp('day-close-test-');
    try {
      final rowWithDecimal = closeRow(1)..totalSales = '256.25';
      final file = await exportDayCloseList([rowWithDecimal], 'SAR',
          outputDirectory: directory);
      final workbook = Excel.decodeBytes(await file.readAsBytes());
      final row = workbook.tables['Daily Sales Closes']!.rows[1];
      expect(row[0]!.value, TextCellValue('1'));
      expect(row[2]!.value, TextCellValue('0012345678'));
      expect(row[4]!.value, TextCellValue('2026-10-07'));
      expect(row[5]!.value, const IntCellValue(12));
      expect(row[6]!.value, const DoubleCellValue(256.25));
      expect(row[10]!.value, TextCellValue('SAR'));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('legacy closes export without inventing a business date', () async {
    final source = FakeDayCloseSource()
      ..fetchPage = ((p, _) async {
        final data = pageData(p);
        for (final row in data.rows) {
          row.businessDate = null;
          row.closingPeriod = '2026-05-18 to 2026-06-05';
        }
        return data;
      });
    expect((await dayCloseListSnapshot(source)).length, 3);
  });

  test('live API fixtures pass the production parser and complete snapshot',
      () async {
    final path = Platform.environment['DAY_CLOSE_LIVE_PAGES'];
    if (path == null) return;
    final pages = jsonDecode(await File(path).readAsString()) as List;
    final client = MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode(
            pages[int.parse(request.url.queryParameters['page']!) - 1])),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    try {
      final rows = await dayCloseListSnapshot(
          DayCloseListRepository(scope, client: client));
      expect(rows.length, pages.first['pagination']['total']);
      expect(rows.map((r) => r.id).toSet().length, rows.length);
    } finally {
      client.close();
    }
  });
}
