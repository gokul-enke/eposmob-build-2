import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/features/invoices/domain/invoice_list_query.dart';
import 'package:pos_machine/features/invoices/data/invoice_list_repository.dart';
import 'package:pos_machine/features/invoices/presentation/state/invoice_list_controller.dart';

class FakeProvider extends InvoiceProvider {
  int page = 1, resets = 0, loads = 0, exports = 0;
  bool? resetReload, resetNotify;
  String? loadedToken, loadedZatca;
  int? loadedPage;
  final applied = <Map<String, Object?>>[];
  Completer<void>? pending;
  Completer<List<Invoice>>? pendingExport;
  @override
  int get currentPage => page;
  @override
  Future<dynamic> listAllInvoices(
      {required String accessToken,
      String? name,
      String? invoiceNumber,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      String? phone,
      String? email,
      String? orderNumber,
      int? page,
      int? perPage,
      bool loadAll = false,
      http.Client? client}) async {
    loads++;
    loadedToken = accessToken;
    loadedZatca = zatcaStatus;
    loadedPage = page;
    if (pending != null) await pending!.future;
    return {'status': 'success'};
  }

  @override
  void applyFilters(
      {String? name,
      String? invoiceNumber,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      String? phone,
      String? email,
      String? orderNumber,
      int page = 1}) {
    applied.add({
      'name': name,
      'invoiceNumber': invoiceNumber,
      'phone': phone,
      'fromDate': fromDate,
      'toDate': toDate,
      'status': status,
      'zatcaStatus': zatcaStatus
    });
    this.page = page;
  }

  @override
  void resetFilters({bool reload = true, bool notify = true}) {
    resets++;
    resetReload = reload;
    resetNotify = notify;
    page = 1;
  }

  @override
  void goToPage(int value) {
    page = value;
  }

  @override
  Future<List<Invoice>> fetchInvoicesForExport(
      {required String accessToken,
      String? name,
      String? invoiceNumber,
      String? phone,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      void Function(int, int)? onProgress,
      http.Client? client,
      Duration requestTimeout = const Duration(seconds: 30)}) async {
    exports++;
    applied.add({
      'name': name,
      'invoiceNumber': invoiceNumber,
      'phone': phone,
      'fromDate': fromDate,
      'toDate': toDate,
      'status': status,
      'zatcaStatus': zatcaStatus
    });
    onProgress?.call(2, 2);
    return pendingExport == null ? <Invoice>[] : await pendingExport!.future;
  }
}

