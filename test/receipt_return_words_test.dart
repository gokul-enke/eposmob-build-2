import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';

void main() {
  testWidgets('final words always describe the balance regardless of visible rows',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    for (final language in ['en', 'ar', 'en_ar']) {
      for (var mask = 0; mask < 16; mask++) {
        final params = ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: const [],
          formattedTotal: '40',
          orderDate: '2026-09-26',
          orderNumber: 'QA',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          customerCareNumber: '',
          customerCareEmail: '',
          orderReturns: OrderReturns(returnTotalAmount: '21', returnItems: [
            OrderReturnItem(productName: 'Coffee', quantity: 1, unitPrice: '21'),
          ]),
          billDocumentConfig: DocumentConfig(
            language: language,
            displayConfiguration: DisplayConfiguration(options: {
              for (final entry in {
                'showFinalPurchase': 1,
                'showFinalReturn': 2,
                'showFinalNetAmount': 4,
                'showFinalAmountInWords': 8,
              }.entries)
                entry.key: DisplayOption(visible: mask & entry.value != 0),
            }),
          ),
        );
        expect(params.finalSummaryWordsLines('SAR'),
            mask & 8 == 0 ? isEmpty : params.amountInWordsLines(19, currency: 'SAR'),
            reason: '$language visibility mask $mask');
      }
    }
  });

  testWidgets('return words obey their own control independently of totals',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final visible in [true, false]) {
        final params = ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: const [],
          formattedTotal: '11',
          orderDate: '2026-09-26',
          orderNumber: 'QA',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          customerCareNumber: '',
          customerCareEmail: '',
          isReturnOnly: true,
          orderReturns: OrderReturns(returnTotalAmount: '11', returnItems: [
            OrderReturnItem(productName: 'Coffee', quantity: 1),
          ]),
          billDocumentConfig: DocumentConfig(
            language: language,
            displayConfiguration: DisplayConfiguration(options: {
              'showReturnAmountInWords': DisplayOption(
                visible: visible,
                value: language == 'en' ? 'Refund words' : 'المبلغ كتابة',
                defaultValue: '',
              ),
              'showReturnTotalAmount': DisplayOption(visible: false),
              'showReturnNetAmount': DisplayOption(visible: false),
            }),
          ),
        );
        expect(params.returnsSection!.totalRows, isEmpty);
        expect(params.returnsWordsLines('SAR').isNotEmpty, visible,
            reason: '$language visible=$visible');
        if (visible) {
          expect(params.returnsSection!.wordsHeading,
              language == 'en' ? 'Refund words' : 'المبلغ كتابة');
        }
      }
    }
  });
}
