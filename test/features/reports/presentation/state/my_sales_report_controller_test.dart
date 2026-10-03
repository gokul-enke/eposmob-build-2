import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/presentation/state/my_sales_report_controller.dart';
import 'package:pos_machine/features/reports/presentation/state/report_load_error.dart';

import '../../support/report_fixtures.dart';

void main() {
  late List<({String? from, String? to})> calls;
  late Future<dynamic> Function(String? from, String? to) handler;
  late MySalesReportController report;

  setUp(() {
    calls = [];
    handler = (_, __) async => salesReport();
    report = MySalesReportController(
        now: () => DateTime(2026, 10, 3),
        fetch: ({from, to}) {
          calls.add((from: from, to: to));
          return handler(from, to);
        });
  });
  tearDown(() => report.dispose());

  test('pages are cut locally, 20 rows each', () async {
    handler = (_, __) async =>
        salesReport([for (var i = 0; i < 21; i++) salesRow('Executive $i')]);
    await report.load();
    expect(report.pages, 2);
    expect(report.pageRows, hasLength(20));
    report.setPage(2);
    expect(report.pageRows.single.name, 'Executive 20');
    expect(calls, hasLength(1));
  });

  test('dates are sent in the API format and Reset returns to today', () async {
    report.setFrom(DateTime(2026, 9, 1, 10, 30));
    await pumpEventQueue();
    report.setTo(DateTime(2026, 9, 30, 22));
    await pumpEventQueue();
    expect(
        calls.last, (from: '2026-09-01 10:30:00', to: '2026-09-30 22:00:00'));
    expect(report.loadedRange?.apiFrom, '2026-09-01 10:30:00');

    await report.reset();
    expect(calls.last, (from: null, to: null));
    expect(report.loadedAt, DateTime(2026, 10, 3));
  });

  test('From after To issues no request and keeps the rows', () async {
    await report.load();
    report.setFrom(DateTime(2026, 10, 2));
    await pumpEventQueue();
    final before = calls.length;
    report.setTo(DateTime(2026, 10, 1));
    await pumpEventQueue();
    expect(calls.length, before);
    expect(report.error, ReportLoadError.invertedRange);
    expect(report.canExport, isFalse);
    expect(report.rows.single.name, 'My Executive');
  });

  test('a failed request keeps the rows; a retry recovers', () async {
    await report.load();
    handler = (_, __) async => {'status': 'failed', 'message': 'server error'};
    await report.load();
    expect(report.rows.single.name, 'My Executive');
    expect(report.canExport, isFalse);

    handler = (_, __) async => salesReport([salesRow('Recovered')]);
    await report.load();
    expect(report.rows.single.name, 'Recovered');
    expect(report.canExport, isTrue);
  });

  test('an older request cannot replace a newer result', () async {
    final older = Completer<dynamic>();
    handler = (from, _) async =>
        from == null ? older.future : salesReport([salesRow('Newer')]);
    final old = report.load();
    report.setFrom(DateTime(2026, 9, 1));
    await pumpEventQueue();
    older.complete(salesReport([salesRow('Stale')]));
    await old;
    expect(report.rows.single.name, 'Newer');
  });

  test('an empty result clears the rows and blocks the export', () async {
    await report.load();
    handler = (_, __) async => salesReport([]);
    await report.load();
    expect(report.rows, isEmpty);
    expect(report.canExport, isFalse);
  });
}
