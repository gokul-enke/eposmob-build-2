import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/customer_report_details_snapshot.dart';
import 'package:pos_machine/features/reports/domain/customer_report_details_query.dart';

const query =
    CustomerReportDetailsQuery(customerId: '42', customerName: 'Twin');

Map<String, dynamic> row(int id,
        {int customer = 42,
        String date = '2026-10-12',
        String kind = 'Receipt',
        String type = 'credit',
        String status = 'SUCC'}) =>
    {
      'id': id,
      'customer_id': customer,
      'customer_name': 'Twin',
      'date': date,
      'amount': '10.125',
      'transaction_type': kind,
      'type': type,
      'status': status,
      'order_number': 'ORD-$id',
    };

Map<String, dynamic> group(int id, List<Map<String, dynamic>> rows) => {
      'customer_id': id,
      'customer_name': 'Twin',
      'transaction_count': rows.length,
      'transactions': rows,
    };

Map<String, dynamic> response(List<Map<String, dynamic>> rows,
        {int page = 1, int last = 1, int? total}) =>
    {
      'status': 'success',
      'data': {
        'data': rows,
        'current_page': page,
        'last_page': last,
        'per_page': 20,
        if (total != null) 'total': total
      }
    };

void main() {
  for (final grouped in [true, false]) {
    for (final declared in [1001, 1000000, '1001']) {
      test(
          'rejects excessive ${grouped ? 'grouped' : 'flat'} pages: $declared (${declared.runtimeType})',
          () async {
        final calls = <int>[], progress = <(int, int)>[];
        await expectLater(
            fetchCustomerReportDetailsSnapshot((page) async {
              calls.add(page);
              if (page > 1) throw StateError('Unexpected extra page request.');
              final value = response(grouped
                  ? [
                      group(42, [row(1)])
                    ]
                  : [row(1)]);
              (value['data'] as Map)['last_page'] = declared;
              return value;
            }, query, onProgress: (page, last) => progress.add((page, last))),
            throwsFormatException);
        expect(calls, [1]);
        expect(progress, isEmpty);
      });
    }
    test('accepts all 1000 ${grouped ? 'grouped' : 'flat'} pages at the limit',
        () async {
      final calls = <int>[], progress = <(int, int)>[];
      final result = await fetchCustomerReportDetailsSnapshot((page) async {
        calls.add(page);
        final customer = page == 1000 ? 42 : 10000 + page;
        final value = response(
            grouped
                ? [
                    group(customer, [row(page, customer: customer)])
                  ]
                : [row(page)],
            page: page,
            last: 1000,
            total: 1000);
        final data = value['data'] as Map;
        data['per_page'] = 1;
        if (grouped) data['last_page'] = '1000';
        return value;
      }, query, onProgress: (page, last) => progress.add((page, last)));
      expect(calls, List.generate(1000, (index) => index + 1));
      expect(progress.length, 1000);
      expect(progress.last, (1000, 1000));
      expect(result.length, grouped ? 1 : 1000);
      expect(result.last.id, 1000);
      expect(result.last.amount, '10.125');
    });
  }

  test('outer grouped pages find the selected ID and preserve financial values',
      () async {
    final pages = <int>[], progress = <(int, int)>[];
    final result = await fetchCustomerReportDetailsSnapshot((page) async {
      pages.add(page);
      return response([
        page == 1
            ? group(99, [row(99, customer: 99)])
            : group(42, [row(1), row(2)])
      ], page: page, last: 2, total: 2);
    }, query, onProgress: (page, last) => progress.add((page, last)));
    expect(pages, [1, 2]);
    expect(progress, [(1, 2), (2, 2)]);
    expect(result.map((r) => r.id), [1, 2]);
    expect(result.first.amount, '10.125');
    expect(result.first.orderNumber, 'ORD-1');
    expect(result.every((r) => r.customerId == 42), true);
  });

  test('flat pages collect every matching transaction without other customers',
      () async {
    final result = await fetchCustomerReportDetailsSnapshot(
        (page) async => response(
            page == 1 ? [row(1), row(99, customer: 99)] : [row(2)],
            page: page,
            last: 2,
            total: 3),
        query);
    expect(result.map((r) => r.id), [1, 2]);
  });

  test('all filters use contains matching and inclusive start/end dates',
      () async {
    const filtered = CustomerReportDetailsQuery(
        customerId: '42',
        customerName: 'Twin',
        transactionType: 'Receipt',
        status: 'SUCC',
        type: 'Credit',
        from: '2026-10-12',
        to: '2026-10-12');
    final source = [
      row(1),
      row(2, date: '2026-10-12T23:59:00'),
      row(3, date: '2026-10-13'),
      row(4, date: '2026-10-11'),
      row(5, kind: 'Invoice'),
      row(6, type: 'debit'),
      row(7, status: 'FAIL')
    ];
    final result = await fetchCustomerReportDetailsSnapshot(
        (_) async => response([group(42, source)], total: 1), filtered);
    expect(result.map((r) => r.id), [1, 2]);
  });

  test('name fallback is case insensitive and rejects duplicate customer names',
      () async {
    const named =
        CustomerReportDetailsQuery(customerId: '', customerName: 'tWIN');
    final result = await fetchCustomerReportDetailsSnapshot(
        (_) async => response([
              group(42, [row(1)])
            ]),
        named);
    expect(result.single.customerId, 42);
    await expectLater(
        fetchCustomerReportDetailsSnapshot(
            (_) async => response([
                  group(42, [row(1)]),
                  group(99, [row(99, customer: 99)])
                ]),
            named),
        throwsFormatException);
  });

  final badResponses = <String, Map<String, dynamic>>{
    'failed response': {'status': 'failed'},
    'missing pagination': {
      'status': 'success',
      'data': {
        'data': [
          group(42, [row(1)])
        ]
      }
    },
    'wrong page': response([
      group(42, [row(1)])
    ], page: 2),
    'declared nested count mismatch': response([
      {
        ...group(42, [row(1)]),
        'transaction_count': 2
      }
    ]),
    'repeated group': response([
      group(42, [row(1)]),
      group(42, [row(2)])
    ]),
    'repeated transaction': response([
      group(42, [row(1), row(1)])
    ]),
    'child belongs to another customer': response([
      group(42, [row(1, customer: 99)])
    ]),
    'invalid amount': response([
      group(42, [
        {...row(1), 'amount': 'NaN'}
      ])
    ]),
    'invalid date': response([
      group(42, [row(1, date: '2026-02-30')])
    ]),
    'missing page rows': response([], last: 2),
    'incomplete outer count': response([
      group(42, [row(1)])
    ], total: 2),
    'mixed row formats': response([
      group(42, [row(1)]),
      row(2)
    ]),
  };
  for (final entry in badResponses.entries) {
    test('rejects ${entry.key} instead of exporting partial rows', () async {
      await expectLater(
          fetchCustomerReportDetailsSnapshot((_) async => entry.value, query),
          throwsFormatException);
    });
  }

  for (final change in ['last', 'total', 'per_page', 'format', 'duplicate']) {
    test('rejects changing or overlapping pages: $change', () async {
      await expectLater(
          fetchCustomerReportDetailsSnapshot((page) async {
            if (page == 1) {
              return response([
                group(42, [row(1)])
              ], last: 2, total: 2);
            }
            final next = response([
              group(99, [row(99, customer: 99)])
            ], page: 2, last: 2, total: 2);
            final data = next['data'] as Map;
            switch (change) {
              case 'last':
                data['last_page'] = 3;
              case 'total':
                data['total'] = 3;
              case 'per_page':
                data['per_page'] = 10;
              case 'format':
                data['data'] = [row(2)];
              case 'duplicate':
                data['data'] = [
                  group(42, [row(2)])
                ];
            }
            return next;
          }, query),
          throwsFormatException);
    });
  }

  test('empty single-page response is valid and missing selection is rejected',
      () async {
    expect(
        await fetchCustomerReportDetailsSnapshot(
            (_) async => response([], total: 0), query),
        isEmpty);
    await expectLater(
        fetchCustomerReportDetailsSnapshot((_) async => response([]),
            const CustomerReportDetailsQuery(customerId: '', customerName: '')),
        throwsStateError);
  });
}
