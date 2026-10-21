import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/receipts/data/receipt_list_repository.dart';
import 'package:pos_machine/features/receipts/domain/receipt_list_query.dart';
import 'package:pos_machine/features/receipts/presentation/state/receipt_list_controller.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends ReceiptListRepository {
  _Repository() : super(InvoiceProvider());
  final applied = <ReceiptListQuery>[];
  @override
  void apply(ReceiptListQuery q) => applied.add(q);
  @override
  void reset() {}
}

Receipt receipt(int id,
        {Map<String, dynamic> extra = const {},
        List<Map<String, dynamic>> payments = const []}) =>
    Receipt.fromJson({
      'id': id,
      'receipt_number': 'RCP$id',
      'amount': '1.00',
      'receipt_status': 'paid',
      'customer': {
        'user': {'name': 'Alice'}
      },
      'created_at': '2026-10-01T12:00:00',
      'updated_at': '2026-10-01T12:00:00',
      'receipt_payments': [
        for (final p in payments)
          {
            'id': id,
            'receipt_id': id,
            'payment_method': 'CARD',
            'paid_amount': '1.00',
            'status': 'paid',
            'payment_date': '2026-10-01',
            ...p,
          }
      ],
      ...extra,
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('numbers are read from the receipt and its payments, without duplicates',
      () {
    final r = receipt(1, extra: {
      'order_number': 'ORD-004785',
      'offline_receipt_number': ' 2-11-261015-0010 ',
    }, payments: [
      {
        'order_number': 'ORD-004785',
        'offline_receipt_number': '2-11-261015-0010'
      },
      {'order_number': 'ORD-004786', 'offline_receipt_number': ''},
    ]);

    expect(r.orderNumbers, ['ORD-004785', 'ORD-004786']);
    expect(r.offlineReceiptNumbers, ['2-11-261015-0010']);
  });

  test('missing numbers give empty lists', () {
    final r = receipt(2, payments: [{}]);
    expect(r.orderNumbers, isEmpty);
    expect(r.offlineReceiptNumbers, isEmpty);
  });

  test(
      'filter matches order or offline number, partially, ignoring spaces '
      'and case', () {
    final rows = [
      receipt(1, payments: [
        {
          'order_number': 'ORD-004785',
          'offline_receipt_number': '2-11-261015-0010'
        }
      ]),
      receipt(2, extra: {'offline_receipt_number': '2-11-261015-0009'}),
      receipt(3),
    ];
    List<int> ids(String filter) => [
          for (final r in matchReceiptList(rows, filterOrderNumber: filter))
            r.id
        ];

    expect(ids('ORD-004785'), [1]);
    expect(ids('ord-004785'), [1]);
    expect(ids('2-11-261015-0010'), [1]);
    expect(ids('2 - 11 - 261015 - 0009'), [2]);
    expect(ids('261015'), [1, 2]);
    expect(ids('NOPE'), isEmpty);
    expect(ids('  '), [1, 2, 3]);
  });

  test('the controller sends the order / offline receipt number', () async {
    final repository = _Repository();
    final controller =
        ReceiptListController(repository, readToken: () => 'token');
    controller.orderNumber.text = '2-11-261015-0010';
    controller.search.flush();
    await Future<void>.delayed(Duration.zero);

    expect(repository.applied.last.orderNumber, '2-11-261015-0010');
    expect(repository.applied.last.isActive, isTrue);
    controller.dispose();
  });
}
