import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/sales_return_detail_helper.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';

void main() {
  test('return print items retain API product HSN and tax-rate presence', () {
    for (final rate in [null, '0.000', '18.000']) {
      final summary = SalesReturnItem.fromJson({
        'id': 1, 'cart_item_id': 10, 'quantity': 2, 'price': '360',
        'cart_item': {'id': 10, 'unit_price': '180', 'quantity': '7',
          if (rate != null) 'tax_rate': rate,
          'product': {'name': 'Coffee', 'hsn_code': '0090121'}},
      });
      final printed = buildTransactionReturnPrintItems([summary], []).single;
      expect(printed.hsnCode, '0090121');
      expect(printed.taxRate, rate);
      final restored = OrderReturnItem.fromJson(printed.toJson());
      expect(restored.hsnCode, '0090121');
      expect(restored.taxRate, rate);
      expect(restored.quantity, 2, reason: 'Use return quantity, not original sold quantity');
    }
  });
  testWidgets('return totals and words share authoritative total or line fallback',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    for (final entry in <String?, double>{
      '21': 21, '0': 0, '1,200.50': 1200.50,
      null: 21, '': 21, 'invalid': 21,
    }.entries) {
      final params = ReceiptLayoutParams(
        context: context, selectedPrinter: BluetoothPrinter.development(),
        cartItems: const [], formattedTotal: '1500', orderDate: '2026-09-26',
        orderNumber: 'QA', isFromLocalStorage: false, selectedPaperSize: 'A4',
        customerCareNumber: '', customerCareEmail: '',
        billDocumentConfig: DocumentConfig(language: 'en',
          displayConfiguration: DisplayConfiguration(options: {
            for (final key in ['showReturnTotalAmount', 'showReturnNetAmount',
              'showReturnAmountInWords', 'showFinalNetAmount', 'showFinalAmountInWords'])
              key: DisplayOption(visible: true),
          })),
        orderReturns: OrderReturns(returnTotalAmount: entry.key, returnItems: [
          OrderReturnItem(productName: 'Coffee', quantity: 1, unitPrice: '11'),
          OrderReturnItem(productName: 'Tea', quantity: 2, unitPrice: '5'),
        ]),
      );
      expect(params.returnsSection!.totalRows.map((r) => r.$2),
          [entry.value, entry.value], reason: 'API total ${entry.key}');
      expect(params.returnsWordsLines('SAR'), params.amountInWordsLines(entry.value, currency: 'SAR'));
      expect(params.finalSummaryRows.single.amount, 1500 - entry.value);
      expect(params.finalSummaryWordsLines('SAR'), params.amountInWordsLines(1500 - entry.value, currency: 'SAR'));
    }
  });

  test('transaction price preserves zero and prefers loaded unit price to line price', () {
    SalesReturnItem summary(Map<String, dynamic> cart) => SalesReturnItem.fromJson({
      'id': 1, 'cart_item_id': 10, 'quantity': 12, 'price': '60',
      'cart_item': {'id': 10, ...cart},
    });
    final loaded = SalesReturnCart.fromJson({
      'cart_item_id': 10, 'unit_price': '5', 'quantity': 12,
    });
    expect(salesReturnItemUnitPrice(summary({'unit_price': '0.00'}), [loaded]), '0.00');
    expect(salesReturnItemUnitPrice(summary({}), [loaded]), '5');
    expect(salesReturnItemUnitPrice(summary({'unit_price': 'invalid'}), [loaded]), '5');
    final freeLoaded = SalesReturnCart.fromJson({'cart_item_id': 10, 'unit_price': '0'});
    expect(salesReturnItemUnitPrice(summary({}), [freeLoaded]), '0');
    final missingLoaded = SalesReturnCart.fromJson({'cart_item_id': 10});
    expect(double.parse(salesReturnItemUnitPrice(summary({}), [missingLoaded])), 5);
    final missingIds = SalesReturnItem.fromJson({'price': '20', 'quantity': 1});
    expect(salesReturnItemUnitPrice(missingIds,
        [SalesReturnCart.fromJson({'unit_price': '999'})]), '20.0');
    final flatUnitPrice = SalesReturnItem.fromJson({
      'cart_item_id': 10, 'quantity': 12, 'price': '60', 'unit_price': '5',
    });
    expect(salesReturnItemUnitPrice(flatUnitPrice, []), '5');
  });
  test('missing unit prices derive a rate from the returned line value only', () {
    for (final row in [(12, '60', 5.0), (2.5, '12.5', 5.0),
      (2, '1,200.50', 600.25), (3, '0', 0.0)]) {
      final item = SalesReturnItem.fromJson({
        'quantity': row.$1, 'price': row.$2,
      });
      final rate = double.parse(salesReturnItemUnitPrice(item, []));
      expect(rate, row.$3);
      expect(rate * row.$1, double.parse(row.$2.replaceAll(',', '')));
    }
    for (final quantity in [0, -1]) {
      expect(salesReturnItemUnitPrice(SalesReturnItem.fromJson({
        'quantity': quantity, 'price': '60',
      }), []), isEmpty);
    }
  });
  testWidgets('transaction returns preserve different unit prices and MRP',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    final items = buildTransactionReturnPrintItems([
      for (final row in [
        (1, 12, '5.00', '6.00', '60.00'),
        (2, 1, '20.00', '25.00', '20.00')
      ])
        SalesReturnItem.fromJson({
          'id': row.$1,
          'cart_item_id': row.$1,
          'quantity': row.$2,
          'price': row.$5,
          'reason': 'Returned',
          'cart_item': {
            'id': row.$1,
            'product_name': 'Item ${row.$1}',
            'unit_price': row.$3,
            'mrp': row.$4,
            'quantity': row.$2,
            'total_price': row.$5,
          },
        }),
    ], []);
    final params = ReceiptLayoutParams(
      context: context,
      selectedPrinter: BluetoothPrinter.development(),
      cartItems: const [
        {'id': 1, 'product_name': 'Shared name', 'unit_price': '5', 'mrp': '6'},
        {
          'id': 2,
          'product_name': 'Shared name',
          'unit_price': '20',
          'mrp': '25'
        },
        {'id': 3, 'product_name': 'Free sample', 'unit_price': '0', 'mrp': '2'},
      ],
      formattedTotal: '80',
      orderDate: '2026-09-26',
      orderNumber: 'QA',
      isFromLocalStorage: false,
      selectedPaperSize: '80mm',
      customerCareNumber: '',
      customerCareEmail: '',
      billDocumentConfig: DocumentConfig(),
      orderReturns: OrderReturns(returnTotalAmount: '80', returnItems: items),
    );
    expect(params.returnItemRate(items[0]), (5.0, 6.0));
    expect(params.returnItemRate(items[1]), (20.0, 25.0));
    final derived = buildTransactionReturnPrintItems([
      SalesReturnItem.fromJson({
        'cart_item_id': 999, 'quantity': 2.5, 'price': '12.50',
        'product_name': 'Item without an explicit unit price',
      }),
    ], []).single;
    final roundTrip = OrderReturnItem.fromJson(derived.toJson());
    expect(params.returnItemRate(roundTrip).$1, 5.0);
    expect(params.returnItemRate(roundTrip).$1 * roundTrip.quantity!, 12.5,
        reason: 'The print route must not multiply a line total by quantity again');
    final free = OrderReturnItem.fromJson({
      'product_name': 'Free sample',
      'quantity': 1,
      'unit_price': '0.00',
      'mrp': '2.00',
    });
    expect(params.returnItemRate(free), (0.0, 2.0));
    expect(
        params.returnItemRate(OrderReturnItem.fromJson({
          'cart_item_id': 2,
          'product_name': 'Shared name',
          'quantity': 1,
        })),
        (20.0, 25.0));
    expect(
        params.returnItemRate(OrderReturnItem.fromJson({
          'cart_item_id': 3,
          'product_name': 'Free sample',
          'quantity': 1,
        })),
        (0.0, 2.0));
    expect(params.returnItemRate(OrderReturnItem.fromJson(items[0].toJson())),
        (5.0, 6.0));
  });
}
