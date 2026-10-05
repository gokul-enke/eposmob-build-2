import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/services/print_service.dart';

/// The shared field-text helpers every template (thermal and A4/A5 PDF) uses.
/// The fixture follows the bilingual audit brief: every option carries an
/// Arabic `value` except a few left empty, and only the item-table header
/// options also carry a typed English `default`.

const _itemHeaderDefaults = {
  'showSLNumber': 'No',
  'showParticulars': 'Item',
  'showQty': 'Qty',
  'showRate': 'Rate',
  'showUnit': 'Unit',
  'showTaxHeader': 'Tax',
  'showTotal': 'Total',
};

const _emptyValueKeys = {
  'showCustomerName',
  'showCustomerAddress',
  'showPayment',
  'showDate',
  'showBankInfo',
  'showBankName',
  'showAccountName',
  'showAccountNumber',
  'showIBAN',
  'showSwiftCode',
};

Map<String, DisplayOption> _auditOptions() => {
      for (final key in ReceiptConfigurationContract.canonicalBillKeys)
        key: DisplayOption(
          visible: key != 'showCustomerPhoneMasked',
          value: _emptyValueKeys.contains(key) ? null : 'عربي $key',
          defaultValue: _itemHeaderDefaults[key],
        ),
    };

ReceiptLayoutParams _params(
  BuildContext context, {
  required String language,
  Map<String, DisplayOption>? options,
  Map<String, dynamic>? paymentBreakdown,
  String? paymentMethod = 'CASH',
  double? paidAmount = 100,
  List<dynamic> cartItems = const [],
  String? numberPrefix,
  String? savedTotal,
  String? netExcTax,
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: cartItems,
    formattedTotal: '100.00',
    savedTotal: savedTotal,
    netExcTax: netExcTax,
    orderDate: '2026-09-24T09:40:00Z',
    orderNumber: 'ORD-000015',
    tokenNumber: '286',
    isFromLocalStorage: true,
    selectedPaperSize: 'A4',
    billDocumentConfig: DocumentConfig(
      language: language,
      numberPrefix: numberPrefix,
      displayConfiguration:
          DisplayConfiguration(options: options ?? _auditOptions()),
    ),
    customerCareNumber: '',
    customerCareEmail: '',
    paymentMethod: paymentMethod,
    paymentBreakdown: paymentBreakdown,
    paidAmount: paidAmount,
    customerOldBalance: 10,
    customerCurrentBalance: 4,
    zatcaVatNumber: '300000000000003',
    zatcaCrNumber: '1010101010',
    bankDetails: const [
      StoreBank(
        bankName: 'Al Rajhi Bank',
        status: 1,
        bankAccounts: [
          StoreBankAccount(
            accountHolderName: 'FUNZCART',
            accountNumber: '30312312',
            iban: 'SA03',
            swiftCode: 'RJHISARI',
          ),
        ],
      ),
    ],
  );
}

bool _hasArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

