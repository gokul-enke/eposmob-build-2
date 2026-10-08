import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/quotations/data/quotation_list_repository.dart';
import 'package:pos_machine/features/quotations/presentation/state/quotation_list_controller.dart';
import '../../support/fake_quotation_list_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeQuotationListSource source;
  late QuotationListController controller;
  setUp(() {
    source = FakeQuotationListSource();
    controller = QuotationListController(source, () => 'token');
  });
  tearDown(() => controller.dispose());
  test('every filter reaches all pages; Reset clears dates and IDs', () async {
    controller.number.text = 'QTN';
    controller.customerId = '8';
    controller.storeId = 4;
    controller.status = 'Pending';
    controller.quotationDate = DateTime(2026, 9, 28);
    controller.expiryDate = DateTime(2026, 10, 28);
    await controller.search();
    await controller.load(2);
    expect(source.requests.last.page, 2);
    expect(source.requests.last.query.parameters(2, null),
        controller.query.parameters(2, null));
    expect(controller.current, 2);
    expect(controller.canExport, isTrue);
    await controller.reset();
    expect(controller.query.active, isFalse);
    expect(source.requests.last.query.parameters(1, null), {'page': '1'});
    expect(controller.current, 1);
  });
  test('filter failure keeps rows, blocks export and retries page one',
      () async {
    await controller.search();
    await controller.load(2);
    source.fail = true;
    controller.status = 'Pending';
    await controller.search();
    expect(controller.current, 2);
    expect(controller.rows.first.id, 4);
    expect(controller.error, isNotNull);
    expect(controller.canExport, isFalse);
    expect(controller.requestedPage, 1);
    source.fail = false;
    await controller.load(controller.requestedPage);
    expect(controller.current, 1);
    expect(controller.canExport, isTrue);
    source.fail = true;
    await controller.load(2);
    expect(controller.requestedPage, 2);
    source.fail = false;
    await controller.load(controller.requestedPage);
    expect(controller.current, 2);
  });
  test('stale request cannot replace a newer success or failure', () async {
    final old = Completer<QuotationListPageData>();
    source.handler = (q, page) async => q.number == 'old'
        ? await old.future
        : QuotationListPageData(
            rows: [quotation(2)], current: 1, last: 1, from: 1);
    controller.number.text = 'old';
    final request = controller.search();
    controller.number.text = 'new';
    await controller.search();
    old.complete(QuotationListPageData(
        rows: [quotation(1)], current: 1, last: 1, from: 1));
    await request;
    expect(controller.rows.single.id, 2);
    expect(controller.applied!.number, 'new');
  });
  testWidgets(
      'typing, pagination and export flush pending filters; undone edits preserve page',
      (tester) async {
    await controller.search();
    await controller.load(2);
    controller.number.text = 'QTN';
    controller.scheduleSearch();
    await controller.prepareExport();
    expect(controller.applied!.number, 'QTN');
    expect(controller.current, 1);
    await controller.load(2);
    final requests = source.requests.length;
    controller.number.text = 'QTNx';
    controller.scheduleSearch();
    controller.number.text = 'QTN';
    controller.scheduleSearch();
    await controller.prepareExport();
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.current, 2);
    expect(source.requests.length, requests);
    controller.number.text = 'other';
    controller.scheduleSearch();
    await controller.load(2);
    expect(source.requests.last.page, 1);
    await tester.pump(const Duration(milliseconds: 350));
    expect(source.requests.last.query.number, 'other');
  });
  test('session invalidation discards rows and pending responses', () async {
    await controller.search();
    final old = Completer<QuotationListPageData>();
    source.handler = (_, __) => old.future;
    final request = controller.load(2);
    controller.invalidateSession();
    expect(controller.rows, isEmpty);
    expect(controller.canExport, isFalse);
    old.complete(QuotationListPageData(
        rows: [quotation(4)], current: 2, last: 2, from: 4));
    await request;
    expect(controller.rows, isEmpty);
    expect(controller.applied, isNull);
  });
  test('literal quotation search text cannot hide a changed customer filter',
      () async {
    controller.number.text = 'QTN, customer_id: 8';
    await controller.search();
    final requests = source.requests.length;
    controller.number.text = 'QTN';
    controller.customerId = '8';
    await controller.prepareExport();
    expect(source.requests.length, requests + 1);
    expect(controller.applied!.number, 'QTN');
    expect(controller.applied!.customerId, '8');
  });
  testWidgets('disposal cancels debounces and ignores late responses',
      (tester) async {
    final old = Completer<QuotationListPageData>();
    source.handler = (_, __) => old.future;
    final request = controller.search();
    controller.number.text = 'changed';
    controller.scheduleSearch();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();
    old.complete(QuotationListPageData(rows: [], current: 1, last: 1, from: 1));
    await request;
    await tester.pump(const Duration(milliseconds: 350));
    expect(notifications, 0);
    expect(source.requests, hasLength(1));
    controller = QuotationListController(source, () => 'token');
  });
}
