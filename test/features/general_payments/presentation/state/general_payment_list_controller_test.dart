import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/domain/models/general_payment.dart';
import 'package:pos_machine/features/general_payments/presentation/state/general_payment_list_controller.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import '../../support/general_payment_fixtures.dart';

/// Answers loads with [rows]; [gate] holds the answer back, [fail] throws.
class _Server {
  List<GeneralPayment> rows = mixedPayments();
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;

  Future<List<GeneralPayment>?> fetch(bool Function() isCurrent) async {
    calls++;
    final answer = List.of(rows);
    final wait = gate;
    if (wait != null) await wait.future;
    if (fail) throw StateError('down');
    return isCurrent() ? answer : null;
  }
}

final _now = DateTime(2026, 10, 30, 15);

GeneralPaymentListController _list(_Server server) =>
    GeneralPaymentListController(fetch: server.fetch, clock: () => _now);

List<String> _refs(GeneralPaymentListController list) =>
    [for (final row in list.pageRows) row.referenceNumber];

void main() {
  test('loads every entry with the four totals', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    expect(list.loaded, isFalse);
    final load = list.load();
    expect(list.loading, isTrue);
    await load;
    expect(list.loading, isFalse);
    expect(list.loaded, isTrue);
    expect(_refs(list),
        ['EXP00184', 'LON00177', 'INC00176', 'EXP00175', 'AST00030']);
    expect(list.totals[GeneralPaymentType.expense], 2050);
    expect(list.totals[GeneralPaymentType.asset], 32800);
    expect(list.totals[GeneralPaymentType.income], 2000);
    expect(list.totals[GeneralPaymentType.loan], 2000);
    expect((list.matchCount, list.totalCount), (5, 5));
    expect(list.canExport, isTrue);
  });

  test('filters and totals follow the chosen entry type', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.setType(GeneralPaymentType.expense);
    expect(_refs(list), ['EXP00184', 'EXP00175']);
    expect(list.totals[GeneralPaymentType.income], 0);
    expect(list.totals[GeneralPaymentType.expense], 2050);
    expect(list.categoryOptions,
        {'11054': 'Office Expenses', '8192': 'Transportation'});
    expect(list.debitAccountOptions.keys, ['20', '15']);
    expect(list.hasActiveFilters, isTrue);
  });

  test('changing the type drops a category or account it does not use',
      () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.setCategory('8497'); // Term Loan
    list.setCreditAccount('11'); // Cash Account
    expect(_refs(list), ['LON00177']);
    list.setType(GeneralPaymentType.loan);
    expect(
        (list.filter.categoryId, list.filter.creditAccountId), ('8497', '11'));
    list.setType(GeneralPaymentType.income);
    expect(list.filter.categoryId, isNull);
    expect(list.filter.creditAccountId, isNull);
    expect(_refs(list), ['INC00176']);
  });

  test('New Entry gets the next number of every reference series', () async {
    final server = _Server()
      ..rows = [
        ...mixedPayments(),
        payment(189, type: 'LOAN_REPAY', amount: 5000),
      ];
    final list = _list(server);
    addTearDown(list.dispose);
    expect(list.nextReferences, isEmpty, reason: 'nothing loaded yet');
    await list.load();
    expect(list.nextReferences, {
      'EXP': 'EXP00185',
      'AST': 'AST00031',
      'INC': 'INC00177',
      'LON': 'LON00178',
      'LRP': 'LRP00190',
    });
    expect(list.totals[GeneralPaymentType.loan], 7000,
        reason: 'repayments count in Total Loan');
  });

  test('typing a reference filters at once and returns to page one', () async {
    final server = _Server()
      ..rows = [for (var id = 60; id > 0; id--) payment(id)];
    final list = _list(server);
    addTearDown(list.dispose);
    await list.load();
    expect((list.page, list.totalPages, list.pageRows.length), (1, 3, 25));
    list.goToPage(3);
    expect((list.page, list.pageRows.length), (3, 10));
    list.reference.text = '0005';
    expect(list.page, 1);
    expect(_refs(list), [
      'EXP00059',
      'EXP00058',
      'EXP00057',
      'EXP00056',
      'EXP00055',
      'EXP00054',
      'EXP00053',
      'EXP00052',
      'EXP00051',
      'EXP00050',
      'EXP00005',
    ]);
  });

  test('a reload keeps the page; a filter change goes back to page one',
      () async {
    final server = _Server()
      ..rows = [for (var id = 60; id > 0; id--) payment(id)];
    final list = _list(server);
    addTearDown(list.dispose);
    await list.load();
    list.goToPage(2);
    await list.load();
    expect(list.page, 2);
    list.setDebitAccount('15');
    expect(list.page, 1);
  });

  test('date presets and the custom range filter by payment day', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.setPeriod(ReportPeriod.lastMonth);
    expect(_refs(list), ['LON00177', 'INC00176', 'EXP00175']);
    // Custom starts from the range on screen.
    list.setPeriod(ReportPeriod.custom);
    expect((list.filter.customFrom, list.filter.customTo),
        (DateTime(2026, 9), DateTime(2026, 9, 30)));
    expect(_refs(list), hasLength(3));
    list.setCustomDate(DateTime(2026, 10, 3, 18), from: false);
    expect(list.filter.customTo, DateTime(2026, 10, 3));
    expect(_refs(list), hasLength(4));
    list.setPeriod(null);
    expect((list.filter.customFrom, list.filter.customTo), (null, null));
    expect(_refs(list), hasLength(5));
  });

  test('an inverted custom range shows nothing and says why', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.setCustomDate(DateTime(2026, 10, 3), from: true);
    list.setCustomDate(DateTime(2026, 9, 1), from: false);
    expect(list.filterErrorKey, GeneralPaymentListController.invertedDates);
    expect(list.pageRows, isEmpty);
    expect(list.canExport, isFalse);
    list.setCustomDate(null, from: true);
    expect(list.filterErrorKey, isNull);
  });

  test('reset clears every filter including the typed reference', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.reference.text = 'INC';
    list.setType(GeneralPaymentType.income);
    list.setPeriod(ReportPeriod.thisMonth);
    expect(list.pageRows, isEmpty);
    list.reset();
    expect(list.reference.text, isEmpty);
    expect(list.hasActiveFilters, isFalse);
    expect(list.pageRows, hasLength(5));
    expect(list.appliedFilters, isEmpty);
  });

  test('applied filters name the choices for the export', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.reference.text = ' 17 ';
    list.setType(GeneralPaymentType.loan);
    list.setCategory('8497');
    list.setDebitAccount('376');
    list.setCustomDate(DateTime(2026, 9, 1), from: true);
    expect(list.appliedFilters, [
      ('general_payments.filter_reference', '17', translate: false),
      (
        'general_payments.filter_entry_type',
        'general_payments.type_loan',
        translate: true
      ),
      ('general_payments.filter_category', 'Term Loan', translate: false),
      (
        'general_payments.filter_debit_account',
        'Loan Account',
        translate: false
      ),
      (
        'general_payments.filter_date_range',
        'report_period.custom',
        translate: true
      ),
      ('general_payments.from_date', '2026-09-01', translate: false),
    ]);
  });

  test('a failed reload keeps the entries, says so and blocks export',
      () async {
    final server = _Server();
    final list = _list(server);
    addTearDown(list.dispose);
    await list.load();
    server.fail = true;
    await list.load();
    expect(list.errorKey, GeneralPaymentListController.loadError);
    expect(list.pageRows, hasLength(5));
    expect(list.canExport, isFalse);
    server.fail = false;
    await list.load();
    expect(list.errorKey, isNull);
    expect(list.canExport, isTrue);
  });

  test('a first load that fails shows the error with nothing loaded', () async {
    final list = _list(_Server()..fail = true);
    addTearDown(list.dispose);
    await list.load();
    expect(list.errorKey, GeneralPaymentListController.loadError);
    expect(list.loaded, isFalse);
    expect(list.pageRows, isEmpty);
  });

  test('a newer load wins over an older answer', () async {
    final server = _Server()..gate = Completer();
    final list = _list(server);
    addTearDown(list.dispose);
    final first = list.load();
    final late = server.gate!;
    server
      ..rows = [payment(9)]
      ..gate = null;
    await list.load();
    expect(_refs(list), ['EXP00009']);
    // The first load's answer (every entry) arrives after the newer one.
    late.complete();
    await first;
    expect(_refs(list), ['EXP00009']);
    expect(list.loading, isFalse);
  });

  test('clearing for a session change drops the old entries at once', () async {
    final server = _Server();
    final list = _list(server);
    addTearDown(list.dispose);
    await list.load();
    server.gate = Completer();
    final load = list.load(clear: true);
    expect(list.pageRows, isEmpty);
    expect(list.loaded, isFalse);
    server.gate!.complete();
    await load;
    expect(list.pageRows, hasLength(5));
  });

  test('a reload drops a category or account the new entries do not use',
      () async {
    final server = _Server();
    final list = _list(server);
    addTearDown(list.dispose);
    await list.load();
    list.setCategory('8497'); // Term Loan
    list.setDebitAccount('376'); // Loan Account
    list.setCreditAccount('11'); // Cash Account
    list.setPeriod(ReportPeriod.lastMonth);
    expect(_refs(list), ['LON00177']);
    // Another store: no loans, and only cash and bank accounts.
    server.rows = [payment(5, date: '2026-09-10')];
    await list.load(clear: true);
    expect(list.filter.categoryId, isNull);
    expect(list.filter.debitAccountId, isNull);
    expect(list.filter.creditAccountId, '11', reason: 'still used');
    expect(list.filter.period, ReportPeriod.lastMonth, reason: 'not a choice');
    expect(_refs(list), ['EXP00005']);
  });

  test('a reload keeps choices the entries still use', () async {
    final list = _list(_Server());
    addTearDown(list.dispose);
    await list.load();
    list.setCategory('8491');
    await list.load();
    expect(list.filter.categoryId, '8491');
    expect(_refs(list), ['INC00176']);
  });

  test('an answer after dispose changes nothing', () async {
    final server = _Server()..gate = Completer();
    final list = _list(server);
    final load = list.load();
    list.dispose();
    server.gate!.complete();
    await load;
    expect(list.loaded, isFalse);
  });
}
