import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/layouts/common/return_metadata_rows.dart';
import 'package:pos_machine/screens/print/layouts/common/layout_rows.dart';

void main() {
  testWidgets('return summary preserves independent controls and known allocations',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    const keys = ['showSubTotal', 'showDiscount', 'showGstBreakdown', 'showTaxRow'];
    final allocated = [
      OrderReturnItem(quantity: 1, unitPrice: '12', taxAmount: '1.25',
          taxableValue: '10', subTotal: '20', discount: '3'),
      OrderReturnItem(quantity: 2, unitPrice: '4', taxAmount: '0',
          taxableValue: '2.5', subTotal: '4', discount: '0'),
    ];
    ReceiptLayoutParams params(String language, int flags,
        {bool english = true, bool returnOnly = true,
        bool remarks = false, String? remarksText, bool taxSummary = false,
        List<OrderReturnItem>? items}) => ReceiptLayoutParams(
      context: context,
      selectedPrinter: BluetoothPrinter.development(),
      // Deliberately unrelated sale amounts must never feed return totals.
      cartItems: const [{'tax_amount': '999', 'discount': '999'}],
      formattedTotal: '999', discountAmount: '999', apiTotalTax: 999,
      netExcTax: '999',
      orderDate: '2026-09-29', orderNumber: 'SUMMARY',
      isFromLocalStorage: false, selectedPaperSize: 'A4',
      customerCareNumber: '', customerCareEmail: '',
      isReturnOnly: returnOnly,
      orderReturns: OrderReturns(returnTotalAmount: '20', returnItems: items ?? allocated),
      billDocumentConfig: DocumentConfig.fromJson({
        'type': 'Return Bill', 'language': language,
        'display_configuration': {
          'showTaxSummary': {
            'visible': taxSummary,
            'value': language == 'en' ? 'EN TAX SUMMARY' : 'ملخص الضريبة',
            'default': english ? 'EN TAX SUMMARY' : '',
          },
          'showCreditNoteRemarks': {
            'visible': remarks,
            'value': language == 'en' ? 'EN REMARKS' : 'ملاحظات',
            'default': english ? 'EN REMARKS' : '',
          },
          for (var i = 0; i < keys.length; i++) keys[i]: {
            'visible': flags & (1 << i) != 0,
            'value': language == 'en' ? 'EN SUMMARY $i' : 'ملخص $i',
            'default': english ? 'EN SUMMARY $i' : '',
          },
        },
        'resolved_labels': {
          if (remarksText != null) 'remarks_text': remarksText,
        },
      }),
    );
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final english in [true, false]) {
        for (var flags = 0; flags < 16; flags++) {
          final p = params(language, flags, english: english);
          final rows = p.returnAllocationTotalRows;
          final expected = [for (var i = 0; i < keys.length; i++)
            if (flags & (1 << i) != 0) [24.0, 3.0, 12.5, 1.25][i]];
          expect(rows.map((row) => row.$2), expected);
          for (final row in rows) {
            expect(row.$1.contains('EN SUMMARY'),
                language == 'en' || (language == 'en_ar' && english));
            expect(RegExp(r'[\u0600-\u06ff]').hasMatch(row.$1), language != 'en');
          }
          expect(p.returnsSection!.totalRows, rows);
          expect(p.returnTotalValue, 20);
          expect(params(language, flags, returnOnly: false).returnAllocationTotalRows, isEmpty);
        }
      }
    }
    final unknown = params('en', 15, items: [allocated.first, OrderReturnItem(quantity: 2)]);
    expect(unknown.returnAllocationTotalRows.map((row) => row.$2), everyElement(isNull));
    expect(unknown.returnsSection!.totalRows.length, 4,
        reason: 'Enabled labels remain visible instead of hiding missing data');
    for (final value in ['', 'bad', 'NaN', 'Infinity', '-Infinity']) {
      final p = params('en', 15, items: [OrderReturnItem(taxAmount: value,
          taxableValue: value, subTotal: value, discount: value)]);
      expect(p.returnAllocationTotalRows.map((row) => row.$2), everyElement(isNull));
    }
    final zero = params('en', 15, items: [OrderReturnItem(taxAmount: '0',
        taxableValue: '0', subTotal: '0', discount: '0')]);
    expect(zero.returnAllocationTotalRows.map((row) => row.$2), everyElement(0));
    final signed = params('en', 15, items: [OrderReturnItem(taxAmount: '-1.25',
        taxableValue: '1,234.56', subTotal: '-2', discount: '-3')]);
    expect(signed.returnAllocationTotalRows.map((row) => row.$2), [-2, -3, 1234.56, -1.25]);
    final item = OrderReturnItem.fromJson({'discount': 0});
    expect(OrderReturnItem.fromJson(item.toJson()).discount, '0');
    expect(OrderReturnItem.fromJson({}).toJson().containsKey('discount'), false);
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final english in [true, false]) {
        final body = language == 'en' ? 'QA RETURN REMARKS'
            : language == 'ar' || !english ? 'ملاحظات المرتجع'
            : 'ملاحظات المرتجع\nQA RETURN REMARKS';
        final p = params(language, 0, english: english,
            remarks: true, remarksText: body);
        final row = p.returnsSection!.remarksRow!;
        expect(row.$2, body);
        expect(row.$1.contains('EN REMARKS'),
            language == 'en' || (language == 'en_ar' && english));
        final cached = DocumentConfig.fromJson(p.billDocumentConfig.toJson());
        expect(cached.resolvedLabels?.text('remarks_text'), body);
        final rows = <ReceiptRow>[];
        appendReturnFooterRows(rows, p);
        final text = rows.whereType<TextRow>().map((row) => row.text).join('\n');
        expect(text, contains(body));
        expect(text, contains(row.$1));
        expect(params(language, 0, remarksText: body).returnsSection!.remarksRow, isNull);
        expect(params(language, 0, remarks: true, remarksText: body,
            returnOnly: false).returnsSection!.remarksRow, isNull);
        final unknown = params(language, 0, remarks: true).returnsSection!.remarksRow!;
        expect(unknown.$1, isNotEmpty);
        expect(unknown.$2, isEmpty,
            reason: 'An absent Remarks Text must not become renderer placeholder text');
      }
    }
    final grouped = [
      OrderReturnItem(taxRate: '18.000', taxableValue: '10', taxAmount: '1.25'),
      OrderReturnItem(taxRate: '0', taxableValue: '2.50', taxAmount: '0'),
      OrderReturnItem(taxRate: '18', taxableValue: '5', taxAmount: '0.75'),
    ];
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final english in [true, false]) {
        final p = params(language, 0, english: english,
            taxSummary: true, items: grouped);
        final summary = p.returnTaxSummary!;
        expect(summary.rows, [('18%', '15.00', '2.00'), ('0%', '2.50', '0.00')]);
        expect(summary.totalRow.$2, '17.50');
        expect(summary.totalRow.$3, '2.00');
        expect(summary.heading.contains('EN TAX SUMMARY'),
            language == 'en' || (language == 'en_ar' && english));
        expect(summary.headers.join().contains('Tax'), language == 'en',
            reason: 'Unconfigured bilingual table captions must not add generic English');
        expect(p.returnsSection!.totalRows, isEmpty,
            reason: 'The tax summary does not enable separate total-row controls');
        final rows = <ReceiptRow>[];
        appendReturnTaxSummaryRows(rows, p, scale: 0.85);
        final table = rows.whereType<MultiLineReceiptTableRow>().toList();
        expect(table.length, 4);
        expect(table.expand((row) => row.columns).map((cell) => cell.text),
            containsAll(['18%', '15.00', '2.00', '0%', '2.50', '0.00', '17.50']));
        expect(params(language, 15, items: grouped).returnTaxSummary, isNull);
        expect(params(language, 0, taxSummary: true, items: grouped,
            returnOnly: false).returnTaxSummary, isNull);
      }
    }
    final incomplete = params('en', 0, taxSummary: true, items: [
      grouped.first,
      OrderReturnItem(taxRate: '18', taxableValue: '5', taxAmount: 'NaN'),
      OrderReturnItem(taxRate: 'bad', taxableValue: null, taxAmount: null),
    ]).returnTaxSummary!;
    expect(incomplete.rows, [('18%', '15.00', '')]);
    expect(incomplete.totalRow.$2, '');
    expect(incomplete.totalRow.$3, '');
    final unknownRate = params('en', 0, taxSummary: true, items: [
      OrderReturnItem(taxableValue: '10', taxAmount: '1.25'),
    ]).returnTaxSummary!;
    expect(unknownRate.rows, [('', '10.00', '1.25')],
        reason: 'Missing tax rate must never be assigned zero percent');
    final missing = params('en', 0, taxSummary: true, items: [OrderReturnItem()])
        .returnTaxSummary!;
    expect(missing.rows, isEmpty);
    expect(missing.totalRow.$2, '');
    expect(missing.totalRow.$3, '');
  });
}
