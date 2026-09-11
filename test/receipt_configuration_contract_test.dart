import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_factory.dart';

void main() {
  group('DisplayOption API parsing', () {
    test('normalizes legacy boolean encodings used by cached configurations',
        () {
      for (final value in <dynamic>[true, 1, '1', 'true', 'yes', 'on']) {
        expect(DisplayOption.fromJson({'visible': value}).visible, isTrue,
            reason: '$value');
      }
      for (final value in <dynamic>[false, 0, '0', 'false', 'no', 'off']) {
        expect(DisplayOption.fromJson({'visible': value}).visible, isFalse,
            reason: '$value');
      }
      expect(DisplayOption.fromJson({'visible': null}).visible, isNull);
    });
  });

  group('ReceiptLanguageMode normalization', () {
    test('accepts the mapped English and Arabic settings', () {
      expect(ReceiptConfigurationContract.languageMode('en'),
          ReceiptLanguageMode.english);
      expect(ReceiptConfigurationContract.languageMode('ar'),
          ReceiptLanguageMode.arabic);
      expect(ReceiptConfigurationContract.languageMode('en_ar'),
          ReceiptLanguageMode.bilingual);
      expect(ReceiptConfigurationContract.languageMode('ar_en'),
          ReceiptLanguageMode.bilingual);
    });

    test('keeps unset language compatible with existing English fallback', () {
      expect(ReceiptConfigurationContract.languageMode(null),
          ReceiptLanguageMode.english);
      expect(ReceiptConfigurationContract.languageMode('unknown'),
          ReceiptLanguageMode.english);
    });
  });

  group('Bill configuration contract', () {
    test('contains the complete supplied 61-key Bill contract', () {
      expect(ReceiptConfigurationContract.canonicalBillKeys.length, 61);
      expect(
        ReceiptConfigurationContract.canonicalBillKeys.toSet().length,
        61,
      );
    });

    test('resolves aliases and requires explicit visibility', () {
      final options = <String, DisplayOption>{
        'showMRPTotal': DisplayOption(visible: true, value: 'الإجمالي'),
        'showNetAmount': DisplayOption(visible: false, value: 'الصافي'),
      };
      expect(ReceiptConfigurationContract.isVisible(options, 'showTotalMRP'),
          isTrue);
      expect(ReceiptConfigurationContract.isVisible(options, 'showNetTotal'),
          isFalse);
      expect(
        ReceiptConfigurationContract.isVisible(options, 'showDiscount'),
        isFalse,
      );
    });

    test('supports a one-key visibility toggle for every canonical key', () {
      for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
        final enabled = <String, DisplayOption>{
          key: DisplayOption(visible: true),
        };
        final disabled = <String, DisplayOption>{
          key: DisplayOption(visible: false),
        };
        expect(ReceiptConfigurationContract.isVisible(enabled, key), isTrue,
            reason: key);
        expect(ReceiptConfigurationContract.isVisible(disabled, key), isFalse,
            reason: key);
      }
    });

    test('supports all-visible and all-hidden configurations', () {
      final allVisible = <String, DisplayOption>{
        for (final key in ReceiptConfigurationContract.canonicalBillKeys)
          key: DisplayOption(visible: true),
      };
      final allHidden = <String, DisplayOption>{
        for (final key in ReceiptConfigurationContract.canonicalBillKeys)
          key: DisplayOption(visible: false),
      };

      for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
        expect(ReceiptConfigurationContract.isVisible(allVisible, key), isTrue,
            reason: key);
        expect(ReceiptConfigurationContract.isVisible(allHidden, key), isFalse,
            reason: key);
      }
    });
  });

  group('configured labels', () {
    final options = <String, DisplayOption>{
      'showStoreName': DisplayOption(
        visible: true,
        value: 'متجر الاختبار',
        defaultValue: 'Test Store',
      ),
    };

    test('selects independent English and Arabic values', () {
      expect(
        ReceiptConfigurationContract.label(
          options: options,
          key: 'showStoreName',
          mode: ReceiptLanguageMode.english,
          englishFallback: 'Fallback EN',
          arabicFallback: 'احتياطي',
        ),
        'Test Store',
      );
      expect(
        ReceiptConfigurationContract.label(
          options: options,
          key: 'showStoreName',
          mode: ReceiptLanguageMode.arabic,
          englishFallback: 'Fallback EN',
          arabicFallback: 'احتياطي',
        ),
        'متجر الاختبار',
      );
      expect(
        ReceiptConfigurationContract.label(
          options: options,
          key: 'showStoreName',
          mode: ReceiptLanguageMode.bilingual,
          englishFallback: 'Fallback EN',
          arabicFallback: 'احتياطي',
        ),
        'متجر الاختبار\nTest Store',
      );
    });

    test('prints Arabic-only configuration on an English document', () {
      // Stores run an English template and still localize individual fields in
      // Arabic. The renderer fallback is a placeholder for keys left empty, not
      // a language filter, so configured text must survive. This previously
      // asserted the opposite ('Fallback EN'), which contradicted the shipped
      // behaviour and masked the resolved-label regression below.
      final arabicOnly = <String, DisplayOption>{
        'showStoreName': DisplayOption(
          visible: true,
          value: 'متجر الاختبار',
          defaultValue: 'متجر الاختبار',
        ),
      };
      expect(
        ReceiptConfigurationContract.label(
          options: arabicOnly,
          key: 'showStoreName',
          mode: ReceiptLanguageMode.english,
          englishFallback: 'Fallback EN',
          arabicFallback: 'احتياطي',
        ),
        'متجر الاختبار',
      );
    });

    test('configured value outranks a resolved master label', () {
      // Regression: resolved_labels.tax mirrors showTaxHeader ("TAX"), yet
      // every renderer also passes it as showTax's resolved label. Ranked above
      // the store's own value it replaced the configured "ضريبة" with "TAX" on
      // an English document, so the settings preview disagreed with the print.
      final options = <String, DisplayOption>{
        'showTax': DisplayOption(visible: true, value: 'ضريبة'),
      };
      expect(
        ReceiptConfigurationContract.label(
          options: options,
          key: 'showTax',
          mode: ReceiptLanguageMode.english,
          resolvedArabic: 'TAX',
          englishFallback: 'VAT',
          arabicFallback: 'الضريبة',
        ),
        'ضريبة',
      );
    });

    test('still uses the resolved master label when the key is unconfigured',
        () {
      expect(
        ReceiptConfigurationContract.label(
          options: const <String, DisplayOption>{},
          key: 'showTax',
          mode: ReceiptLanguageMode.english,
          resolvedEnglish: 'Sales Tax',
          englishFallback: 'VAT',
          arabicFallback: 'الضريبة',
        ),
        'Sales Tax',
      );
    });

    test('supports legacy English-only values stored in value', () {
      final englishOnly = <String, DisplayOption>{
        'showStoreName': DisplayOption(visible: true, value: 'Legacy Store'),
      };
      expect(
        ReceiptConfigurationContract.label(
          options: englishOnly,
          key: 'showStoreName',
          mode: ReceiptLanguageMode.english,
          englishFallback: 'Fallback EN',
          arabicFallback: 'متجر',
        ),
        'Legacy Store',
      );
    });

    test('does not synthesize a bilingual secondary label when value is empty',
        () {
      final englishOnlyField = <String, DisplayOption>{
        'showCustomerName': DisplayOption(
          visible: true,
          defaultValue: 'Customer',
        ),
      };

      expect(
        ReceiptConfigurationContract.label(
          options: englishOnlyField,
          key: 'showCustomerName',
          mode: ReceiptLanguageMode.bilingual,
          englishFallback: 'Fallback customer',
          arabicFallback: 'العميل',
        ),
        'Customer',
      );
    });

    test('keeps the primary English fallback when both API labels are empty',
        () {
      expect(
        ReceiptConfigurationContract.label(
          options: const {},
          key: 'showTax',
          mode: ReceiptLanguageMode.bilingual,
          englishFallback: '',
          arabicFallback: 'الضريبة',
          resolvedArabic: 'ضريبة المبيعات',
        ),
        'VAT',
      );
    });

    test('keeps the secondary label when bilingual value is configured', () {
      expect(
        ReceiptConfigurationContract.label(
          options: {
            'showCustomerName': DisplayOption(
              visible: true,
              value: 'العميل',
              defaultValue: 'Customer',
            ),
          },
          key: 'showCustomerName',
          mode: ReceiptLanguageMode.bilingual,
          englishFallback: 'Fallback customer',
          arabicFallback: 'اسم العميل',
        ),
        'العميل\nCustomer',
      );
    });
  });

  test(
      'bilingual document text keeps a configured script and adds its counterpart',
      () {
    final output = ReceiptConfigurationContract.documentText(
      'عنوان عربي',
      ReceiptLanguageMode.bilingual,
      englishFallback: 'English heading',
    );
    expect(output, 'عنوان عربي\nEnglish heading');
    expect(
      ReceiptConfigurationContract.documentText(
        null,
        ReceiptLanguageMode.bilingual,
        englishFallback: 'English heading',
        arabicFallback: 'عنوان عربي',
      ),
      'عنوان عربي\nEnglish heading',
    );
  });

  group('invoice number prefix', () {
    test('preserves the configured prefix literally in bilingual mode', () {
      expect(
        ReceiptConfigurationContract.numberPrefix(
          'ع-',
          ReceiptLanguageMode.bilingual,
          englishFallback: 'INV-',
          arabicFallback: 'رقم الفاتورة: ',
        ),
        'ع-',
      );
    });

    test('uses only the primary fallback when the prefix is missing', () {
      expect(
        ReceiptConfigurationContract.numberPrefix(
          null,
          ReceiptLanguageMode.bilingual,
          englishFallback: 'INV-',
          arabicFallback: 'رقم الفاتورة: ',
        ),
        'INV-',
      );
    });
  });

  test('every registered thermal theme is routed through a contract layout',
      () {
    for (final theme in ReceiptLayoutFactory.availableThemes) {
      final layout = ReceiptLayoutFactory.getLayout(theme);
      expect(layout.layoutId, theme);
    }
    expect(ReceiptLayoutFactory.availableThemes.length, 17);
  });
}
