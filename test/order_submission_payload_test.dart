import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_submission_payload.dart';

void main() {
  test('multi-payment body preserves every supported checkout field', () {
    final payload = OrderSubmissionPayload(
      items: [
        {'product_id': 1, 'quantity': 2, 'comment': 'no onion'},
        {'product_id': 2, 'quantity': 1, 'stock_id': 20},
      ],
      clientSaleId: '01995643-7f83-7a21-9a4b-b8c26d9c7b61',
      receiptNumber: '6-03-260916-0001',
      issuedAt: '2026-09-16T04:14:00.000Z',
      posDeviceId: 'device-1',
      counterNumber: 3,
      customerId: 31,
      customerPhone: '9999999999',
      transactionNumber: 'TX-9',
      paymentMethods: const ['CASH', 'CARD'],
      paidMethods: const [
        {'method': 'CASH', 'amount': 40.0},
        {'method': 'CARD', 'amount': 60.0},
      ],
      balanceAmount: '12.50',
      couponId: 'SAVE10',
      orderId: '44',
      comment: 'deliver carefully',
      deliveryMethodId: '7',
      tableId: 'T-4',
      carNumber: 'KL-01-AA-1',
      status: 'confirmed',
      deliveryDate: '2026-09-15',
      deliveryTime: '14:30',
      flatDiscount: 5,
      percentageDiscount: 10,
      discountAmount: 15,
      toCustomerCredit: true,
      address: 'Main road',
      addressId: 81,
      pincode: ' 682001 ',
      quotationId: 91,
      deliveryCharge: 25,
      storeId: 6,
    ).toApiJson();

    expect(payload, {
      'items': [
        {'product_id': 2, 'quantity': 1, 'stock_id': 20},
        {'product_id': 1, 'quantity': 2, 'comment': 'no onion'},
      ],
      'client_sale_id': '01995643-7f83-7a21-9a4b-b8c26d9c7b61',
      'receipt_number': '6-03-260916-0001',
      'issued_at': '2026-09-16T04:14:00.000Z',
      'pos_device_id': 'device-1',
      'counter_number': 3,
      'phone': '9999999999',
      'customer_id': 31,
      'transaction_number': 'TX-9',
      'payment_method': ['CASH', 'CARD'],
      'paid_methods': [
        {'method': 'CASH', 'amount': 40.0},
        {'method': 'CARD', 'amount': 60.0},
      ],
      'source_type': 'executive',
      'balance': '12.50',
      'coupon_id': 'SAVE10',
      'order_id': '44',
      'comment': 'deliver carefully',
      'delivery_method_id': '7',
      'table_id': 'T-4',
      'car_number': 'KL-01-AA-1',
      'status': 'confirmed',
      'delivery_date': '2026-09-15',
      'delivery_time': '14:30',
      'table': 'T-4',
      'flat_discount': 5.0,
      'percentage_discount': 10.0,
      'discount_amount': 15.0,
      'to_customer_credit': true,
      'address': 'Main road',
      'address_id': 81,
      'pincode': '682001',
      'quotation_id': 91,
      'delivery_charge': 25.0,
      'store_id': 6,
    });
  });

  test('single-payment fallback matches the legacy API contract', () {
    final body = OrderSubmissionPayload(
      items: const [],
      customerPhone: null,
      transactionNumber: '',
      paymentMethod: 'CASH',
      paidAmount: '100',
      balanceAmount: '0',
    ).toApiJson(fallbackStoreId: 3);

    expect(body['payment_method'], 'CASH');
    expect(body['paid_amount'], '100');
    expect(body.containsKey('paid_methods'), isFalse);
    expect(body['phone'], isNull);
    expect(body['coupon_id'], isNull);
    expect(body['delivery_charge'], 0.0);
    expect(body['store_id'], 3);
  });

  test('credit-only sale uses the existing balance contract', () {
    final body = OrderSubmissionPayload(
      items: const [
        {'product_id': 1, 'quantity': 1}
      ],
      transactionNumber: 'TX-CREDIT',
      paymentMethods: const [],
      paidMethods: const [],
      creditSaleAmount: 75.0,
      balanceAmount: '0',
    ).toApiJson();

    expect(body['payment_method'], isNull);
    expect(body['paid_amount'], isNull);
    expect(body['balance'], '75.0');
    expect(body.containsKey('paid_methods'), isFalse);
  });

  test('partial credit maps the unpaid remainder to balance', () {
    final body = OrderSubmissionPayload(
      items: const [],
      transactionNumber: 'TX-PARTIAL-CREDIT',
      paymentMethods: const ['7973'],
      paidMethods: const [
        {'method': '7973', 'amount': 25.0},
      ],
      creditSaleAmount: 10.0,
    ).toApiJson();

    expect(body['payment_method'], ['7973']);
    expect(body['paid_methods'], [
      {'method': '7973', 'amount': 25.0},
    ]);
    expect(body['balance'], '10.0');
  });

  test('existing restaurant order includes its stable receipt identity', () {
    final body = OrderSubmissionPayload(
      items: const [
        {'product_id': 1, 'quantity': 2}
      ],
      clientSaleId: 'client-existing',
      receiptNumber: '6-04-260916-0001',
      issuedAt: '2026-09-16T05:00:00.000Z',
      posDeviceId: 'device-2',
      counterNumber: 4,
      customerId: 31,
      customerPhone: '9999999999',
      transactionNumber: 'TX-10',
      paymentMethods: const ['CASH', 'CARD'],
      paidMethods: const [
        {'method': 'CASH', 'amount': 30.0},
        {'method': 'CARD', 'amount': 70.0},
      ],
      balanceAmount: '0',
      couponId: 'SAVE10',
      orderId: '501',
      comment: 'table bill',
      deliveryMethodId: '',
      tableId: '12',
      carNumber: 'KL-1',
      status: 'confirmed',
      flatDiscount: 5,
      percentageDiscount: 10,
      discountAmount: 15,
      toCustomerCredit: false,
      address: 'not part of the update contract',
      addressId: 44,
      pincode: '682001',
      deliveryCharge: 20,
    ).toUpdateApiJson();

    expect(body, {
      'client_sale_id': 'client-existing',
      'receipt_number': '6-04-260916-0001',
      'issued_at': '2026-09-16T05:00:00.000Z',
      'pos_device_id': 'device-2',
      'counter_number': 4,
      'phone': '9999999999',
      'transaction_number': 'TX-10',
      'payment_method': ['CASH', 'CARD'],
      'paid_methods': [
        {'method': 'CASH', 'amount': 30.0},
        {'method': 'CARD', 'amount': 70.0},
      ],
      'source_type': 'executive',
      'balance': '0',
      'coupon_id': 'SAVE10',
      'order_id': '501',
      'comment': 'table bill',
      'delivery_method_id': '',
      'table_id': '12',
      'car_number': 'KL-1',
      'status': 'confirmed',
      'flat_discount': 5.0,
      'percentage_discount': 10.0,
      'discount_amount': 15.0,
      'to_customer_credit': false,
      'delivery_charge': 20.0,
    });
    expect(body.containsKey('items'), isFalse);
    expect(body.containsKey('customer_id'), isFalse);
    expect(body.containsKey('address'), isFalse);
  });

  test('payload owns a deep immutable snapshot of mutable caller input', () {
    final items = <Map<String, dynamic>>[
      {
        'product_id': 1,
        'modifiers': [
          {'id': 7}
        ],
      }
    ];
    final paid = <Map<String, dynamic>>[
      {'method': 'CASH', 'amount': 10}
    ];
    final payload = OrderSubmissionPayload(
      items: items,
      transactionNumber: '',
      paymentMethods: const ['CASH'],
      paidMethods: paid,
    );

    (items.first['modifiers'] as List).clear();
    paid.first['amount'] = 999;

    final body = payload.toApiJson();
    expect((body['items'] as List).single['modifiers'], [
      {'id': 7}
    ]);
    expect((body['paid_methods'] as List).single['amount'], 10);
  });
}
