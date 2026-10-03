import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_transactions_controller.dart';

Map<String, dynamic> _row(
  int id, {
  String amount = '10.00',
  String type = 'credit',
  String date = '2026-02-10',
  String? reference,
}) =>
    {
      'id': id,
      'reference_id': 'TXN-$id',
      'reference': reference ?? 'REF-$id',
      'amount': amount,
      'type': type,
      'date': date,
      'currency': 'INR',
      'status': 'completed',
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> rows, {
  int current = 1,
  int last = 1,
}) =>
    {
      'status': 'success',
      'data': {'current_page': current, 'last_page': last, 'data': rows},
    };

class _FakeApi {
  final queries = <CustomerTransactionsQuery>[];
  Object? Function(CustomerTransactionsQuery query) respond =
      (_) => _page(const []);

  Future<dynamic> call(CustomerTransactionsQuery query) async {
    queries.add(query);
    final result = respond(query);
    if (result is Exception) throw result;
    return result;
  }
}

CustomerTransactionsController _controller(
  _FakeApi api, {
  String? token = 'token',
  String? customerId = '42',
  List<CustomerTransaction> initial = const [],
}) {
  return CustomerTransactionsController(
    fetch: api.call,
    readToken: () => token,
    customerId: customerId,
    initial: initial,
  );
}

void main() {
  group('CustomerTransactionsController', () {
    test('shows the customer\'s embedded transactions before loading', () {
      final controller = _controller(
        _FakeApi(),
        initial: [CustomerTransaction(id: 1, amount: '5')],
      );
      expect(controller.transactions, hasLength(1));
      expect(controller.isLoading, isFalse);
    });

    test('loads a page with the same query parameters as before', () async {
      final api = _FakeApi()
        ..respond = (q) => _page([_row(1), _row(2)], current: 1, last: 3);
      final controller = _controller(api);

      await controller.load(page: 1);

      expect(api.queries.single.accessToken, 'token');
      expect(api.queries.single.customerId, '42');
      expect(api.queries.single.perPage, 20);
      expect(api.queries.single.page, 1);
      expect(api.queries.single.dateFrom, isNull);
      expect(api.queries.single.type, isNull);
      expect(controller.transactions.map((t) => t.id), [1, 2]);
      expect(controller.currentPage, 1);
      expect(controller.lastPage, 3);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
    });

    test('goToPage loads valid pages only', () async {
      final api = _FakeApi()
        ..respond = (q) => _page([_row(q.page)], current: q.page, last: 2);
      final controller = _controller(api);
      await controller.load(page: 1);

      controller.goToPage(0);
      controller.goToPage(1);
      controller.goToPage(3);
      expect(api.queries, hasLength(1));

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);
      expect(api.queries.last.page, 2);
      expect(controller.currentPage, 2);
      expect(controller.transactions.single.id, 2);
    });

    test('empty response gives an empty list on page 1 of 1', () async {
      final controller = _controller(_FakeApi());
      await controller.load(page: 1);
      expect(controller.transactions, isEmpty);
      expect(controller.lastPage, 1);
      expect(controller.hasError, isFalse);
    });

    test('a failed request flags an error and retry reloads', () async {
      final api = _FakeApi()..respond = (_) => Exception('boom');
      final controller = _controller(api);

      await controller.load(page: 1);
      expect(controller.hasError, isTrue);
      expect(controller.isLoading, isFalse);

      api.respond = (_) => _page([_row(1)]);
      await controller.retry();
      expect(controller.hasError, isFalse);
      expect(controller.transactions, hasLength(1));
    });

    test('does nothing without a token or customer id', () async {
      final api = _FakeApi();
      await _controller(api, token: null).load(page: 1);
      await _controller(api, token: '').load(page: 1);
      await _controller(api, customerId: null).load(page: 1);
      expect(api.queries, isEmpty);
    });

    test('applyFilters sends type and dates, filters reference locally',
        () async {
      final api = _FakeApi()
        ..respond = (_) => _page([
              _row(1, reference: 'Invoice A'),
              _row(2, reference: 'Receipt B'),
              _row(3, reference: 'invoice c', date: '2026-03-01'),
            ]);
      final controller = _controller(api);

      controller.toggleFilters();
      expect(controller.filtersVisible, isTrue);
      controller.referenceController.text = 'INVOICE';
      controller.setDraftType(TransactionDirection.credit);
      controller.setDraftRange(
        DateTimeRange(start: DateTime(2026, 2, 1), end: DateTime(2026, 2, 28)),
      );
      await controller.applyFilters();

      final query = api.queries.single;
      expect(query.type, 'credit');
      expect(query.dateFrom, '2026-02-01');
      expect(query.dateTo, '2026-02-28');
      expect(query.page, 1);
      expect(controller.filtersVisible, isFalse);
      // Row 2 fails the reference filter, row 3 is outside the range.
      expect(controller.transactions.map((t) => t.id), [1]);
    });

    test('date filter accepts ISO date-times from the API', () async {
      final api = _FakeApi()
        ..respond = (_) => _page([_row(1, date: '2026-02-10T08:30:00Z')]);
      final controller = _controller(api)
        ..setDraftRange(DateTimeRange(
          start: DateTime(2026, 2, 10),
          end: DateTime(2026, 2, 10),
        ));
      await controller.applyFilters();
      expect(controller.transactions, hasLength(1));
    });

    test('resetFilters clears everything and reloads page 1', () async {
      final api = _FakeApi()..respond = (_) => _page([_row(1)]);
      final controller = _controller(api)
        ..setDraftType(TransactionDirection.debit);
      controller.referenceController.text = 'x';
      await controller.applyFilters();
      expect(controller.transactions, isEmpty);

      await controller.resetFilters();
      expect(controller.filter.type, isNull);
      expect(controller.filter.reference, isNull);
      expect(controller.referenceController.text, isEmpty);
      expect(api.queries.last.type, isNull);
      expect(controller.transactions, hasLength(1));
    });

    test('totals split credit and debit', () async {
      final api = _FakeApi()
        ..respond = (_) => _page([
              _row(1, amount: '+100.00', type: 'sale'),
              _row(2, amount: '40.50', type: 'debit'),
              _row(3, amount: '10', type: 'credit'),
            ]);
      final controller = _controller(api);
      await controller.load(page: 1);

      final totals = controller.totals;
      expect(totals.credit, 110);
      expect(totals.debit, 40.5);
      expect(totals.net, closeTo(69.5, 0.001));
    });

    test('ignores a response that arrives after a newer request', () async {
      final controller = CustomerTransactionsController(
        readToken: () => 't',
        customerId: '1',
        fetch: (q) async {
          if (q.page == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          return _page([_row(q.page)], current: q.page, last: 2);
        },
      );
      final first = controller.load(page: 1);
      await controller.load(page: 2);
      await first;
      expect(controller.currentPage, 2);
      expect(controller.transactions.single.id, 2);
    });
  });
}
