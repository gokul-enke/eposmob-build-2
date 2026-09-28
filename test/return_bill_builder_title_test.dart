import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/return_bill_layout_params_builder.dart';

class _Settings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

void main() {
  testWidgets('return builder preserves configured B2B title when base title is blank',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext context;
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AppSettingsProvider>(create: (_) => _Settings()),
      ChangeNotifierProvider<BankProvider>(create: (_) => BankProvider()),
      ChangeNotifierProvider<StoreSessionProvider>(create: (_) => StoreSessionProvider()),
    ], child: MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    }))));
    for (final language in ['en', 'ar', 'en_ar']) {
      for (final visible in [false, true]) {
        final params = await ReturnBillLayoutParamsBuilder.build(
          context: context, selectedPrinter: BluetoothPrinter.development(),
          returnItems: const [], returnTotalAmount: '0,021.00',
          orderDate: '2026-09-26', orderNumber: 'QA-VERIFY', selectedPaperSize: 'A4',
          originalInvoiceNumber: 'SALE-789', originalInvoiceDate: '2026-08-20',
          customerType: 'B2B', customerVatNumber: '300000000000003',
          returnBillDocumentConfig: DocumentConfig.fromJson({
            'language': language,
            'display_configuration': {
              'showInvoiceTitle': {'visible': visible, 'value': '', 'default': ''},
              'showInvoiceTitleB2b': {'visible': visible,
                'value': language == 'en' ? 'Business return' : 'مرتجع تجاري',
                'default': language == 'en_ar' ? 'Business return' : ''},
            },
          }),
        );
        expect(params.formattedTotal, '21.00');
        expect(params.originalInvoiceNumber, 'SALE-789');
        expect(params.originalInvoiceDate, '2026-08-20');
        expect(params.returnTotalValue, 21);
        if (!visible) {
          expect(params.invoiceTitleText, isEmpty);
        } else {
          expect(params.invoiceTitleText, contains(
              language == 'en' ? 'Business return' : 'مرتجع تجاري'));
          if (language == 'en_ar') {
            expect(params.invoiceTitleText, contains('Business return'));
          }
        }
      }
    }
  });
}
