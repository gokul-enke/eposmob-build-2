import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/data/sales_list_repository.dart';
import 'package:pos_machine/features/sales/domain/sales_list_query.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_list_controller.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/providers/sales_provider.dart';

class Source implements SalesListSource {
  final requests =
      <({SalesListQuery query, int page, Completer<SalesListPageData> done})>[];
  @override
  Future<SalesListPageData> fetch(
      String token, SalesListQuery query, int page) {
    final done = Completer<SalesListPageData>();
    requests.add((query: query, page: page, done: done));
    return done.future;
  }

  void complete(int index, {int? id, String? status}) {
    final request = requests[index];
    request.done.complete(SalesListPageData(
        rows: [
          ListOrderModelData(
              id: id ?? index + 1, grantTotal: '10', status: status)
        ],
        current: request.page,
        last: 3,
        from: (request.page - 1) * 10 + 1,
        perPage: 10));
  }

  @override
  Future<List<ListOrderModelData>> snapshot(String token, SalesListQuery query,
          {void Function(int, int)? progress}) =>
      throw UnimplementedError();
}

void main() {
  test('failed filter changes retain rows but retries request page one',
      () async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    var load = c.load(2);
    source.complete(0);
    await load;
    c.status = 'pending';
    load = c.search();
    source.requests.last.done.completeError(StateError('offline'));
    await load;
    expect(c.current, 2);
    expect(c.requestedPage, 1);
    expect(c.canExport, false);
    load = c.refresh();
    expect(source.requests.last.page, 1);
    expect(source.requests.last.query.status, 'pending');
    source.complete(2);
    await load;
    expect(c.current, 1);
    expect(c.canExport, true);
  });
  test('older responses never replace newer filter results', () async {
    final source = Source();
    final controller = SalesListController(source, () => 'token');
    addTearDown(controller.dispose);
    final old = controller.load(1);
    controller.number.text = 'new';
    final newer = controller.search();
    source.complete(1, id: 9);
    await newer;
    source.complete(0, id: 1);
    await old;
    expect(controller.rows.single.id, 9);
    expect(controller.applied!.number, 'new');
  });
  testWidgets(
      'export flushes pending search and reset clears all visible filters',
      (tester) async {
    final source = Source();
    final controller = SalesListController(source, () => 'token');
    addTearDown(controller.dispose);
    var load = controller.load(2);
    source.complete(0);
    await load;
    controller.customer.text = 'Ann';
    controller.scheduleSearch();
    final prepare = controller.prepareExport();
    expect(source.requests.last.query.customer, 'Ann');
    expect(source.requests.last.page, 1);
    source.complete(1);
    await prepare;
    controller.phone.text = '00123';
    controller.price.text = '10';
    controller.number.text = 'old';
    controller.from = DateTime(2026);
    controller.until = DateTime(2026, 2);
    controller.businessDate = DateTime(2026, 1, 5);
    controller.status = 'new';
    load = controller.reset();
    expect(source.requests.last.query.active, false);
    source.complete(2);
    await load;
    await tester.pump(const Duration(seconds: 1));
    expect(source.requests, hasLength(3));
  });
  testWidgets('undoing pending input keeps the current page', (tester) async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    final load = c.load(2);
    source.complete(0);
    await load;
    c.number.text = 'abc';
    c.scheduleSearch();
    c.number.clear();
    c.scheduleSearch();
    await tester.pump(const Duration(milliseconds: 500));
    expect(source.requests, hasLength(1));
    expect(c.current, 2);
  });
  testWidgets('abandoned search preserves an in-flight mutation refresh',
      (tester) async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    var load = c.load(2);
    source.complete(0, id: 1, status: 'confirmed');
    await load;
    load = c.refresh();
    c.customer.text = 'x';
    c.scheduleSearch();
    c.customer.clear();
    c.scheduleSearch();
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.loading, true);
    expect(source.requests, hasLength(2));
    source.complete(1, id: 1, status: 'cancelled');
    await load;
    expect(c.rows.single.id, 1);
    expect(c.rows.single.status, 'cancelled');
    expect(c.current, 2);
    expect(c.loading, false);
  });
  testWidgets('undoing a running filter replaces it with the restored query',
      (tester) async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    var load = c.load(2);
    source.complete(0);
    await load;
    c.customer.text = 'Ann';
    final filtered = c.search();
    c.customer.clear();
    c.scheduleSearch();
    await tester.pump(const Duration(milliseconds: 500));
    expect(source.requests, hasLength(3));
    expect(source.requests.last.query.customer, isEmpty);
    source.complete(2, id: 9);
    await tester.pump();
    source.complete(1, id: 1);
    await filtered;
    expect(c.rows.single.id, 9);
    expect(c.matchesInputs, true);
  });
  test('online scope survives Reset, pagination and refresh', () async {
    final source = Source();
    final c = SalesListController(source, () => 'token', isOnlineSales: true);
    addTearDown(c.dispose);
    var load = c.load(2);
    source.complete(0);
    await load;
    c.phone.text = '00123';
    load = c.reset();
    source.complete(1);
    await load;
    load = c.refresh();
    source.complete(2);
    await load;
    expect(source.requests.every((r) => r.query.isOnlineSales), true);
    expect(c.query.active, false);
    expect(c.query.parameters(1, null)['filter_online_sales'], 'true');
  });
  test(
      'session invalidation discards in-flight results and old export eligibility',
      () async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    final load = c.load(1);
    c.invalidateSession(7);
    source.complete(0);
    await load;
    expect(c.rows, isEmpty);
    expect(c.canExport, false);
    expect(c.query.storeId, 7);
  });
  test('realtime refresh keeps the shown page and pending typed filters',
      () async {
    final source = Source();
    final c = SalesListController(source, () => 'token');
    addTearDown(c.dispose);
    var load = c.load(2);
    source.complete(0);
    await load;
    c.email.text = 'ann@';
    c.scheduleSearch();
    load = c.refreshShown();
    expect(source.requests.last.page, 2);
    expect(source.requests.last.query.email, '');
    source.complete(1);
    await load;
    expect(c.current, 2);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(source.requests.last.page, 1);
    expect(source.requests.last.query.email, 'ann@');
    expect(
        source.requests.last.query.parameters(1, null)['filter_email'], 'ann@');
  });
  test('realtime refresh routes to the current listing and detaches by owner',
      () async {
    final provider = SalesProvider(), first = Object(), second = Object();
    var count = 0;
    provider.attachListRefresh(first, () async => count += 1);
    provider.attachListRefresh(second, () async => count += 10);
    provider.detachListRefresh(first);
    await provider.refreshOrdersForRealtime(accessToken: 'token', storeId: 7);
    expect(count, 10);
    provider.detachListRefresh(second);
    provider.dispose();
  });
}
