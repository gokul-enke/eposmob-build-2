import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/premium2_bilingual_receipt_layout.dart';
import 'package:pos_machine/screens/print/layouts/premium_receipt_layout.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_factory.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

/// The factory is the production boundary for receipt themes.  Keep this list
/// explicit so adding/removing a theme forces an intentional contract review.
const _productionThemes = <String>[
  'classic',
  'premium',
  'premium1',
  'premium2',
  'premium2_bilingual',
  'supermarket_en',
  'standard',
  'arabic_and_english',
  'arabic_english_table_headers',
  'arabic_and_english_3',
  'supermarket',
  'supermarket2',
  'supermarket2_bilingual',
  'supermarkerrecpt3',
  'bilingual',
  'multi_store',
  'mobile_shop_tax_invoice',
];

const _languageModes = <String, ReceiptLanguageMode>{
  'en': ReceiptLanguageMode.english,
  'ar': ReceiptLanguageMode.arabic,
  'en_ar': ReceiptLanguageMode.bilingual,
};

const _legacyLayoutFiles = <String>[
  'classic_receipt_layout.dart',
  'bilingual_receipt_layout.dart',
  'arabic_and_english_recipt_layput.dart',
  'arabic_english_table_headers_receipt_layout.dart',
  'arabic_and_english_3_receipt_layout.dart',
  'premium1_receipt_layout.dart',
  'premium2_receipt_layout.dart',
  'supermarket_en_receipt_layout.dart',
  'supermarket_receipt_layout.dart',
  'supermarket2_receipt_layout.dart',
  'supermarket2_bilingual_receipt_layout.dart',
  'supermarket3_receipt_layout.dart',
  'multi_store_receipt_layout.dart',
  'mobile_shop_tax_invoice_receipt_layout.dart',
];

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

ReceiptLayoutParams _params({
  required BuildContext context,
  required String theme,
  required String language,
  required Map<String, DisplayOption> options,
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: const <dynamic>[],
    formattedTotal: '0.00',
    orderDate: '2026-01-01T00:00:00Z',
    orderNumber: '1',
    isFromLocalStorage: false,
    selectedPaperSize: '80mm',
    billDocumentConfig: DocumentConfig(
      activeTheme: theme,
      language: language,
      displayConfiguration: DisplayConfiguration(options: options),
    ),
    customerCareNumber: '',
    customerCareEmail: '',
  );
}

String _rendererSource(String theme) {
  final layout = ReceiptLayoutFactory.getLayout(theme);
  final file = layout is Premium2BilingualReceiptLayout
      ? 'lib/screens/print/layouts/premium2_bilingual_receipt_layout.dart'
      : layout is PremiumReceiptLayout
          ? 'lib/screens/print/layouts/premium_receipt_layout.dart'
          : 'lib/screens/print/layouts/standard_receipt_layout.dart';
  return File(file).readAsStringSync();
}

int _firstCallOffset(String source, String call) {
  final match = RegExp(RegExp.escape(call)).firstMatch(source);
  return match?.start ?? -1;
}

