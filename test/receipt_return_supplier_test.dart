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
  testWidgets('return supplier metadata uses available values and independent controls',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    ReceiptLayoutParams params(String language,
        {bool visible = true, bool gstin = true, bool available = true,
        bool returnOnly = true}) => ReceiptLayoutParams(
      context: context,
      selectedPrinter: BluetoothPrinter.development(),
      cartItems: const [],
      formattedTotal: '20',
      orderDate: '2026-09-29',
      orderNumber: 'RETURN-SUPPLIER',
      isFromLocalStorage: false,
      selectedPaperSize: '80mm',
      customerCareNumber: '',
      customerCareEmail: '',
      isReturnOnly: returnOnly,
      zatcaCompanyName: available ? 'QA Supplier' : '',
      zatcaVatNumber: available ? 'QA-VAT-123' : null,
      storeLocation: available ? 'QA Address' : null,
      orderReturns: OrderReturns(returnTotalAmount: '20', returnItems: [
        OrderReturnItem(productName: 'Item', quantity: 1, unitPrice: '20'),
      ]),
      billDocumentConfig: DocumentConfig.fromJson({
        'type': 'Return Bill', 'language': language,
        'display_configuration': {
          'showSupplierDetails': {
            'visible': visible,
            'value': language == 'en' ? 'Supplier heading' : 'بيانات المورد',
            'default': '',
          },
          'showSupplierGstin': {
            'visible': gstin,
            'value': language == 'en' ? 'Supplier VAT' : 'ضريبة المورد',
            'default': '',
          },
        },
        'resolved_labels': {
          'company_name': language == 'en' ? 'Supplier company' : 'اسم الشركة',
          'address': language == 'en' ? 'Supplier address' : 'عنوان المورد',
        },
      }),
    );
    for (final language in ['en', 'ar', 'en_ar']) {
      final p = params(language);
      final section = p.returnsSection!;
      expect(section.supplierRows.map((row) => row.$2),
          ['QA Supplier', 'QA Address', 'QA-VAT-123']);
      final labels = [section.supplierHeading,
        ...section.supplierRows.map((row) => row.$1)].join(' ');
      expect(labels.contains('Supplier'), language == 'en');
      expect(RegExp(r'[\u0600-\u06ff]').hasMatch(labels), language != 'en');
      expect(labels.contains('State'), false);
      final rows = <ReceiptRow>[];
      appendReturnMetadataRows(rows, p, scale: 1, gap: 4);
      final cells = rows.whereType<MultiLineReceiptTableRow>()
          .expand((row) => row.columns).map((cell) => cell.text);
      expect(cells, containsAll(['QA Supplier', 'QA Address', 'QA-VAT-123']));
      expect(params(language, gstin: false).returnsSection!.supplierRows.length, 2);
      for (final hidden in [
        params(language, visible: false),
        params(language, available: false),
        params(language, returnOnly: false),
      ]) {
        expect(hidden.returnsSection!.supplierRows, isEmpty);
        expect(hidden.returnsSection!.supplierHeading, isEmpty);
      }
      expect(p.returnTotalValue, 20);
    }
  });
}
