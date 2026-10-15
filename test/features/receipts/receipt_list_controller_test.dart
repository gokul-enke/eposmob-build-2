import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/receipts/data/receipt_list_repository.dart';
import 'package:pos_machine/features/receipts/domain/receipt_list_query.dart';
import 'package:pos_machine/features/receipts/presentation/state/receipt_list_controller.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends ReceiptListRepository {
  _Repository() : super(InvoiceProvider());
  int loads = 0, resets = 0;
  final pages = <int>[];
  final applied = <ReceiptListQuery>[];
  ReceiptListQuery? exported;
  Completer<void>? loadGate;
  Completer<List<Receipt>>? exportGate;
  Object? loadError;

  @override
  Future<void> load(String token) async {
    loads++;
    if (loadError != null) throw loadError!;
    await loadGate?.future;
  }

  @override
  void apply(ReceiptListQuery q) => applied.add(q);
  @override
  void reset() => resets++;
  @override
  void goToPage(int page) => pages.add(page);
  @override
  Future<List<Receipt>> export(String token, ReceiptListQuery q,
      {void Function(int, int)? onProgress}) async {
    exported = q;
    return await exportGate?.future ?? <Receipt>[];
  }
}

Receipt receipt(int id, {String method = 'Cash', String status = 'paid'}) =>
    Receipt.fromJson({
      'id': id,
      'receipt_number': '000$id',
      'amount': '1.00',
      'payment_reference': 'REF-0$id',
      'receipt_status': status,
      'payment_method': method,
      'customer': {
        'user': {'name': 'Alice', 'phone': '00123', 'email': 'A@Example.com'}
      },
      'created_at': '2026-10-01T12:00:00',
      'updated_at': '2026-10-01T12:00:00',
      'receipt_payments': [],
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('matching preserves case, substring, leading zero and exact code rules',
      () {
    final rows = [receipt(1), receipt(2, method: 'Card', status: 'pending')];
    expect(
        matchReceiptList(rows,
                filterName: ' ALI ',
                filterReceiptNumber: '000',
                filterPaymentReference: 'ref',
                filterPhone: '001',
                filterEmail: 'example',
                filterStatus: ' PAID ',
                filterPaymentMethod: 'cash')
            .map((r) => r.id),
        [1]);
    expect(matchReceiptList(rows, filterPaymentMethod: 'Ca'), isEmpty);
    expect(matchReceiptList(rows, filterStatus: 'pai'), isEmpty);
    expect(matchReceiptList(rows, filterName: '  '), hasLength(2));
    expect(formatReceiptApiDate('01/10/2026'), '2026-10-01');
    expect(formatReceiptApiDate('2026-10-01 23:59:00'), '2026-10-01 23:59:00');
    expect(const ReceiptListQuery().isActive, isFalse);
  });

  test('initial load succeeds once and errors remain retryable', () async {
    final repository = _Repository();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    addTearDown(controller.dispose);
    repository.loadError = StateError('offline');
    await expectLater(controller.load(), throwsStateError);
    expect(controller.initialized, isFalse);
    repository.loadError = null;
    await controller.load();
    await controller.load();
    expect(controller.initialized, isTrue);
    expect(repository.loads, 2);
  });

  testWidgets('search then date/status/method, reset, page, refresh and export',
      (tester) async {
    final repository = _Repository();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    addTearDown(controller.dispose);
    await controller.load();
    controller.name.text = 'Alice';
    controller.search.schedule();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.applied.single.name, 'Alice');
    controller.receiptNumber.text = '0001';
    controller.paymentReference.text = 'REF';
    controller.phone.text = '001';
    controller.email.text = 'a@example.com';
    controller.fromDate.text = '2026-10-01 00:00:00';
    controller.toDate.text = '2026-10-01 23:59:00';
    controller.status = 'paid';
    controller.paymentMethod = 'Cash';
    controller.apply();
    final q = repository.applied.last;
    expect(q.phone, '001');
    expect(q.email, 'a@example.com');
    expect(q.receiptNumber, '0001');
    expect(q.paymentReference, 'REF');
    expect(q.fromDate, '2026-10-01 00:00:00');
    expect(q.toDate, '2026-10-01 23:59:00');
    expect(q.status, 'paid');
    expect(q.paymentMethod, 'Cash');
    controller.search.schedule();
    controller.reset();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.applied, hasLength(2));
    expect(repository.resets, 1);
    expect(controller.query.isActive, isFalse);
    expect(controller.inputs.every((input) => input.text.isEmpty), isTrue);
    controller.goToPage(2);
    await controller.refresh();
    await controller.export();
    expect(repository.pages, [2]);
    expect(repository.loads, 2);
    expect(repository.exported!.isActive, isFalse);
  });

  testWidgets('pending search wins over pagination and runs only once',
      (tester) async {
    final repository = _Repository();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    addTearDown(controller.dispose);
    controller.receiptNumber.text = '0002';
    controller.search.schedule();
    controller.goToPage(3);
    expect(repository.pages, isEmpty);
    expect(repository.applied.single.receiptNumber, '0002');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.applied, hasLength(1));
    controller.goToPage(2);
    expect(repository.pages, [2]);
  });

  testWidgets('export flushes pending filters and freezes all captured values',
      (tester) async {
    final repository = _Repository()..exportGate = Completer<List<Receipt>>();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    addTearDown(controller.dispose);
    controller.name.text = 'Alice';
    controller.status = 'paid';
    controller.fromDate.text = '2026-10-01 00:00:00';
    controller.search.schedule();
    final result = controller.export();
    controller.name.text = 'Bob';
    controller.status = 'pending';
    controller.fromDate.clear();
    repository.exportGate!.complete([]);
    await result;
    expect(repository.exported!.name, 'Alice');
    expect(repository.exported!.status, 'paid');
    expect(repository.exported!.fromDate, '2026-10-01 00:00:00');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.applied, hasLength(1));
  });

  testWidgets('dispose cancels searches and ignores unfinished initialization',
      (tester) async {
    final repository = _Repository()..loadGate = Completer<void>();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    int notices = 0;
    controller.addListener(() => notices++);
    final load = controller.load();
    controller.search.schedule();
    controller.dispose();
    repository.loadGate!.complete();
    await load;
    await tester.pump(const Duration(milliseconds: 400));
    expect(notices, 0);
    expect(repository.applied, isEmpty);
    controller.apply();
    controller.reset();
    controller.goToPage(2);
    await controller.refresh();
    expect(repository.resets, 0);
    expect(repository.pages, isEmpty);
    expect(repository.loads, 1);
  });

  test('closed page blocks unfinished export and missing token blocks requests',
      () async {
    final repository = _Repository()..exportGate = Completer<List<Receipt>>();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    final pending = controller.export();
    final check = expectLater(pending, throwsStateError);
    controller.dispose();
    repository.exportGate!.complete([]);
    await check;
    await expectLater(controller.export(), throwsStateError);
    final unauthenticated =
        ReceiptListController(repository, readToken: () => null);
    addTearDown(unauthenticated.dispose);
    await expectLater(unauthenticated.load(), throwsStateError);
    await expectLater(unauthenticated.refresh(), throwsStateError);
    await expectLater(unauthenticated.export(), throwsStateError);
    expect(repository.loads, 0);
  });
}
