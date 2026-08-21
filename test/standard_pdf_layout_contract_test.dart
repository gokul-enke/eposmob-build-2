import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

const _themes = <String>[
  'classic',
  'simplified_tax_invoice',
  'centered_simplified_tax_invoice',
  'bilingual_centered_tax_invoice',
  'boxed_bilingual_tax_invoice',
  'boxed_header_tax_invoice',
];

const _languageModes = <String, ReceiptLanguageMode>{
  'en': ReceiptLanguageMode.english,
  'ar': ReceiptLanguageMode.arabic,
  'en_ar': ReceiptLanguageMode.bilingual,
};

/// Avoid AppSettingsProvider's production network fetch in renderer tests.
class _OfflineAppSettingsProvider extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

Map<String, DisplayOption> _options({required bool visible}) {
  return <String, DisplayOption>{
    for (final key in ReceiptConfigurationContract.canonicalBillKeys)
      key: DisplayOption(
        visible: visible,
        value: 'عربي $key',
        defaultValue: 'English $key',
      ),
  };
}

DocumentConfig _config({
  required String theme,
  required String language,
  required Map<String, DisplayOption> options,
}) {
  return DocumentConfig(
    activeTheme: theme,
    language: language,
    showLogo: 0,
    header: 'English header',
    subheader: 'عنوان فرعي',
    numberPrefix: 'INV-',
    terms: 'English terms',
    footer: 'English footer',
    displayConfiguration: DisplayConfiguration(options: options),
  );
}

ReceiptLayoutParams _params({
  required BuildContext context,
  required String theme,
  required String language,
  required String paperSize,
  required Map<String, DisplayOption> options,
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    // The standard PDF layouts deliberately support both API-style maps and
    // model objects. This map covers both snake_case and camelCase names used
    // by the production readers and exercises dynamic source extraction.
    cartItems: <dynamic>[
      <String, dynamic>{
        'productName': 'Dynamic Widget',
        'product_name': 'عنصر ديناميكي',
        'productNames': <String, dynamic>{
          'en': 'Dynamic Widget',
          'ar': 'عنصر ديناميكي',
        },
        'product_names': <String, dynamic>{
          'en': 'Dynamic Widget',
          'ar': 'عنصر ديناميكي',
        },
        'names': <String, dynamic>{
          'en': 'Dynamic Widget',
          'ar': 'عنصر ديناميكي',
        },
        'mrp': 100.0,
        // The legacy local-storage path reads quantity as a String before
        // parsing it; other layouts accept either representation.
        'quantity': '2',
        'unitPrice': 50.0,
        'unit_price': 50.0,
        'discount': 5.0,
        'discount_amount': 5.0,
        'taxAmount': 9.0,
        'tax_amount': 9.0,
        'totalPrice': 104.0,
        'total_price': 104.0,
        'variantAttributes': <String, dynamic>{'size': 'M'},
        'variant_attributes': <String, dynamic>{'size': 'M'},
      },
    ],
    formattedTotal: '104.00',
    savedTotal: '1.00',
    discountAmount: '5.00',
    orderDate: '2026-01-01T00:00:00Z',
    orderNumber: 'INV-1001',
    tokenNumber: 'T-7',
    isFromLocalStorage: true,
    selectedPaperSize: paperSize,
    billDocumentConfig: _config(
      theme: theme,
      language: language,
      options: options,
    ),
    customerCareNumber: '+91 90000 00000',
    customerCareEmail: 'care@example.test',
    customerName: 'Dynamic Customer',
    customerPhone: '+91 91111 11111',
    customerEmail: 'customer@example.test',
    customerAddress: '1 Test Street',
    customerOldBalance: 10.0,
    customerCurrentBalance: 4.0,
    paidAmount: 100.0,
    orderComment: 'Dynamic order comment',
    deliveryMethod: 'Delivery',
    deliveryPhone: '+91 92222 22222',
    customerAlternatePhone: '+91 93333 33333',
    paymentMethod: 'Cash',
    customerVatNumber: 'VAT-CUSTOMER',
    customerCrNumber: 'CR-CUSTOMER',
    customerType: 'B2C',
    paymentBreakdown: <String, dynamic>{
      'isMultiPayment': true,
      'amounts': <String, dynamic>{'Cash': 54.0, 'Card': 50.0},
    },
    zatcaVatNumber: 'VAT-STORE',
    zatcaCrNumber: 'CR-STORE',
    zatcaCompanyName: 'Dynamic Store',
    isDefaultCustomer: false,
    hideDefaultCustomerPhone: false,
    netExcTax: '95.00',
  );
}

Widget _providerHarness({required void Function(BuildContext) onContext}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppSettingsProvider>.value(
        value: _OfflineAppSettingsProvider(),
      ),
      ChangeNotifierProvider<PaymentGatewaysProvider>.value(
        value: PaymentGatewaysProvider(),
      ),
    ],
    child: Builder(
      builder: (context) {
        onContext(context);
        return const SizedBox.shrink();
      },
    ),
  );
}

String _standardLayoutSource(String theme) {
  const files = <String, String>{
    'classic': 'classic_standard_pdf_layout.dart',
    'simplified_tax_invoice': 'simplified_tax_invoice_standard_pdf_layout.dart',
    'centered_simplified_tax_invoice':
        'centered_simplified_tax_invoice_standard_pdf_layout.dart',
    'bilingual_centered_tax_invoice':
        'bilingual_centered_tax_invoice_standard_pdf_layout.dart',
    'boxed_bilingual_tax_invoice':
        'boxed_bilingual_tax_invoice_standard_pdf_layout.dart',
    'boxed_header_tax_invoice':
        'boxed_header_tax_invoice_standard_pdf_layout.dart',
  };
  return File(
    'lib/screens/print/standard_layouts/${files[theme]}',
  ).readAsStringSync();
}