void main() {
  late BuildContext context;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        Builder(builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        }),
      );

  testWidgets('MRP and ex-tax subtotal retain separate labels, amounts and switches',
      (tester) async {
    await pump(tester);
    for (final subtotal in [false, true]) {
      for (final mrp in [false, true]) {
        final params = _params(context, language: 'en_ar',
            savedTotal: '20', netExcTax: '90', options: {
          'showSubTotal': DisplayOption(visible: subtotal,
              value: 'صافي', defaultValue: 'EX TAX'),
          'showMRPTotal': DisplayOption(visible: mrp,
              value: 'تجزئة', defaultValue: 'RETAIL'),
        });
        final rows = params.totalsRows.where((r) =>
            r.key == 'showSubTotal' || r.key == 'showMRPTotal').toList();
        expect(rows.map((r) => r.key), [
          if (subtotal) 'showSubTotal', if (mrp) 'showMRPTotal',
        ]);
        expect(rows.map((r) => r.amount), [
          if (subtotal) 90.0, if (mrp) 120.0,
        ]);
        expect(rows.map((r) => r.label.english), [
          if (subtotal) 'EX TAX', if (mrp) 'RETAIL',
        ]);
      }
    }
  });

  testWidgets('token labels ending in digits cannot merge with the token value',
      (tester) async {
    await pump(tester);
    for (final language in ['en', 'ar', 'en_ar']) {
      final params = _params(context, language: language, options: {
        'showTokenNumber': DisplayOption(visible: true,
            value: language == 'en' ? 'Counter 8' : 'عداد 8',
            defaultValue: ''),
      });
      expect(params.tokenText, endsWith(': 286'));
      expect(params.tokenText, isNot(contains('8286')));
    }
    expect(_params(context, language: 'en', options: {
      'showTokenNumber': DisplayOption(visible: true, value: '#'),
    }).tokenText, '#286');
  });

  testWidgets(
      'en_ar: only typed English defaults reach the English slot; the rest '
      'print Arabic', (tester) async {
    await pump(tester);
    final params = _params(context, language: 'en_ar');

    for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
      final parts = params.fieldLabelParts(key);
      expect(parts.english, _itemHeaderDefaults[key] ?? '', reason: key);
      if (!_emptyValueKeys.contains(key)) {
        expect(parts.arabic, 'عربي $key', reason: key);
      }
    }

    // Keys the store left empty print the built-in Arabic fallback.
    expect(params.fieldLabelParts('showCustomerName').arabic, 'العميل');
    expect(params.fieldLabelParts('showPayment').arabic, 'الدفع');
    expect(params.fieldLabelParts('showBankInfo').arabic, 'تفاصيل البنك');
    // No date label unless the store or resolved_labels supply one.
    expect(params.fieldLabelParts('showDate').isEmpty, isTrue);

    // Every row helper stays Arabic.
    for (final row in params.bankDetailRows) {
      expect(_hasArabic(row.$1), isTrue, reason: row.$1);
    }
    expect(params.bankDetailsHeading, 'تفاصيل البنك');
    // Payment methods print their untranslated code (user decision).
    for (final row in params.paymentBreakdownRows) {
      expect(row.$1, 'CASH');
    }
    for (final row in params.customerBalanceRows) {
      expect(_hasArabic(row.$1), isTrue, reason: row.$1);
    }
    expect(params.tokenText, 'عربي showTokenNumber: 286');
    expect(params.vatFooterText, 'عربي showVATFooter 300000000000003');
    expect(params.orderNumberFooterText, 'عربي showOrderNumberInFooter 15');
    expect(params.storeTaxText('showCRNumber'), 'عربي showCRNumber: 1010101010');
    expect(params.qrCaption, 'عربي showQRCode');
    expect(params.rendererText(english: 'Page', arabic: 'صفحة'), 'صفحة');
  });

  testWidgets('item headers stack the Arabic value over the typed default',
      (tester) async {
    await pump(tester);
    final params = _params(context, language: 'en_ar');
    expect(params.fieldLabel('showQty'), 'عربي showQty\nQty');
    expect(params.fieldLabelParts('showQty').arabic, 'عربي showQty');
    expect(params.fieldLabelParts('showQty').english, 'Qty');
    // Rate Ex Tax has no typed default: Arabic only, never "RATE EX TAX".
    expect(params.fieldLabel('showRateExcTax'), 'عربي showRateExcTax');
  });

  testWidgets('English and Arabic documents fill only their own slot',
      (tester) async {
    await pump(tester);
    final english = _params(context, language: 'en', options: {
      'showQty': DisplayOption(visible: true, value: 'الكمية', defaultValue: 'Qty'),
      'showCustomerName': DisplayOption(visible: true),
    });
    expect(english.fieldLabelParts('showQty').english, 'Qty');
    expect(english.fieldLabelParts('showQty').arabic, '');
    expect(english.fieldLabel('showCustomerName'), 'Customer');

    final arabic = _params(context, language: 'ar', options: {
      'showQty': DisplayOption(visible: true, value: 'الكمية', defaultValue: 'Qty'),
      'showCustomerName': DisplayOption(visible: true),
    });
    expect(arabic.fieldLabelParts('showQty').arabic, 'الكمية');
    expect(arabic.fieldLabelParts('showQty').english, '');
    expect(arabic.fieldLabel('showCustomerName'), 'العميل');
  });

  testWidgets('payment rows print each method by its untranslated code',
      (tester) async {
    await pump(tester);
    for (final language in ['en', 'ar', 'en_ar']) {
      final single = _params(context, language: language);
      expect(single.paymentBreakdownRows, [('CASH', 100.0)]);
      expect(single.paymentMethodSummary, 'CASH');

      final multi = _params(
        context,
        language: language,
        paymentBreakdown: {'CASH': 60.0, 'Card': 40.0, 'BANK': 0},
      );
      expect(multi.paymentBreakdownRows, [('CASH', 60.0), ('CARD', 40.0)]);
      expect(multi.paymentMethodSummary, 'CASH, CARD');
    }

    final english = _params(
      context,
      language: 'en',
      paymentBreakdown: {'isMultiPayment': true, 'amounts': {'CASH': 60.0}},
    );
    expect(english.paymentBreakdownRows, [('CASH', 60.0)]);

    final noPaid = _params(context, language: 'en', paidAmount: null);
    expect(noPaid.paymentBreakdownRows, isEmpty);
  });

  testWidgets('the on-account amount prints as CREDIT whatever its key',
      (tester) async {
    await pump(tester);
    // Billing stores it as DEBIT; server orders may say CREDIT or BALANCE.
    for (final key in ['DEBIT', 'CREDIT', 'BALANCE']) {
      for (final language in ['en', 'ar', 'en_ar']) {
        final params = _params(
          context,
          language: language,
          paidAmount: 60,
          paymentBreakdown: {'CASH': 60.0, key: 40.0},
        );
        expect(params.paymentBreakdownRows.last, ('CREDIT', 40.0));
        expect(params.paymentMethodSummary, endsWith(', CREDIT'));
      }
    }
  });

  testWidgets('a local sale prints the Arabic item name like a server order',
      (tester) async {
    await pump(tester);
    final item = PrintService.savedOrderReceiptItem(LocalCartItem(
      product: GetProduct(
        productId: 1,
        productName: '3D BALL SMALL',
        names: const {'en': '3D BALL SMALL', 'ar': 'كرة صغيرة'},
        price: ProductPrice(price: '5'),
      ),
      quantity: 1,
      price: 5,
    ));

    expect(_params(context, language: 'en_ar').itemNameLines(item),
        ['كرة صغيرة', '3D BALL SMALL']);
    expect(_params(context, language: 'ar').itemNameLines(item), ['كرة صغيرة']);
    expect(_params(context, language: 'en').itemNameLines(item),
        ['3D BALL SMALL']);
  });

  testWidgets('item names follow the document language', (tester) async {
    await pump(tester);
    final item = <String, dynamic>{
      'product_name': 'Milk',
      'names': {'en': 'Milk', 'ar': 'حليب'},
      'variant_attributes': {'size': '1L'},
    };
    List<String> lines(String language) =>
        _params(context, language: language).itemNameLines(item);

    expect(lines('en_ar'), ['حليب', 'Milk (1L)']);
    expect(lines('ar'), ['حليب (1L)']);
    expect(lines('en'), ['Milk (1L)']);
    expect(
      _params(context, language: 'ar').itemNameLines({'product_name': 'Kitkat'}),
      ['Kitkat'],
    );
  });

  testWidgets('typed return items retain variants once in every language', (tester) async {
    await pump(tester);
    for (final language in ['en', 'ar', 'en_ar']) {
      final params = _params(context, language: language);
      for (final name in ['Coffee', 'Coffee (Large | Blue)']) {
        final item = OrderReturnItem(productName: name,
            variantAttributes: {'Size': 'Large', 'Colour': 'Blue'});
        expect(params.itemNameLines(item), ['Coffee (Large | Blue)']);
      }
      expect(params.itemNameLines(OrderReturnItem(productName: 'Tea')),
          ['Tea']);
    }
  });

  testWidgets('order date/time is one left-to-right value', (tester) async {
    await pump(tester);
    final text = _params(context, language: 'ar').orderDateTimeText;
    expect(_hasArabic(text), isFalse);
    expect(text, contains('2026'));
    expect(text.split('  '), hasLength(2));
  });

  test('labelled strips a typed trailing colon before joining', () {
    expect(ReceiptConfigurationContract.labelled('الكمية:', '3'), 'الكمية: 3');
    expect(ReceiptConfigurationContract.labelled('', '3'), '3');
  });
}
