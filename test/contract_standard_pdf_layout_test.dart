import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';

void main() {
  testWidgets('all standard themes build the normalized A4/A5 PDF path',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox.shrink();
        },
      ),
    );

    final options = <String, DisplayOption>{
      for (final key in ReceiptConfigurationContract.canonicalBillKeys)
        key: DisplayOption(
          visible: true,
          value: 'عربي $key',
          defaultValue: 'English $key',
        ),
    };
    final params = ReceiptLayoutParams(
      context: context,
      selectedPrinter: BluetoothPrinter.development(),
      cartItems: const [
        {
          'product_name': 'Test item',
          'quantity': 2,
          'unit_price': '10.00',
          'total_price': '20.00',
          'tax_amount': '2.00',
          'currency': 'SAR',
          'product_unit': 'pcs',
        },
      ],
      formattedTotal: '22.00',
      orderDate: '2026-01-01T00:00:00Z',
      orderNumber: 'INV-1',
      isFromLocalStorage: false,
      selectedPaperSize: 'A5',
      billDocumentConfig: DocumentConfig(
        language: 'en_ar',
        displayConfiguration: DisplayConfiguration(options: options),
      ),
      customerCareNumber: '123',
      customerCareEmail: 'support@example.test',
      storeName: 'Contract Store',
      storeLocation: 'Address',
      storePhone: '555',
      storeEmail: 'store@example.test',
      customerName: 'Customer',
      paidAmount: 22,
      paymentMethod: 'CASH',
    );

    for (final theme in StandardPdfLayoutFactory.availableThemes) {
      final document = await StandardPdfLayoutFactory
          .getLayout(theme)
          .buildPdfDocument(params);
      final bytes = await document.save();
      expect(bytes.length, greaterThan(500), reason: theme);
    }
  });
}