void main() {
  test('factory exposes exactly the six standard PDF themes', () {
    expect(StandardPdfLayoutFactory.availableThemes, orderedEquals(_themes));
    expect(StandardPdfLayoutFactory.availableThemes.toSet(), hasLength(6));
    for (final theme in _themes) {
      final layout = StandardPdfLayoutFactory.getLayout(theme);
      expect(layout.layoutId, theme);
      expect(layout.displayName.trim(), isNotEmpty, reason: theme);
    }
  });

  test('language aliases normalize to the three renderer modes', () {
    const expected = <String, ReceiptLanguageMode>{
      'en': ReceiptLanguageMode.english,
      'English': ReceiptLanguageMode.english,
      'eng': ReceiptLanguageMode.english,
      'ar': ReceiptLanguageMode.arabic,
      'Arabic': ReceiptLanguageMode.arabic,
      'ara': ReceiptLanguageMode.arabic,
      'en_ar': ReceiptLanguageMode.bilingual,
      'ar_en': ReceiptLanguageMode.bilingual,
      'en-ar': ReceiptLanguageMode.bilingual,
      'ar/en': ReceiptLanguageMode.bilingual,
      'en+ar': ReceiptLanguageMode.bilingual,
      'English Arabic': ReceiptLanguageMode.bilingual,
      'bilingual': ReceiptLanguageMode.bilingual,
      'dual': ReceiptLanguageMode.bilingual,
      'dual_language': ReceiptLanguageMode.bilingual,
    };
    for (final entry in expected.entries) {
      expect(
        ReceiptConfigurationContract.languageMode(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
    expect(ReceiptConfigurationContract.languageMode(null),
        ReceiptLanguageMode.english);
    expect(ReceiptConfigurationContract.languageMode('unsupported'),
        ReceiptLanguageMode.english);
  });

  testWidgets('all 61 keys obey strict visibility and aliases', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_providerHarness(onContext: (value) {
      context = value;
    }));

    final missing = _params(
      context: context,
      theme: 'classic',
      language: 'en_ar',
      paperSize: 'A4',
      options: const <String, DisplayOption>{},
    );
    final allVisibleOptions = _options(visible: true);
    final allVisible = _params(
      context: context,
      theme: 'classic',
      language: 'en_ar',
      paperSize: 'A4',
      options: allVisibleOptions,
    );
    final allHidden = _params(
      context: context,
      theme: 'classic',
      language: 'en_ar',
      paperSize: 'A4',
      options: _options(visible: false),
    );

    expect(ReceiptConfigurationContract.canonicalBillKeys, hasLength(61));
    expect(
        ReceiptConfigurationContract.canonicalBillKeys.toSet(), hasLength(61));
    for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
      expect(missing.isVisible(key), isFalse, reason: 'missing/$key');
      expect(allVisible.isVisible(key), isTrue, reason: 'visible/$key');
      expect(allHidden.isVisible(key), isFalse, reason: 'hidden/$key');
    }

    expect(
      ReceiptConfigurationContract.isVisible(
        <String, DisplayOption>{
          'showMRPTotal': DisplayOption(visible: true),
        },
        'showTotalMRP',
      ),
      isTrue,
    );
    expect(
      ReceiptConfigurationContract.isVisible(
        <String, DisplayOption>{
          'showMRPTotal': DisplayOption(visible: false),
        },
        'showTotalMRP',
      ),
      isFalse,
    );
  });

  testWidgets(
      'every standard PDF theme builds a non-empty A4/A5 PDF for EN/AR/bilingual',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_providerHarness(onContext: (value) {
      context = value;
    }));

    for (final theme in _themes) {
      for (final language in _languageModes.entries) {
        for (final paper in const ['A4', 'A5']) {
          final params = _params(
            context: context,
            theme: theme,
            language: language.key,
            paperSize: paper,
            // Keep QR hidden so this contract test cannot invoke any external
            // image/payment source. Dynamic cart/order data remains enabled.
            options: <String, DisplayOption>{
              ..._options(visible: true),
              'showQRCode': DisplayOption(visible: false),
            },
          );
          final layout = StandardPdfLayoutFactory.getLayout(theme);
          expect(params.receiptLanguageMode, language.value,
              reason: '$theme/${language.key}/$paper/mode');

          final document = await layout.buildPdfDocument(params);
          final bytes = await document.save();
          expect(bytes, isNotEmpty,
              reason: '$theme/${language.key}/$paper/bytes');
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
              reason: '$theme/${language.key}/$paper/header');
        }
      }
    }
  });

  test('PDF themes expose a real document builder and no printer invocation',
      () {
    for (final theme in _themes) {
      final layout = StandardPdfLayoutFactory.getLayout(theme);
      expect(layout.buildPdfDocument, isA<Function>(), reason: theme);
      final source = _standardLayoutSource(theme);
      expect(source.contains('buildPdfDocument'), isTrue, reason: theme);
      expect(source.contains('generateAndPrintPdf'), isTrue, reason: theme);

      // Factory coverage alone is not sufficient: callers in older screens
      // can still instantiate a historical class directly.  Each legacy
      // entry point must therefore delegate exactly once to the shared
      // contract implementation.
      expect(
        RegExp(r'StandardPdfContractDelegate\.generateAndPrintPdf\(')
            .allMatches(source)
            .length,
        1,
        reason: '$theme direct generate guard',
      );
      expect(
        RegExp(r'StandardPdfContractDelegate\.buildPdfDocument\(')
            .allMatches(source)
            .length,
        1,
        reason: '$theme direct build guard',
      );
    }
  });
}
