import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/item_discount_details.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/receipt_line_discount.dart';

Map<String, dynamic> _example(String name) =>
    jsonDecode(File('docs/api/$name.example.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final order =
      OrderDetailsModel.fromJson(_example('receipt-discount-order-response'));
  final items = order.data!.cart!.cartItems!;
  final configJson =
      _example('receipt-discount-document-config')['document_configurations']
          ['Bill A4'] as Map<String, dynamic>;

  test('older completed-sale snapshots do not require future metadata', () {
    final body = OrderSubmissionPayload(
      items: [
        {
          'product_id': 1,
          'quantity': 1,
          'price': 80,
          'standard_unit_price': 100,
          'tax_rate': 15,
          'tax_amount': 10.43,
          'total_price': 80
        }
      ],
      transactionNumber: '',
      storeId: 2,
      clientSaleId: 'sale',
      receiptNumber: 'receipt',
      issuedAt: '2026-10-09T00:00:00Z',
      posDeviceId: 'device',
    ).toApiJson();
    expect(body['pricing_mode'], 'completed_sale');
    expect((body['items'] as List).single['standard_unit_price'], 100);
    expect((body['items'] as List).single.containsKey('offer_name'), isFalse);
  });

  test('documented response reconciles item reductions and order allocations',
      () {
    final offer = ReceiptLineDiscount.fromItem(items.first);
    final manual = ReceiptLineDiscount.fromItem(items.last);
    expect(offer.itemDiscount, 40);
    expect(offer.orderDiscount, 16);
    expect(offer.discountedTotal, 144);
    expect(offer.formattedRateExcTax, '86.96');
    expect(manual.itemDiscount, 5);
    expect(manual.orderDiscount, 4.5);
    expect(manual.discountedTotal, 40.5);
    expect(items.first.discountDetails.offerId, 7);
    expect(items.first.discountDetails.offerVersion, 3);
    expect(items.first.discountDetails.isOffer, isTrue);
    expect(items.last.discountDetails.isManual, isTrue);
    final summary = order.data!.cart!.priceSummary!;
    expect(summary.discount, 20.5);
    expect(summary.netPayable, 184.5);
    expect(summary.totalTax, 24.06);
    expect(offer.discountedTotal + manual.discountedTotal, summary.netPayable);
    expect(summary.netTotal! - summary.discount!, summary.netPayable);
  });

  test('source snapshots survive model round trip and partial monetary copies',
      () {
    final restored =
        OrderDetailsModelDataCartItem.fromJson(items.first.toJson());
    expect(restored.discountDetails.toJson(),
        items.first.discountDetails.toJson());
    final partial = restored.copyWith(quantity: 1, totalPrice: '80.00');
    expect(partial.discountDetails.itemDiscountAmount, '20.00');
    expect(partial.discountDetails.offerDiscountValue, '20.000');
    expect(partial.discountDetails.offerName, 'Summer offer');
    expect(
        partial.discountDetails.orderDiscountAllocations.map((a) => a.amount),
        [5, 3]);
    expect(ReceiptLineDiscount.fromItem(partial).orderDiscount, 8);
  });

  test('explicit zero wins and malformed metadata does not invent reductions',
      () {
    final base = items.first.toJson();
    expect(
        ReceiptLineDiscount.fromItem({...base, 'item_discount_amount': 0})
            .itemDiscount,
        0);
    for (final invalid in [-1, 'NaN', 'Infinity', {}, 'not money']) {
      expect(
          ReceiptLineDiscount.fromItem(
              {...base, 'item_discount_amount': invalid}).itemDiscount,
          40);
    }
    final withoutHistory = {...base}
      ..remove('standard_unit_price')
      ..remove('item_discount_amount');
    withoutHistory['mrp'] = '500';
    expect(ReceiptLineDiscount.fromItem(withoutHistory).itemDiscount, 0);
    final malformed = ItemDiscountDetails.fromJson({
      'offer_names': [],
      'order_discount_allocations': [
        null,
        {},
        {'source': 'coupon', 'amount': '-5'}
      ],
    });
    expect(malformed.offerNames, isEmpty);
    expect(malformed.orderDiscountAllocations, isEmpty);
  });

  testWidgets('discount amounts occupy a column in each language',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    ReceiptLayoutParams params(String language,
            {Map<String, dynamic>? options}) =>
        ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: items,
          formattedTotal: '184.50',
          discountAmount: '20.50',
          orderDate: '2026-10-09',
          orderNumber: 'DISCOUNT-COLUMN-QA',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          billDocumentConfig: DocumentConfig.fromJson({
            ...configJson,
            'language': language,
            if (options != null) 'display_configuration': options,
          }),
          customerCareNumber: '',
          customerCareEmail: '',
        );
    for (final language in ['en', 'ar', 'en_ar']) {
      final receipt = params(language);
      expect(receipt.itemColumns.map((column) => column.key),
          contains('showItemDiscount'));
      expect(receipt.itemLines.first.valueFor('showItemDiscount'), '56.00');
      expect(receipt.itemLines.last.valueFor('showItemDiscount'), '9.50');
      expect(receipt.itemLines.first.rate, '100.00');
      expect(receipt.itemLines.first.total, '144.00');
      expect(receipt.itemLines.last.rate, '50.00');
      expect(receipt.itemLines.last.total, '40.50');
      expect(receipt.itemLines.first.nameLines.join(' '),
          isNot(contains('discount')));
      expect(receipt.itemLines.first.nameLines.join(' '),
          isNot(contains('Summer offer')));
      expect(receipt.itemLine(items.first.toJson(), 1).discount, '56.00');
      final label = receipt.itemColumns
          .firstWhere((column) => column.key == 'showItemDiscount')
          .label;
      if (language != 'ar') expect(label.english, 'Discount');
      if (language != 'en') expect(label.arabic, 'الخصم');
    }
    final custom = params('en_ar', options: {
      ...Map<String, dynamic>.from(configJson['display_configuration']),
      'showDiscountColumn': {
        'visible': true,
        'value': 'تخفيض',
        'default': 'Saving',
      },
    });
    expect(
        custom.itemColumns
            .firstWhere((column) => column.key == 'showItemDiscount')
            .label
            .joined(inline: true),
        'تخفيض / Saving');

    final options =
        Map<String, dynamic>.from(configJson['display_configuration']);
    final hiddenItem = params('en', options: {
      ...options,
      'showDiscountColumn': {'visible': false},
    });
    expect(hiddenItem.itemColumns.map((column) => column.key),
        isNot(contains('showItemDiscount')));
    expect(hiddenItem.discountAmountValue, 20.5);
    expect(hiddenItem.isVisible('showDiscount'), isTrue);
    for (final key in ['showParticulars', 'showDiscount']) {
      final hiddenOther = params('en', options: {
        ...options,
        key: {'visible': false},
      });
      expect(hiddenOther.itemColumns.map((column) => column.key),
          contains('showItemDiscount'));
      expect(hiddenOther.itemLines.first.discount, '56.00');
    }
    options.remove('showDiscountColumn');
    expect(params('en', options: options).showItemDiscountColumn, isTrue);
    final legacy = params('en_ar', options: {
      ...options,
      'showItemDiscount': {
        'visible': true,
        'value': 'تخفيض',
        'default': 'Saving',
      },
    });
    expect(legacy.fieldLabel('showItemDiscount', inlineBilingual: true),
        'تخفيض / Saving');
    expect(
        params('en', options: {
          ...options,
          'showItemDiscount': {'visible': false},
        }).showItemDiscountColumn,
        isFalse);
    final manual = {...items.first.toJson(), 'discount_origin': 'manual'};
    final inconsistent = {
      ...manual,
      'order_discount_allocations': [
        {'source': 'coupon', 'code': 'WRONG', 'amount': '1.00'},
      ]
    };
    expect(params('en').itemLine(inconsistent, 1).discount, '56.00');
    expect(params('en').itemLine(inconsistent, 1).nameLines.join(' '),
        isNot(contains('WRONG')));
  });

  testWidgets('current API Discount column honors null title and visibility',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    ReceiptLayoutParams params(String language, bool visible) =>
        ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: [
            {
              'product_name': 'Full price item',
              'quantity': 1,
              'price': 20,
              'total_price': 20
            }
          ],
          formattedTotal: '20.00',
          discountAmount: '0.00',
          orderDate: '2026-10-10',
          orderNumber: 'CURRENT-DISCOUNT-CONFIG',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          billDocumentConfig: DocumentConfig.fromJson({
            'language': language,
            'display_configuration': {
              // Matches the supplied API response, without a custom title.
              'showDiscountColumn': {'visible': visible, 'value': null},
              // Current API key takes precedence over the old key.
              'showItemDiscount': {'visible': !visible, 'value': 'Legacy'},
              'showDiscount': {'visible': true, 'value': 'Discount عربي '},
            },
          }),
          customerCareNumber: '',
          customerCareEmail: '',
        );
    for (final language in ['en', 'ar', 'en_ar']) {
      final receipt = params(language, true);
      expect(receipt.showItemDiscountColumn, isTrue);
      final column = receipt.itemColumns
          .firstWhere((column) => column.key == 'showItemDiscount');
      expect(column.label.english, language == 'en' ? 'Discount' : '');
      if (language != 'en') expect(column.label.arabic, 'الخصم');
      expect(receipt.itemLines.single.discount, '0.00');
      expect(
          receipt.billDocumentConfig.toJson()['display_configuration']
              ['showDiscountColumn'],
          {'visible': true, 'value': null, 'default': null});
      expect(params(language, false).showItemDiscountColumn, isFalse);
      expect(params(language, false).isVisible('showDiscount'), isTrue);
    }
  });
}