void main() {
  test('factory exposes the complete 17-theme production matrix', () {
    expect(
        ReceiptLayoutFactory.availableThemes, orderedEquals(_productionThemes));
    expect(ReceiptLayoutFactory.availableThemes.toSet().length,
        _productionThemes.length);

    for (final theme in _productionThemes) {
      final layout = ReceiptLayoutFactory.getLayout(theme);
      expect(layout.layoutId, theme);
      expect(layout.displayName.trim(), isNotEmpty, reason: theme);
    }
  });

  testWidgets(
      'every theme carries all 61 keys through EN, AR and bilingual params',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );

    for (final theme in _productionThemes) {
      // Instantiating the exact factory product is part of this matrix.  The
      // test intentionally does not call printThermal: that would connect to
      // a device and require every provider/image asset in a unit test.
      final layout = ReceiptLayoutFactory.getLayout(theme);
      expect(layout.layoutId, theme);

      for (final mode in _languageModes.entries) {
        final params = _params(
          context: context,
          theme: theme,
          language: mode.key,
          options: _options(visible: true),
        );

        expect(params.receiptLanguageMode, mode.value,
            reason: '$theme/${mode.key}');
        expect(params.activeTheme, theme);
        for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
          expect(params.isVisible(key), isTrue,
              reason: '$theme/${mode.key}/$key');
        }

        expect(
          params.labelFor(
            'showStoreName',
            englishFallback: 'Fallback EN',
            arabicFallback: 'احتياطي',
          ),
          switch (mode.value) {
            ReceiptLanguageMode.english => 'English showStoreName',
            ReceiptLanguageMode.arabic => 'عربي showStoreName',
            ReceiptLanguageMode.bilingual =>
              'عربي showStoreName\nEnglish showStoreName',
          },
          reason: '$theme/${mode.key}/label',
        );
      }
    }
  });

  testWidgets('missing keys stay hidden for every factory theme',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );

    for (final theme in _productionThemes) {
      final params = _params(
        context: context,
        theme: theme,
        language: 'en_ar',
        options: <String, DisplayOption>{},
      );
      for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
        expect(params.isVisible(key), isFalse, reason: '$theme/$key');
      }
    }
  });

  test('all registered renderer families keep canonical section order', () {
    // These are the calls in printThermal, not merely the order of helper
    // declarations later in each large renderer source file.
    const requiredOrder = <String>[
      '_buildHeaderSection',
      '_buildCustomerSection',
      '_buildCartItemsSection',
      '_buildTotalsSection',
      '_buildReturnSection',
      '_buildFooterSection',
    ];

    for (final theme in _productionThemes) {
      final source = _rendererSource(theme);
      var previous = -1;
      for (final call in requiredOrder) {
        final offset = _firstCallOffset(source, call);
        expect(offset, greaterThanOrEqualTo(0), reason: '$theme/$call');
        expect(offset, greaterThan(previous), reason: '$theme/$call');
        previous = offset;
      }
    }
  });

  test('shared renderer families reference every canonical Bill key', () {
    final sources = <String, String>{
      'standard': File('lib/screens/print/layouts/standard_receipt_layout.dart')
          .readAsStringSync(),
      'premium': File('lib/screens/print/layouts/premium_receipt_layout.dart')
          .readAsStringSync(),
      'premium2_bilingual': File(
              'lib/screens/print/layouts/premium2_bilingual_receipt_layout.dart')
          .readAsStringSync(),
    };

    for (final entry in sources.entries) {
      for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
        // B2B title is intentionally merged into showInvoiceTitle by
        // ReceiptLayoutParams so the renderer consumes one canonical switch.
        if (key == 'showInvoiceTitleB2b') continue;
        expect(entry.value.contains(key), isTrue, reason: '${entry.key}/$key');
      }
    }
  });

  test('direct legacy layout entry points cannot bypass the contract delegate',
      () {
    for (final fileName in _legacyLayoutFiles) {
      final source =
          File('lib/screens/print/layouts/$fileName').readAsStringSync();
      expect(
        RegExp(r'ReceiptContractDelegate\.printThermal\(').allMatches(source),
        hasLength(1),
        reason: '$fileName/printThermal',
      );
      expect(
        RegExp(r'ReceiptContractDelegate\.buildPdf\(').allMatches(source),
        hasLength(1),
        reason: '$fileName/buildPdf',
      );
      expect(
        RegExp(r'ReceiptContractDelegate\.printThermalNative\(')
            .allMatches(source),
        hasLength(1),
        reason: '$fileName/printThermalNative',
      );
    }
  });

  test('every contract alias preserves strict visibility semantics', () {
    for (final alias in ReceiptConfigurationContract.aliases.entries) {
      final options = <String, DisplayOption>{
        alias.value.first: DisplayOption(visible: true),
      };
      expect(ReceiptConfigurationContract.isVisible(options, alias.key), isTrue,
          reason: alias.key);
      expect(
        ReceiptConfigurationContract.isVisible(
          <String, DisplayOption>{
            alias.value.first: DisplayOption(visible: false),
          },
          alias.key,
        ),
        isFalse,
        reason: alias.key,
      );
    }
  });
}