void main() {
  test('query and API normalization retain text, dates and ZATCA aliases', () {
    expect(const InvoiceListQuery().isActive, false);
    expect(const InvoiceListQuery(phone: '0').isActive, true);
    expect(normalizeInvoiceFilter('  00123  '), '00123');
    expect(normalizeInvoiceFilter(' '), isNull);
    expect(formatInvoiceApiDate('1/2/2024'), '2024-02-01');
    expect(formatInvoiceApiDate('2024-02-01 11:12:13'), '2024-02-01 11:12:13');
    for (final value in ['sent', 'success']) {
      expect(mapInvoiceZatcaStatusToApi(value), 'sent');
    }
    for (final value in ['fail', 'FAILED']) {
      expect(mapInvoiceZatcaStatusToApi(value), 'failed');
    }
    expect(mapInvoiceZatcaStatusToApi('Not Sent'), 'not_sent');
    expect(mapInvoiceZatcaStatusToApi('All ZATCA Status'), isNull);
  });
  test('initial load forwards pending ZATCA once', () async {
    final p = FakeProvider();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    addTearDown(c.dispose);
    c.zatcaStatus = 'failed';
    await c.load();
    await c.load();
    expect(p.loads, 1);
    expect(p.loadedToken, 'token');
    expect(p.loadedZatca, 'failed');
    expect(c.initialized, true);
  });
  testWidgets(
      'pending search then date filters Reset pagination refresh and export',
      (t) async {
    final p = FakeProvider();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    addTearDown(c.dispose);
    c.name.text = 'Name';
    c.phone.text = '00123';
    c.invoiceNumber.text = 'INV-001';
    c.fromDate.text = '2024-02-01 00:00:00';
    c.toDate.text = '2024-02-02 23:59:00';
    c.status = 'paid';
    c.zatcaStatus = 'failed';
    c.select(1, true);
    c.search.schedule();
    await t.pump(const Duration(milliseconds: 350));
    expect(p.applied.single['fromDate'], '2024-02-01 00:00:00');
    expect(c.selectedIds, isEmpty);
    c.name.text = 'pending';
    c.search.schedule();
    c.reset();
    await t.pump(const Duration(milliseconds: 400));
    expect(p.applied.length, 1);
    expect(c.query.isActive, false);
    expect(p.resets, 1);
    expect(p.resetReload, true);
    c.goToPage(2);
    await c.refresh();
    expect(p.loadedPage, 2);
    expect(p.loadedZatca, isNull);
    await c.export(showZatca: true);
    expect(p.applied.last['name'], '');
    expect(p.applied.last['fromDate'], '');
    expect(p.applied.last['zatcaStatus'], isNull);
  });
  testWidgets('export flushes pending search and freezes its inputs',
      (t) async {
    final p = FakeProvider()..pendingExport = Completer<List<Invoice>>();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    addTearDown(c.dispose);
    c.name.text = 'Captured';
    c.zatcaStatus = 'failed';
    c.search.schedule();
    final job = c.export(showZatca: false);
    expect(p.applied.length, 2);
    expect(p.applied.last['name'], 'Captured');
    expect(p.applied.last['zatcaStatus'], isNull);
    c.name.text = 'Edited';
    p.pendingExport!.complete([]);
    await job;
    await t.pump(const Duration(milliseconds: 400));
    expect(p.applied.length, 2);
  });
  testWidgets('page and refresh cancel pending debounce and clear selection',
      (t) async {
    final p = FakeProvider();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    addTearDown(c.dispose);
    c.selectPage([1, 2, 2]);
    expect(c.selectedIds.length, 2);
    c.search.schedule();
    c.goToPage(2);
    await t.pump(const Duration(milliseconds: 400));
    expect(p.applied, isEmpty);
    expect(c.selectedIds, isEmpty);
    c.select(1, true);
    c.search.schedule();
    await c.refresh();
    await t.pump(const Duration(milliseconds: 400));
    expect(p.applied, isEmpty);
    expect(c.selectedIds, isEmpty);
    expect(p.loadedPage, 2);
  });
  test(
      'silent exit clears filters without loading or notifying shared provider',
      () {
    final p = FakeProvider();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    addTearDown(c.dispose);
    c.name.text = 'Name';
    c.zatcaStatus = 'failed';
    c.select(1, true);
    c.reset(reload: false, notifyProvider: false);
    expect(c.query.isActive, false);
    expect(p.resetReload, false);
    expect(p.resetNotify, false);
    expect(p.loads, 0);
  });
  test('dispose ignores pending initialization and blocks unfinished export',
      () async {
    final p = FakeProvider()..pending = Completer<void>();
    final c = InvoiceListController(InvoiceListRepository(p),
        readToken: () => 'token');
    final task = c.load();
    c.dispose();
    p.pending!.complete();
    await task;
    expect(c.initialized, false);
    final p2 = FakeProvider()..pendingExport = Completer<List<Invoice>>();
    final c2 = InvoiceListController(InvoiceListRepository(p2),
        readToken: () => 'token');
    final job = c2.export(showZatca: true);
    c2.dispose();
    p2.pendingExport!.complete([]);
    await expectLater(job, throwsStateError);
  });
  test('missing token does not call backend', () async {
    final p = FakeProvider();
    final c =
        InvoiceListController(InvoiceListRepository(p), readToken: () => null);
    addTearDown(c.dispose);
    await expectLater(c.load(), throwsStateError);
    await c.refresh();
    await expectLater(c.export(showZatca: true), throwsStateError);
    expect(p.loads, 0);
    expect(p.exports, 0);
  });
}
