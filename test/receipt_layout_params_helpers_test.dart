import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

/// Shared one-line helpers every receipt/PDF template calls instead of
/// re-implementing visibility, label and value rules locally. The option
/// shapes mirror the three API responses: `en` sends only `value`, while `ar`
/// and `en_ar` send Arabic in `value` and English in `default`.
DisplayOption _option(String language, String english, String arabic,
    {bool visible = true}) {
  return language == 'en'
      ? DisplayOption(visible: visible, value: english)
      : DisplayOption(visible: visible, value: arabic, defaultValue: english);
}

ReceiptLayoutParams _params(
  BuildContext context, {
  required String language,
  required Map<String, DisplayOption> options,
  String? storePhone,
  String customerCareNumber = '',
  String? customerPhone,
  bool isDefaultCustomer = false,
  bool hideDefaultCustomerPhone = true,
  String? numberPrefix,
  String? terms,
  String? footer,
  String orderNumber = '2-03-260916-0001',
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: const <dynamic>[],
    formattedTotal: '0.00',
    orderDate: '2026-01-01T00:00:00Z',
    orderNumber: orderNumber,
    isFromLocalStorage: false,
    selectedPaperSize: '80mm',
    billDocumentConfig: DocumentConfig(
      language: language,
      numberPrefix: numberPrefix,
      terms: terms,
      footer: footer,
      displayConfiguration: DisplayConfiguration(options: options),
    ),
    customerCareNumber: customerCareNumber,
    customerCareEmail: '',
    storePhone: storePhone,
    customerPhone: customerPhone,
    isDefaultCustomer: isDefaultCustomer,
    hideDefaultCustomerPhone: hideDefaultCustomerPhone,
  );
}

void main() {
  late BuildContext context;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        Builder(builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        }),
      );

  testWidgets('store contact prints the configured label with the store value',
      (tester) async {
    await pump(tester);

    String tel(String language, {String? storePhone = '0500', bool v = true}) =>
        _params(
          context,
          language: language,
          storePhone: storePhone,
          customerCareNumber: '920000',
          options: {'showTel': _option(language, 'Tel', 'هاتف', visible: v)},
        ).storeContactText('showTel');

    expect(tel('en'), 'Tel: 0500');
    expect(tel('ar'), 'هاتف: 0500');
    expect(tel('en_ar'), 'هاتف / Tel: 0500');
    expect(tel('en', storePhone: null), 'Tel: 920000',
        reason: 'customer-care number is the fallback value');
    expect(tel('en', v: false), isEmpty);

    final noValue = _params(context, language: 'en', options: {
      'showTel': _option('en', 'Tel', 'هاتف'),
    });
    expect(noValue.storeContactText('showTel'), isEmpty,
        reason: 'no orphan label without a phone number');
  });

  testWidgets('customer phone honours toggle, walk-in hiding and masking',
      (tester) async {
    await pump(tester);

    ReceiptLayoutParams build(Map<String, DisplayOption> options,
            {bool isDefault = false}) =>
        _params(context,
            language: 'en',
            options: options,
            customerPhone: '0501234567',
            isDefaultCustomer: isDefault);

    final visible = {'showCustomerPhone': DisplayOption(visible: true)};
    expect(build(visible).customerPhoneText, '0501234567');
    expect(build(const {}).customerPhoneText, isEmpty);
    expect(build(visible, isDefault: true).customerPhoneText, isEmpty);

    for (final maskKey in ['showCustomerPhoneMasked', 'maskCustomerPhone']) {
      final masked =
          build({...visible, maskKey: DisplayOption(visible: true)})
              .customerPhoneText;
      expect(masked, isNot('0501234567'), reason: maskKey);
      expect(masked, endsWith('4567'), reason: maskKey);
    }
  });

  testWidgets('invoice number keeps the literal prefix exactly once',
      (tester) async {
    await pump(tester);

    expect(
      _params(context, language: 'en_ar', options: const {}, numberPrefix: 'INV-')
          .invoiceNumberText,
      'INV-2-03-260916-0001',
    );
    expect(
      _params(context, language: 'en', options: const {}).invoiceNumberText,
      'INV-2-03-260916-0001',
    );
    expect(
      _params(context, language: 'ar', options: const {}).invoiceNumberText,
      startsWith('رقم الفاتورة:'),
    );
  });

  testWidgets('terms and thank-you text resolve identically for every template',
      (tester) async {
    await pump(tester);

    ReceiptLayoutParams build(String language,
            {bool configured = true,
            bool visible = true,
            String? terms,
            String? footer}) =>
        _params(context, language: language, terms: terms, footer: footer,
            options: {
              'showTermsConditions': configured
                  ? _option(language, 'EN TERMS', 'الشروط', visible: visible)
                  : DisplayOption(visible: visible),
              'showThankYouMessage': configured
                  ? _option(language, 'EN THANKS', 'شكراً', visible: visible)
                  : DisplayOption(visible: visible),
            });

    expect(build('en').termsText, 'EN TERMS');
    expect(build('ar').termsText, 'الشروط');
    expect(build('en_ar').termsText, 'الشروط\nEN TERMS');
    expect(build('en', visible: false, terms: 'Doc terms').termsText, isEmpty);
    expect(build('en', configured: false, terms: 'Doc terms').termsText,
        'Doc terms');
    expect(build('en', configured: false).termsText, isEmpty);

    expect(build('en', footer: 'Doc footer').thankYouText, 'EN THANKS',
        reason: 'the document footer is only a fallback');
    expect(build('en_ar').thankYouText, 'شكراً\nEN THANKS');
    expect(build('en', configured: false, footer: 'Doc footer').thankYouText,
        'Doc footer');
    expect(build('en_ar', configured: false, footer: 'تذييل').thankYouText,
        contains('تذييل'),
        reason: 'an Arabic-only footer must not vanish in bilingual mode');
    expect(build('en', configured: false).thankYouText,
        'Thank You for Your Visit!');
    expect(build('ar', configured: false).thankYouText, 'شكراً لزيارتكم!');
    expect(build('en', visible: false, footer: 'Doc footer').thankYouText,
        isEmpty);
  });

  testWidgets('amount-in-words language follows the normalized mode',
      (tester) async {
    await pump(tester);
    String code(String language) =>
        _params(context, language: language, options: const {})
            .amountInWordsLanguage;
    expect(code('ar'), 'ar');
    expect(code('en'), 'en');
    expect(code('en_ar'), 'en');
    expect(code('ar_en'), 'en');
  });
}
