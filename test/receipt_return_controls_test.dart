import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';

void main() {
  testWidgets('credit-note controls govern metadata even with resolved labels',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    ReceiptLayoutParams params(
            {bool invoice = false,
            bool reason = false,
            bool customer = false,
            bool subtitle = false,
            bool signatory = false,
            bool customerGstin = false,
            bool unitPrice = false,
            bool rate = false,
            bool originalInvoice = false,
            String? originalNumber = 'SALE-789',
            String? originalDate = '2026-08-20',
            String language = 'en',
            String? originalLabel,
            String? englishOriginalLabel,
            bool returnOnly = true,
            bool itemCount = false,
            bool mrpTotal = false,
            String? mrp = '12',
            bool hsn = false,
            bool taxRateColumn = false,
            String? taxRate = '18.000',
            List<num> quantities = const [1],
            String unitPriceValue = '11',
            String customerName = 'Customer',
            Map<String, String> labels = const {}}) =>
        ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: const [],
          formattedTotal: '11',
          orderDate: '2026-09-26',
          orderNumber: 'ORD-123',
          originalInvoiceNumber: originalNumber,
          originalInvoiceDate: originalDate,
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          customerCareNumber: '',
          customerCareEmail: '',
          customerName: customerName,
          customerPhone: '5551234567',
          customerAddress: 'Address',
          customerVatNumber: '300000000000003',
          isReturnOnly: returnOnly,
          orderReturns: OrderReturns(returnTotalAmount: '11', returnItems: [
            for (final quantity in quantities) OrderReturnItem(
                productName: 'Coffee', quantity: quantity, reason: 'Damaged',
                mrp: mrp,
                hsnCode: '0090121', taxRate: taxRate,
                unitPrice: unitPriceValue),
          ]),
          billDocumentConfig: DocumentConfig.fromJson({
            'type': 'Return Bill',
            'template': 'credit_note',
            'language': language,
            'display_configuration': {
              'showInvoiceNumber': {'visible': invoice},
              'showOriginalInvoice': {'visible': originalInvoice,
                'value': originalLabel, 'default': englishOriginalLabel},
              'showReturnItemsCount': {'visible': itemCount, 'value': 'Returned units'},
              'showMRPTotal': {'visible': mrpTotal, 'value': 'Returned MRP'},
              'showHsnCode': {'visible': hsn, 'value': 'Classification'},
              'showTaxRateColumn': {'visible': taxRateColumn, 'value': 'Tax percentage'},
              'showInvoiceTitle': {'visible': true},
              'showCreditNoteReason': {'visible': reason},
              'showCustomerNameAndPhone': {'visible': customer},
              'showReturnTotal': {'visible': true},
              'showReturnAmountInWords': {'visible': true},
              'showGstSubtitle': {'visible': subtitle},
              'showAuthorizedSignatory': {'visible': signatory},
              'showCustomerGstin': {'visible': customerGstin},
              'showUnitPrice': {'visible': unitPrice, 'value': 'Unit cost'},
              'showReturnRate': {'visible': rate, 'value': 'Rate'},
            },
            'resolved_labels': {
              'credit_note_number': 'Credit Note No.',
              'credit_note_date': 'Credit Note Date',
              'credit_note_reason': 'Reason',
              'customer_heading': 'CUSTOMER DETAILS',
              ...labels,
            },
          }),
        );
    expect(params().returnsSection!.creditNoteRows, isEmpty);
    expect(params().returnsSection!.countRow, isNull);
    expect(params().returnMrpTotalRow, isNull);
    for (final hsn in [false, true]) {
      for (final tax in [false, true]) {
        final section = params(hsn: hsn, taxRateColumn: tax).returnsSection!;
        expect(section.columns.any((c) => c.key == 'showHsnCode'), hsn);
        expect(section.columns.any((c) => c.key == 'showTaxRateColumn'), tax);
        expect(section.lines.single['showHsnCode'], '0090121');
        expect(section.lines.single['showTaxRateColumn'], '18%');
      }
    }
    for (final rate in <String?, String>{null: '', 'invalid': '', 'NaN': '', 'Infinity': '', '-1': '', '0': '0%', '5.5': '5.5%'}.entries) {
      expect(params(taxRate: rate.key).returnsSection!.lines.single['showTaxRateColumn'], rate.value);
    }
    expect(params(returnOnly: false, mrpTotal: true).returnMrpTotalRow, isNull);
    for (final entry in <String?, double>{'12': 21, '0': 0, '1,200': 2100, null: 19.25}.entries) {
      final p = params(mrpTotal: true, mrp: entry.key, quantities: [1.5, .25]);
      expect(p.returnMrpTotalRow, ('Returned MRP', entry.value));
      expect(p.returnsSection!.totalRows.first, p.returnMrpTotalRow);
      expect(p.returnTotalValue, 11, reason: 'MRP must not change the explicit refund');
    }
    for (final quantities in <List<num>>[[2, 1], [1.5, 0.25], [0, 0]]) {
      final expected = quantities.reduce((a, b) => a + b);
      final row = params(itemCount: true, quantities: quantities,
          labels: {'credit_note_items_count': 'Server fallback'})
          .returnsSection!.countRow!;
      expect(row.$1, 'Returned units');
      expect(num.parse(row.$2), expected);
      expect(params(returnOnly: false, itemCount: true, quantities: quantities)
          .returnsSection!.countRow!.$2, '2');
    }
    expect(params(originalInvoice: true).returnsSection!.creditNoteRows, [
      ('Original Invoice', 'SALE-789'),
      ('Invoice Date', '20-08-2026'),
    ]);
    expect(params(originalInvoice: true, invoice: true)
        .returnsSection!.creditNoteRows, hasLength(4));
    expect(params(originalInvoice: true, originalNumber: ' ', originalDate: null)
        .returnsSection!.creditNoteRows, isEmpty);
    expect(params(originalInvoice: true, originalNumber: null)
        .returnsSection!.creditNoteRows, [('Invoice Date', '20-08-2026')]);
    expect(params(originalInvoice: true, originalDate: null, labels: {
      'credit_note_order': 'Source sale',
    }).returnsSection!.creditNoteRows, [('Source sale', 'SALE-789')]);
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final english in ['Source sale', '']) {
        final row = params(originalInvoice: true, originalDate: null,
          language: language,
          originalLabel: language == 'en' ? 'Source sale' : 'الفاتورة الأصلية',
          englishOriginalLabel: english,
        ).returnsSection!.creditNoteRows.single;
        expect(row.$2, 'SALE-789');
        expect(row.$1.contains('Source sale'),
            language == 'en' || (language == 'en_ar' && english.isNotEmpty));
        expect(row.$1.contains('الفاتورة الأصلية'), language != 'en');
      }
    }
    for (final unitPrice in [false, true]) {
      for (final rate in [false, true]) {
        for (final value in ['11', '0']) {
          final section = params(unitPrice: unitPrice, rate: rate,
              unitPriceValue: value).returnsSection!;
          final keys = section.columns.map((c) => c.key).toList();
          expect(keys.contains('showUnitPrice'), unitPrice);
          expect(keys.contains('showReturnRate'), rate);
          expect(section.lines.single['showUnitPrice'],
              double.parse(value).toStringAsFixed(2));
          expect(section.lines.single['showUnitPrice'],
              section.lines.single['showReturnRate']);
          if (unitPrice) {
            expect(section.columns.singleWhere((c) => c.key == 'showUnitPrice')
                .label.english, 'Unit cost');
          }
        }
      }
    }
    expect(params().invoiceTitleText, 'CREDIT NOTE');
    expect(params(invoice: true).returnsSection!.creditNoteRows, hasLength(2));
    expect(params(reason: true).returnsSection!.creditNoteRows,
        [('Reason', 'Damaged')]);
    expect(params(customer: true).returnsSection!.customerRows.map((r) => r.$2),
        ['Customer', '5551234567', 'Address']);
    expect(params().returnsSection!.customerRows, isEmpty);
    expect(params(customer: true, customerName: '').returnsSection!.customerRows.map((r) => r.$2),
        ['5551234567', 'Address']);
    expect(params(customer: true, customerGstin: true, labels: {'customer_gstin': 'Customer tax ID'})
        .returnsSection!.customerRows.last, ('Customer tax ID', '300000000000003'));
    expect(params(customerGstin: true).returnsSection!.customerRows, isEmpty);
    final custom = params(customer: true, labels: {
      'customer_name': 'ER20X',
      'customer_phone': 'ER21X',
      'billing_address': 'ER22X',
      'grand_total_header': 'ER40X',
      'amount_in_words': 'ER51X',
    });
    expect(custom.returnsSection!.customerRows.map((r) => r.$1),
        ['ER20X', 'ER21X', 'ER22X']);
    expect(custom.returnsSection!.columns.single.label.english, 'ER40X');
    expect(custom.returnsSection!.wordsHeading, 'ER51X');
    expect(custom.billDocumentConfig.resolvedLabels!.toJson()['customer_name'],
        'ER20X');
    const extraLabels = {'subtitle': 'Subtitle marker', 'signatory': 'Signatory marker'};
    final hiddenExtras = params(labels: extraLabels).returnsSection!;
    expect(hiddenExtras.subtitle, isEmpty);
    expect(hiddenExtras.signatory, isEmpty);
    final visibleExtras = params(subtitle: true, signatory: true,
        labels: extraLabels).returnsSection!;
    expect(visibleExtras.subtitle, 'Subtitle marker');
    expect(visibleExtras.signatory, 'Signatory marker');
  });
}
