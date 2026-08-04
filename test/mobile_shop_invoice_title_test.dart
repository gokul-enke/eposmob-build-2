import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/mobile_shop_tax_invoice_receipt_layout.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

void main() {
  group('mobile-shop B2B/B2C invoice title', () {
    testWidgets('uses each customer segment configured value', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final config = DocumentConfig(
        language: 'en',
        displayConfiguration: DisplayConfiguration(
          options: {
            'showInvoiceTitle': DisplayOption(
              visible: true,
              value: 'SIMPLIFIED TAX INVOICE',
              defaultValue: 'B2C DEFAULT MUST NOT WIN',
            ),
            'showInvoiceTitleB2B': DisplayOption(
              visible: true,
              value: 'TAX INVOICE',
              defaultValue: 'B2B DEFAULT MUST NOT WIN',
            ),
          },
        ),
      );

      final b2cParams = _params(
        context,
        config: config,
        customerType: 'B2C',
      );
      final b2bParams = _params(
        context,
        config: config,
        customerType: 'B2B',
      );

      expect(
        resolveMobileShopInvoiceTitle(
          option: b2cParams.displayConfig?['showInvoiceTitle'],
          fallbackTitle: 'APP TITLE',
        ),
        'SIMPLIFIED TAX INVOICE',
      );
      expect(
        resolveMobileShopInvoiceTitle(
          option: b2bParams.displayConfig?['showInvoiceTitle'],
          fallbackTitle: 'APP TITLE',
        ),
        'TAX INVOICE',
      );
    });

    testWidgets('honors a document title override stored in value',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final config = DocumentConfig(
        language: 'en',
        displayConfiguration: DisplayConfiguration(
          options: {
            'showInvoiceTitle': DisplayOption(
              visible: true,
              value: 'SIMPLIFIED TAX INVOICE',
              defaultValue: 'DEFAULT TITLE',
            ),
          },
        ),
      );
      final params = _params(
        context,
        config: config,
        customerType: 'B2C',
        documentTitleOverride: 'CREDIT NOTE',
      );

      expect(
        resolveMobileShopInvoiceTitle(
          option: params.displayConfig?['showInvoiceTitle'],
          fallbackTitle: 'APP TITLE',
        ),
        'CREDIT NOTE',
      );
    });

    test('derives the matching Arabic companion title', () {
      expect(
        resolveMobileShopArabicInvoiceTitle('SIMPLIFIED TAX INVOICE'),
        'فاتورة ضريبية مبسطة',
      );
      expect(
        resolveMobileShopArabicInvoiceTitle('TAX INVOICE'),
        'فاتورة ضريبية',
      );
    });
  });
}

ReceiptLayoutParams _params(
  BuildContext context, {
  required DocumentConfig config,
  required String customerType,
  String? documentTitleOverride,
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: const [],
    formattedTotal: '0.00',
    orderDate: '2026-08-01T00:00:00Z',
    orderNumber: 'TEST-1',
    isFromLocalStorage: false,
    selectedPaperSize: '80mm',
    billDocumentConfig: config,
    customerCareNumber: '',
    customerCareEmail: '',
    customerType: customerType,
    documentTitleOverride: documentTitleOverride,
  );
}
