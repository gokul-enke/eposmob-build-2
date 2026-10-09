import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/features/proforma_invoices/data/proforma_list_repository.dart';
import 'package:pos_machine/features/proforma_invoices/presentation/state/proforma_list_controller.dart';

Map<String, dynamic> response(int page, {int last = 3, int id = 1}) => {
      'data': {
        'current_page': page,
        'last_page': last,
        'data': [
          {'id': id, 'invoice_number': '000$id'}
        ]
      }
    };

class RecordingProvider extends QuotationsProvider {
  final calls = <Map<String, String>>[];
  Future<Map<String, dynamic>> Function(Map<String, String>)? handler;
  @override
  Future<Map<String, dynamic>> fetchProformaInvoices(
      {required String accessToken, Map<String, String>? filters}) async {
    final query = Map<String, String>.of(filters!);
    calls.add(query);
    return handler != null
        ? await handler!(query)
        : response(int.parse(query['page']!), id: int.parse(query['page']!));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingProvider provider;
  late ProformaListController controller;
  setUp(() {
    provider = RecordingProvider();
    controller = ProformaListController(ProformaListRepository(provider),
        readToken: () => 'test-token');
  });
  tearDown(() => controller.dispose());
  test('search, page, refresh, pending change, reset and export sequence',
      () async {
    await controller.fetch();
    await controller.goToPage(2);
    await controller.refresh();
    expect(provider.calls.last['page'], '2');
    controller.invoiceNumber.text = ' 00012 ';
    controller.customerSearch.text = ' Alice ';
    controller.search.schedule();
    await controller.goToPage(3);
    expect(provider.calls.last, containsPair('page', '1'));
    expect(provider.calls.last, containsPair('invoice_number', '00012'));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(provider.calls.length, 4);
    controller.selectStatus('paid');
    await Future<void>.delayed(Duration.zero);
    expect(provider.calls.last['status'], 'paid');
    final rows = await controller.export();
    expect(rows.length, 3);
    expect(provider.calls.last['per_page'], '1000');
    expect(provider.calls.last['customer_search'], 'Alice');
    expect(controller.rows.single['id'], 1);
    controller.reset();
    await Future<void>.delayed(Duration.zero);
    expect(provider.calls.last, {'page': '1', 'per_page': '20'});
    expect(controller.status, 'All');
  });
  test('old failure cannot replace newer success or clear loading', () async {
    final older = Completer<Map<String, dynamic>>(),
        newer = Completer<Map<String, dynamic>>();
    provider.handler =
        (q) => q['customer_search'] == 'old' ? older.future : newer.future;
    controller.customerSearch.text = 'old';
    final a = controller.fetch();
    controller.customerSearch.text = 'new';
    final b = controller.fetch();
    older.completeError(StateError('old failure'));
    await a;
    expect(controller.loading, isTrue);
    expect(controller.errorMessage, isNull);
    newer.complete(response(1, id: 22));
    await b;
    expect(controller.rows.single['id'], 22);
    expect(controller.loading, isFalse);
  });
  test('failed page retains successful rows and retry clears error', () async {
    await controller.fetch();
    provider.handler = (q) => Future.error(StateError('offline'));
    await controller.goToPage(2);
    expect(controller.rows.single['id'], 1);
    expect(controller.currentPage, 1);
    expect(controller.errorMessage, contains('offline'));
    provider.handler = null;
    await controller.refresh();
    expect(controller.errorMessage, isNull);
  });
  test('export snapshot stays fixed while inputs change', () async {
    await controller.fetch();
    final first = Completer<Map<String, dynamic>>();
    provider.handler = (q) => q['page'] == '1'
        ? first.future
        : Future.value(response(2, last: 2, id: 2));
    final export = controller.export();
    controller.customerSearch.text = 'changed';
    controller.status = 'paid';
    first.complete(response(1, last: 2));
    await export;
    final exportCalls = provider.calls.where((q) => q['per_page'] == '1000');
    expect(exportCalls.length, 2);
    expect(
        exportCalls.every((q) =>
            !q.containsKey('customer_search') && !q.containsKey('status')),
        isTrue);
    expect(controller.rows.single['id'], 1);
  });
  test('disposed controller ignores completion and cancels pending search',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    provider.handler = (_) => pending.future;
    final operation = controller.fetch();
    controller.search.schedule();
    controller.dispose();
    pending.complete(response(1));
    await operation;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(provider.calls.length, 1);
    expect(controller.rows, isEmpty);
    // Avoid a second dispose in tearDown by replacing with a fresh controller.
    controller = ProformaListController(ProformaListRepository(provider),
        readToken: () => 'test-token');
  });
}
