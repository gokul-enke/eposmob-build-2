import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/list_sales_return.dart';
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
  testWidgets('return builder distinguishes missing total from explicit zero',
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
      for (final entry in {
        '': 21.0, 'invalid': 21.0, 'NaN': 21.0, 'Infinity': 21.0,
        '-Infinity': 21.0, '0': 0.0, '1,200.50': 1200.50,
      }.entries) {
        final params = await ReturnBillLayoutParamsBuilder.build(
          context: context, selectedPrinter: BluetoothPrinter.development(),
          returnItems: [
            OrderReturnItem(quantity: 1, unitPrice: '11'),
            OrderReturnItem(quantity: 2, unitPrice: '5'),
          ], returnTotalAmount: entry.key,
          orderDate: '', orderNumber: '758', selectedPaperSize: 'A4',
          returnBillDocumentConfig: DocumentConfig.fromJson({
            'language': language, 'display_configuration': {
              for (final key in ['showReturnTotalAmount', 'showReturnNetAmount',
                'showReturnAmountInWords']) key: {'visible': true},
            },
          }),
        );
        expect(params.orderReturns!.returnTotalAmount, entry.key);
        expect(params.formattedTotal, entry.value.toStringAsFixed(2));
        expect(params.returnTotalValue, entry.value);
        expect(params.returnsSection!.totalRows.map((r) => r.$2),
            [entry.value, entry.value]);
        expect(params.returnsWordsLines('SAR'),
            params.amountInWordsLines(entry.value, currency: 'SAR'));
      }
    }
    final originalCart = await ReturnBillLayoutParamsBuilder.build(
      context: context, selectedPrinter: BluetoothPrinter.development(),
      returnItems: [OrderReturnItem(cartItemId: 13386, quantity: 2)],
      originalCartItems: [OrderDetailsModelDataCartItem(id: 13386,
          quantity: 7, unitPrice: '180', mrp: '200')],
      returnTotalAmount: '', orderDate: '', orderNumber: '758',
      selectedPaperSize: 'A4', returnBillDocumentConfig: DocumentConfig(),
    );
    expect(originalCart.formattedTotal, '360.00');
    expect(originalCart.returnTotalValue, 360,
        reason: 'Use returned quantity with the matching original unit price');
    expect(SalesReturnOrder.fromJson({}).totalAmount, isEmpty,
        reason: 'Transaction parsing must preserve a missing refund total');
    expect(SalesReturnOrder.fromJson({'total_amount': 0}).totalAmount, '0');
  });
}
