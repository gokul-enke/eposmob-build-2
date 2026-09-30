import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/layouts/common/layout_rows.dart';
import 'package:pos_machine/screens/print/layouts/common/return_metadata_rows.dart';

void main() {
  test(
      'return allocations survive model serialization, including explicit zero',
      () {
    final item = OrderReturnItem.fromJson({
      'tax_amount': 1.25,
      'taxable_value': 0,
      'sub_total': 20,
      'quantity': 2,
    });
    final restored = OrderReturnItem.fromJson(item.toJson());
    expect(restored.taxAmount, '1.25');
    expect(restored.taxableValue, '0');
    expect(restored.subTotal, '20');
    expect(
        OrderReturnItem.fromJson({}).toJson().containsKey('tax_amount'), false);
    expect(OrderReturnItem.fromJson({}).toJson().containsKey('taxable_value'),
        false);
    expect(
        OrderReturnItem.fromJson({}).toJson().containsKey('sub_total'), false);
  });

  testWidgets(
      'return tax columns obey language and independent switches without guessing allocations',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    ReceiptLayoutParams params(String language, bool tax, bool taxable,
            {String? taxAmount,
            String? taxableValue,
            String? subTotal,
            bool subtotal = false,
            bool returnOnly = true,
            bool englishFilled = true,
            bool dense = false}) =>
        ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: const [
            {'tax_amount': '999', 'quantity': 100}
          ],
          formattedTotal: '21',
          orderDate: '2026-09-29',
          orderNumber: 'RETURN-1',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          customerCareNumber: '',
          customerCareEmail: '',
          isReturnOnly: returnOnly,
          orderReturns: OrderReturns(returnTotalAmount: '21', returnItems: [
            OrderReturnItem(
                quantity: 2,
                unitPrice: '10.5',
                taxRate: '18',
                taxAmount: taxAmount,
                taxableValue: taxableValue,
                subTotal: subTotal),
          ]),
          billDocumentConfig: DocumentConfig.fromJson({
            'type': 'Return Bill',
            'language': language,
            'display_configuration': {
              if (dense)
                for (final key in [
                  'showReturnSLNumber',
                  'showReturnParticulars',
                  'showReturnMRP',
                  'showHsnCode',
                  'showTaxRateColumn',
                  'showUnitPrice',
                  'showReturnQty',
                  'showReturnRate',
                  'showReturnTotal'
                ])
                  key: {'visible': true, 'value': key},
              'showSubTotal': {
                'visible': subtotal,
                'value':
                    language == 'en' ? 'Refund subtotal' : 'المجموع الفرعي',
                'default': englishFilled ? 'Refund subtotal' : ''
              },
              'showTaxAmountColumn': {
                'visible': tax,
                'value': language == 'en' ? 'Refund tax' : 'ضريبة المرتجع',
                'default': englishFilled ? 'Refund tax' : ''
              },
              'showTaxableColumn': {
                'visible': taxable,
                'value': language == 'en'
                    ? 'Refund taxable value'
                    : 'القيمة الخاضعة',
                'default': englishFilled ? 'Refund taxable value' : ''
              },
            },
          }),
        );

    for (final language in ['en', 'ar', 'en_ar']) {
      for (final tax in [false, true]) {
        for (final taxable in [false, true]) {
          for (final english in [false, true]) {
            final p = params(language, tax, taxable, englishFilled: english);
            final section = p.returnsSection!;
            expect(section.columns.any((c) => c.key == 'showTaxAmountColumn'),
                tax);
            expect(section.columns.any((c) => c.key == 'showTaxableColumn'),
                taxable);
            for (final column in section.columns) {
              final text = '${column.label.arabic}${column.label.english}';
              expect(text.contains('Refund'),
                  language == 'en' || (language == 'en_ar' && english));
              expect(RegExp(r'[؀-ۿ]').hasMatch(text), language != 'en');
            }
            expect(section.lines.single['showTaxAmountColumn'], '');
            expect(section.lines.single['showTaxableColumn'], '');
            expect(p.returnTotalValue, 21);
          }
        }
      }
    }
    final sparseRows = <ReceiptRow>[];
    expect(
        appendDenseReturnItemRows(sparseRows, params('en', true, true),
            scale: 1, gap: 4),
        false);
    expect(sparseRows, isEmpty);
    for (final language in ['en', 'ar', 'en_ar']) {
      final p = params(language, true, true,
          dense: true,
          taxAmount: '0',
          taxableValue: '20.35',
          subTotal: '20.35',
          subtotal: true);
      final rows = <ReceiptRow>[];
      expect(appendDenseReturnItemRows(rows, p, scale: 1, gap: 4), true);
      final dataRows = rows.whereType<MultiLineReceiptTableRow>().toList();
      expect(dataRows.length, p.returnsSection!.columns.length);
      for (var i = 0; i < dataRows.length; i++) {
        final valueCell = language == 'en'
            ? dataRows[i].columns.last
            : dataRows[i].columns.first;
        final key = p.returnsSection!.columns[i].key;
        if (key != 'showReturnParticulars') {
          expect(valueCell.text, p.returnsSection!.lines.single[key],
              reason: 'Dense rows must preserve the label/value pairing');
        }
        expect(valueCell.weight, 0.38);
      }
      expect(p.returnTotalValue, 21);
    }
    for (final entry in <String?, String>{
      null: '',
      '': '',
      'invalid': '',
      'NaN': '',
      'Infinity': '',
      '0': '0.00',
      '1,234.56': '1234.56',
      '-1.25': '-1.25',
    }.entries) {
      final p = params('en', true, true,
          taxAmount: entry.key,
          taxableValue: entry.key,
          subTotal: entry.key,
          subtotal: true);
      expect(
          p.returnsSection!.lines.single['showTaxAmountColumn'], entry.value);
      expect(p.returnsSection!.lines.single['showTaxableColumn'], entry.value);
      expect(p.returnsSection!.lines.single['showSubTotal'], entry.value);
      expect(p.returnTotalValue, 21,
          reason: 'Column values cannot change the supplied refund');
    }
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final visible in [false, true]) {
        for (final returnOnly in [false, true]) {
          for (final english in [false, true]) {
            final p = params(language, false, false,
                subtotal: visible,
                returnOnly: returnOnly,
                englishFilled: english);
            final columns = p.returnsSection!.columns
                .where((column) => column.key == 'showSubTotal')
                .toList();
            expect(columns.isNotEmpty, visible && returnOnly,
                reason:
                    'The sales summary switch must not add a combined-return column');
            if (columns.isNotEmpty) {
              final label =
                  '${columns.single.label.arabic}${columns.single.label.english}';
              expect(label.contains('Refund'),
                  language == 'en' || (language == 'en_ar' && english));
              expect(RegExp(r'[؀-ۿ]').hasMatch(label), language != 'en');
            }
            expect(p.returnsSection!.lines.single['showSubTotal'], '');
            expect(p.returnTotalValue, 21);
          }
        }
      }
    }
  });
}
