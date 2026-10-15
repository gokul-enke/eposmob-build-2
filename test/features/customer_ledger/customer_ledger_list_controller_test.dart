import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customer_ledger/data/customer_ledger_repository.dart';
import 'package:pos_machine/features/customer_ledger/presentation/state/customer_ledger_list_controller.dart';
import '../../screens/transactions/transaction_list_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late fixture.FakeProvider provider;
  late CustomerLedgerListController controller;
  setUp(() {
    provider = fixture.FakeProvider();
    controller = CustomerLedgerListController(
        CustomerLedgerRepository(provider),
        readToken: () => 'test-token');
  });
  tearDown(() => controller.dispose());
  test('complete local cache sequence reset and refresh restores API scope',
      () async {
    provider.handler = (q) async => fixture.page(
        q['page'], List.generate(25, (i) => fixture.row(i + 1)),
        total: 25);
    controller.amount.text = '10';
    controller.search.schedule();
    await controller.fetch();
    controller.search.cancel();
    expect(controller.rows.length, 20);
    expect(controller.totalPages, 2);
    expect(provider.queries.single['per_page'], 1000);
    controller.goToPage(2);
    await Future<void>.delayed(Duration.zero);
    expect(controller.rows.length, 5);
    expect(provider.queries.length, 1);
    final exported = await controller.exportRows();
    expect(exported.length, 25);
    expect(provider.queries.length, 1);
    expect(controller.currentPage, 2);
    await controller.refresh();
    expect(provider.queries.length, 2);
    expect(controller.currentPage, 1);
    controller.selectDate(DateTime(2026, 10, 1));
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries.last['date'], '2026-10-01');
    controller.reset();
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries.last['date'], isNull);
    expect(provider.queries.last['per_page'], 20);
    expect(controller.date, isNull);
    expect(provider.queries.every((q) => q['updateState'] == false), isTrue);
  });
  test('selection, editing and type changes preserve filter semantics',
      () async {
    await controller.fetch();
    controller.name.text = 'Test Customer';
    controller.selectCustomer(controller.rows.single);
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries.last['customer_id'], '1');
    expect(provider.queries.last['per_page'], 20);
    controller.name.text = 'Customer';
    controller.editCustomer();
    controller.search.flush();
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries.last['customer_id'], isNull);
    expect(provider.queries.last['per_page'], 1000);
    controller.selectType('Debit');
    await Future<void>.delayed(Duration.zero);
    expect(provider.queries.last['type'], 'debit');
  });
  test('old failure cannot overwrite newer load or stop its loading state',
      () async {
    final old = Completer<dynamic>(), latest = Completer<dynamic>();
    provider.handler =
        (q) => q['type'] == 'credit' ? old.future : latest.future;
    controller.type = 'Credit';
    final a = controller.fetch();
    controller.type = 'Debit';
    final b = controller.fetch();
    old.completeError(StateError('old failure'));
    await a;
    expect(controller.loading, isTrue);
    expect(controller.error, isNull);
    latest.complete(fixture.page(1, [fixture.row(22)]));
    await b;
    expect(controller.rows.single.id, 22);
    expect(controller.loading, isFalse);
  });
  test('pending export applies draft once and freezes its matching', () async {
    await controller.fetch();
    controller.reference.text = '0001';
    controller.search.schedule();
    final rows = await controller.exportRows();
    expect(rows.single.referenceId, '0001');
    expect(provider.queries.length, 2);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(provider.queries.length, 2);
    expect(controller.currentPage, 1);
  });
  test('later export page failure leaves visible rows and page unchanged',
      () async {
    await controller.fetch();
    provider.handler = (q) => q['page'] == 1
        ? Future.value(fixture.page(1, [fixture.row(1)], last: 2, total: 2))
        : Future.error(StateError('offline'));
    await expectLater(controller.exportRows(), throwsStateError);
    expect(controller.rows.single.id, 1);
    expect(controller.currentPage, 1);
    expect(controller.error, isNull);
  });
  test('export snapshot stays independent during a newer UI request', () async {
    await controller.fetch();
    final exportPage = Completer<dynamic>();
    provider.handler = (q) => q['per_page'] == 1000
        ? exportPage.future
        : Future.value(fixture.page(1, [fixture.row(9)]));
    final exporting = controller.exportRows();
    controller.type = 'Debit';
    await controller.fetch();
    exportPage.complete(fixture.page(1, [fixture.row(1)]));
    final result = await exporting;
    expect(result.single.id, 1);
    expect(controller.rows.single.id, 9);
    expect(provider.queries[1]['type'], isNull);
    expect(provider.queries.last['type'], 'debit');
  });
  test('disposing cancels debounce and prevents late load publication',
      () async {
    final response = Completer<dynamic>();
    provider.handler = (_) => response.future;
    final pending = controller.fetch();
    controller.search.schedule();
    controller.dispose();
    response.complete(fixture.page(1, [fixture.row(1)]));
    await pending;
    controller.reset();
    controller.editCustomer();
    controller.selectType('Credit');
    await controller.fetch();
    await expectLater(controller.exportRows(), throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(provider.queries.length, 1);
    expect(controller.rows, isEmpty);
    controller = CustomerLedgerListController(
        CustomerLedgerRepository(provider),
        readToken: () => 'test-token');
  });
}
