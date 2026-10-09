import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/features/supplier_ledger/data/supplier_ledger_repository.dart';
import 'package:pos_machine/features/supplier_ledger/domain/supplier_ledger_query.dart';
import 'package:pos_machine/features/supplier_ledger/presentation/state/supplier_ledger_list_controller.dart';

TransactionModel _transaction() => TransactionModel.withIndex(
    TransactionModel.fromJson({
      'id': 1,
      'supplier_id': 7,
      'date': '2026-10-01',
      'type': 'Credit',
      'transaction_type': 'Invoice',
      'payment_mode': 'CASH',
      'amount': '250.00',
      'currency': 'INR',
      'reference': 'INV-TEST-001',
      'status': 'SUCCESS',
      'user_id': 1,
      'created_at': '',
      'updated_at': '',
      'supplier': {
        'id': 7,
        'user_id': 1,
        'balance': '250.00',
        'created_at': '',
        'updated_at': '',
        'user': {
          'id': 1,
          'name': 'Test Supplier',
          'email': '',
          'phone': '',
          'phone_verified': 0,
          'company_id': 1,
          'created_at': '',
          'updated_at': ''
        }
      }
    }),
    0);

class FakeRepository extends SupplierLedgerRepository {
  FakeRepository() : super(TransactionProvider());
  final pages = <(SupplierLedgerQuery, int)>[];
  final snapshots = <SupplierLedgerQuery>[];
  final pendingPages = <Completer<SupplierLedgerPage>>[];
  final pendingSnapshots = <Completer<List<TransactionModel>>>[];
  bool deferPages = false, deferSnapshots = false;
  List<TransactionModel> source = List.generate(120, (_) => _transaction());
  @override
  String? supplierId(String name) => name == 'Test Supplier' ? '7' : null;
  @override
  List<String> get supplierOptions => ['Test Supplier'];
  @override
  Future<SupplierLedgerPage> fetchPage(
      SupplierLedgerQuery query, int page, int pageSize) {
    pages.add((query, page));
    if (deferPages) {
      final c = Completer<SupplierLedgerPage>();
      pendingPages.add(c);
      return c.future;
    }
    return Future.value(SupplierLedgerPage([_transaction()], page, 3));
  }

  @override
  Future<List<TransactionModel>> snapshot(SupplierLedgerQuery query,
      {bool applyLocalFilters = false, void Function(int, int)? onProgress}) {
    snapshots.add(query);
    if (deferSnapshots) {
      final c = Completer<List<TransactionModel>>();
      pendingSnapshots.add(c);
      return c.future;
    }
    return Future.value(applyLocalFilters ? filter(source, query) : source);
  }
}

