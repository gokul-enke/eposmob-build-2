import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';
import 'package:pos_machine/features/reports/domain/supplier_report_details_query.dart';
import 'package:pos_machine/features/reports/presentation/state/supplier_report_details_controller.dart';
import '../../fixtures/supplier_report_details_fixture.dart';

void main() {
  late SupplierReportDetailsSelection selected;
  late SupplierReportScope scope;
  late SupplierReportDetailsController controller;
  late List<SupplierReportDetailsQuery> calls;
  bool fail = false;
  Completer<void>? exportGate;
  setUp(() {
    selected = (id: '7', name: 'Supplier');
    scope =
        (token: 'token', tenant: 'tenant', storeId: 2, endpoint: 'endpoint');
    calls = [];
    fail = false;
    exportGate = null;
    controller = SupplierReportDetailsController(
      selection: () => selected,
      readScope: () async => scope,
      now: () => DateTime(2026, 10, 13),
      fetch: (query, page) async {
        calls.add(query);
        if (page != null && exportGate != null) await exportGate!.future;
        if (fail) throw StateError('network');
        return detailResponse(groups: [
          detailGroup(7, rows: [
            detailRow(71),
            detailRow(72, type: 'Debit', payment: 'CASH'),
            if (query.from.compareTo('2026-09-01') <= 0)
              detailRow(73, date: '2026-09-01'),
          ])
        ]);
      },
    );
  });
  tearDown(() {
    if (!disposed) controller.dispose();
    disposed = false;
  });
  test(
      'defaults remain one month ago through today; local filters never need the directory',
      () async {
    expect(controller.fromInput.text, '2026-09-13');
    expect(controller.toInput.text, '2026-10-13');
    await controller.load();
    expect(controller.rows.length, 2);
    expect(controller.canExport, isTrue);
    controller.selectType('Debit');
    controller.selectPayment('Cash');
    controller.searchInput.text = 'REF-72';
    controller.filterChanged();
    expect(controller.rows.single.id, 72);
    expect(calls.length, 1);
    controller.selectType('All');
    controller.selectPayment('All');
    controller.searchInput.clear();
    controller.filterChanged();
    expect(controller.rows.length, 2);
  });
  test(
      'widen date -> reload older rows -> Reset restores default dates and whole matching snapshot',
      () async {
    await controller.load();
    await controller.selectDate(DateTime(2026, 9, 1), true);
    expect(calls.last.from, '2026-09-01');
    expect(controller.rows.length, 3);
    controller.selectType('Debit');
    controller.searchInput.text = 'REF';
    controller.filterChanged();
    await controller.reset();
    expect(controller.fromInput.text, '2026-09-13');
    expect(controller.toInput.text, '2026-10-13');
    expect(controller.searchInput.text, '');
    expect(controller.type, 'All');
    expect(controller.payment, 'All');
    expect(controller.rows.length, 2);
    expect(controller.canExport, isTrue);
  });
  test('failed refresh retains rows, blocks export; Retry recovers', () async {
    await controller.load();
    fail = true;
    await controller.load();
    expect(controller.rows.length, 2);
    expect(controller.error, isNotNull);
    expect(controller.canExport, isFalse);
    fail = false;
    await controller.load();
    expect(controller.error, isNull);
    expect(controller.canExport, isTrue);
  });
  test(
      'latest refresh wins and filters edited during loading apply to fetched data',
      () async {
    final first = Completer<Map<String, dynamic>>(),
        second = Completer<Map<String, dynamic>>();
    var request = 0;
    final local = SupplierReportDetailsController(
        selection: () => selected,
        readScope: () async => scope,
        now: () => DateTime(2026, 10, 13),
        fetch: (_, __) => ++request == 1 ? first.future : second.future);
    addTearDown(local.dispose);
    final old = local.load();
    await Future<void>.delayed(Duration.zero);
    final fresh = local.load();
    await Future<void>.delayed(Duration.zero);
    local.selectType('Debit');
    second.complete(detailResponse(groups: [
      detailGroup(7, rows: [detailRow(2, type: 'Debit')])
    ]));
    await fresh;
    first.complete(detailResponse());
    await old;
    expect(local.rows.single.id, 2);
    expect(local.loading, isFalse);
  });
  test('export keeps visible rows and uses its own filtered snapshot',
      () async {
    await controller.load();
    final visible = controller.rows;
    controller.selectType('Debit');
    final result = await controller.export(build: (rows, query) async {
      expect(rows.single.id, 72);
      expect(query.type, 'Debit');
      return rows.single.amount;
    });
    expect(result, '10.125');
    expect(visible.length, 2);
    expect(controller.rows.single.id, 72);
  });
  for (final change in [
    'search',
    'type',
    'payment',
    'date',
    'reset',
    'refresh',
    'supplier',
    'token',
    'tenant',
    'store',
    'dispose'
  ]) {
    test('pending export cancels after $change', () async {
      await controller.load();
      exportGate = Completer<void>();
      var built = false;
      final pending = controller.export(build: (_, __) async {
        built = true;
        return 'file';
      });
      final assertion = expectLater(
          pending, throwsA(isA<SupplierReportDetailsExportCancelled>()));
      await Future<void>.delayed(Duration.zero);
      switch (change) {
        case 'search':
          controller.searchInput.text = 'REF';
          controller.filterChanged();
        case 'type':
          controller.selectType('Debit');
        case 'payment':
          controller.selectPayment('Cash');
        case 'date':
          await controller.selectDate(DateTime(2026, 9, 1), true);
        case 'reset':
          await controller.reset();
        case 'refresh':
          await controller.load();
        case 'supplier':
          selected = (id: '8', name: 'Supplier');
        case 'token':
          scope = (
            token: 'new',
            tenant: scope.tenant,
            storeId: scope.storeId,
            endpoint: scope.endpoint
          );
        case 'tenant':
          scope = (
            token: scope.token,
            tenant: 'new',
            storeId: scope.storeId,
            endpoint: scope.endpoint
          );
        case 'store':
          scope = (
            token: scope.token,
            tenant: scope.tenant,
            storeId: 3,
            endpoint: scope.endpoint
          );
        case 'dispose':
          controller.dispose();
          disposed = true;
      }
      exportGate!.complete();
      await assertion;
      expect(built, isFalse);
    });
  }
  test('scope change while workbook is built blocks delivery', () async {
    await controller.load();
    final gate = Completer<String>(), started = Completer<void>();
    final pending = controller.export(build: (_, __) {
      started.complete();
      return gate.future;
    });
    final assertion = expectLater(
        pending, throwsA(isA<SupplierReportDetailsExportCancelled>()));
    await started.future;
    scope = (token: 'new', tenant: 'tenant', storeId: 2, endpoint: 'endpoint');
    gate.complete('file');
    await assertion;
  });
  test('supplier/session change during display fetch cannot publish rows',
      () async {
    final gate = Completer<Map<String, dynamic>>();
    final local = SupplierReportDetailsController(
        selection: () => selected,
        readScope: () async => scope,
        fetch: (_, __) => gate.future);
    addTearDown(local.dispose);
    final pending = local.load();
    await Future<void>.delayed(Duration.zero);
    selected = (id: '8', name: 'Other');
    gate.complete(detailResponse());
    await pending;
    expect(local.rows, isEmpty);
    expect(local.canExport, isFalse);
  });
}

bool disposed = false;