Future<void> tick() => Future.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRepository repo;
  late SupplierLedgerListController list;
  setUp(() {
    repo = FakeRepository();
    list = SupplierLedgerListController(repo);
  });
  tearDown(() => list.dispose());
  test(
      'local filtering, cached pagination, known supplier, reset and refresh sequence',
      () async {
    await list.fetchPage(1);
    list.searchController.text = 'INV-TEST';
    list.searchTransactions();
    await tick();
    expect(list.items.length, 50);
    expect(list.totalPages, 3);
    expect(repo.snapshots.length, 1);
    await list.fetchPage(3);
    expect(list.items.length, 20);
    list.statusController.text = 'SUCCESS';
    list.searchTransactions();
    await tick();
    expect(list.currentPage, 1);
    expect(repo.snapshots.length, 1);
    await list.refresh();
    expect(repo.snapshots.length, 2);
    list.supplierSearchController.text = 'Test Supplier';
    list.searchTransactions();
    await tick();
    expect(repo.snapshots.last.supplierId, '7');
    list.resetSearch();
    await tick();
    expect(list.hasActiveFilters, false);
    expect(list.currentPage, 1);
    expect(repo.pages.last.$1.supplierId, isNull);
    list.supplierSearchController.text = 'Test Supplier';
    list.typeController.text = 'Credit';
    list.transactionTypeController.text = 'Invoice';
    await list.fetchPage(2);
    expect(repo.pages.last.$1.supplierId, '7');
    expect(repo.pages.last.$1.type, 'Credit');
    expect(repo.pages.last.$1.transactionType, 'Invoice');
    expect(repo.pages.last.$2, 2);
    list.supplierSearchController.text = 'Unknown';
    list.searchTransactions();
    await tick();
    expect(list.items, isEmpty);
    expect(list.currentPage, 1);
    expect(list.totalPages, 1);
  });
  test('latest local query wins when complete snapshots finish out of order',
      () async {
    repo.deferSnapshots = true;
    list.searchController.text = 'INV';
    final old = list.fetchPage(1);
    list.typeController.text = 'Debit';
    list.searchController.text = 'notfound';
    final latest = list.fetchPage(1);
    repo.pendingSnapshots[1].complete([_transaction()]);
    await latest;
    expect(list.items, isEmpty);
    expect(list.loading, false);
    repo.pendingSnapshots[0].complete([_transaction()]);
    await old;
    expect(list.items, isEmpty);
    expect(list.typeController.text, 'Debit');
  });
  test(
      'overlapping server pages are serialized and stale results never publish',
      () async {
    repo.deferPages = true;
    final first = list.fetchPage(1);
    await tick();
    list.typeController.text = 'Debit';
    final latest = list.fetchPage(2);
    await tick();
    expect(repo.pages.length, 1);
    repo.pendingPages[0].complete(SupplierLedgerPage([_transaction()], 1, 3));
    await first;
    await tick();
    expect(list.items, isEmpty);
    expect(list.loading, true);
    expect(repo.pages.length, 2);
    expect(repo.pages.last.$1.type, 'Debit');
    repo.pendingPages[1].complete(const SupplierLedgerPage([], 2, 3));
    await latest;
    expect(list.currentPage, 2);
    expect(list.items, isEmpty);
    expect(list.loading, false);
  });
  test('failed local snapshot is retried and never presents unfiltered rows',
      () async {
    final errors = <Object>[];
    list.dispose();
    list = SupplierLedgerListController(repo, onError: errors.add);
    await list.fetchPage(1);
    repo.deferSnapshots = true;
    list.searchController.text = 'INV';
    final failure = list.fetchPage(1);
    repo.pendingSnapshots[0].completeError(StateError('offline'));
    await failure;
    expect(errors.length, 1);
    expect(list.hasLoadError, true);
    expect(list.items, isEmpty);
    expect(list.loading, false);
    final retry = list.refresh();
    expect(repo.pendingSnapshots.length, 2);
    repo.pendingSnapshots[1].complete(repo.source);
    await retry;
    expect(list.items.length, 50);
    expect(list.hasLoadError, false);
  });
  test('export freezes all filter values and does not mutate the visible page',
      () async {
    await list.fetchPage(2);
    repo.deferSnapshots = true;
    list.searchController.text = 'INV';
    list.supplierSearchController.text = 'Test Supplier';
    list.typeController.text = 'Credit';
    list.transactionTypeController.text = 'Invoice';
    list.statusController.text = 'SUCCESS';
    final export = list.exportRows();
    list.searchController.text = 'other';
    list.typeController.text = 'Debit';
    expect(repo.snapshots.single.search, 'INV');
    expect(repo.snapshots.single.type, 'Credit');
    expect(repo.snapshots.single.supplierId, '7');
    expect(repo.snapshots.single.status, 'SUCCESS');
    repo.pendingSnapshots.single.complete([_transaction()]);
    expect((await export).length, 1);
    expect(list.currentPage, 2);
    expect(list.items.length, 1);
    expect(list.loading, false);
  });
  test('late requests and queued searches do not publish after disposal',
      () async {
    repo.deferSnapshots = true;
    list.searchController.text = 'INV';
    var notifications = 0;
    list.addListener(() => notifications++);
    final request = list.fetchPage(1);
    list.search.schedule();
    list.dispose();
    final before = notifications;
    repo.pendingSnapshots.single.complete([_transaction()]);
    await request;
    await tick();
    expect(notifications, before);
    expect(repo.snapshots.length, 1);
    list = SupplierLedgerListController(repo);
  });
  test('two local edits share a snapshot but only the latest filter publishes',
      () async {
    repo.deferSnapshots = true;
    list.searchController.text = 'missing';
    final old = list.fetchPage(1);
    list.searchController.text = 'INV';
    list.searchTransactions();
    expect(repo.pendingSnapshots.length, 1);
    repo.pendingSnapshots.single.complete(repo.source);
    await old;
    await tick();
    expect(list.items.length, 50);
    expect(list.totalPages, 3);
    expect(repo.snapshots.length, 1);
  });
  test('stale failure cannot mark the latest successful query as failed',
      () async {
    final errors = <Object>[];
    list.dispose();
    list = SupplierLedgerListController(repo, onError: errors.add);
    repo.deferSnapshots = true;
    list.searchController.text = 'INV';
    final old = list.fetchPage(1);
    list.typeController.text = 'Debit';
    list.searchTransactions();
    repo.pendingSnapshots[1].complete(repo.source);
    await tick();
    repo.pendingSnapshots[0].completeError(StateError('old failure'));
    await old;
    expect(errors, isEmpty);
    expect(list.hasLoadError, false);
    expect(list.items.length, 50);
  });
  test('disposing cancels queued server calls and late publication', () async {
    repo.deferPages = true;
    final old = list.fetchPage(1);
    await tick();
    final queued = list.fetchPage(2);
    list.dispose();
    repo.pendingPages.single
        .complete(SupplierLedgerPage([_transaction()], 1, 3));
    await old;
    await queued;
    expect(repo.pages.length, 1);
    list = SupplierLedgerListController(repo);
  });
}
